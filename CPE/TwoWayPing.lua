--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local twp = {}

function twp:load()
	registerSvPacket(0x2B, '>bbH')
	registerClPacket(0x2B, '>bH', function(player, dir, data)
		if dir == 0 then
			player:sendPacket(false, 0x2B, 0, data)
		elseif dir == 1 then
			if data == player.pData then
				player.ping = (ctime - player.pTime) / .002
			end
		end
	end)
	getPlayerMT().testPing = function(player)
		if not player:isSupported('TwoWayPing')then
			return false
		end
		local rand = math.random(0, 32767)
		player:sendPacket(false, 0x2B, 1, rand)
		player.pData = rand
		player.pTime = ctime
		return true
	end
end

return twp
