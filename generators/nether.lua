--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local GEN_BIOME_STEP = 20
local GEN_BIOME_RADIUS = 2
local GEN_ENABLE_HOUSES = true
local GEN_HOUSES_COUNT_MULT = 1 / 50000

local heightGrass
local heightLava
local heightMap
local layers
local biomes

local function biomsGenerate(dx, dz)
	biomes = {}

	-- Circles
	local biomesSizeX = math.ceil(dx / GEN_BIOME_STEP)
	local biomesSizeZ = math.ceil(dz / GEN_BIOME_STEP)
	for x = 0, biomesSizeX do
		biomes[x] = {}
		for z = 0, biomesSizeZ do
			biomes[x][z] = 1
		end
	end

	local BIOME_COUNT = dx * dz / GEN_BIOME_STEP / GEN_BIOME_RADIUS / 512 + 1
	local radius2 = GEN_BIOME_RADIUS ^ 2

	for i = 1, BIOME_COUNT do
		local x = math.random(biomesSizeX)
		local z = math.random(biomesSizeZ)
		local biome = math.random(1, 3)

		for dx = -GEN_BIOME_RADIUS, GEN_BIOME_RADIUS do
			for dz = -GEN_BIOME_RADIUS, GEN_BIOME_RADIUS do
				if
				dx * dx + dz * dz < radius2
				and biomes[x + dx] ~= nil and biomes[x + dx][z + dz] ~= nil
				then
					biomes[x + dx][z + dz] = biome
				end
			end
		end
	end
end

local function getBiome(x, z)
	return biomes[math.floor(x / GEN_BIOME_STEP)][math.floor(z / GEN_BIOME_STEP)]
end

local function heightSet(dy)
	heightGrass = 7
	heightLava = heightGrass
	heightLava = 7
end

local function heightMapGenerate(dx, dz)
	heightMap = {}
	for x = 0, dx / GEN_BIOME_STEP + 1 do
		heightMap[x] = {}
		for z = 0, dz / GEN_BIOME_STEP + 1 do
			heightMap[x][z] = heightGrass + math.random(-6, 15)
		end
	end
end

local function getHeight(x, z)
	local hx, hz = math.floor(x / GEN_BIOME_STEP), math.floor(z / GEN_BIOME_STEP)
	local percentX = x / GEN_BIOME_STEP - hx
	local percentZ = z / GEN_BIOME_STEP - hz

	return math.floor(
		  (heightMap[hx][hz  ] * (1 - percentX) + heightMap[hx + 1][hz  ] * percentX) * (1 - percentZ)
		+ (heightMap[hx][hz + 1] * (1 - percentX) + heightMap[hx + 1][hz + 1] * percentX) * percentZ
		+ 0.5
	)
end

local function layersGenerate(dx, dy, dz)
	layers = {}

	LAYERS_COUNT = dy / 32

	for layer = 1, LAYERS_COUNT do
		layers[layer] = {}

		-- Circles
		local biomesSizeX = math.ceil(dx / GEN_BIOME_STEP)
		local biomesSizeZ = math.ceil(dz / GEN_BIOME_STEP)
		for x = 0, biomesSizeX do
			layers[layer][x] = {}
			for z = 0, biomesSizeZ do
				local height = math.random(-dy / LAYERS_COUNT / 2, dy / LAYERS_COUNT / 2)
				layers[layer][x][z] = height
			end
		end

		--[[local radius = 3
		local BIOME_COUNT = dx * dz / GEN_BIOME_STEP / radius / 128 + 1
		local radius2 = radius * radius

		for i = 1, BIOME_COUNT do
			local x = math.random(biomesSizeX)
			local z = math.random(biomesSizeZ)
			local height = math.random(0, 1)

			for dx = -radius, radius do
				for dz = -radius, radius do
					if
						dx*dx + dz*dz < radius2
						and layers[layer][x + dx] ~= nil and layers[layer][x + dx][z + dz] ~= nil
					then
						layers[layer][x + dx][z + dz] = height
					end
				end
			end
		end]]--
	end
end

local function getLayerMultiplier(layer, x, z)
	local hx, hz = math.floor(x / GEN_BIOME_STEP), math.floor(z / GEN_BIOME_STEP)
	local percentX = x / GEN_BIOME_STEP - hx
	local percentZ = z / GEN_BIOME_STEP - hz

	return (layers[layer][hx][hz  ] * (1 - percentX) + layers[layer][hx + 1][hz  ] * percentX) * (1 - percentZ)
		+ (layers[layer][hx][hz + 1] * (1 - percentX) + layers[layer][hx + 1][hz + 1] * percentX) * percentZ

	--[[return math.floor(
		  (layers[layer][hx][hz  ] * (1 - percentX) + layers[layer][hx + 1][hz  ] * percentX) * (1 - percentZ)
		+ (layers[layer][hx][hz + 1] * (1 - percentX) + layers[layer][hx + 1][hz + 1] * percentX) * percentZ
		+ 0.5
	)]]
end

-- Generate
local function threadTerrain(mapaddr, dx, dy, dz, heightMap, heightLava, startX, endX, layers)
	set_debug_threadname('TerrainGenerator')

	local map = ffi.cast('char*', mapaddr)
	local size = dx * dy * dz + 4

	local SetBlock = function(x, y, z, id)
		map[(y * dz + z) * dx + x + 4] = id
	end

	local height1, biome
	local offsetX, offsetY
	for x = startX, endX do
		local hx = math.floor(x / GEN_BIOME_STEP)
		local percentPosX = x / GEN_BIOME_STEP - hx
		local percentNegX = 1 - percentPosX

		local biomePosX = math.floor(x/GEN_BIOME_STEP)
		local b0 = biomes[biomePosX]
		local b1 = biomes[biomePosX + 1]
		local biomePosZOld = nil
		local b00 = nil
		local b01 = b0[0]
		local b10 = nil
		local b11 = b1[0]

		for z = 0, dz - 1 do
			local hz = math.floor(z / GEN_BIOME_STEP)
			local percentZ = z / GEN_BIOME_STEP - hz

			height1 = math.floor(
				  (heightMap[hx][hz  ] * percentNegX + heightMap[hx + 1][hz  ] * percentPosX) * (1 - percentZ)
				+ (heightMap[hx][hz + 1] * percentNegX + heightMap[hx + 1][hz + 1] * percentPosX) * percentZ
				+ 0.5
			)

			local biomePosZ = math.floor(z / GEN_BIOME_STEP)
			if biomePosZ ~= biomePosZOld then
				biomePosZOld = biomePosZ
				b00 = b01
				b01 = b0[biomePosZ+1]
				b10 = b11
				b11 = b1[biomePosZ+1]
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
				if percentNegX * percentNegX + (1 - percentZ)^2 > 0.25 then
					biome = b00
				else
					biome = b11
				end
			else
				biome = biomes[math.ceil(x / GEN_BIOME_STEP)][math.ceil(z / GEN_BIOME_STEP)]
				--biome = getBiome(x + GEN_BIOME_STEP / 2, z + GEN_BIOME_STEP / 2)
			end

			local block = 4

			if biome == 1 then
				block = 45
			elseif biome == 2 then
				block = 3
			elseif biome == 3 then
				block = 13
			end

			local offset = z * dx + x + 4
			local step = dz * dx

			for y = 1, height1 do
				map[offset + y * step] = block
			end

			for y = height1 + 1, heightLava do
				SetBlock(x, y, z, 11)
			end

			-- temp for up
			for y = dy - height1 - math.random(1, 2), dy - 2 do
				map[offset + y * step] = 45
			end

			-- temp for layers
			for layer = 1, #layers do
				local multiplier = getLayerMultiplier(layer, x, z)
				
				local layerHeight = dy * layer / (#layers + 1)
				for y = math.floor(layerHeight - multiplier / 2) + math.random(0, 1), layerHeight + multiplier - 1 do
					if 0 < y and y < dy - 1 then
						map[offset + y * step] = 45
					end
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
	local materials = {49, 44, 43}

	for i = 1, HOUSE_COUNT do
		local startX = math.random(4, dimx - 11)
		local startZ = math.random(4, dimz - 9)
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
				if tempHeight < heightLava or tempHeight > dimy - 11 then
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
					ffi.fill(map + (y * dimz + z) * dimx + startX + 4, lengthX, materials[1])
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
				SetBlock(startX + 2, maxHeight - j, startZ - j, materials[1])
				j = j + 1
			end

			maxHeight = maxHeight + 4

			for i = -1, math.ceil(math.min(endX - startX - 1, endZ - startZ - 1) / 2) do
				ffi.fill(map + ((maxHeight + i) * dimz + startZ + i) * dimx + startX + i + 4, lengthX - 2 * i, materials[3])
				ffi.fill(map + ((maxHeight + i) * dimz + endZ - i) * dimx + startX + i + 4, lengthX - 2 * i, materials[3])

				for z = startZ + i + 1, endZ - i - 1 do
					SetBlock(startX + i, maxHeight + i, z, materials[3])
					SetBlock(endX - i, maxHeight + i, z, materials[3])
				end
			end
		end
	end
end

return function(world, seed)
	seed = seed or os.time()
	local dx, dy, dz = world:getDimensions()
	dy = math.min(dy, 128)

	math.randomseed(seed)

	ffi.fill(world.ldata + 4, dx * dz, 7)
	ffi.fill(world.ldata + 4 + dx * dz * (dy - 1), dx * dz, 7)

	biomsGenerate(dx, dz)

	heightSet(dy)
	heightMapGenerate(dx, dz)

	layersGenerate(dx, dy, dz)

	local mapaddr = world:getAddr()

	local threads = {}

	local count = config:get('generatorThreadsCount')
	for i = 0, count - 1 do
		startX = math.floor(dx * i / count)
		endX = math.floor(dx * (i + 1) / count) - 1

		local terrain_gen = lanes.gen('math,ffi', threadTerrain)
		table.insert(threads, terrain_gen(mapaddr, dx, dy, dz, heightMap, heightLava, startX, endX, layers))
	end

	if GEN_ENABLE_HOUSES then
		local houses_gen = lanes.gen('math,ffi', generateHouse)
		table.insert(threads, houses_gen(mapaddr, dx, dy, dz, seed))
		log.debug('HousesGenerator: started')
	end

	watchThreads(threads)

	local x, z = math.random(1, dx), math.random(1, dz)
	local y = getHeight(x,z)

	for i = 1, 20 do
		if y < 0 then
			x, z = math.random(1, dx), math.random(1, dz)
			y = getHeight(x,z)
			break
		end
	end

	world:setSpawn(x + 0.5, y + 2.5, z + 0.5)
	world:setEnvProp(MEP_SIDESBLOCK, 0)
	world:setEnvProp(MEP_EDGEBLOCK, 11)
	world:setEnvProp(MEP_EDGELEVEL, heightLava + 1)
	world:setEnvProp(MEP_CLOUDSLEVEL, -10000)
	world:setEnvProp(MEP_MAPSIDESOFFSET, 0)
	world:setEnvColor(EC_SKY, 255, 0, 0)
	world:setEnvColor(EC_FOG, 250, 10, 10)
	world:setData('isNether', true)
	world:setData('seed', seed)
	collectgarbage()

	return true
end
