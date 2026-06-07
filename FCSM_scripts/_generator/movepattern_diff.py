import argparse
import copy
import sys
from lxml import etree

PARSER = etree.XMLParser(
    remove_blank_text=True,
    encoding="SHIFT_JIS", #fix the fucking full width "ｂ" in patchouli bulletIｂ000.png
)

# -----------------------------
# 基础工具
# -----------------------------

def load_xml(path):
    try:
        return etree.parse(path, PARSER).getroot()
    except Exception as e:
        print("XML load error:", e)
        sys.exit(1)

def deepcopy(node):
    return copy.deepcopy(node)

def pre_clone(root):
    # --------------------------------
    # collect original move groups
    # --------------------------------
    groups = {}
    for node in root:
        if node.tag != "move":
            continue
        mid = node.attrib.get("id")
        if mid is None:
            continue
        groups.setdefault(mid, []).append(node)
    # --------------------------------
    # collect clone nodes
    # --------------------------------
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
    # --------------------------------
    # dfs resolve clone dependency
    # --------------------------------
    visiting = set()
    resolved = set(groups.keys())

    def resolve(mid):
        # already solved
        if mid in resolved:
            return groups[mid]
        clone_node = clones.get(mid)
        if clone_node is None:
            raise RuntimeError(
                f"clone target not found: {mid}"
            )
        # cycle detect
        if mid in visiting:
            raise RuntimeError(
                f"circular clone dependency: {mid}"
            )
        visiting.add(mid)
        target = clone_node.attrib.get("target")
        if target is None:
            raise RuntimeError(
                f"clone {mid} missing target"
            )
        src_group = resolve(target)
        expanded = []
        for src in src_group:
            cp = deepcopy(src)
            # clone id overrides target id
            cp.attrib["id"] = mid
            expanded.append(cp)
        groups[mid] = expanded
        resolved.add(mid)
        visiting.remove(mid)
        return expanded
    # --------------------------------
    # expand all clone nodes
    # --------------------------------
    replacements = []
    for cid, node in clones.items():
        expanded = resolve(cid)
        replacements.append((node, expanded))
    # --------------------------------
    # replace clone node in xml tree
    # --------------------------------
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

#fix xml con-version difference
def box_equal(a, b):
    if a.tag != b.tag:
        return False
    # completely ignore unknown
    a_attr = {
        k:v
        for k,v in a.attrib.items()
        if k.lower() != "unknown"
    }
    b_attr = {
        k:v
        for k,v in b.attrib.items()
        if k.lower() != "unknown"
    }
    if a_attr != b_attr:
        return False


    # preserve recursive comparison; no need but I just kept it
    if len(a) != len(b):
        return False

    for ca, cb in zip(a, b):
        if not box_equal(ca, cb):
            return False

    return True

def attr_diff(a, b):
    diff = {}
    for k, v in b.attrib.items():
        if a.attrib.get(k) != v:
            diff[k] = v
    return diff

# -----------------------------
# key
# -----------------------------

def move_key(node):
    return (
        node.attrib.get("id"),
        node.attrib.get("index")
    )

def frame_key(node):
    return node.attrib.get("index")

# -----------------------------
# node classification
# -----------------------------

def contains_box(node):
    for c in node.iter():
        if c.tag.lower() == "box":
            return True
    return False

# -----------------------------
# traits diff
# -----------------------------

def diff_traits(a, b):
    out = etree.Element("traits")

    # 属性 diff
    for k, v in b.attrib.items():
        if a.attrib.get(k) != v:
            out.attrib[k] = v

    # 子节点必须完整复制
    for c in b:
        out.append(deepcopy(c))

    return out

# -----------------------------
# generic node diff
# -----------------------------

def diff_generic(a, b):
    out = etree.Element(b.tag)

    # 属性 diff
    for k, v in b.attrib.items():
        if a.attrib.get(k) != v:
            out.attrib[k] = v

    # 子节点复制
    for c in b:
        out.append(deepcopy(c))

    if len(out.attrib) == 0 and len(out) == 0:
        return None

    return out

# -----------------------------
# child finder
# -----------------------------

def find_child(parent, tag):
    for c in parent:
        if c.tag == tag:
            return c
    return None

# -----------------------------
# frame diff
# -----------------------------

def diff_frames(a_move, b_move): # blendOption的drop尚未处理

    result = []

    a_frames = a_move.findall("frame")
    b_frames = b_move.findall("frame")

    a_map = {frame_key(f): f for f in a_frames}
    b_map = {frame_key(f): f for f in b_frames}

    # 按 B 顺序处理
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

        # frame 属性 diff
        for k, v in attr_diff(a, b).items():
            out.attrib[k] = v

        # 子节点 diff
        for child_b in b:

            # traits 特殊规则
            if child_b.tag == "traits":

                child_a = find_child(a, "traits")

                if child_a is None:
                    out.append(deepcopy(child_b))
                else:
                    if not node_equal(child_a, child_b):
                        out.append(diff_traits(child_a, child_b))

                continue

            # box 类节点 atomic
            if contains_box(child_b):
                child_a = find_child(a, child_b.tag)
                if child_a is None or not box_equal(child_a, child_b):
                    out.append(deepcopy(child_b))
                continue

            # 普通节点
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

    # 删除 frame
    for a in a_frames:

        idx = frame_key(a)

        if idx not in b_map:

            drop = etree.Element("frame")
            drop.attrib["index"] = idx
            drop.attrib["merge_option"] = "drop"

            result.append(drop)

    return result

# -----------------------------
# move diff
# -----------------------------

def diff_moves(a_root, b_root):
    pre_clone(a_root)
    pre_clone(b_root)
    out_root = etree.Element("movepatterndiff")

    a_moves = a_root.findall("move")
    b_moves = b_root.findall("move")

    a_map = {move_key(m): m for m in a_moves}
    b_map = {move_key(m): m for m in b_moves}

    # B 顺序
    for b in b_moves:

        key = move_key(b)

        if key not in a_map:
            out_root.append(deepcopy(b))
            continue

        a = a_map[key]

        out_move = etree.Element("move")

        # id/index 必须保留
        if "id" in b.attrib:
            out_move.attrib["id"] = b.attrib["id"]

        if "index" in b.attrib:
            out_move.attrib["index"] = b.attrib["index"]

        # 其它属性 diff
        for k, v in b.attrib.items():
            if k in ("id", "index"):
                continue
            if a.attrib.get(k) != v:
                out_move.attrib[k] = v

        frames = diff_frames(a, b)

        for f in frames:
            out_move.append(f)

        if len(out_move.attrib) > 2 or len(out_move):
            out_root.append(out_move)

    # 删除 move
    for a in a_moves:

        key = move_key(a)

        if key not in b_map:

            drop = etree.Element("move")

            if "id" in a.attrib:
                drop.attrib["id"] = a.attrib["id"]

            if "index" in a.attrib:
                drop.attrib["index"] = a.attrib["index"]

            drop.attrib["merge_option"] = "drop"

            out_root.append(drop)

    return out_root

# -----------------------------
# write xml
# -----------------------------

def write_xml(root, path):

    etree.indent(root, space="\t")

    tree = etree.ElementTree(root)

    tree.write(
        path,
        encoding="utf-8",
        xml_declaration=True,
        pretty_print=False
    )

# -----------------------------
# CLI
# -----------------------------

def main():

    parser = argparse.ArgumentParser(
        description="movepattern XML diff generator"
    )

    parser.add_argument("xml_a", help="original xml")
    parser.add_argument("xml_b", help="modified xml")

    parser.add_argument(
        "-o",
        "--output",
        default="diff.xml",
        help="output diff file"
    )

    args = parser.parse_args()

    a_root = load_xml(args.xml_a)
    b_root = load_xml(args.xml_b)

    diff_root = diff_moves(a_root, b_root)

    write_xml(diff_root, args.output)

    print("diff written:", args.output)


if __name__ == "__main__":
    main()