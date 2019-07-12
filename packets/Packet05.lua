--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

return function(player, buf)
	local x, y, z, mode, id
	if player:isSupported('ExtEntityPositions')then
		x, y, z = buf:readInt3()
	else
		x, y, z = buf:readShort3()
	end
	mode = buf:readByte()
	id = buf:readByte()

	local world = getWorld(player)
	local cblock = world:getBlock(x, y, z)

	if mode == 0x00 then
		id = 0
	end

	local cantPlace = not player.isSpawned

	if world:isReadOnly()then
		player:sendMessage(WORLD_RO, MT_ANNOUNCE)
		cantPlace = true
	end

	if not cantPlace and cblock == -1 then
		cblock = 1
		cantPlace = true
	end

	if not cantPlace then
		cantPlace = not isValidBlockID(id)
	end

	if not cantPlace then
		cantPlace = hooks:call('prePlayerPlaceBlock', player, x, y, z, id)
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
		buf:reset()
			buf:writeByte(0x06)
			buf:writeVarShort(x, y, z)
			buf:writeByte(cblock)
		buf:sendTo(player:getClient())
	end
end
