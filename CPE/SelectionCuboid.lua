local sc = {
	global = true
}

function sc:load()
	registerSvPacket(0x1A, '>bbc64hhhhhhhhhh')
	registerSvPacket(0x1B, 'bb')
end

function sc:create(player, id, label, x1, y1, z1, x2, y2, z2, r, g, b, a)
	label = label or'New selection'
	r = r or 20
	g = g or 250
	b = b or 20
	a = a or 100
	x1, y1, z1, x2, y2, z2 = makeNormalCube(x1, y1, z1, x2, y2, z2)
	if player:isSupported('SelectionCuboid')then
		player:sendPacket(
			false,
			0x1A,
			id,
			label,
			x1, y1, z1,
			x2, y2, z2,
			r, g, b, a
		)
	end
end

function sc:remove(player, id)
	if player:isSupported('SelectionCuboid')then
		player:sendPacket(false, 0x1B, id)
	end
end

return sc
