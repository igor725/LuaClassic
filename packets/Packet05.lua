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

		if not cantPlace then
			if world:setBlock(x, y, z, id, player)then
				hooks:call('postPlayerPlaceBlock', player, x, y, z, id, cblock)
			else
				cantPlace = true
			end
		end

		if cantPlace then
			cblock = cblock or 1
			player:sendPacket(false, 0x06, x, y, z, cblock)
		end
	end
end
