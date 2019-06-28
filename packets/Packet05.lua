--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

return function(player, x, y, z, mode, id)
	local world = getWorld(player)
	local cblock = world:getBlock(x, y, z)

	if mode == 0x00 then
		id = 0
	end

	if cblock ~= id and isValidBlockID(id)then
		local cantPlace
		if world:isReadOnly()then
			player:sendMessage(WORLD_RO, MT_ANNOUNCE)
			cantPlace = true
		end
		
		if not cantPlace then
			cantPlace = hooks:call('onPlayerPlaceBlock', player, x, y, z, id)
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
			if postPlayerPlaceBlock then
				postPlayerPlaceBlock(player, x, y, z, id, cblock)
			end
			hooks:call('postPlayerPlaceBlock', player, x, y, z, id, cblock)
		else
			player:sendPacket(false, 0x06, x, y, z, cblock)
		end
	end
end
