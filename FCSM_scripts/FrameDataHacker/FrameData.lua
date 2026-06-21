local relative = ... and (...):gsub("FrameData$", "") or ""
local M = require(relative.."declarator")
require(relative.."vector")

M.define("BlendOptions", {
    size = 0x1C,
    fields = {
        mode = {offset=0, type="uint"},
        color = {offset=4, type="uint"}, 
            colorb = {offset=4, type="uchar"}, 
            colorg = {offset=5, type="uchar"}, 
            colorr = {offset=6, type="uchar"},
            colora = {offset=7, type="uchar"},
        scale = {offset=8, type="Vector2f"},
        rotateX = {offset=16, type="float"},
        rotateY = {offset=20, type="float"},
        rotateZ = {offset=24, type="float"},
    },
    methods = {
        init = function (self)
            M.default_init(self)
            self.mode = 1; self.color = 0xFFFFFFFF
            self.scale.x = 1
            self.scale.y = 1
            return self
        end,
    }
})
M.define("FrameData", {
    size = 0x1C,
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
    },
    static = {
        _copy = memory.createfunccall(0x422e40, 1, true),
    },
    methods = {
        init = function (self)
            M.default_init(self)
            self.vtable = 0x857a8c
            return self
        end,
        clear = function (self)
            -- self._clear(self.basePtr)
            if (self.blendOptions) then
                M.free(self.blendOptions.basePtr)
            end
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
return M, M.verbose and print(relative.."FrameData")