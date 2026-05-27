print("main", ...)
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