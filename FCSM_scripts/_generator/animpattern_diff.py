# animpattern_diff.py
# Based on movepattern_diff.py
# Changes:
# - move -> animation
# - keep clone expansion
# - remove box logic
# - remove traits logic
# - unknown participates in diff normally

import argparse
import copy
import sys
from lxml import etree

PARSER = etree.XMLParser(
    remove_blank_text=True,
    encoding="SHIFT_JIS",
)

def load_xml(path):
    try:
        return etree.parse(path, PARSER).getroot()
    except Exception as e:
        print("XML load error:", e)
        sys.exit(1)

def deepcopy(node):
    return copy.deepcopy(node)

def pre_clone(root):
    groups = {}
    for node in root:
        if node.tag != "animation":
            continue
        aid = node.attrib.get("id")
        if aid is None:
            continue

        groups.setdefault(aid, []).append(node)
    clones = {}
    for node in root:
        if node.tag != "clone":
            continue
        cid = node.attrib.get("id")
        if cid is None:
            raise RuntimeError(
                "clone without id"
            )
        clones[cid] = node
    visiting = set()
    resolved = set(groups.keys())

    def resolve(aid):
        if aid in resolved:
            return groups[aid]
        clone_node = clones.get(aid)
        if clone_node is None:
            raise RuntimeError(
                f"clone target not found: {aid}"
            )
        if aid in visiting:
            raise RuntimeError(
                f"circular clone dependency: {aid}"
            )
        visiting.add(aid)
        target = clone_node.attrib.get("target")
        if target is None:
            raise RuntimeError(
                f"clone {aid} missing target"
            )
        src_group = resolve(target)
        expanded = []
        for src in src_group:
            cp = deepcopy(src)
            cp.attrib["id"] = aid
            expanded.append(cp)
        groups[aid] = expanded
        resolved.add(aid)
        visiting.remove(aid)
        return expanded

    replacements = []
    for cid, node in clones.items():
        replacements.append((node, resolve(cid)))
    for old, expanded in replacements:
        parent = old.getparent()
        pos = parent.index(old)
        parent.remove(old)
        for i, node in enumerate(expanded):
            parent.insert(pos + i, deepcopy(node))
    return root

def node_equal(a, b):
    if a.tag != b.tag:
        return False
    if a.attrib != b.attrib:
        return False
    if len(a) != len(b):
        return False
    for ca, cb in zip(a, b):
        if not node_equal(ca, cb):
            return False

    return True

def attr_diff(a, b):
    diff = {}
    for k, v in b.attrib.items():
        if a.attrib.get(k) != v:
            diff[k] = v
    return diff

def animation_key(node):
    return (
        node.attrib.get("id"),
        node.attrib.get("index")
    )

def frame_key(node):
    return node.attrib.get("index")

def diff_generic(a, b):
    out = etree.Element(b.tag)

    for k, v in b.attrib.items():
        if a.attrib.get(k) != v:
            out.attrib[k] = v

    for c in b:
        out.append(deepcopy(c))

    if len(out.attrib) == 0 and len(out) == 0:
        return None

    return out

def find_child(parent, tag):
    for c in parent:
        if c.tag == tag:
            return c
    return None

def diff_frames(a_anim, b_anim):
    result = []

    a_frames = a_anim.findall("frame")
    b_frames = b_anim.findall("frame")

    a_map = {frame_key(f): f for f in a_frames}
    b_map = {frame_key(f): f for f in b_frames}

    for b in b_frames:
        idx = frame_key(b)

        if idx not in a_map:
            result.append(deepcopy(b))
            continue

        a = a_map[idx]

        if node_equal(a, b):
            continue

        out = etree.Element("frame")
        out.attrib["index"] = idx

        for k, v in attr_diff(a, b).items():
            out.attrib[k] = v

        for child_b in b:
            child_a = find_child(a, child_b.tag)

            if child_a is None:
                out.append(deepcopy(child_b))
                continue

            if not node_equal(child_a, child_b):
                diff_node = diff_generic(child_a, child_b)
                if diff_node is not None:
                    out.append(diff_node)

        if len(out.attrib) > 1 or len(out):
            result.append(out)

    for a in a_frames:
        idx = frame_key(a)

        if idx not in b_map:
            drop = etree.Element("frame")
            drop.attrib["index"] = idx
            drop.attrib["merge_option"] = "drop"
            result.append(drop)

    return result

def diff_animations(a_root, b_root):
    pre_clone(a_root)
    pre_clone(b_root)
    out_root = etree.Element("animpatterndiff")

    a_anims = a_root.findall("animation")
    b_anims = b_root.findall("animation")

    a_map = {animation_key(m): m for m in a_anims}
    b_map = {animation_key(m): m for m in b_anims}

    for b in b_anims:
        key = animation_key(b)

        if key not in a_map:
            out_root.append(deepcopy(b))
            continue

        a = a_map[key]

        out_anim = etree.Element("animation")

        if "id" in b.attrib:
            out_anim.attrib["id"] = b.attrib["id"]

        if "index" in b.attrib:
            out_anim.attrib["index"] = b.attrib["index"]

        for k, v in b.attrib.items():
            if k in ("id", "index"):
                continue
            if a.attrib.get(k) != v:
                out_anim.attrib[k] = v

        frames = diff_frames(a, b)

        for f in frames:
            out_anim.append(f)

        if len(out_anim.attrib) > 2 or len(out_anim):
            out_root.append(out_anim)

    for a in a_anims:
        key = animation_key(a)

        if key not in b_map:
            drop = etree.Element("animation")

            if "id" in a.attrib:
                drop.attrib["id"] = a.attrib["id"]

            if "index" in a.attrib:
                drop.attrib["index"] = a.attrib["index"]

            drop.attrib["merge_option"] = "drop"

            out_root.append(drop)

    return out_root

def write_xml(root, path):
    etree.indent(root, space="\t")

    tree = etree.ElementTree(root)

    tree.write(
        path,
        encoding="utf-8",
        xml_declaration=True,
        pretty_print=False
    )

def main():
    parser = argparse.ArgumentParser(
        description="animpattern XML diff generator"
    )

    parser.add_argument("xml_a")
    parser.add_argument("xml_b")

    parser.add_argument(
        "-o",
        "--output",
        default="diff.xml"
    )

    args = parser.parse_args()

    a_root = load_xml(args.xml_a)
    b_root = load_xml(args.xml_b)

    diff_root = diff_animations(a_root, b_root)

    write_xml(diff_root, args.output)

    print("diff written:", args.output)

if __name__ == "__main__":
    main()