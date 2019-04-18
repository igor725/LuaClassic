local bp = {
	global = true
}

function bp:load()
	registerSvPacket('BBBB')
end

function bp:setFor(player, id, allowPlace, allowDelete)
	allowPlace = (allowPlace and 1)or 0
	allowDelete = (allowDelete and 1)or 0
	player:sendPacket(false, 0x1C, id, allowPlace, allowDelete)
end

return bp
