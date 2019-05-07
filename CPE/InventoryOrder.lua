local iord = {}

function iord:load()
	registerSvPacket(0x2C, 'BBB')
	getPlayerMT().setInventoryOrder = function(player, order, id)
		if player:isSupported('InventoryOrder')then
			player:sendPacket(false, order, id)
		end
	end
end

return iord
