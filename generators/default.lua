--
-- Created by scaled
-- and Igor
-- for LuaClassic server
--

local GEN_ENABLE_CAVES     = true
local GEN_ENABLE_TREES     = true
local GEN_ENABLE_ORES      = true
local GEN_ENABLE_HOUSES    = true

local GEN_CAVE_RADIUS      = 3
local GEN_CAVE_MIN_LENGTH  = 100
local GEN_CAVE_MAX_LENGTH  = 500

local GEN_TREES_COUNT_MULT = 0.007

local GEN_HOUSES_COUNT_MULT = 1 / 70000

local GEN_ORE_VEIN_SIZE    = 3
local GEN_ORE_COUNT_MULT   = 1 / 2000
local GEN_GRAVEL_VEIN_SIZE = 14

local GEN_BIOME_STEP       = 20
local GEN_BIOME_RADIUS     = 5

--[[
	GENERATOR CODE START
]]

local BIOME_NORMAL = 1
local BIOME_HIGH   = 2
local BIOME_TREES  = 3
local BIOME_SAND   = 4
local BIOME_WATER  = 5

local lanelibs = 'math,ffi'
local heightStone
local heightGrass
local heightWater
local heightLava
local heightMap
local bsx, bsz
local biomes

local function biomesGenerate(dimx, dimz)
	biomes = {}

	-- Circles
	local biomesSizeX = math.ceil(dimx / GEN_BIOME_STEP)
	local biomesSizeZ = math.ceil(dimz / GEN_BIOME_STEP)
	bsx = biomesSizeX
	bsz = biomesSizeZ
	for i = 0, biomesSizeX * (biomesSizeZ + 1) do
		biomes[i] = 1
	end

	local BIOME_COUNT = dimx * dimz / GEN_BIOME_STEP / GEN_BIOME_RADIUS / 64 + 1
	local radius2 = GEN_BIOME_RADIUS ^ 2

	for i = 1, BIOME_COUNT do
		local x = math.random(biomesSizeX)
		local z = math.random(biomesSizeZ)
		local biome = math.random(1, 5)

		for dx = -GEN_BIOME_RADIUS, GEN_BIOME_RADIUS do
			for dz = -GEN_BIOME_RADIUS, GEN_BIOME_RADIUS do
				local nx, nz = x + dx, z + dz
				if dx * dx + dz * dz < radius2 then
					local offset = nx + nz * bsx
					if offset >= 0 and offset <= #biomes then
						biomes[offset] = biome
					end
				end
			end
		end
	end
end

local function getBiome2(x, z)
	return biomes[x + z * bsx]
end

local function getBiome(x, z)
	x = math.floor(x / GEN_BIOME_STEP + 0.5)
	z = math.floor(z / GEN_BIOME_STEP + 0.5)
	return biomes[x + z * bsx]
end

local function heightSet(dimy)
	heightGrass = math.floor(dimy / 2)
	heightStone = heightGrass - 3
	heightWater = heightGrass
	heightLava = 7
end

local function heightMapGenerate(dimx, dimy, dimz)
	heightMap = {}

	for x = 0, bsx do
		for z = 0, bsz do
			local biome = getBiome2(x, z)
			local offset = x + z * bsx

			if biome == BIOME_NORMAL then
				if math.random(0, 6) == 0 then
					heightMap[offset] = heightGrass + math.random(-3, -1)
				else
					heightMap[offset] = heightGrass + math.random(1, 3)
				end
			elseif biome == BIOME_HIGH then
				if math.random(0, 30) == 0 then
					heightMap[offset] = heightGrass + math.random(20, math.min(dimy - 1 - heightGrass, 40))
				else
					heightMap[offset] = heightGrass + math.random(-2, 20)
				end
			elseif biome == BIOME_TREES then
				heightMap[offset] = heightGrass + math.random(1, 5)
			elseif biome == BIOME_SAND then
				heightMap[offset] = heightGrass + math.random(1, 4)
			elseif biome == BIOME_WATER then
				if math.random(0, 10) == 0 then
					heightMap[offset] = heightGrass + math.random(-20, -3)
				else
					heightMap[offset] = heightGrass + math.random(-10, -3)
				end
			else
				heightMap[offset] = heightGrass
			end
		end
	end
end

local function getHeight(x, z)
	local hx, hz = math.floor(x / GEN_BIOME_STEP), math.floor(z / GEN_BIOME_STEP)
	local percentX = x / GEN_BIOME_STEP - hx
	local percentZ = z / GEN_BIOME_STEP - hz

	return math.floor(
		  (heightMap[hx + hz * bsx] * (1 - percentX)
		+ heightMap[(hx + 1) + hz * bsx ] * percentX)
		* (1 - percentZ) + (heightMap[hx + (hz + 1) * bsx]
		* (1 - percentX) + heightMap[(hx + 1) + (hz + 1) * bsx] * percentX) * percentZ + 0.5
	)
end

local function threadTerrain(mapaddr, dimx, dimy, dimz, startX, endX, seed)
	set_debug_threadname('TerrainGenerator')
	math.randomseed(seed)

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local SetBlock = function(x, y, z, id)
		map[(y * dimz + z) * dimx + x + 4] = id
	end

	local height1, heightStone1, biome
	local offsetX, offsetY
	for x = startX, endX do
		local hx = math.floor(x / GEN_BIOME_STEP)
		local percentPosX = x / GEN_BIOME_STEP - hx
		local percentNegX = 1 - percentPosX

		local biomePosX = math.floor(x / GEN_BIOME_STEP)
		local b0 = biomePosX
		local b1 = b0 + 1
		local biomePosZOld = nil
		local b00 = nil
		local b01 = biomes[b0]
		local b10 = nil
		local b11 = biomes[b1]

		for z = 0, dimz - 1 do
			local hz = math.floor(z / GEN_BIOME_STEP)
			local percentZ = z / GEN_BIOME_STEP - hz

			height1 = math.floor(
				  (heightMap[hx + hz * bsx ] * percentNegX + heightMap[(hx + 1) + hz * bsx] * percentPosX)
				* (1 - percentZ)
				+ (heightMap[hx + (hz + 1) * bsx] * percentNegX + heightMap[(hx + 1) + (hz + 1) * bsx] * percentPosX) * percentZ + 0.5
			)

			local offset = z * dimx + x + 4

			heightStone1 = height1 + math.random(-6, -4)

			local step = dimz * dimx
			for y = heightStone, heightStone1 - 1 do
				map[offset + y * step] = 1
			end

			-- Biome depend
			local biomePosZ = math.floor(z / GEN_BIOME_STEP)
			if biomePosZ ~= biomePosZOld then
				biomePosZOld = biomePosZ
				b00 = b01
				b01 = biomes[b0 + (biomePosZ + 1) * bsx]
				b10 = b11
				b11 = biomes[b1 + (biomePosZ + 1) * bsx]

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
				if percentPosX * percentPosX + (1 - percentZ) ^ 2 > 0.25 then
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
				if percentNegX * percentNegX + (1 - percentZ) ^ 2 > 0.25 then
					biome = b00
				else
					biome = b11
				end
			else
				biome = getBiome2(math.floor(x / GEN_BIOME_STEP + .5), math.floor(z / GEN_BIOME_STEP + .5))
			end

			if biome == BIOME_NORMAL or biome == BIOME_TREES then
				-- Dirt
				for y = heightStone1, height1 - 2 do
					map[offset + y * step] = 3
				end

				if height1 > heightWater then
					-- Grass
					SetBlock(x, height1 - 1, z, 3)
					SetBlock(x, height1, z, 2)
				else
					-- Sand
					SetBlock(x, height1 - 1, z, 12)
					SetBlock(x, height1, z, 12)

					for y = height1 + 1, heightWater do
						SetBlock(x, y, z, 8)
					end
				end
			elseif biome == BIOME_HIGH then
				-- Rock
				for y = heightStone1, height1 do
					map[offset + y * step] = 1
				end

				-- Water
				for y = height1 + 1, heightWater do
					SetBlock(x, y, z, 8)
				end
			elseif biome == BIOME_SAND then
				-- Sand
				for y = heightStone1, height1 do
					map[offset + y * step] = 12
				end

				-- Water
				for y = height1 + 1, heightWater do
					SetBlock(x, y, z, 8)
				end
			elseif biome == BIOME_WATER then
				-- Rock
				for y = heightStone1, height1 do
					map[offset + y * step] = 3
				end

				-- Water
				for y = height1 + 1, heightWater do
					SetBlock(x, y, z, 8)
				end
			else
				SetBlock(x, height1 - 1, z, 4)
				SetBlock(x, height1, z, 4)
			end
		end
	end
end

local function generateTrees(mapaddr, dimx, dimy, dimz, seed)
	set_debug_threadname('TreesGenerator')
	math.randomseed(seed)

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local SetBlock = function(x, y, z, id)
		map[(y * dimz + z) * dimx + x + 4] = id
	end

	local biomesWithTrees = {}

	for i=1, #biomes do
		if biomes[i] == BIOME_TREES or biomes[i] == BIOME_SAND then
			biomesWithTrees[#biomesWithTrees + 1] = i
		end
	end

	local TREES_COUNT = dimx * dimz * GEN_TREES_COUNT_MULT * (#biomesWithTrees / #biomes)

	local x, z, baseHeight, baseHeight2, randBiome
	for i = 1, TREES_COUNT do
		randBiome = math.random(1, #biomesWithTrees)
		x = (biomesWithTrees[randBiome] % bsx) * GEN_BIOME_STEP + math.random(GEN_BIOME_STEP) - GEN_BIOME_STEP / 2
		z = math.floor(biomesWithTrees[randBiome] / bsx) * GEN_BIOME_STEP + math.random(GEN_BIOME_STEP) - GEN_BIOME_STEP / 2

		if x > dimx - 6 then
			x = dimx - 6
		elseif x < 6 then
			x = 6
		end

		if z > dimz - 6 then
			z = dimz - 6
		elseif z < 6 then
			z = 6
		end

		baseHeight = getHeight(x, z)
		if baseHeight > heightWater and baseHeight + 8 < dimy then
			if getBiome(x, z) == BIOME_TREES then
				i = i + 1

				baseHeight2 = baseHeight + math.random(4, 6)

					for dz = z - 2, z + 2 do
						for y = baseHeight2 - 2, baseHeight2 - 1 do
							ffi.fill(map + (y * dimz + dz) * dimx + x - 2 + 4, 5, 18)
						end
					end

				for y = baseHeight + 1, baseHeight2 do
					SetBlock(x, y, z, 17)
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
			elseif getBiome(x, z) == BIOME_SAND then
				i = i + 1

				baseHeight2 = baseHeight + math.random(1, 4)

				for y = baseHeight + 1, baseHeight2 do
					SetBlock(x, y, z, 18)
				end
			end
		end
	end
end

local function generateHouse(mapaddr, dimx, dimy, dimz, seed)
	set_debug_threadname('HousesGenerator')
	math.randomseed(seed)

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local SetBlock = function(x, y, z, id)
		map[(y * dimz + z) * dimx + x + 4] = id
	end

	local GetBlock = function(x, y, z)
		return map[(y * dimz + z) * dimx + x + 4]
	end

	local HOUSE_COUNT = math.ceil(dimx * dimz * GEN_HOUSES_COUNT_MULT)
	local materials = {4, 20, 5}

	for i = 1, HOUSE_COUNT do
		local startX = math.random(4, dimx - 10)
		local startZ = math.random(4, dimz - 8)
		local endX = startX + math.random(6, 8)
		local endZ = startZ + math.random(4, 6)

		-- Find max height
		local cancel = false

		local maxHeight = 0
		local minHeight = dimy
		local tempHeight
		for x = startX, endX do
			for z = startZ, endZ do
				tempHeight = getHeight(x, z)
				if tempHeight > maxHeight then
					maxHeight = tempHeight
				end
				if tempHeight < minHeight then
					minHeight = tempHeight
				end
				if tempHeight < heightWater or tempHeight > dimy - 10 then
					cancel = true
					break
				end
			end
		end

		if not cancel then
			maxHeight = maxHeight + 1

			local lengthX = endX - startX + 1
			for z = startZ, endZ do
				for y = minHeight, maxHeight do
					ffi.fill(map + (y * dimz + z) * dimx + startX + 4, lengthX, 4)
				end
			end


			-- walls
			for i = 1, #materials do
				ffi.fill(map + ((maxHeight + i) * dimz + startZ) * dimx + startX + 4, lengthX, materials[i])
				ffi.fill(map + ((maxHeight + i) * dimz + endZ) * dimx + startX + 4, lengthX, materials[i])

				for z = startZ + 1, endZ - 1 do
					SetBlock(startX, maxHeight + i, z, materials[i])
					SetBlock(endX, maxHeight + i, z, materials[i])
				end

				SetBlock(startX + 2, maxHeight + i, startZ, 0)
			end

			-- SetBlock(startX + 2, maxHeight + i, startZ, 0)

			local j = 1
			while GetBlock(startX + 2, maxHeight - j, startZ - j) == 0 do
				SetBlock(startX + 2, maxHeight - j, startZ - j, 4)
				j = j + 1
			end

			maxHeight = maxHeight + 4

			for i = -1, math.ceil(math.min(endX - startX - 1, endZ - startZ - 1) / 2) do
				ffi.fill(map + ((maxHeight + i) * dimz + startZ + i) * dimx + startX + i + 4, lengthX - 2 * i, 5)
				ffi.fill(map + ((maxHeight + i) * dimz + endZ - i) * dimx + startX + i + 4, lengthX - 2 * i, 5)

				for z = startZ + i + 1, endZ - i - 1 do
					SetBlock(startX + i, maxHeight + i, z, 5)
					SetBlock(endX - i, maxHeight + i, z, 5)
				end
			end
		end
	end
end

local function generateOre(mapaddr, dimx, dimy, dimz, seed)
	set_debug_threadname('OreGenerator')
	math.randomseed(seed)

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local SetBlock = function(x, y, z, id)
		map[(y * dimz + z) * dimx + x + 4] = id
	end
	local GetBlock = function(x, y, z, id)
		return map[(y * dimz + z) * dimx + x + 4]
	end
	local ORE_COUNT = dimx * dimy * dimz * GEN_ORE_COUNT_MULT

	local x, y, z, ore
	for i = 1, ORE_COUNT do
		x = math.random(GEN_ORE_VEIN_SIZE, dimx - GEN_ORE_VEIN_SIZE)
		z = math.random(GEN_ORE_VEIN_SIZE, dimz - GEN_ORE_VEIN_SIZE)
		--y = math.random(1, heightGrass + 15)
		y = math.floor(1 + math.random() ^ 3 * (heightGrass + 15))

		ore = math.random(14, 16)
		for dx = 1, GEN_ORE_VEIN_SIZE do
			for dz = 1, GEN_ORE_VEIN_SIZE do
				for dy = 1, GEN_ORE_VEIN_SIZE do
					if math.random(0, 1) == 1 and GetBlock(x + dx, y + dy, z + dz) == 1 then
						SetBlock(x + dx, y + dy, z + dz, ore)
					end
				end
			end
		end
	end

	local GRAVEL_COUNT = dimx * dimy * dimz / 500000
	for i = 1, GRAVEL_COUNT do
		x = math.random(1, dimx - GEN_ORE_VEIN_SIZE + 1)
		z = math.random(1, dimz - GEN_ORE_VEIN_SIZE + 1)
		y = math.random(1, heightGrass - 20 - GEN_GRAVEL_VEIN_SIZE + 1)

		for dz = 1, GEN_GRAVEL_VEIN_SIZE do
			for dy = 1, GEN_GRAVEL_VEIN_SIZE do
				ffi.fill(map + ((y + dy) * dimz + z + dz) * dimx + x + 4, GEN_GRAVEL_VEIN_SIZE, 13)
			end
		end
	end
end

local function generateCaves(mapaddr, dimx, dimy, dimz, seed)
	set_debug_threadname('CavesGenerator')
	math.randomseed(seed)

	local map = ffi.cast('char*', mapaddr)
	local size = dimx * dimy * dimz + 4

	local GetBlock = function(x, y, z)
		return map[(y * dimz + z) * dimx + x + 4]
	end
	local SetBlock = function(x, y, z, id)
		map[(y * dimz + z) * dimx + x + 4] = id
	end

	local CAVE_LENGTH = math.random(GEN_CAVE_MIN_LENGTH, GEN_CAVE_MAX_LENGTH)
	local CAVE_RADIUS2 = GEN_CAVE_RADIUS ^ 2

	local CAVE_CHANGE_DIRECTION = math.floor(CAVE_LENGTH / 3)

	local ddx, ddy, ddz, length, directionX, directionY, directionZ

	local x = math.random(GEN_CAVE_RADIUS, dimx - GEN_CAVE_RADIUS)
	local z = math.random(GEN_CAVE_RADIUS, dimz - GEN_CAVE_RADIUS)
	local y = math.random(10, heightGrass - 20)

	directionX = (math.random() - 0.5) * 0.6
	directionY = -math.random() * 0.1
	directionZ = (math.random() - 0.5) * 0.6
	for j = 1, CAVE_LENGTH do
		if j % CAVE_CHANGE_DIRECTION == 0 then
			directionX = (math.random() - 0.5) * 0.6
			directionY = (math.random() - 0.5) * 0.2
			directionZ = (math.random() - 0.5) * 0.6
		end

		ddx = math.random() - 0.5 + directionX
		ddy = (math.random() - 0.5) * 0.4 + directionY
		ddz = math.random() - 0.5 + directionZ

		length = math.sqrt(ddx^2 + ddy^2 + ddz^2)

		x = math.floor(x + ddx * GEN_CAVE_RADIUS / length + 0.5)
		y = math.floor(y + ddy * GEN_CAVE_RADIUS / length + 0.5)
		z = math.floor(z + ddz * GEN_CAVE_RADIUS / length + 0.5)

		for dx = -GEN_CAVE_RADIUS, GEN_CAVE_RADIUS do
			for dz = -GEN_CAVE_RADIUS, GEN_CAVE_RADIUS do
				for dy = GEN_CAVE_RADIUS, -GEN_CAVE_RADIUS, -1 do
					local bx, by, bz = x + dx, y + dy, z + dz
					if
						dx * dx + dz * dz + dy * dy < CAVE_RADIUS2
						and 0 < by and by < dimy - 1
						and 1 < bx and bx < dimx - 1
						and 1 < bz and bz < dimz - 1
					then
						local cblock = GetBlock(bx, by, bz)
						if cblock < 8 or cblock > 9 then
							SetBlock(bx, by, bz, (by > heightLava and 0)or 11)
						else
							SetBlock(bx, by - 1, bz, 8)
						end
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

return function(world, seed)
	log.debug('DefaultGenerator: START')
	seed = seed or (os.clock() * os.time())
	local dimx, dimy, dimz = world:getDimensions()
	math.randomseed(seed)

	biomesGenerate(dimx, dimz)

	heightSet(dimy)
	heightMapGenerate(dimx, dimy, dimz)

	fillStone(world, dimx, dimz)

	local mapaddr = world:getAddr()

	local threads = {}

	local thlimit = config:get('generator-threads-count')

	local terrain_gen = lanes.gen(lanelibs, threadTerrain)
	for i = 0, thlimit - 1 do
		startX = math.floor(dimx * i / thlimit)
		endX = math.floor(dimx * (i + 1) / thlimit) - 1

		table.insert(threads, terrain_gen(mapaddr, dimx, dimy, dimz, startX, endX, seed + i))
		log.debug(('TerrainGenerator: #%d thread spawned'):format(#threads))
	end
	watchThreads(threads)

	if GEN_ENABLE_ORES then
		local ores_gen = lanes.gen(lanelibs, generateOre)
		table.insert(threads, ores_gen(mapaddr, dimx, dimy, dimz, seed))
		log.debug('OresGenerator: started')
	end

	if #threads == thlimit then
		watchThreads(threads)
	end

	if GEN_ENABLE_TREES then
		local trees_gen = lanes.gen(lanelibs, generateTrees)
		table.insert(threads, trees_gen(mapaddr, dimx, dimy, dimz, seed))
		log.debug('TreesGenerator: started')
	end

	if #threads == thlimit then
		watchThreads(threads)
	end

	if GEN_ENABLE_HOUSES then
		local houses_gen = lanes.gen(lanelibs, generateHouse)
		table.insert(threads, houses_gen(mapaddr, dimx, dimy, dimz, seed))
		log.debug('HousesGenerator: started')
	end

	watchThreads(threads)

	if GEN_ENABLE_CAVES then
		log.debug('CavesGenerator: started')

		local caves_gen = lanes.gen(lanelibs, generateCaves)
		local CAVES_COUNT = dimx * dimy * dimz / 700000

		for i = 1, CAVES_COUNT do
			if i % thlimit == 0 then
				watchThreads(threads)
				log.debug(('CaveGenerator: %d threads done'):format(thlimit))
			end

			table.insert(threads, caves_gen(mapaddr, dimx, dimy, dimz, seed + i * math.random(0, 100)))
			log.debug(('CaveGenerator: #%d thread spawned'):format(#threads))
		end
	end

	watchThreads(threads)

	local x, z = math.random(1, dimx), math.random(1, dimz)
	local y = getHeight(x, z)

	for i = 1, 20 do
		if y < 0 then
			x, z = math.random(1, dimx), math.random(1, dimz)
			y = getHeight(x, z)
			break
		end
	end

	world:setSpawn(x, y + 2, z)
	world:setEnvProp(MEP_SIDESBLOCK, 0)
	world:setEnvProp(MEP_EDGEBLOCK, 8)
	world:setEnvProp(MEP_EDGELEVEL, heightWater + 1)
	world:setEnvProp(MEP_MAPSIDESOFFSET, 0)
	world:setData('isNether', false)
	world:setData('seed', seed)
	collectgarbage()
	log.debug('DefaultGenerator: DONE')

	return true
end
