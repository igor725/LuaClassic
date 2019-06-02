return function(player, x, y, z, mode, id)
	local world = getWorld(player)
	local cblock = world:getBlock(x, y, z)

	if mode == 0x00 then
		id = 0
	else
		if cblock ~= 0 and not(cblock >= 8 and cblock <= 11)then
			id = cblock
		end
	end
	if cblock ~= id then
		local cantPlace
		if world:isReadOnly()then
			player:sendMessage(WORLD_RO, MT_ANNOUNCE)
			cantPlace = true
		end
		if not cantPlace then
			cantPlace = hooks:call('onPlayerPlaceBlock', player, dy, dp)
		end
		if not cantPlace and player.onPlaceBlock then
			cantPlace = player.onPlaceBlock(x, y, z, id)
		end
		if not cantPlace and onPlayerPlaceBlock then
			cantPlace = onPlayerPlaceBlock(player, x, y, z, id)
		end
		if not cantPlace then
			world:setBlock(x, y, z, id)
			broadcast(generatePacket(0x06, x, y, z, id))
		else
			player:sendPacket(false, 0x06, x, y, z, cblock)
		end
	end
end
