-- print("main", ...)
local relative = ... and (...):gsub(".init$", "").."." or ""
local Hkr = require(relative.."FrameDataHacker")
local G = require(relative.."merger")

local function check_story()
    return memory.readbytes(0x898690, 1)=="\x00"
end

local diff_suwako = G.fromXml(relative:gsub("%.","/").."_generator/diff_suwako.xml")
local diff_utsuho = G.fromXml(relative:gsub("%.","/").."_generator/diff_utsuho.xml")

Hkr.AddCallBack("suwako", function (hkr, palette, isFirst)
    -- local block = hkr:getBlock(800, 0)
    -- if not block or palette~=0 then return end
    -- block.frames[0].untech = 120
    -- block.frames[0].damage = 1000
    -- -- print(hkr.tex:size())
    -- block.frames[0].texIndex = hkr:loadTexture("yukari", "bulletAb000.bmp")
    -- print(hkr.tex[-1])
    if check_story() then
        G.merge(hkr, "suwako", diff_suwako)
        print("Suwako pat fix merged.")
    end
end)

Hkr.AddCallBack("utsuho", function (hkr, palette, isFirst)
    if check_story() then
        G.merge(hkr, "utsuho", diff_utsuho)
        print("Utsuho pat fix merged.")
    end
end)

--[[expand story menu to all - hardcode
require("FCSM_scripts.ChainedPatch")
--]]

local ADDR_ENABLED_SCENARIOS = 0x899f60+0x1C
local _mEnableCharacterScenario= memory.createfunccall(0x422990, 1, true)

local function split_chars(str)
    local result = {}
    for k = 1, #str do
        result[k] = string.byte(str, k)
    end
    return result
end
local function merge_chars(arr)
    return string.char(table.unpack(arr))
end

local function EnableCharacterScenario(thisptr, character)
    local psc = memory.new(4)
    if psc~=0 then
        memory.writeint(psc, character)
        _mEnableCharacterScenario(thisptr, psc)
    end
    memory.delete(psc)
end

local initialScenario = {
    [soku.Character.Reimu]=true, [soku.Character.Marisa]=true, [soku.Character.Sakuya]=true,
    [soku.Character.Sanae]=true,
}
local originalScenario = {
    [soku.Character.Sanae]=true, --sanae
    [soku.Character.Cirno]=true, --cirno
    [soku.Character.Meiling]=true, --meiling
}

---[[SOR scenario unlock tree
local ADDR_SCENARIO_SCORES = 0x899f60+0x8
local unlock_tree = {
    [soku.Character.Youmu] = {
        requires = { soku.Character.Reimu }
    },
    [soku.Character.Alice] = {
        requires = { soku.Character.Marisa }
    },
    [soku.Character.Patchouli] = {
        requires = { soku.Character.Sakuya }
    },
    [soku.Character.Remilia] = {
        requires = { 
            soku.Character.Reimu,
            soku.Character.Marisa,
            soku.Character.Sakuya
        }
    },
    [soku.Character.Yuyuko] = { 
        requires = { soku.Character.Remilia }
    },
    [soku.Character.Yukari] = {
        completed_count = 4
    },
    [soku.Character.Suika] = {
        completed_count = 7
    },
    [soku.Character.Reisen] = {
        requires = { soku.Character.Alice }
    },
    [soku.Character.Aya] = {
        requires = { soku.Character.Remilia }
    },
    [soku.Character.Komachi] = {
        requires = { soku.Character.Youmu }
    },
    [soku.Character.Iku] = {
        any_of = {
            soku.Character.Reimu,
            soku.Character.Marisa,
            soku.Character.Sakuya
        }
    },
    [soku.Character.Tenshi] = {
        any_of = {
            soku.Character.Reimu,
            soku.Character.Marisa,
            soku.Character.Sakuya
        }
    },
    --for custom
    [soku.Character.Utsuho]= {
        requires = { soku.Character.Meiling }
    },
    [soku.Character.Suwako]= {
        requires = { soku.Character.Utsuho }
    }
}

memory.hooktramp(0x431253, 5, memory.createcallback(0, function (state)
    local es = split_chars(memory.readbytes(ADDR_ENABLED_SCENARIOS, 20))
    local ss = split_chars(memory.readbytes(ADDR_SCENARIO_SCORES, 20))
    -- patch reimu, marisa, sakuya
    for i, enabled in pairs(initialScenario) do
        local k= i+1
        if not originalScenario[i] then
            es[k]=1
        end
    end
    ---[[unlock by tree
    local completed=0
    for k,v in pairs(ss) do
        if v~=0 then
            completed=completed+1
        end
    end

    for unlock,rule in pairs(unlock_tree) do
        local ok=true
        -- AND
        if rule.requires then
            for _,c in pairs(rule.requires) do
                if ss[c+1]==0 then
                    ok=false
                    break
                end
            end
        end
        -- OR
        if ok and rule.any_of then
            ok=false
            for _,c in pairs(rule.any_of) do
                if ss[c+1]~=0 then
                    ok=true
                    break
                end
            end
        end
        -- count
        if ok and rule.completed_count then
            ok= completed >= rule.completed_count
        end

        if ok then
            es[unlock+1]=1
        end
    end
    --]]
    -- local debug=""
    -- for k = 1, 20 do
    --     local i = k-1
    --     debug=debug..tostring(i)..(es[k]~=0 and "|" or "o").." "
    -- end
    -- print(debug)
    memory.writebytes(ADDR_ENABLED_SCENARIOS, merge_chars(es))
end))
--]]

local function EnableAll (state)
    local thisptr = state.ecx
    local unlocked = {}
    local es = split_chars(memory.readbytes(ADDR_ENABLED_SCENARIOS, 20))
    local ss = split_chars(memory.readbytes(ADDR_SCENARIO_SCORES, 20))
    for k = 1, 20 do
        local i = k-1
        unlocked[k] = not originalScenario[i] and (es[k]~=0 or ss[k]~=0)
    end

    for k=19,20 do
        local i = k-1
        if unlocked[k] then
            EnableCharacterScenario(thisptr, i)
            -- print("unlocked", i)
        end
    end
    for k=1,18 do
        local i = k-1
        if unlocked[k] then
            EnableCharacterScenario(thisptr, i)
            -- print("unlocked", i)
        end
    end
end
---[[expand story menu to all
local ADDR_CSELECT_TYPE=0x898690
memory.hooktramp(0x426e43, 5, memory.createcallback(1, function (state)
    if memory.readint(ADDR_CSELECT_TYPE)==0 then
        EnableAll(state)
    end
end))
--]]

---[[expand result menu to all
memory.hooktramp(0x44c66d, 5, memory.createcallback(1, EnableAll))
--]]