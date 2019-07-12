--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local twp = {}

function twp:load()
	registerClPacket(0x2B, 3, function(player, buf)
		local dir = buf:readByte()
		local data = buf:readUShort()

		if dir == 0 then
			buf:reset()
				buf:writeByte(0x2B)
				buf:writeByte(0)
				buf:writeShort(data)
			buf:sendTo(player:getClient())
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
		local buf = player._buf
		buf:reset()
			buf:writeByte(0x2B)
			buf:writeByte(1)
			buf:writeShort(rand)
		buf:sendTo(player:getClient())
		player.pData = rand
		player.pTime = ctime
		return true
	end
end

return twp
