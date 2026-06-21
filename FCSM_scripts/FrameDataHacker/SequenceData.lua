local relative = ... and (...):gsub("SequenceData$", "") or ""
local M = require(relative.."declarator")
require(relative.."FrameData")
require(relative.."vector")


M.define("vector<FrameData>", M.get_template("vector<>")("FrameData"))

M.define("SequenceData", {
    size = 0x20,
    static = {
        _init = memory.createfunccall(0x423c20, 0, true),
        -- void __stdcall PatternData_copy(PatternData* dst, PatternData* src)
        _copy = memory.createfunccall(0x423ec0, 2, false)
    },
    fields = {
        -- Vector<FrameData>
        frames = {offset=0x04, type="vector<FrameData>"},
        isLoop = {offset=0x14, type="bool"},

        prev = {
            offset=0x18,
            type="SequenceData",
            isPtr=true
        },

        next = {
            offset=0x1C,
            type="SequenceData",
            isPtr=true
        },
    },
    methods = {
        init = function (self)
            self._init(self.basePtr)
            self.prev = nil
            self.next = self
            return self
        end,
        addFrame = function (self, pframe, _index) --with copy
            local csize = self.frames:size()
            -- if index<0 then index = index + 1 + csize end
            -- if index>csize or index<0 then return end
            -- have to manually manage insert, but for now just append
            
            if type(pframe)=="number" then
                self.frames:resize(csize+1)
                self.frames[-1]:copy(pframe)
            elseif type(pframe)=="table" and pframe.typeDef.typename=="FrameData" then
                local og = pframe.basePtr
                self.frames:resize(csize+1)
                self.frames[-1]:copy(og)
                if M.verbose then
                    print("frame inserted,", csize, "of", self.frames:size())
                end
                pframe.basePtr = self.frames[csize].basePtr -- keep proxy valid
                M.free(og)
            end
            return true
        end,
        dropFrame = function (self, index)
            local frames = self.frames
            local target = frames[index]
            if not target then return end
            target:clear()
            local result = frames:erase(index)
            if M.verbose then
                print("frame erased,", index, "of", self.frames:size())
            end
            return result
        end,

        isFirst = function(self)
            return self.prev == nil
        end,
        isLast = function (self)
            return self.next:isFirst()
        end,
        _to_head_seq = function (self)
            local i = 0
            local cur = self
            while not cur:isFirst() do
                cur = cur.prev
                i = i + 1
            end
            return cur, i
        end,
        _to_tail_seq = function (self)
            local i = 0
            local cur = self
            while not cur:isLast() do
                cur = cur.next
                i = i + 1
            end
            return cur, i
        end,
        getTotalCount = function (self)
            local tail_seq, steps = self:_to_head_seq():_to_tail_seq()
            return steps + 1
        end,
        getSeqId = function (self) -- 0, 1, 2
            local head_seq, index = self:_to_head_seq()
            return index
        end,
        getSeqById = function (self, seqId)
            local cur_seq
            if seqId<0 then
                cur_seq = self:_to_tail_seq()
                for i = -1, seqId+1, -1 do
                    if cur_seq and not cur_seq:isFirst() then
                        cur_seq = cur_seq.prev
                    else
                        return nil
                    end
                end
            else
                cur_seq = self:_to_head_seq()
                for i = 1, seqId do
                    if cur_seq and not cur_seq:isLast() then
                        cur_seq = cur_seq.next
                    else
                        return nil
                    end
                end
            end
            return cur_seq
        end,
        
    },
})

return M, M.verbose and print(relative.."SequenceData")