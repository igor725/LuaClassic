return function(player, id, x, y, z, yaw, pitch)
	player:setPos(x / 32, y / 32, z / 32)
	player:setEyePos((yaw / 255) * 360, (pitch / 255) * 360)

	if player:isSupported('HeldBlock')then
		id = math.max(0, math.min(255, id))
		if player.heldBlock ~= id then
			player.heldBlock = id
			hooks:call('onHeldBlockChange', player, id)
		end
	end

	local pid = player:getID()
	local pck, cpepck

	playersForEach(function(ply)
		if not ply.isSpawned then return end
		if ply:isInWorld(player)then
			if ply:isSupported('ExtEntityPositions')then
				cpepck = cpepck or cpe:generatePacket(0x08, pid, x, y, z, yaw, pitch)
				ply:sendNetMesg(cpepck)
			else
				pck = pck or generatePacket(0x08, pid, x, y, z, yaw, pitch)
				ply:sendNetMesg(pck)
			end
		end
	end)
end
