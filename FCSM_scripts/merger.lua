local relative = ... and (...):gsub("merger$", "") or ""
local xml2lua = require(relative.."xml2lua")
local xmlhandler = require(relative.."xml2lua.xmlhandler.tree")
local F = require(relative.."Flags")
local Hkr = require(relative.."FrameDataHacker")
local Hkr2 = require(relative.."FrameDataHacker.hacker2")

local function read_xml(filename)
    local data = readfile(filename)
    --[[pre
    --]]
    return data
end
local function parse(data)
    local handler = xmlhandler:new()
    xml2lua.parser(handler):parse(data)
    local base = handler.root
    return base
end

local G = {
    fromXml = function (filename)
        -- print(filename)
        return parse(read_xml(filename))
    end
}

local function apply_ops(index, ops)
    local idx = index
    for _, op in ipairs(ops) do
        if op.type == "drop" then
            if op.index == index then
                return nil
            elseif op.index < index then
                idx = idx - 1
            end
        elseif op.type == "add" then
            if op.index <= index then
                -- idx = idx + 1 --no need on appending
            end
        end
    end
    return idx
end
local function resolve(self, actId, seqId, poseId)
    -- block
    if poseId == nil then
        local blockLayer = self.block[actId]
        if blockLayer then
            seqId = apply_ops(seqId, blockLayer.ops)
            if not seqId then
                return nil
            end
        end
        return actId, seqId
    end
    -- frame
    local key = actId .. "|" .. seqId
    local frameLayer = self.frame[key]
    
    if frameLayer then
        poseId = apply_ops(poseId, frameLayer.ops)
        
        if not poseId then
            return nil
        end
    end

    return actId, seqId, poseId
end

-- to keep iter valid
local function record_modify(self, opType, actId, seqId, poseId)
    -- assert(opType == "drop" or opType == "add", "invalid opType")
    -- assert(actId ~= nil, "actId required")
    -- assert(seqId ~= nil, "seqId required")

    local layer

    -- block level
    if poseId == nil then
        layer = self.block[actId]
        if not layer then
            layer = { ops = {} }
            self.block[actId] = layer
        end

        table.insert(layer.ops, {
            type  = opType,
            index = seqId
        })

        return
    end

    -- frame level
    local key = actId .. "|" .. seqId
    layer = self.frame[key]
    if not layer then
        layer = { ops = {} }
        self.frame[key] = layer
    end
    table.insert(layer.ops, {
        type  = opType,
        index = poseId
    })
    -- if actId==790 and seqId==3 and self.frame["790|3"] then
    --     local dbg = "ops: "
    --     for index, value in ipairs(self.frame["790|3"].ops) do
    --         dbg = dbg..string.format("%sed%d;", value.type, value.index)
    --     end
    --     print(dbg)
    -- end
end

local function get_block_id(move, data)
    local ref = data.dropBuffer
    local actId, seqId = tonumber(move._attr.id), tonumber(move._attr.index)
    data.xactId, data.xseqId, data.xposeId = actId, seqId, nil
    return ref:resolve(actId, seqId)
end
local function get_frame_id(frame, data)
    local ref = data.dropBuffer
    local actId, seqId, poseId = data.xactId, data.xseqId, tonumber(frame._attr.index)
    data.xposeId = poseId
    actId, seqId, poseId = ref:resolve(actId, seqId, poseId)
    -- if data.xposeId~=poseId then
    --     print("got frame id", data.xposeId, "to", poseId)
    -- end
    return poseId
end

local function IsArray(t)
    return type(t) == "table" and type(t[1]) == "table"
end
local function AsArray(node)
    if not node then
        return {}
    end
    if IsArray(node) then
        return node
    end
    return { [1]=node }
end

local function traits_collect_flags(t, index)
    local value = 0
    for flag, _ in pairs(t) do
        local type, nv =  F.GetFlagValue(flag)
        value = value + (type==index and nv or 0)
    end
    return value
end

local function convert_BGRA(bgra)
    local b = (bgra >> 24) & 0xFF
    local g = (bgra >> 16) & 0xFF
    local r = (bgra >> 8)  & 0xFF
    local a = bgra & 0xFF
    return (a << 24) | (r << 16) | (g << 8) | b
end

-- local attr_handlers = {}
local node_handlers = {}
node_handlers = {
    block = function(t, data) --block
        local SD = data.type==2 and Hkr2.SequenceData or Hkr.CharacterSequenceData
        local hkr = data.hacker
        local actId, seqId = get_block_id(t, data)
        local block = hkr:getBlock(actId, seqId)
        local merge_option = t._attr and t._attr.merge_option
        if not merge_option then
            merge_option = block and "update" or "add"
        end
        if merge_option=="drop" then
            hkr:dropBlock(actId, seqId)
            data.dropBuffer:record_modify(merge_option, data.xactId, data.xseqId, data.xposeId)
        else
            if merge_option=="add" then
                block = SD()
                block:init()
                hkr:addBlock(actId, seqId, block)
                data.dropBuffer:record_modify(merge_option, data.xactId, data.xseqId, data.xposeId)
            elseif merge_option=="update" then

            end
            for k,v in pairs(t._attr) do
                if k=="loop" then
                    block.isLoop = tonumber(v)==1
                elseif k=="movelock" then
                    block.moveLock = tonumber(v)
                elseif k=="actionlock" then
                    block.actionLock = tonumber(v)
                end
            end
            data.cblock = block
            for index, frame in ipairs(AsArray(t.frame)) do
                node_handlers.frame(frame, data)
            end
        end
    end,
    
    frame = function(t, data) --frame
        local FD = data.type==2 and Hkr2.FrameData or Hkr.CharacterFrameData
        local hkr = data.hacker
        local poseId = get_frame_id(t, data)
        if not data.cblock then
            error("current block not found")
        end
        local frame = data.cblock.frames[poseId]
        local merge_option = t._attr and t._attr.merge_option
        if not merge_option then
            merge_option = frame and "update" or "add"
        end
        if merge_option=="drop" then
            data.cblock:dropFrame(poseId)
            data.dropBuffer:record_modify(merge_option, data.xactId, data.xseqId, data.xposeId)
        else
            if merge_option=="add" then
                frame = FD()
                frame:init()
                data.cblock:addFrame(frame)
                data.dropBuffer:record_modify(merge_option, data.xactId, data.xseqId, data.xposeId)
            elseif merge_option=="update" then

            end
            for k,v in pairs(t._attr) do
                local nv = tonumber(v)
                if k=="image" then
                    frame.texIndex = hkr:loadTexture(data.cname, v)
                elseif k=="unknown" then
                    -- frame. = nv
                elseif k=="xtexoffset" then
                    frame.texOffset.x = nv
                elseif k == "ytexoffset" then
                    frame.texOffset.y = nv
                elseif k == "texwidth" then
                    frame.texSize.x = nv
                elseif k == "texheight" then
                    frame.texSize.y = nv
                elseif k == "xoffset" then
                    frame.offset.x = nv
                elseif k == "yoffset" then
                    frame.offset.y = nv
                elseif k == "duration" then
                    frame.duration = nv
                elseif k == "rendergroup" then
                    frame.renderGroup = nv
                end
            end

            data.cframe = frame
            if t.blend then
                node_handlers.blend(t.blend, data)
            end
            if t.traits then
                node_handlers.traits(t.traits, data)
            end
            if t.attack then
                node_handlers.attack(t.attack, data)
            end
            if t.hit then
                node_handlers.hit(t.hit, data)
            end
            if frame.frameFlags and frame.frameFlags & 0x1000000 ~=0 then
                frame.hurtboxes:copy(frame.attackBoxes)
            end
            if t.collision then
                node_handlers.collision(t.collision, data)
            end
            if t.effect then
                node_handlers.effect(t.effect, data)
            end
        end
    end,
    blend = function (t, data)
        local BO = data.type==2 and Hkr2.BlendOptions or Hkr.BlendOptions
        local frame = data.cframe
        local merge_option = t._attr and t._attr.merge_option
        if not merge_option then
            merge_option = frame.blendOptions and "update" or "add"
        end
        if merge_option=="drop" then
            memory.delete(frame.blendOptions.basePtr)
            frame.blendOptions = nil
        else
            local blend
            if merge_option=="add" then
                blend = BO()
                blend:init()
                frame.blendOptions = blend
            elseif merge_option=="update" then
                blend = frame.blendOptions
            end
            for k,v in pairs(t._attr) do
                local nv = tonumber(v)
                if k=="mode" then
                    blend.mode = nv + 1 --0 in pat is 1 in game
                elseif k=="color" then
                    blend.color = convert_BGRA(tonumber(v, 16))
                elseif k=="xscale" then
                    blend.scale.x = nv/100
                elseif k=="yscale" then
                    blend.scale.y = nv/100
                elseif k=="vertflip" then
                    blend.rotateX = nv
                elseif k=="horzflip" then
                    blend.rotateY = nv
                elseif k=="angle" then
                    blend.rotateZ = nv
                end
            end
        end
    end,
    traits = function(t, data) --
        local frame = data.cframe
        for k, v in pairs(t._attr) do
            local nv = tonumber(v)
            if k == "damage" then
                frame.damage = nv
            elseif k == "proration" then
                frame.ratio = nv
            elseif k == "chipdamage" then
                frame.chipDamage = nv
            elseif k == "spiritdamage" then
                frame.spiritDamage = nv
            elseif k == "untech" then
                frame.untech = nv
            elseif k == "power" then
                frame.power = nv
            elseif k == "limit" then
                frame.limit = nv
            elseif k == "onhitplayerstun" then
                frame.onHitPStun = nv
            elseif k == "onhitenemystun" then
                frame.onHitEStun = nv
            elseif k == "onblockplayerstun" then
                frame.onBlockPStun = nv
            elseif k == "onblockenemystun" then
                frame.onBlockEStun = nv
            elseif k == "onhitcardgain" then
                frame.onHitCardGain = nv
            elseif k == "onblockcardgain" then
                frame.onBlockCardGain = nv
            elseif k == "onairhitsetsequence" then
                frame.onAirHitSet = nv
            elseif k == "ongroundhitsetsequence" then
                frame.onGroundHitSet = nv
            elseif k == "xspeed" then
                frame.onHitSpeed.x = nv/100
            elseif k == "yspeed" then
                frame.onHitSpeed.y = nv/100
            elseif k == "onhitsfx" then
                frame.onHitSFX = nv
            elseif k == "onhiteffect" then
                frame.onHitFX = nv
            elseif k == "attacklevel" then
                frame.attackType = nv
            end
        end
        frame.frameFlags = traits_collect_flags(t, 0)
        frame.attackFlags = traits_collect_flags(t, 1)
        frame.comboFlags = traits_collect_flags(t, 2)
    end,

    hit = function(t, data) --hurtboxes
        local frame = data.cframe
        local boxes = frame.hurtboxes
        local merge_option = t._attr and t._attr.merge_option
        if not merge_option then
            merge_option = boxes:size()>0 and "trunc"
        end
        if merge_option=="drop" then
            boxes:clear()
        else
            if merge_option=="trunc" then
                boxes:clear()
            end
            local count = 0
            for index, box in ipairs(AsArray(t.box)) do
                count = count+1
            end
            if count>0 then
                boxes:resize(count)
            end
            for index, box in ipairs(AsArray(t.box)) do
                box = box._attr
                local proxy = boxes[index-1]
                proxy.left = tonumber(box.left)
                proxy.top = tonumber(box.up)
                proxy.right = tonumber(box.right)
                proxy.bottom = tonumber(box.down)
            end
        end
    end,

    attack = function(t, data) --hitboxes
        local frame = data.cframe
        local boxes = frame.attackBoxes
        local eboxes = frame.extraBoxes
        local merge_option = t._attr and t._attr.merge_option
        if not merge_option then
            merge_option = boxes:size()>0 and "trunc"
        end
        if merge_option=="drop" then
            boxes:clear()
            eboxes:clear()
        else
            if merge_option=="trunc" then
                boxes:clear()
                eboxes:clear()
            end
            local count = 0
            for index, box in ipairs(AsArray(t.box)) do
                count = count+1
            end
            if count>0 then
                boxes:resize(count)
                eboxes:resize(count)
            end
            for index, box in ipairs(AsArray(t.box)) do
                box = box._attr --ignore extraBoxes
                local proxy = boxes[index-1]
                proxy.left = tonumber(box.left)
                proxy.top = tonumber(box.up)
                proxy.right = tonumber(box.right)
                proxy.bottom = tonumber(box.down)
            end
        end
    end,

    collision = function(t, data) --collision box
        local frame = data.cframe
        local merge_option = t._attr and t._attr.merge_option
        if not merge_option then
            merge_option = frame.collisionBox and "update" or "add"
        end
        if merge_option=="drop" then
            memory.delete(frame.collisionBox.basePtr)
            frame.collisionBox = nil
        else
            local cbox
            if merge_option=="add" then
                cbox = Hkr.Box()
                cbox:init()
                frame.collisionBox = cbox
            elseif merge_option=="update" then
                cbox = frame.collisionBox
            end
            local box = t.box and AsArray(t.box)[1]
            if box then
                box = box._attr
                cbox.left = tonumber(box.left)
                cbox.top = tonumber(box.up)
                cbox.right = tonumber(box.right)
                cbox.bottom = tonumber(box.down)
            end
        end
    end,

    effect = function (t, data) --extra property
        local frame = data.cframe
        for k, v in pairs(t._attr) do
            local nv = tonumber(v)
            if k == "xpivot" then
                frame.customVector1.x = nv
            elseif k == "ypivot" then
                frame.customVector1.y = nv
            elseif k == "xpositionextra" then
                frame.customVector2.x = nv
            elseif k == "ypositionextra" then
                frame.customVector2.y = nv
            elseif k == "xposition" then
                frame.customVector3.x = nv
            elseif k == "yposition" then
                frame.customVector3.y = nv
            elseif k == "xspeed" then
                frame.customShort1 = nv
            elseif k == "yspeed" then
                frame.customShort2 = nv
            elseif k == "unknown02" then
                frame.customShort3 = nv
            end
        end
    end,

    movepatterndiff = function (t, hkr, cname)
        local data = {
            type = 1,
            cname = cname,
            hacker = hkr,
            cblock = nil, cframe = nil,
            xactId = nil, xseqId = nil, xposeId = nil,
            dropBuffer = {
                block = {}, frame = {},
                record_modify = record_modify,
                resolve = resolve,
            }
        }
        for index, move in ipairs(AsArray(t.move)) do
            node_handlers.block(move, data)
        end
    end,
    animpatterndiff = function (t, hkr, cname)
        local data = {
            type = 2,
            cname = cname,
            hacker = hkr,
            cblock = nil, cframe = nil,
            xactId = nil, xseqId = nil, xposeId = nil,
            dropBuffer = {
                block = {}, frame = {},
                record_modify = record_modify,
                resolve = resolve,
            }
        }
        for index, move in ipairs(AsArray(t.animation)) do
            node_handlers.block(move, data)
        end
    end
}


function G.merge(hkr, cname, parsed_table)
    for index, diff in ipairs(AsArray(parsed_table.movepatterndiff)) do
        node_handlers.movepatterndiff(diff, hkr, cname)
    end
    for index, diff in ipairs(AsArray(parsed_table.animpatterndiff)) do
        node_handlers.animpatterndiff(diff, hkr, cname)
    end
end

return G

