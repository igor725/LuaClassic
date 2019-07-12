--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

return function(player, buf)
	local id, x, y, z, yaw, pitch

	id = buf:readByte()
	if player:isSupported('ExtEntityPositions')then
		x, y, z = buf:readInt3()
	else
		x, y, z = buf:readShort3()
	end
	yaw = buf:readByte()
	pitch = buf:readByte()

	player:setPos(x / 32, y / 32, z / 32)
	player:setEyePos((yaw / 255) * 360, (pitch / 255) * 360)

	if player:isSupported('HeldBlock')then
		if not isValidBlockID(id)then
			id = 0
		end

		if player.heldBlock ~= id then
			player.heldBlock = id
			hooks:call('onHeldBlockChange', player, id)
		end
	end

	playersForEach(function(ply)
		if not ply.isSpawned then return end
		if ply == player then return end

		if ply:isInWorld(player)then
			buf:reset()
				buf:writeByte(0x08)
				buf:writeByte(player:getID())
			if ply:isSupported('ExtEntityPositions')then
				buf:writeVarInt(x, y, z)
			else
				buf:writeVarShort(x, y, z)
			end
				buf:writeByte(yaw)
				buf:writeByte(pitch)
			buf:sendTo(ply:getClient())
		end
	end)
end
