function treeCreate(x, y, z, treeType, world)
	BulkBlockUpdate:start(world)
	local baseHeight2

	if treeType == 1 then
		baseHeight2 = y + math.random(3, 5)

		for dz = z - 2, z + 2 do
			for dy = baseHeight2 - 2, baseHeight2 - 1 do
				for dx = x - 2, x + 2 do
					local o = BulkBlockUpdate:write(dx, dy, dz, 18)
					if o then
						world.ldata[o] = 18
					end
				end
			end
		end

		for dx = x - 1, x + 1 do
			if dx ~= x then
				for y = baseHeight2, baseHeight2 + 1 do
					local o = BulkBlockUpdate:write(dx, y, z, 18)
					if o then
						world.ldata[o] = 18
					end
				end
			end
		end
		for dz = z - 1, z + 1 do
			if dz ~= z then
				for y = baseHeight2, baseHeight2 + 1 do
					local o = BulkBlockUpdate:write(x, y, dz, 18)
					if o then
						world.ldata[o] = 18
					end
				end
			end
		end
		local o = BulkBlockUpdate:write(x, baseHeight2 + 1, z, 18)
		if o then
			world.ldata[o] = 18
		end
	elseif treeType == 2 then
		baseHeight2 = y + math.random(3, 5)

		for y = y + 2, baseHeight2 + 2 do
			local radius = y > baseHeight2
			and ((y - baseHeight2) % 2) + 1
			or (((y - baseHeight2) % 2) + math.random() * 2)

			local radiusCeil = math.ceil(radius)
			radius = radius * radius

			for dx = -radiusCeil, radiusCeil do
				for dz = -radiusCeil, radiusCeil do
					if dx * dx + dz * dz < radius then
						local o = BulkBlockUpdate:write(x + dx, y, z + dz, 18)
						if o then
							world.ldata[o] = 18
						end
						if y > baseHeight2 then
							local o = BulkBlockUpdate:write(x + dx, y + 1, z + dz, 53)
							if o then
								world.ldata[o] = 53
							end
						end
					end
				end
			end
		end
	end

	for dy = y, baseHeight2 do
		local o = BulkBlockUpdate:write(x, dy, z, 17)
		if o then
			world.ldata[o] = 17
		end
	end
	BulkBlockUpdate:done()
end
