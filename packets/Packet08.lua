return function(player, id, x, y, z, yaw, pitch)
	player:setPos(x/32, y/32, z/32)
	player:setEyePos((yaw/255)*360,(pitch/255)*360)

	local id = player:getID()
	local pck, cpepck

	playersForEach(function(ply)
		if not ply.isSpawned then return end
		if ply.worldName == player.worldName then
			if ply:isSupported('ExtEntityPositions')then
				cpepck = cpepck or cpe:GeneratePacket(0x08, id, x, y, z, yaw, pitch)
				ply:sendNetMesg(cpepck)
			else
				pck = pck or generatePacket(0x08, id, x, y, z, yaw, pitch)
				ply:sendNetMesg(pck)
			end
		end
	end)
end
