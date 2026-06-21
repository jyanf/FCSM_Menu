local relative = ... and (...):gsub("CharacterFrameData$", "") or ""
local M = require(relative.."declarator")
require(relative.."FrameData")
require(relative.."vector")
require(relative.."Box")

--derived from Framedata
M.define("CharacterFrameData", {
    size = 0xA8,
    fields = {
        vtable = {offset=0x00, type="ptr"},
        -- base FrameData part
        offset = {offset=0x04, type="Vector2s"},
        duration = {offset=0x08, type="short"},
        texIndex = {offset=0x0A, type="short"},
        texOffset = {offset=0x0C, type="Vector2s"},
        texSize = {offset=0x10, type="Vector2s"},
        renderGroup = {offset=0x14, type="uchar"},
        blendOptions = {
            offset=0x18,
            type="BlendOptions",
            isPtr=true
        },
        -- 
        damage = {offset=0x1C, type="short"},
        ratio = {offset=0x1E, type="short"},
        chipDamage = {offset=0x20, type="short"},
        spiritDamage = {offset=0x22, type="short"},
        untech = {offset=0x24, type="short"},
        power = {offset=0x26, type="short"},
        limit = {offset=0x28, type="short"},
        onHitPStun = {offset=0x2A, type="short"},
        onHitEStun = {offset=0x2C, type="short"},
        onBlockPStun = {offset=0x2E, type="short"},
        onBlockEStun = {offset=0x30, type="short"},
        onHitCardGain = {offset=0x32, type="short"},
        onBlockCardGain = {offset=0x34, type="short"},
        onAirHitSet = {offset=0x36, type="short"},
        onGroundHitSet = {offset=0x38, type="short"},

        onHitSpeed = {offset=0x3C, type="Vector2f"},
        onHitSFX = {offset=0x44, type="short"},
        onHitFX = {offset=0x46, type="short"},
        attackType = {offset=0x48, type="uchar"},
        comboFlags = {offset=0x49, type="uchar"},

        frameFlags = {offset=0x4C, type="uint"},
        attackFlags = {offset=0x50, type="uint"},
        collisionBox = {
            offset = 0x54,
            type = "Box",
            isPtr = true
        },
        hurtboxes = {
            offset = 0x58,
            type = "vector<Box>",
        },
        attackBoxes = {
            offset = 0x68,
            type = "vector<Box>",
        },
        extraBoxes = {
            offset = 0x78,
            type = "vector<Box*>",
        },
        customVector1 = {offset=0x88, type="Vector2i"},
        customVector2 = {offset=0x90, type="Vector2i"},
        customVector3 = {offset=0x98, type="Vector2i"},
        customShort1 = {offset=0xA0, type="short"},
        customShort2 = {offset=0xA2, type="short"},
        customShort3 = {offset=0xA4, type="short"},
        -- align 0xA6+0x2
    },
    static = {
        _init = memory.createfunccall(0x466e20, 0, true),
        _clear = memory.createfunccall(0x465770, 0, true),
        _copy = memory.createfunccall(0x466a50, 1, true)
    },
    methods = {
        init = function (self)
            self._init(self.basePtr)
            self.vtable = 0x85a2a4 -- fix org function memset
            return self
        end,
        clear = function (self)
            self._clear(self.basePtr)
        end,
        copy = function (self, pframe)
            if type(pframe)=="table" and pframe.basePtr then
                pframe = pframe.basePtr
            end
            self._copy(self.basePtr, pframe)
            return self
        end
    }
})
return M, M.verbose and print(relative.."CharacterFrameData")