--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local cd = {}

function cd:load()
	registerSvPacket(0x12, '>bH')
	getPlayerMT().setClickDistance = function(player, cdist)
		if not player:isSupported('ClickDistance')then
			return false
		end
		player:sendPacket(false, 0x12, cdist)
		return true
	end
end

return cd
