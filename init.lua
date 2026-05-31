local _checkNoSWR = memory.createfunccall(0x43dc10, 0, false)
local function CheckSWR()
	return (_checkNoSWR()&0xff)==0
end
soku.SubscribeReady(function ()

if not CheckSWR() then
	print("Game failed to load SWR data!") print("FullCharacterStoryMenu has auto closed.")
	return
end

require("FCSM_scripts")
local CMat = require("FCSM_scripts.CursorMatProxy")
local ADDR_SUBMENU_CHARACTER = 0x899D10
local ADDR_CURRENT_SCENE = 0x8A000C

local isChanged=false

---
---@param menu guilib.Menu
---@return boolean|nil
local function MenuProcess(menu)
	local input = menu.input
	local data = menu.data
	-- local v, h= data["cursorV"], data["cursorH"]
	local m = data["cursor"]
	isChanged = false
	--box update
	local boxResult = menu.renderer.showResult
	if data["box"] then --gui.Renderer.MSG_WAIT
		if boxResult==gui.Renderer.MSG_CANCEL or boxResult==gui.Renderer.MSG_NO then
			data["box"] = nil
		elseif boxResult==gui.Renderer.MSG_OK or boxResult==gui.Renderer.MSG_YES then
			soku.playSFX(40) --save
			memory.writeint(ADDR_SUBMENU_CHARACTER, m.index)
			isChanged = true
			--to deck
			local pscene = memory.readint(ADDR_CURRENT_SCENE)
			if pscene~=0 then
				memory.writeint(pscene+0x1424, 1)
			end
			return false
		end
		return
	end
	---[[mat cursor update
	m:update()
	--]]
	
	if(input.b==1 or soku.checkFKey(1) or memory.readint(0x89A2A0)==1) then--X/ keyboard esc / InputCluster.Pause
		soku.playSFX(41) --exit
		return false
	elseif(input.a==1) then
		local result = m.index
		menu.renderer:ShowChoice("Sure to choose \""..soku.characterName(result).."\"?", true)
		soku.playSFX(61)
		data["box"] = true
	end
	-- data["last"] = m.index
end

local ft= gui.Font()
ft:setFontName("simhei")
ft.shadow=1
ft.height=18
--ft.weight=300
soku.SubscribeSceneChange(
	function(id, scene)
		if(id~=soku.Scene.SelectStage) then return false end
		--print("submenu")
		local infoS = scene.renderer:createText("Character was set, now enter battle to start!", ft, 400, 20)
		infoS.position.x=-10
		infoS.position.y=-440
		infoS:setColor(0x00FFFFFF)
		scene.data["infoS"]=infoS --avoid closure
		
		return function(scene)
			local input = scene.input
			if(input.spell==1 and not gui.isMenuOpen()) then --open menu
				local menu = gui.OpenMenu(MenuProcess); soku.playSFX(61)--enter
				local width, max, ind, warp = 300, 20, 0, 15
				local m = CMat.create(menu.renderer, width, max, ind, warp, false)
				ind = m.index
				local x, y, dx, dy, rx, ry = 100, 50, 15, 20, 300, 10
				m:setGrid(x,y, dx,dy, rx,ry)
				
				menu.data["cursor"] = m
				-- menu.data["last"] = ind
				---[[show names
				for i= 0,19 do
					--cursor:setPosition(i, 80+i*10, 100+i*20)
					local names = menu.renderer:createSprite(string.format("data/profile/deck1/%02da_%s.png", i, soku.characterName(i)))
					local x, y = m:getPosition(i)
					names.position.x = -(x)
					names.position.y = -(y) + 5
				end--]]
			end
			if(isChanged) then --enable text
				if(scene.data["infoF"]==nil) then scene.data["infoF"] = 0 end
				isChanged = false
			end
			if(scene.data["infoF"]) then --fade text
				local opacity=scene.data["infoF"]<100 and 255 or 255*(160-scene.data["infoF"])/60
				scene.data["infoS"]:setColor(0x00FFFFFF + math.floor(opacity)*(2^24))
				scene.data["infoF"] = scene.data["infoF"] + 1
				if(scene.data["infoF"]>160) then scene.data["infoF"]=nil end
			end
		end
	end
)
	
end)

--[[
	local Df = require "FCSM_scripts.DatFlater"

	-- local d = Df.FromFile("score123-full-sc.dat")
	-- print("decomp str size", #d)
	-- local f= io.open("score123-full-sc.dat.decomp", "wb")
	-- if f then
	-- 	f:write(d); f:close()
	-- end
	local f = io.open("score123-full-sc.dat.decomp", "rb")
	if f then
		local d = f:read("a"); f:close()
		print("recomp str size", #d)
		Df.ToFile("score123-full-sc.dat.recomp", d)
	end
--]]

--[[try to unlock all sc
local ADDR_SPELLCARD_RECORDS = 0x899f60+0x1a4
local M = require("FCSM_scripts.FrameDataHacker.declarator")
M.define("BonusRecord", {
	size=0x18,
	fields = {
        enemy = {offset=0x00, type="int"},
        difficulty = {offset=0x4, type="int"},
		csvIndex = {offset=0x8, type="int"},
        countTry= {offset=0xC, type="int"},
		countSucc = {offset=0x10, type="int"},
        timeLeft = {offset=0x14, type="int"},
    },
})
M.define("vector<BonusRecord>", M.get_template("vector<>")("BonusRecord"))
soku.SubscribeReady(function ()
	for k=1,20 do
		local p = ADDR_SPELLCARD_RECORDS + (k-1)*M.get_define("vector<BonusRecord>").size
		local rec = M.fromPtr("vector<BonusRecord>", p)
		print(p)
		for i=0, rec:size()-1 do
			local v = rec[i] or {}
			v.countTry=1; v.countSucc=1
			v.timeLeft = -60
		end
	end
end)
--]]

---[[try to unlock cards
--]]