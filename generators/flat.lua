local function getOffset(ptr, offset)
	local addr = tonumber(ffi.cast('uint32_t', ptr))
	return ffi.cast('char*',addr+offset)
end

return function(world, seed)
	local dx, dy, dz = world:getDimensions()
	local data = world.ldata
	local flr = dz*dx
	local sz = flr*(dy/4-2)
	ffi.fill(data+4, flr, 7)
	ffi.fill(data+flr+4, sz, 3)
	ffi.fill(data+sz+4, dz*dx, 2)

	local ma = {
		[0] = 3,
		[1] = 8,
		[2] = (dy/4)-1
	}
	world.data.map_aspects = ma
	world.data.isNether = false

	world:setSpawn(dx/2, (dy/4)+1.59375, dz/2)
	return true
end
