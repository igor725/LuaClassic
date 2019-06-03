return function(world)
	local dx, dy, dz = world:getDimensions()
	local data = world.ldata
	local flr = dz * dx
	local sz = flr * (dy / 4 - 2)
	ffi.fill(data + 4, flr, 7)
	ffi.fill(data + flr + 4, sz, 3)
	ffi.fill(data + sz + 4, dz * dx, 2)

	world:setEnvProp(MEP_SIDESBLOCK, 3)
	world:setEnvProp(MEP_EDGEBLOCK, 8)
	world:setEnvProp(MEP_EDGELEVEL, dy / 4 - 1)
	world:setData('isNether', false)

	world:setSpawn(dx / 2, dy / 4 + 1.59375, dz / 2)
	return true
end
