function treeCreate(x, y, z, treeType, world)
	if treeType == 1 then
		baseHeight2 = y + math.random(3, 5)

			for dz = z - 2, z + 2 do
				for dy = baseHeight2 - 2, baseHeight2 - 1 do
					for dx = x - 2, x + 2 do
						world:setBlock(dx, dy, dz, 18)
					end
				end
			end

		for dy = y, baseHeight2 do
			world:setBlock(x, dy, z, 17)
		end

		for dx = x - 1, x + 1 do
			if dx ~= x then
				for y = baseHeight2, baseHeight2 + 1 do
					world:setBlock(dx, y, z, 18)
				end
			end
		end
		for dz = z - 1, z + 1 do
			if dz ~= z then
				for y = baseHeight2, baseHeight2 + 1 do
					world:setBlock(x, y, dz, 18)
				end
			end
		end
		world:setBlock(x, baseHeight2 + 1, z, 18)
	elseif treeType == 2 then
		baseHeight2 = y + math.random(3, 5)

		for y = y + 2, baseHeight2 + 2 do
			local radius = y > baseHeight2
				and ((y-baseHeight2) % 2) + 1
				or (((y-baseHeight2) % 2) + math.random() * 2)

			local radiusCeil = math.ceil(radius)
			radius = radius*radius
			for dx = -radiusCeil, radiusCeil do
				for dz = -radiusCeil, radiusCeil do
					if dx*dx + dz*dz < radius then
						world:setBlock(x+dx, y, z+dz, 18)
						if y > baseHeight2 then
							world:setBlock(x+dx, y+1, z+dz, 53)
						end
					end
				end
			end
		end

		for dy = y, baseHeight2 do
			world:setBlock(x, dy, z, 17)
		end
	end
end
