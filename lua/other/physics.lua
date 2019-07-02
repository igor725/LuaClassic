hooks:add('onInitDone', 'load_physics', function()
	if not config:get('physicsEnabled')then return end

	local WATER_LEAK_SIZE = 6

	local function findWaterBlockToRemove(world, x, y, z, dirx, dirz)
		local dirx, dirz = dirx or 0, dirz or 0
		local upX, upY, upZ = x, y, z
		while true do
			-- Check up
			if world:getBlock(x, y + 1, z) == 8 then
				y = y + 1

			-- Check up forward
			elseif world:getBlock(x + 1, y + 1, z) == 8 then
				x = x + 1
				y = y + 1

			-- Check up back
			elseif world:getBlock(x - 1, y + 1, z) == 8 then
				x = x - 1
				y = y + 1

			-- Check up left
			elseif world:getBlock(x, y + 1, z + 1) == 8 then
				z = z + 1
				y = y + 1

			-- Check up right
			elseif world:getBlock(x, y + 1, z - 1) == 8 then
				z = z - 1
				y = y + 1

			-- Check forward
			elseif dirx >= 0 and world:getBlock(x + 1, y, z) == 8 then
				dirx = 1
				x = x + 1

			-- Check back
			elseif dirx <= 0 and world:getBlock(x - 1, y, z) == 8 then
				dirx = -1
				x = x - 1

			-- Check left
			elseif dirz >= 0 and world:getBlock(x, y, z + 1) == 8 then
				dirz = 1
				z = z + 1

			-- Check right
			elseif dirz <= 0 and world:getBlock(x, y, z - 1) == 8 then
				dirz = -1
				z = z - 1

			-- Block found
			else
				return x, y, z, upX, upY, upZ
			end

			if upY < y then
				upX, upY, upZ = x, y, z
			end
		end
	end

	local function findWaterBlockToCreate(world, x, y, z)
		if y == 0 then return end

		-- Under
		if world:getBlock(x, y - 1, z) == 0 then
			return x, y - 1, z
		end

		local dirX, dirZ = 0, 0

		-- nearest x
		for dx = -1, 1, 2 do
			if world:getBlock(x + dx, y, z) == 0 then
				dirX = dirX + dx
				if dirX == 0 then
					dirX = math.random(0, 1) * 2 - 1
				end

				if world:getBlock(x + dx, y - 1, z) == 0 then
					return x + dx, y - 1, z
				end
			end
		end

		-- nearest y
		for dz = -1, 1, 2 do
			if world:getBlock(x, y, z + dz) == 0 then
				dirZ = dirZ + dz
				if dirZ == 0 then
					dirZ = math.random(0, 1) * 2 - 1
				end

				if world:getBlock(x, y - 1, z + dz) == 0 then
					return x, y - 1, z + dz
				end
			end
		end

		-- Check if block don't have way to escape
		if dirX == 0 and dirZ == 0 then
			return nil
		end

		local limiterX, limiterZ = 0, 0

		-- 5 blocks forward
		if dirX > 0 then
			for dx = 2, WATER_LEAK_SIZE do
				if world:getBlock(x + dx, y, z) ~= 0 then
					limiterX = dx - 1
					break
				elseif world:getBlock(x + dx, y - 1, z) == 0 then
					return x + 1, y, z
				end
			end
		end
		-- 5 blocks back
		if dirX < 0 then
			for dx = 2, WATER_LEAK_SIZE do
				if world:getBlock(x - dx, y, z) ~= 0 then
					limiterX = dx - 1
					break
				elseif world:getBlock(x - dx, y - 1, z) == 0 then
					return x - 1, y, z
				end
			end
		end
		-- 5 blocks left
		if dirZ > 0 then
			for dz = 2, WATER_LEAK_SIZE do
				if world:getBlock(x, y, z + dz) ~= 0 then
					limiterZ = dz - 1
					break
				elseif world:getBlock(x, y - 1, z + dz) == 0 then
					return x, y, z + 1
				end
			end
		end
		-- 5 blocks right
		if dirZ < 0 then
			for dz = 2, WATER_LEAK_SIZE do
				if world:getBlock(x, y, z - dz) ~= 0 then
					limiterZ = dz - 1
					break
				elseif world:getBlock(x, y - 1, z - dz) == 0 then
					return x, y, z - 1
				end
			end
		end

		-- Check if block don't have way to escape by diagonal
		if dirX == 0 or dirZ == 0 then
			return nil
		end

		-- nearest squares
		if dirX > 0 then
			for dx = 1, limiterX do
				-- forward left square
				if dirZ > 0 then
					for dz = 1, limiterZ do
						if world:getBlock(x + dx, y, z + dz) ~= 0 then
							break
						end
						if world:getBlock(x + dx, y - 1, z + dz) == 0 then
							if world:getBlock(x + 1, y - 1, z) then
								return x + 1, y, z
							else
								return x, y, z + 1
							end
						end
					end

				-- forward right square
				else
					for dz = 1, limiterZ do
						if world:getBlock(x + dx, y, z - dz) ~= 0 then
							break
						end
						if world:getBlock(x + dx, y - 1, z - dz) == 0 then
							if world:getBlock(x + 1, y - 1, z) then
								return x + 1, y, z
							else
								return x, y, z - 1
							end
						end
					end
				end
			end
		else
			for dx = 1, limiterX do
				-- back left square
				if dirZ > 0 then
					for dz = 1, limiterZ do
						if world:getBlock(x - dx, y, z + dz) ~= 0 then
							break
						end
						if world:getBlock(x - dx, y - 1, z + dz) then
							if world:getBlock(x - 1, y - 1, z) then
								return x - 1, y, z
							else
								return x, y, z + 1
							end
						end
					end

				-- back right square
				else
					for dz = 1, limiterZ do
						if world:getBlock(x - dx, y, z - dz) ~= 0 then
							break
						end
						if world:getBlock(x - dx, y - 1, z - dz) == 0 then
							if world:getBlock(x - 1, y - 1, z) then
								return x - 1, y, z
							else
								return x, y, z - 1
							end
						end
					end
				end
			end
		end

		return nil
	end

	local function doPhysicsFor(world, sx, sy, sz, x, y, z, baseY)
		if not x then
			x, y, z = sx, sy, sz
		end

		baseY = baseY or y

		local id = world:getBlock(x, y, z)
		if id == 8 or id == 9 then
			local newX, newY, newZ = findWaterBlockToCreate(world, x, y, z)

			if newX then
				local remX, remY, remZ

				if world:getBlock(sx, sy, sz) == 8 then
					remX, remY, remZ, sx, sy, sz = findWaterBlockToRemove(world, sx, sy, sz, x - newX, z - newZ)
				elseif sy > baseY and world:getBlock(sx, sy - 1, sz) == 8 then
					sy = sy - 1
					remX, remY, remZ, sx, sy, sz = findWaterBlockToRemove(world, sx, sy, sz, x - newX, z - newZ)
				else
					remX, remY, remZ, sx, sy, sz = findWaterBlockToRemove(world, x, y, z, x - newX, z - newZ)
				end

				if world:getBlock(remX, remY, remZ) ~= 8 then
					log.error("Trying to remove non-water block " .. remX .. ", " .. remY .. ", " .. remZ)
				elseif world:getBlock(newX, newY, newZ) ~= 0 then
					log.error("Trying place water instead " .. (world:getBlock(newX, newY, newZ) == 8 and "water" or "usual") .. " block " .. newX .. ", " .. newY .. ", " .. newZ)
					log.error("\tDiff: " .. (newX - x) .. ", " .. (newY - y) .. ", " .. (newZ - z))
				else
					world:setBlock(remX, remY, remZ, 0)

					world:setBlock(newX, newY, newZ, 8)
					timer.Simple(.2, function()
						doPhysicsFor(world, sx, sy, sz, x, y, z, baseY)
						doPhysicsFor(world, sx, sy, sz, newX, newY, newZ, baseY)
					end)
				end
			-- leak water by surface
			elseif world:getBlock(x, y, z) ~= 0 then
				local counter = 0

				-- nearest x
				for dx = -1, 1, 2 do
					if world:getBlock(x + dx, y, z) == 0 then
						local remX, remY, remZ

						if world:getBlock(sx, sy, sz) == 8 then
							remX, remY, remZ, sx, sy, sz = findWaterBlockToRemove(world, sx, sy, sz, -dx, 0)
						elseif sy > baseY and world:getBlock(sx, sy - 1, sz) == 8 then
							sy = sy - 1
							remX, remY, remZ, sx, sy, sz = findWaterBlockToRemove(world, sx, sy, sz, -dx, 0)
						else
							remX, remY, remZ, sx, sy, sz = findWaterBlockToRemove(world, x, y, z, -dx, 0)
						end

						if remX and remY > y then
							world:setBlock(remX, remY, remZ, 0)
							world:setBlock(x + dx, y, z, 8)
							timer.Simple(.2, function()
								doPhysicsFor(world, sx, sy, sz, x + dx, y, z, baseY)
							end)

							counter = counter + 1
						end
					end
				end

				-- nearest y
				for dz = -1, 1, 2 do
					if world:getBlock(x, y, z + dz) == 0 then
						local remX, remY, remZ

						if world:getBlock(sx, sy, sz) == 8 then
							remX, remY, remZ, sx, sy, sz = findWaterBlockToRemove(world, sx, sy, sz, 0, -dz)
						elseif sy > baseY and world:getBlock(sx, sy - 1, sz) == 8 then
							sy = sy - 1
							remX, remY, remZ, sx, sy, sz = findWaterBlockToRemove(world, sx, sy, sz, 0, -dz)
						else
							remX, remY, remZ, sx, sy, sz = findWaterBlockToRemove(world, x, y, z, 0, -dz)
						end

						if remX and remY > y then
							world:setBlock(remX, remY, remZ, 0)
							world:setBlock(x, y, z + dz, 8)
							timer.Simple(.2, function()
								doPhysicsFor(world, sx, sy, sz, x, y, z + dz, baseY)
							end)

							counter = counter + 1
						end
					end
				end
			end
		elseif id == 12 then
			if world:getBlock(x, y - 1, z) == 0 then
				world:setBlock(x, y - 1, z, 12)
				world:setBlock(x, y, z, 0)

				timer.Simple(.3, function()
					doPhysicsFor(world, sx, sy, sz, x, y - 1, z)
				end)
			end
		end
	end

	hooks:add('postPlayerPlaceBlock', 'doPhysics', function(player, x, y, z)
		local world = getWorld(player)
		for dx = -1, 1, 1 do
			for dy = -1, 1, 1 do
				for dz = -1, 1, 1 do
					doPhysicsFor(world, x - dx, y - dy, z - dz)
				end
			end
		end
	end)
end)
