require("FCSM_scripts")
local ADDR_SUBMENU_CHARACTER = 0x899D10

local isChanged=false

local function MenuProcess(menu)
	local input = menu.input
	local data = menu.data
	local v, h= data["cursorV"], data["cursorH"]
	local m = data["cursor"]
	isChanged = false
	--box update
	if data["box"] then
		if menu.renderer.showResult==2 then
			data["box"] = nil
		elseif menu.renderer.showResult==1 then	
			soku.playSFX(40) --save
			memory.writeint(ADDR_SUBMENU_CHARACTER, m.index)
			isChanged = true
			return false
		end
		return
	end
	--mat cursor update
	local n, ln = v.index + h.index*v.max, data["last"]
	if n>=m.max then
		local d1, d2 = n%v.max-ln%v.max, n//v.max-ln//v.max
		if d1==0 then
			v.index = (m.max-1)%v.max
		elseif d2==0 then
			v.index = d1~=v.max-1 and 0 or (m.max-1)%v.max
		else
			v.index = (m.max-1)%v.max
		end
		n=v.index + h.index*v.max
	end
	m.index = n
	-- print( "v", v.index, "vp", v.page)
	
	if(input.b==1 or soku.checkFKey(1) or memory.readint(0x89A2A0)==1) then--X/ keyboard esc / InputCluster.Pause
		soku.playSFX(41) --exit
		return false
	elseif(input.a==1) then
		local result = m.index
		menu.renderer:ShowMessage("确认选择“"..soku.characterName(result).."”吗？", true)
		soku.playSFX(61)
		data["box"] = true
	end
	data["last"] = n
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
		local infoS = scene.renderer:createText("已修改角色值。请勿切换角色，直接进入对战。", ft, 400, 20)
		infoS.position.x=-10
		infoS.position.y=-440
		infoS:setColor(0x00FFFFFF)
		scene.data["infoS"]=infoS --avoid closure
		
		return function(scene)
			local input = scene.input
			if(input.spell==1 and not gui.isMenuOpen()) then --open menu
				local menu = gui.OpenMenu(MenuProcess); soku.playSFX(61)--enter 
				local ind, sv, sh, max = 0, 15, 2, 20
				local v, h = menu.renderer:createCursorV(0, sv, ind%sv), menu.renderer:createCursorH(0, sh, ind//sv)
				v.isVisible = false; h.isVisible = false
				--v.sfxId = -1; h.sfxId = -1
				menu.data["cursorV"] = v
				menu.data["cursorH"] = h
				local m = menu.renderer:createCursorH(300, max, ind)
				ind = m.index
				m.isActive = false
				local x, y, dx, dy, rx, ry = 100, 50, 15, 20, 300, 10
				for i=0,sh-1 do
					for j=0,sv-1 do
						if i*sv+j>=max then break end
						m:setPosition(i*sv+j, x+j*dx+i*rx, y+j*dy+i*ry)
					end
				end
				menu.data["cursor"] = m
				menu.data["last"] = ind
				---[[show names
				for i= 0,19 do
					--cursor:setPosition(i, 80+i*10, 100+i*20)
					local names = menu.renderer:createSprite(string.format("data/profile/deck1/%02da_%s.png", i, soku.characterName(i)))
					if(i<20) then
						local x, y = m:getPosition(i)
						names.position.x = -(x)
						names.position.y = -(y) + 5
					else
						local x, y = m:getPosition(17)
						names.position.x = -x-dx*(i-17)
						names.position.y = -y-dy*(i-17)
						names:setColor(0xFFFF0000)
					end
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
