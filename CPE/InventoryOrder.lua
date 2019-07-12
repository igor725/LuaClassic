--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local iord = {}

function iord:load()
	getPlayerMT().setInventoryOrder = function(player, order, id)
		if not player:isSupported('InventoryOrder')then
			return false
		end
		local buf = player._buf
		buf:reset()
			buf:writeByte(0x2C)
			buf:writeByte(order)
			buf:writeByte(id)
		buf:sendTo(player:getClient())
		return true
	end
end

return iord
