local relative = ... and (...):gsub("Flags$", "") or ""

local F = {}

-- =========================
-- table 0 : frame flags
-- =========================
F[0] = {
    [0]="standing",[1]="crouching",[2]="airborne",[3]="down",
    [4]="guardcancel",[5]="cancellable",[6]="takecounterhit",[7]="superarmor",
    [8]="normalarmor",[9]="fflag10GUARD_POINT",[10]="grazing",[11]="fflag12GUARDING",
    [12]="grabinvul",[13]="melleinvul",[14]="bulletinvul",[15]="airattackinvul",
    [16]="highattackinvul",[17]="lowattackinvul",[18]="objectattackinvul",[19]="fflag20REFLECT_BULLET",
    [20]="fflag21FLIP_VELOCITY",[21]="movimentcancel",[22]="fflag23AFTER_IMAGE",[23]="fflag24LOOP_ANIMATION",
    [24]="fflag25ATTACK_OBJECT",[25]="fflag26",[26]="fflag27",[27]="fflag28",
    [28]="fflag29",[29]="fflag30",[30]="fflag31",[31]="fflag32",

    standing=0x00000001,crouching=0x00000002,airborne=0x00000004,down=0x00000008,
    guardcancel=0x00000010,cancellable=0x00000020,takecounterhit=0x00000040,superarmor=0x00000080,
    normalarmor=0x00000100,fflag10GUARD_POINT=0x00000200,grazing=0x00000400,fflag12GUARDING=0x00000800,
    grabinvul=0x00001000,melleinvul=0x00002000,bulletinvul=0x00004000,airattackinvul=0x00008000,
    highattackinvul=0x00010000,lowattackinvul=0x00020000,objectattackinvul=0x00040000,fflag20REFLECT_BULLET=0x00080000,
    fflag21FLIP_VELOCITY=0x00100000,movimentcancel=0x00200000,fflag23AFTER_IMAGE=0x00400000,fflag24LOOP_ANIMATION=0x00800000,
    fflag25ATTACK_OBJECT=0x01000000,fflag26=0x02000000,fflag27=0x04000000,fflag28=0x08000000,
    fflag29=0x10000000,fflag30=0x20000000,fflag31=0x40000000,fflag32=0x80000000
}

-- =========================
-- table 1 : attack flags
-- =========================
F[1] = {
    [0]="aflag01STAGGER",[1]="highrightblock",[2]="lowrightblock",[3]="airblockable",
    [4]="unblockable",[5]="ignorearmor",[6]="hitonwrongblock",[7]="aflag08GRAB",
    [8]="aflag09",[9]="aflag10",[10]="inducecounterhit",[11]="skillattacktype",
    [12]="spellattacktype",[13]="airattacktype",[14]="highattacktype",[15]="lowattacktype",
    [16]="objectattacktype",[17]="aflag18UNREFLECTABLE",[18]="aflag19",[19]="guardcrush",
    [20]="friendlyfire",[21]="aflag22stagger",[22]="isbullet",[23]="ungrazeble",
    [24]="aflag25DRAINS_ON_GRAZE",[25]="aflag26",[26]="aflag27",[27]="aflag28",
    [28]="aflag29",[29]="aflag30",[30]="aflag31",[31]="aflag32",

    aflag01STAGGER=0x00000001,highrightblock=0x00000002,lowrightblock=0x00000004,airblockable=0x00000008,
    unblockable=0x00000010,ignorearmor=0x00000020,hitonwrongblock=0x00000040,aflag08GRAB=0x00000080,
    aflag09=0x00000100,aflag10=0x00000200,inducecounterhit=0x00000400,skillattacktype=0x00000800,
    spellattacktype=0x00001000,airattacktype=0x00002000,highattacktype=0x00004000,lowattacktype=0x00008000,
    objectattacktype=0x00010000,aflag18UNREFLECTABLE=0x00020000,aflag19=0x00040000,guardcrush=0x00080000,
    friendlyfire=0x00100000,aflag22stagger=0x00200000,isbullet=0x00400000,ungrazeble=0x00800000,
    aflag25DRAINS_ON_GRAZE=0x01000000,aflag26=0x02000000,aflag27=0x04000000,aflag28=0x08000000,
    aflag29=0x10000000,aflag30=0x20000000,aflag31=0x40000000,aflag32=0x80000000
}

-- =========================
-- table 2 : modifiers
-- =========================
F[2] = {
    [0]="liftmodifier",[1]="smashmodifier",[2]="bordermodifier",[3]="chainmodifier",
    [4]="spellmodifier",[5]="countermodifier",[6]="modifier07",[7]="modifier08",

    liftmodifier=0x01,smashmodifier=0x02,bordermodifier=0x04,chainmodifier=0x08,
    spellmodifier=0x10,countermodifier=0x20,modifier07=0x40,modifier08=0x80
}

local FlagToIndex = {
    -- frame flags (0)
    standing=0,crouching=0,airborne=0,down=0,
    guardcancel=0,cancellable=0,takecounterhit=0,superarmor=0,
    normalarmor=0,fflag10GUARD_POINT=0,grazing=0,fflag12GUARDING=0,
    grabinvul=0,melleinvul=0,bulletinvul=0,airattackinvul=0,
    highattackinvul=0,lowattackinvul=0,objectattackinvul=0,fflag20REFLECT_BULLET=0,
    fflag21FLIP_VELOCITY=0,movimentcancel=0,fflag23AFTER_IMAGE=0,fflag24LOOP_ANIMATION=0,
    fflag25ATTACK_OBJECT=0,fflag26=0,fflag27=0,fflag28=0,
    fflag29=0,fflag30=0,fflag31=0,fflag32=0,

    -- attack flags (1)
    aflag01STAGGER=1,highrightblock=1,lowrightblock=1,airblockable=1,
    unblockable=1,ignorearmor=1,hitonwrongblock=1,aflag08GRAB=1,
    aflag09=1,aflag10=1,inducecounterhit=1,skillattacktype=1,
    spellattacktype=1,airattacktype=1,highattacktype=1,lowattacktype=1,
    objectattacktype=1,aflag18UNREFLECTABLE=1,aflag19=1,guardcrush=1,
    friendlyfire=1,aflag22stagger=1,isbullet=1,ungrazeble=1,
    aflag25DRAINS_ON_GRAZE=1,aflag26=1,aflag27=1,aflag28=1,
    aflag29=1,aflag30=1,aflag31=1,aflag32=1,

    -- modifiers (2)
    liftmodifier=2,smashmodifier=2,bordermodifier=2,chainmodifier=2,
    spellmodifier=2,countermodifier=2,modifier07=2,modifier08=2
}

function F.GetFlagValue(name)
    local index = FlagToIndex[name]
    if index then
        return index, F[index][name]
    end
end

function F.GetFlagName(index, bitofs)
    return F[index] and F[index][bitofs]
end

return F