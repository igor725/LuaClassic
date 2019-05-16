local twp = {}

function twp:load()
	registerSvPacket(0x2b, '>bbh')
	registerClPacket(0x2b, '>bh', function(player, dir, data)
		if dir == 0 then
			player:sendPacket(false, 0x2b, 0, data)
		elseif dir == 1 then
			if data == player.pData then
				player.ping = (CTIME - player.pTime) / .002
			end
		end
	end)
	getPlayerMT().testPing = function(player)
		local rand = math.random(0, 32767)
		player:sendPacket(false, 0x2b, 1, rand)
		player.pData = rand
		player.pTime = CTIME
	end
end

return twp
