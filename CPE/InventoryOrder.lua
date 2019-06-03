local iord = {}

function iord:load()
	registerSvPacket(0x2C, 'bbb')
	getPlayerMT().setInventoryOrder = function(player, order, id)
		if player:isSupported('InventoryOrder')then
			player:sendPacket(false, 0x2C, order, id)
		end
	end
end

return iord
