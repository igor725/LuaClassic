GEN_ENABLE_CAVES = true
GEN_ENABLE_TREES = true
GEN_ENABLE_ORES = true
GEN_ENABLE_HOUSES = true

local STEP = 20
local heightStone
local heightGrass
local heightWater

-- Bioms
local biomes

local function biomsGenerate(dx, dz)
	biomes = {}

	-- 1	normal
	-- 2	high
	-- 3	trees
	-- 4	sand
	-- 5	water

	-- Circles
	local biomesSizeX = math.floor(dx / STEP + 1)
	local biomesSizeZ = math.floor(dz / STEP + 1)
	for x = 0, biomesSizeX do
		biomes[x] = {}
		for z = 0, biomesSizeZ do
			biomes[x][z] = 1
		end
	end

	local radius = 5
	local BIOME_COUNT = dx * dz / STEP / radius / 64 + 1
	--local BIOME_COUNT = 10
	--local radius = math.floor(dx * dz / BIOME_COUNT / STEP / 32)
	local radius2 = radius * radius

	for i = 1, BIOME_COUNT do
		local x = math.random(biomesSizeX)
		local z = math.random(biomesSizeZ)
		local biome = math.random(1, 5)

		for dx = -radius, radius do
			for dz = -radius, radius do
				if
				dx*dx + dz*dz < radius2
				and biomes[x + dx] ~= nil and biomes[x + dx][z + dz] ~= nil
				then
					biomes[x + dx][z + dz] = biome
				end
			end
		end
	end
end

local function getBiome(x, z)
	return biomes[math.floor(x/STEP)][math.floor(z/STEP)]
end


-- Height map
local heightMap

function heightSet(dy)
	heightGrass = dy / 2
	heightWater = heightGrass
	heightLava = 7
end

function heightMapGenerate(dx, dz)
	heightMap = {}
	for x = 0, dx / STEP + 1 do
		heightMap[x] = {}
		for z = 0, dz / STEP + 1 do
			--local r = math.random(0,80)
			--heightMap[x][z] = heightGrass + math.random(-5, 10) + ((r>77 and 13)or 0)

			local biome = biomes[x][z]
			-- normal
			if biome == 1 then
				if math.random(0, 6) == 0 then
					heightMap[x][z] = heightGrass + math.random(-3, -1)
				else
					heightMap[x][z] = heightGrass + math.random(1, 3)
				end
				-- high
			elseif biome == 2 then
				if math.random(0, 6) == 0 then
					heightMap[x][z] = heightGrass + math.random(20, 30)
				else
					heightMap[x][z] = heightGrass + math.random(-2, 20)
				end
				-- trees
			elseif biome == 3 then
				if math.random(0, 5) == 0 then
					heightMap[x][z] = heightGrass + math.random(-3, -1)
				else
					heightMap[x][z] = heightGrass + math.random(1, 5)
				end
				-- sand
			elseif biome == 4 then
				heightMap[x][z] = heightGrass + math.random(1, 4)
				-- water
			elseif biome == 5 then
				if math.random(0, 10) == 0 then
					heightMap[x][z] = heightGrass + math.random(-20, -3)
				else
					heightMap[x][z] = heightGrass + math.random(-10, -3)
				end
			else
				heightMap[x][z] = heightGrass
			end
		end
	end

	heightStone = heightGrass - 3
end

local function getHeight(x, z)
	local hx, hz = math.floor(x/STEP), math.floor(z/STEP)
	local percentX = x / STEP - hx
	local percentZ = z / STEP - hz

	return math.floor(
		  (heightMap[hx][hz  ] * (1 - percentX) + heightMap[hx+1][hz  ] * percentX) * (1 - percentZ)
		+ (heightMap[hx][hz+1] * (1 - percentX) + heightMap[hx+1][hz+1] * percentX) * percentZ
		+ 0.5
	)
end

-- Generate
local function threadTerrain(mapaddr, dx, dy, dz, heightMap, heightWater, startX, endX, heightStone)
	ffi = require("ffi")

	local map = ffi.cast('char*', mapaddr)
	local size = dx * dy * dz + 4

	local SetBlock = function(x, y, z, id)
		--[[local offset = math.floor(z * dx + y * (dx * dz) + x + 4)
		if offset < size then -- <=
			map[offset] = id
		end]]--
		--map[y * dz * dx + z * dx + x + 4] = id
		map[(y * dz + z) * dx + x + 4] = id
	end

	local height1, heightStone1, biome
	local offsetX, offsetY
	for x = startX, endX do
		local hx = math.floor(x/STEP)
		local percentPosX = x / STEP - hx
		local percentNegX = 1 - percentPosX

		local biomePosX = math.floor(x/STEP)
		local b0 = biomes[biomePosX]
		local b1 = biomes[biomePosX+1]
		local biomePosZOld = nil
		local b00 = nil
		local b01 = b0[0]
		local b10 = nil
		local b11 = b1[0]

		for z = 0, dz - 1 do
			local hz = math.floor(z/STEP)
			local percentZ = z / STEP - hz

			height1 = math.floor(
				  (heightMap[hx][hz  ] * percentNegX + heightMap[hx+1][hz  ] * percentPosX) * (1 - percentZ)
				+ (heightMap[hx][hz+1] * percentNegX + heightMap[hx+1][hz+1] * percentPosX) * percentZ
				+ 0.5
			)

			--[[
			-- Badrock
			SetBlock(x, 0, z, 7)

			-- Stone
			heightStone1 = height1 + math.random(-6, -4)
			for y = 1, heightStone1 - 1 do
				SetBlock(x, y, z, 1)
			end

			-- Dirt
			for y = heightStone1, height1 - 2 do
				SetBlock(x, y, z, 3)
			end
			]]--

			-- Badrock
			local offset = z * dx + x + 4
			--map[offset] = 7

			-- Stone
			heightStone1 = height1 + math.random(-6, -4)

			local step = dz * dx
			--for y = 1, heightStone1 - 1 do
			for y = heightStone, heightStone1 - 1 do
				map[offset + y * step] = 1
			end

			-- Dirt
			for y = heightStone1, height1 - 2 do
				map[offset + y * step] = 3
			end


			-- Biom depend
			local biomePosZ = math.floor(z/STEP)
			if biomePosZ ~= biomePosZOld then
				biomePosZOld = biomePosZ
				b00 = b01
				b01 = b0[biomePosZ+1]
				b10 = b11
				b11 = b1[biomePosZ+1]

				if b01 == 3 then
					b01 = 1
				end
				if b11 == 3 then
					b11 = 1
				end
			end

			-- angle around 00
			if b11 == b01 and b11 == b10 then
				if percentPosX * percentPosX + percentZ * percentZ > 0.25 then
					biome = b11
				else
					biome = b00
				end

			-- angle around 01
			elseif b00 == b11 and b00 == b10 then
				if percentPosX * percentPosX + (1 - percentZ)^2 > 0.25 then
					biome = b00
				else
					biome = b01
				end

			-- angle around 10
			elseif b00 == b01 and b00 == b11 then
				if percentNegX * percentNegX + percentZ * percentZ > 0.25 then
					biome = b00
				else
					biome = b10
				end

			-- angle around 11
			elseif b00 == b01 and b00 == b10 then
				if percentNegX * percentNegX + (1 - percentZ)^2 > 0.25 then
					biome = b00
				else
					biome = b11
				end

			-- else
			else
				biome = biomes[math.floor(x / STEP + 0.5)][math.floor(z / STEP + 0.5)]
				--biome = getBiome(x + STEP / 2, z + STEP / 2)
			end

			-- normal or trees
			if biome == 1 or biome == 3 then
				if height1 > heightWater then
					-- Grass
					SetBlock(x, height1-1, z, 3)
					SetBlock(x, height1  , z, 2)
				else
					-- Sand
					SetBlock(x, height1-1, z, 12)
					SetBlock(x, height1  , z, 12)

					for y = height1 + 1, heightWater do
						SetBlock(x, y, z, 8)
					end
				end

				-- high
			elseif biome == 2 then
				-- Rock
				SetBlock(x, height1-1, z, 1)
				SetBlock(x, height1  , z, 1)

				for y = height1 + 1, heightWater do
					SetBlock(x, y, z, 8)
				end

			-- sand
			elseif biome == 4 then
				-- Sand
				SetBlock(x, height1-1, z, 12)
				SetBlock(x, height1,   z, 12)

				for y = height1 + 1, heightWater do
					SetBlock(x, y, z, 8)
				end

				-- water
			elseif biome == 5 then
				-- Dirt
				SetBlock(x, height1-1, z, 3)
				SetBlock(x, height1,   z, 3)

				for y = height1 + 1, heightWater do
					SetBlock(x, y, z, 8)
				end
			else
				SetBlock(x, height1-1, z, 4)
				SetBlock(x, height1,   z, 4)
			end
		end
	end
end


local function generateTrees(mapaddr, dx, dy, dz, heightMap)
	ffi = require("ffi")

	local map = ffi.cast('char*', mapaddr)
	local size = dx * dy * dz + 4

	local SetBlock = function(x, y, z, id)
		local offset = math.floor((y * dz + z) * dx + x + 4)
		if offset < size then
			map[offset] = id
		end
	end

	local getHeight = function(x, z)
		local hx, hz = math.floor(x/STEP), math.floor(z/STEP)
		local percentX = x / STEP - hx
		local percentZ = z / STEP - hz

		return math.floor(
			  (heightMap[hx][hz  ] * (1 - percentX) + heightMap[hx+1][hz  ] * percentX) * (1 - percentZ)
			+ (heightMap[hx][hz+1] * (1 - percentX) + heightMap[hx+1][hz+1] * percentX) * percentZ
			+ 0.5
		)
	end

	local TREES_COUNT = dx * dz / 700
	local i = 1
	local fail = 0

	local x, z, baseHeight, baseHeight2
	while i < TREES_COUNT do
		x, z = math.random(6, dx - 6), math.random(6, dz - 6)

		baseHeight = getHeight(x, z)
		if baseHeight > heightWater then
			-- tree
			if getBiome(x, z) == 3 then
				i = i + 1

				baseHeight2 = baseHeight + math.random(4, 6)

				for y = baseHeight + 1, baseHeight2 do
					SetBlock(x, y, z, 17)
				end

				for dx = x - 2, x + 2 do
					for dz = z - 2, z + 2 do
						if dx ~= x or dz ~= z then
							for y = baseHeight2 - 2, baseHeight2 - 1 do
								SetBlock(dx, y, dz, 18)
							end
						end
					end
				end

				for dx = x - 1, x + 1 do
					if dx ~= x then
						for y = baseHeight2, baseHeight2 + 1 do
							SetBlock(dx, y, z, 18)
						end
					end
				end
				for dz = z - 1, z + 1 do
					if dz ~= z then
						for y = baseHeight2, baseHeight2 + 1 do
							SetBlock(x, y, dz, 18)
						end
					end
				end
				SetBlock(x, baseHeight2 + 1, z, 18)

				-- kaktus
			elseif getBiome(x, z) == 4 then
				i = i + 1

				baseHeight2 = baseHeight + math.random(1, 4)

				for y = baseHeight + 1, baseHeight2 do
					SetBlock(x, y, z, 18)
				end

				-- fail
			else
				fail = fail + 1

				if fail > 1000 then
					fail = 0
					break
				end
			end
		else
			fail = fail + 1

			if fail > 1000 then
				fail = 0
				break
			end
		end
	end
end

local function generateHouse(mapaddr, dimx, dimy, dimz, heightMap, heightWater)
	ffi = require("ffi")

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local SetBlock = function(x, y, z, id)
		local offset = math.floor((y * dimz + z) * dimx + x + 4)
		if 0 < offset and offset < size then
			map[offset] = id
		end
	end

	local GetBlock = function(x, y, z)
		local offset = math.floor((y * dimz + z) * dimx + x + 4)
		if 0 < offset and offset < size then
			return map[offset]
		else
			return -1
		end
	end

	local getHeight = function(x, z)
		local hx, hz = math.floor(x/STEP), math.floor(z/STEP)
		local percentX = x / STEP - hx
		local percentZ = z / STEP - hz

		return math.floor(
			  (heightMap[hx][hz  ] * (1 - percentX) + heightMap[hx+1][hz  ] * percentX) * (1 - percentZ)
			+ (heightMap[hx][hz+1] * (1 - percentX) + heightMap[hx+1][hz+1] * percentX) * percentZ
			+ 0.5
		)
	end

	local HOUSE_COUNT = dimx * dimz / 70000

	for i = 1, HOUSE_COUNT do
		local startX = math.random(4, dimx - 8)
		local startZ = math.random(4, dimz - 10)
		local endX = startX + math.random(4, 6)
		local endZ = startZ + math.random(6, 8)

		-- Find max height
		local calcel = false

		local maxHeight = 0
		local tempHeight
		for x = startX, endX do
			for z = startZ, endZ do
				tempHeight = getHeight(x, z)
				if tempHeight > maxHeight then
					maxHeight = tempHeight
				end
				if tempHeight < heightWater then
					calcel = true
					break
				end
			end
		end

		if not calcel then
			maxHeight = maxHeight + 1

			-- floor
			for x = startX, endX do
				for z = startZ, endZ do
					for y = getHeight(x, z), maxHeight do
						SetBlock(x, y, z, 4)
					end
				end
			end

			local materials = {4, 20, 5}

			-- walls
			for i = 1, #materials do
				for x = startX, endX do
					SetBlock(x, maxHeight + i, startZ, materials[i])
					SetBlock(x, maxHeight + i, endZ, materials[i])
				end

				for z = startZ, endZ do
					SetBlock(startX, maxHeight + i, z, materials[i])
					SetBlock(endX, maxHeight + i, z, materials[i])
				end

				SetBlock(startX + 2, maxHeight + i, startZ, 0)
			end

			SetBlock(startX + 2, maxHeight + i, startZ, 0)

			local j = 1
			while GetBlock(startX + 2, maxHeight - j, startZ - j) == 0 do
				SetBlock(startX + 2, maxHeight - j, startZ - j, 4)
				j = j + 1
			end

			maxHeight = maxHeight + 4

			for i = -1, math.min(endX - startX, endZ - startZ) / 2 do
				for x = startX + i, endX - i do
					SetBlock(x, maxHeight + i, startZ + i, 5)
					SetBlock(x, maxHeight + i, endZ - i, 5)
				end

				for z = startZ + i, endZ - i do
					SetBlock(startX + i, maxHeight + i, z, 5)
					SetBlock(endX - i, maxHeight + i, z, 5)
				end
			end
		end
	end
end


local function generateOre(mapaddr, dimx, dimy, dimz, heightMap, heightGrass)
	ffi = require("ffi")

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local SetBlock = function(x, y, z, id)
		local offset = math.floor((y * dimz + z) * dimx + x + 4)
		if offset < size then
			map[offset] = id
		end
	end
	local METAL_COUNT = dimx * dimy * dimz / 150 / 64
	local METAL_SIZE = 3

	local x, y, z, ore
	for i = 1, METAL_COUNT do
		x = math.random(METAL_SIZE, dimx - METAL_SIZE)
		z = math.random(METAL_SIZE, dimz - METAL_SIZE)
		y = math.random(5, heightGrass / 2)

		ore = math.random(14,16)
		for dx = 1, METAL_SIZE do
			for dz = 1, METAL_SIZE do
				for dy = 1, METAL_SIZE do
					if math.random(0, 1) == 1 then
						SetBlock(x + dx, y + dy, z + dz, ore)
					end
				end
			end
		end
	end
end

local function generateCaves(mapaddr, dimx, dimy, dimz, heightMap, heightGrass, heightLava, seed)
	math.randomseed(seed)

	ffi = require("ffi")

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local SetBlock = function(x, y, z, id)
		local offset = math.floor((y * dimz + z) * dimx + x + 4)
		if offset < size then
			map[offset] = id
		end
		--map[(y * dimz + z) * dimx + x + 4] = id
	end

	--local CAVES_LENGTH = 65
	local CAVES_LENGTH = math.random(50, 150)
	local CAVE_RADIUS = 3
	local CAVE_RADIUS2 = CAVE_RADIUS * CAVE_RADIUS

	local CAVE_CHANGE_DIRECTION = math.floor(CAVES_LENGTH / 3)

	local ddx, ddy, ddz, length, directionX, directionY, directionZ

	--[[local directionX = (math.random() - 0.5) * 0.3
	local directionY = (math.random() - 0.5) * 0.1
	local directionZ = (math.random() - 0.5) * 0.3]]--

	local x = math.random(CAVE_RADIUS, dimx - CAVE_RADIUS)
	local z = math.random(CAVE_RADIUS, dimz - CAVE_RADIUS)
	--y = math.random(heightGrass / 4, heightGrass / 2)
	local y = math.random(10, heightGrass - 20)

	for j = 1, CAVES_LENGTH do
		if j % CAVE_CHANGE_DIRECTION == 1 then
			directionX = (math.random() - 0.5) * 0.6
			directionY = (math.random() - 0.5) * 0.2
			directionZ = (math.random() - 0.5) * 0.6
		end

		ddx = math.random() - 0.5 + directionX
		ddy = (math.random() - 0.5) * 0.4 + directionY
		ddz = math.random() - 0.5 + directionZ

		length = 1--math.sqrt(ddx^2 + ddy^2 + ddz^2)

		x = math.floor(x + ddx * CAVE_RADIUS / length + 0.5)
		y = math.floor(y + ddy * CAVE_RADIUS / length + 0.5)
		z = math.floor(z + ddz * CAVE_RADIUS / length + 0.5)

		for dx = -CAVE_RADIUS, CAVE_RADIUS do
			for dz = -CAVE_RADIUS, CAVE_RADIUS do
				for dy = -CAVE_RADIUS, CAVE_RADIUS do
					if
						dx*dx + dz*dz + dy*dy < CAVE_RADIUS2
						and y + dy > 0
						and 1 < x + dx and x + dx < dimx - 1
						and 1 < z + dz and z + dz < dimz - 1
					then
						SetBlock(x + dx, y + dy, z + dz, (y+dy>heightLava and 0)or 11)
					end
				end
			end
		end
	end
end

local function fillStone(world, dimx, dimz)
	ffi.fill(world.ldata + 4, dimx * dimz, 7)
	ffi.fill(world.ldata + 4 + dimx * dimz, dimx * dimz * (heightStone - 1), 1)
end

-- Main
return function(world, seed)
	seed = seed or (os.clock()*os.time())
	local dx, dy, dz = world:GetDimensions()

	math.randomseed(seed)

	-- Generate map
	biomsGenerate(dx, dz)

	heightSet(dy)
	heightMapGenerate(dx, dz)

	fillStone(world, dx, dz)

	local mapaddr = world:GetAddr()

	io.write('terrain, ')
	local threads = {}

	local count = config:get('generator-threads-count', 2)
	for i = 0, count-1 do
		startX = math.floor(dx * i / count)
		endX = math.floor(dx * (i + 1) / count) - 1

		local sendMap_gen = lanes.gen('*', threadTerrain)
		threads[i] = sendMap_gen(mapaddr, dx, dy, dz, heightMap, heightWater, startX, endX, heightStone)
	end

	count = #threads

	while count > 0 do
		local thread = threads[count]
		if thread then
			if thread.status == "error" then
				print(thread[1])
			elseif thread.status == "done" then
				count = count - 1
			end
		else
			socket.sleep(.1)
		end
	end

	threads = {}
	count = 0

	-- ores
	if GEN_ENABLE_ORES then
		io.write('ores, ')
		local sendMap_gen = lanes.gen('*', generateOre)

		count = count + 1
		threads[count] = sendMap_gen(mapaddr, dx, dy, dz, heightMap, heightGrass)
	end

	-- trees
	if GEN_ENABLE_TREES then
		local sendMap_gen = lanes.gen('*', generateTrees)

		count = count + 1
		threads[count] = sendMap_gen(mapaddr, dx, dy, dz, heightMap)
	end

	-- houses
	if GEN_ENABLE_HOUSES then
		io.write('houses, ')
		local sendMap_gen = lanes.gen('*', generateHouse)

		count = count + 1
		threads[count] = sendMap_gen(mapaddr, dx, dy, dz, heightMap, heightWater)
	end

	while count > 0 do
		local thread = threads[count]
		if thread then
			if thread.status == "error" then
				print(thread[1])
			elseif thread.status == "done" then
				count = count - 1
			end
		else
			socket.sleep(.1)
		end
	end

	if GEN_ENABLE_CAVES then
		io.write('caves, ')
		local limit = config:get('generator-threads-count', 2)
		local sendMap_gen = lanes.gen('*', generateCaves)

		local CAVES_COUNT = dx * dy * dz / 700000
		for i = 1, CAVES_COUNT do
			if count > limit then
				local thread = threads[1]

				while true do
					if thread then
						if thread.status == "error" then
							print(thread[1])
							table.remove(threads, 1)
						elseif thread.status == "done" then
							count = count - 1
							table.remove(threads, 1)
							break
						end
					else
						socket.sleep(.1)
					end
				end
			end

			count = count + 1
			threads[count] = sendMap_gen(mapaddr, dx, dy, dz, heightMap, heightGrass, heightLava, seed + i)
		end
	end

	--[[if GEN_ENABLE_CAVES then
		io.write('caves, ')
		local sendMap_gen = lanes.gen('*', generateCaves)

		local CAVES_COUNT = dx * dy * dz / 700000
		for i = 1, CAVES_COUNT do
			count = count + 1
			threads[count] = sendMap_gen(mapaddr, dx, dy, dz, heightMap, heightGrass, heightLava, seed + i)
		end
	end


	while count > 0 do
		local thread = threads[count]
		if thread then
			if thread.status == "error" then
				print(thread[1])
			elseif thread.status == "done" then
				count = count - 1
			end
		else
			socket.sleep(.1)
		end
	end]]--

	local x, z = math.random(1, dx), math.random(1, dz)
	local y = getHeight(x,z)

	for i = 1, 20 do
		if y < 0 then
			x, z = math.random(1, dx), math.random(1, dz)
			y = getHeight(x,z)
			break
		end
	end

	world:SetSpawn(x,y+2,z,0,0)

	local ma = {
		['0'] = 0,
		['1'] = 8,
		['2'] = heightWater + 1,
		['9'] = 0
	}
	world.data.map_aspects = ma

	return true
end
