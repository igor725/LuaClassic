local twp = {}

function twp:load()
	registerSvPacket(0x2b, '>Bbh')
	registerClPacket(0x2b, '>bh', function(player, dir, data)
		if dir == 0 then
			player:sendPacket(false, 0x2b, 0, data)
			player:sendPacket(false, 0x2b, 1, data)
			player.pData = data
			player.pTime = CTIME
		elseif dir == 1 then
			if data == player.pData then
				player.ping = (CTIME-player.pTime)/.002
			end
		end
	end)
end

return twp
