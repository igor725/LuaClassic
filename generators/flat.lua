local function getOffset(ptr, offset)
	local addr = tonumber(ffi.cast('uint32_t', ptr))
	return ffi.cast('char*',addr+offset)
end

return function(world, seed)
	local dx, dy, dz = world:GetDimensions()
	io.write("terrain, ")
	local data = world.ldata
	local sz = (dz*dx)*(dy/4-2)
	ffi.fill(data+4, sz, 3)
	ffi.fill(data+sz, dz*dx, 2)

	if config:get('cpe-enabled',true)then
		local ma = {
			['0'] = 3,
			['1'] = 8,
			['2'] = (dy/4)-1
		}
		world.data.map_aspects = ma
	end

	world:SetSpawn(dx/2, (dy/4)+1.59375, dz/2)
	return true
end
