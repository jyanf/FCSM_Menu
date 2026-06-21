local relative = ... and (...):gsub("%hacker2$", "") or ""
local M = require(relative.."declarator")
require(relative.."FrameData")
require(relative.."SequenceData")
require(relative.."PatternMap")
require(relative.."PatternData")
require(relative.."vector")

local T = require(relative.."texture2")
local convert_cstring = require(relative.."utils").convert_cstring

--[[
print(M.isDefined("FrameData"), M.isDefined("SequenceData"),
M.isDefined("map<int, SequenceData*>"), M.isDefined("deque<SequenceData>"), 
M.isDefined("vector<int>"), M.isDefined("vector<FrameData>"))
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
        map = M.fromPtr("map<int, SequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, SequenceData*>" then error("not patternMap instance") end
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
        map = M.fromPtr("map<int, SequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, SequenceData*>" then error("not patternMap instance") end
    local cur_seq = map[actId]
    cur_seq = cur_seq and cur_seq:getSeqById(seqId)
    if not cur_seq then return end
    frmId = frmId or -1
    return cur_seq:dropFrame(frmId)
end

function H.GetBlock(map, actId, seqId)
    if type(map)=="number" then
        map = M.fromPtr("map<int, SequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, SequenceData*>" then error("not patternMap instance") end
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
        map = M.fromPtr("map<int, SequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, SequenceData*>" then error("not patternMap instance") end
    if type(deq)=="number" then
        deq = M.fromPtr("deque<SequenceData>", map)
    end
    if type(deq)~="table" or deq.typeDef.typename~="deque<SequenceData>" then error("not patternData instance") end

    if type(seq)=="number" then
        seq = M.fromPtr("SequenceData", seq)
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
        map = M.fromPtr("map<int, SequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, SequenceData*>" then error("not patternMap instance") end
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
        map = M.fromPtr("map<int, SequenceData*>", map)
    end
    if type(map)~="table" or map.typeDef.typename~="map<int, SequenceData*>" then error("not patternMap instance") end
    
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
        map = M.fromPtr("map<int, SequenceData*>", pmap),
        deq = M.fromPtr("deque<SequenceData>", pdeq),
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

local callbackIdGen = 0
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
        cname = p1:lower(); cbf = p2
    end
    if not Callbacks[cname] then
        Callbacks[cname] = {}
    end
    callbackIdGen = callbackIdGen + 1
    local id = callbackIdGen
    Callbacks[cname][id] = cbf
    --table.insert(Callbacks[cname], cbf)
    return id.."@"..cname
end
function H.RemoveCallback(handle)
    local id, cname = handle:match("^(%d+)@(.+)$")
    if not cname then return false end
    local list = Callbacks[cname]
    if not list then return false end

    id = tonumber(id)
    if id and list[id] then
        list[id] = nil
        return true
    end

    return false
end

memory.hooktramp(0x43bc9a, 6, memory.createcallback(0, function(state)
    local restored_ecx = memory.readint(state.esp+0x40)
    if restored_ecx==0 then return end
    local path, pMap, pDeq, pVec = memory.readint(state.esp+0x388), restored_ecx+0x88, restored_ecx+0x74, restored_ecx+0x64
    path = path~=0 and convert_cstring(path):lower()
    if not path then return end
    local hkr = H.InitHacker(pMap, pDeq, pVec)
    if M.verbose then
        print(pMap, pDeq, pVec)
    end 
        
    for idx, gcbf in pairs(Callbacks["_global"]) do
        gcbf(hkr, idx>1)
    end
    if not Callbacks[path] then return end
    for idx, cbf in pairs(Callbacks[path]) do
        cbf(hkr, idx>1)
    end
end))

return setmetatable(H, {
    __index = function (t, k)
        local og = rawget(t, k)
        if og then return og
        elseif type(k)=="string" and M.isDefined(k) then
            return setmetatable({typename=k}, {
                __call = function (t, basePtr)
                    if basePtr==nil then
                        basePtr = memory.new(M.get_define(t.typename).size)
                    end
                    return M.fromPtr(t.typename, basePtr)
                end
            })
        end
    end,
    __call = function (t, ...)
        return H.InitHacker(...)
    end
})
