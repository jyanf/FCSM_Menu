local relative = ... and (...):gsub("CharacterPatternData$", "") or ""
local M = require(relative.."declarator")
require(relative.."CharacterSequenceData")

M.define("deque<CharacterSequenceData>", {
    size = 0x14,
    static = {
        value_type = "CharacterSequenceData",
        element_size = M.sizeof("CharacterSequenceData"),
		-- _block_max = Classes["CharacterSequenceData"].size <= 0x1 and 0x10 
        --         or Classes["CharacterSequenceData"].size <= 0x2 and 0x8 
        --         or Classes["CharacterSequenceData"].size <= 0x4 and 0x4 
        --         or Classes["CharacterSequenceData"].size <= 0x8 and 0x2 
        --         or 1,
        _block_max = 1,
		_min_blocks = 8,

        _deque_grow = memory.createfunccall(0x4659f0, 1, true), --maybe only for _block_max == 1?
    },
    fields = {
        _data = {offset=0x4, type="ptr"},
        _block_count = {offset=0x8, type="uint"},
        _offset = {offset=0xC, type="uint"},
        size = {offset=0x10, type="uint"},
    },
    methods = {
        _grow = function (self, n)
            self._deque_grow(self.basePtr, n)
        end,
        _push_back = function (self, pnew_v) --thanks pinkysmile
            if (self._offset+self.size) % self._block_max == 0 
            and (self.size + self._block_max) // self._block_max >= self._block_count then
               self:_grow(1) 
            end
            local nblock = (self.size + self._offset) // self._block_max
            if nblock>= self._block_count then
                nblock = nblock - self._block_count
            end
            
            if (memory.readint(self._data + nblock*4) == 0) then
                -- local pnew_v = M.alloc(self._block_max*self.element_size)
                memory.writeint(self._data + nblock*4, pnew_v)
            end
            self.size = self.size + 1;
        end,
        push_back = function (self, pseq)
            if type(pseq)=="table" and pseq.typeDef.typename=="CharacterSequenceData" then
                pseq = pseq.basePtr
            end
            if type(pseq)=="number" then
                self:_push_back(pseq)
            end
        end
        --push_front,
        --pop_back,
    }
})
return M, M.verbose and print(relative.."CharacterPatternData")