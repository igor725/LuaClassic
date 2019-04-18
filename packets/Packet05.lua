return function(player, x, y, z, mode, id)
	local world = worlds[player.worldName]
	local cblock = world:GetBlock(x,y,z)

	if mode == 0x00 then
		id = 0
	else
		if cblock~=0 and not(cblock>=8 and cblock<=11)then
			id = cblock
		end
	end
	if cblock ~= id then
		if not onPlayerPlaceBlock(player, x, y, z, id)then
			world:SetBlock(x,y,z,id)
			broadcast(generatePacket(0x06, x, y, z, id))
		else
			player:sendPacket(false, 0x06, x, y, z, cblock)
		end
	end
end
