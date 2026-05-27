local relative = ... and (...):gsub("%.init$", "").."." or ""
local M = require(relative.."declarator")
require(relative.."CharacterFrameData")
require(relative.."CharacterSequenceData")
require(relative.."PatternMap")
require(relative.."PatternData")
require(relative.."vector")

local T = require(relative.."texture")
local convert_cstring = require(relative.."utils").convert_cstring

--[[
print(M.isDefined("CharacterFrameData"), M.isDefined("CharacterSequenceData"),
M.isDefined("map<int, CharacterSequenceData*>"), M.isDefined("deque<CharacterSequenceData>"), 
M.isDefined("vector<int>"), M.isDefined("vector<CharacterFrameData>"))
--]]
local H = {}

---comment
---@param map table | integer
---@param actId integer
---@param seqId integer
---@param frame table | integer
---@param frmId integer | nil
---@return boolean | nil
function H.AddFrame(map, actId, seqId, frame, frmId)
    if type(map)=="number" then
        map = M.fromPtr("map<int, CharacterSequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, CharacterSequenceData*>" then error("not patternMap instance") end
    local head_seq = map[actId] --actId can inject with string
    local cur_seq = head_seq:getSeqById(seqId)
    if not cur_seq then 
        error(string.format("act#%d|seq%d not found, frame insertion failed", actId, seqId))
    end
    return cur_seq:addFrame(frame, frmId)
end

---comment
---@param map table | integer
---@param actId integer
---@param seqId integer
---@param frmId integer | nil
---@return boolean | nil
function H.DropFrame(map, actId, seqId, frmId)
    if type(map)=="number" then
        map = M.fromPtr("map<int, CharacterSequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, CharacterSequenceData*>" then error("not patternMap instance") end
    local cur_seq = map[actId]
    cur_seq = cur_seq and cur_seq:getSeqById(seqId)
    if not cur_seq then return end
    frmId = frmId or -1
    return cur_seq:dropFrame(frmId)
end

function H.GetBlock(map, actId, seqId)
    if type(map)=="number" then
        map = M.fromPtr("map<int, CharacterSequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, CharacterSequenceData*>" then error("not patternMap instance") end
    local head = map[actId]
    return head and head:getSeqById(seqId)
end

---comment
---@param map any
---@param deq any
---@param actId integer
---@param seqId integer
---@param seq any
---@return boolean | nil
function H.AddBlock(map, deq, actId, seqId, seq)
    if type(map)=="number" then
        map = M.fromPtr("map<int, CharacterSequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, CharacterSequenceData*>" then error("not patternMap instance") end
    if type(deq)=="number" then
        deq = M.fromPtr("deque<CharacterSequenceData>", map)
    end
    if type(deq)~="table" or deq.typeDef.typename~="deque<CharacterSequenceData>" then error("not patternData instance") end

    if type(seq)=="number" then
        seq = M.fromPtr("CharacterSequenceData", seq)
    end

    deq:push_back(seq) -- storage
    local head_seq = map[actId]
    if not head_seq then --need map insert, must be seq0
        seqId = seqId or 0
        if seqId~=0 then error("single sequence action cannot have seqId>0") end
        map:insert(actId, seq)
    elseif seqId==0 then --head insert
        map[actId] = seq --remap
        seq.next = head_seq
        head_seq.prev = seq
        --handle tail
        local tail_seq = head_seq:getSeqById(-1)
        tail_seq.next = seq
    else
        seqId = seqId or 0
        local prec_seq = head_seq:getSeqById(seqId-1)
        local succ_seq = prec_seq.next
        -- print("add block", actId, seqId, ";", prec_seq.basePtr, succ_seq.basePtr)
        seq.next = succ_seq
        seq.prev = prec_seq
        prec_seq.next = seq
        if not succ_seq:isFirst() then-- not tail insert
            succ_seq.prev = seq
        end
    end
    return true
end

---comment
---@param map any
---@param actId integer
---@param seqId integer
---@return boolean | nil
function H.DropBlock(map, actId, seqId) --keep storage still
    if type(map)=="number" then
        map = M.fromPtr("map<int, CharacterSequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, CharacterSequenceData*>" then error("not patternMap instance") end
    local cur_seq = map[actId]
    cur_seq = cur_seq and cur_seq:getSeqById(seqId)
    if not cur_seq then return end
    
    if cur_seq:isFirst() and cur_seq:isLast() then --drop action
        map:erase(actId)
    elseif cur_seq:isFirst() then
        map[actId] = cur_seq.next
        cur_seq.next.prev = nil
    else
        local prec_seq, succ_seq = cur_seq.prev, cur_seq.next
        prec_seq.next = succ_seq
        if not succ_seq:isFirst() then--not tail drop
            succ_seq.prev = prec_seq
        end
        --cur_seq:init()
        cur_seq.next = cur_seq--let it self spin
        cur_seq.prev = nil
    end
    return true
end

---
---@param map any
---@param actId integer
function H.DropAction(map, actId)
    if type(map)=="number" then
        map = M.fromPtr("map<int, CharacterSequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, CharacterSequenceData*>" then error("not patternMap instance") end
    
    while H.DropBlock(map, actId, 0) do end
end

---comment
---@param pmap integer
---@param pdeq integer
---@param pvtx integer
---@return table
function H.InitHacker(pmap, pdeq, pvtx)
    -- tex_buffer = tex_buffer or { }
    local inst = {
        map = M.fromPtr("map<int, CharacterSequenceData*>", pmap),
        deq = M.fromPtr("deque<CharacterSequenceData>", pdeq),
        tex = M.fromPtr("vector<int>", pvtx),
        addFrame = function (self, actId, seqId, frame, frmId)
            return H.AddFrame(self.map, actId, seqId, frame, frmId)
        end,
        dropFrame = function (self, actId, seqId, frmId)
            return H.DropFrame(self.map, actId, seqId, frmId)
        end,

        getBlock = function (self, actId, seqId)
            return H.GetBlock(self.map, actId, seqId)
        end,
        addBlock = function (self, actId, seqId, seq)
            return H.AddBlock(self.map, self.deq, actId, seqId, seq)
        end,
        dropBlock = function (self, actId, seqId)
            return H.DropBlock(self.map, actId, seqId)
        end,

        dropAction = function (self, actId)
            return H.DropAction(self.map, actId)
        end,

        loadTexture = function (self, cname, fname)
            return T.get_tex_id(self.tex, cname, fname)
        end,

    }
    return inst
end

local Callbacks = {
    _global = {}
}
---
----@param cname string
----@param cbf fun(hkr, paletteId, isHooked)
function H.AddCallBack(p1, p2)
    local cname, cbf
    if type(p1)=="function" then
        cname = "_global"; cbf = p1
    else
        cname = p1; cbf = p2
    end
    if not Callbacks[cname] then
        Callbacks[cname] = {}
    end
    table.insert(Callbacks[cname], cbf)
end
memory.hookcall(0x4689c2, memory.createcallback(0, function(state)
    local restored_esp = state.esp + 0x39c + 4
    local cname, pid, pMap, pDeq, pVec = string.unpack("<LLLLL", memory.readbytes(restored_esp+4, 20))
    cname = cname~=0 and convert_cstring(cname)
    local hkr = H.InitHacker(pMap, pDeq, pVec)
    if M.verbose then
        print(pMap, pDeq, pVec)
    end 
        
    for idx, gcbf in ipairs(Callbacks["_global"]) do
        gcbf(hkr, pid, idx>1)
    end
    if not Callbacks[cname] then return end
    for idx, cbf in ipairs(Callbacks[cname]) do
        cbf(hkr, pid, idx>1)
    end
end))

return setmetatable(H, {
    __index = function (t, k)
        local og = rawget(t, k)
        if og then return og
        elseif type(k)=="string" and M.isDefined(k) then
            return setmetatable({typename=k}, {
                __call = function (t, basePtr)
                    return M.fromPtr(t.typename, basePtr)
                end
            })
        end
    end,
    __call = function (t, ...)
        return H.InitHacker(...)
    end
})
