--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local iord = {}

function iord:load()
	registerSvPacket(0x2C, 'bbb')
	getPlayerMT().setInventoryOrder = function(player, order, id)
		if not player:isSupported('InventoryOrder')then
			return false
		end
		player:sendPacket(false, 0x2C, order, id)
		return true
	end
end

return iord
