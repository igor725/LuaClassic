local GEN_BIOME_STEP = 20


local heightGrass
local heightLava
local heightMap
local layers
local biomes

local function biomsGenerate(dx, dz)
	biomes = {}

	-- 1	normal
	-- 2	high
	-- 3	trees
	-- 4	sand
	-- 5	water

	-- Circles
	local biomesSizeX = math.floor(dx / GEN_BIOME_STEP + 1)
	local biomesSizeZ = math.floor(dz / GEN_BIOME_STEP + 1)
	for x = 0, biomesSizeX do
		biomes[x] = {}
		for z = 0, biomesSizeZ do
			biomes[x][z] = 1
		end
	end

	local radius = 2
	local BIOME_COUNT = dx * dz / GEN_BIOME_STEP / radius / 512 + 1
	--local BIOME_COUNT = 10
	--local radius = math.floor(dx * dz / BIOME_COUNT / GEN_BIOME_STEP / 32)
	local radius2 = radius * radius

	for i = 1, BIOME_COUNT do
		local x = math.random(biomesSizeX)
		local z = math.random(biomesSizeZ)
		local biome = math.random(1, 3)

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
	return biomes[math.floor(x/GEN_BIOME_STEP)][math.floor(z/GEN_BIOME_STEP)]
end

local function heightSet(dy)
	heightGrass = 7 --dy / 10
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
	local hx, hz = math.floor(x/GEN_BIOME_STEP), math.floor(z/GEN_BIOME_STEP)
	local percentX = x / GEN_BIOME_STEP - hx
	local percentZ = z / GEN_BIOME_STEP - hz

	return math.floor(
		  (heightMap[hx][hz  ] * (1 - percentX) + heightMap[hx+1][hz  ] * percentX) * (1 - percentZ)
		+ (heightMap[hx][hz+1] * (1 - percentX) + heightMap[hx+1][hz+1] * percentX) * percentZ
		+ 0.5
	)
end

local function layersGenerate(dx, dy, dz)
	layers = {}

	LAYERS_COUNT = dy / 32

	for layer = 1, LAYERS_COUNT do
		layers[layer] = {}

		-- Circles
		local biomesSizeX = math.floor(dx / GEN_BIOME_STEP + 1)
		local biomesSizeZ = math.floor(dz / GEN_BIOME_STEP + 1)
		for x = 0, biomesSizeX do
			layers[layer][x] = {}
			for z = 0, biomesSizeZ do
				layers[layer][x][z] = 1
			end
		end

		local radius = 3
		local BIOME_COUNT = dx * dz / GEN_BIOME_STEP / radius / 128 + 1
		local radius2 = radius * radius

		for i = 1, BIOME_COUNT do
			local x = math.random(biomesSizeX)
			local z = math.random(biomesSizeZ)
			local biome = math.random(0, 5)

			for dx = -radius, radius do
				for dz = -radius, radius do
					if
					dx*dx + dz*dz < radius2
					and layers[layer][x + dx] ~= nil and biomes[x + dx][z + dz] ~= nil
					then
						layers[layer][x + dx][z + dz] = biome
					end
				end
			end
		end
	end
end

local function getLayerMultiplier(layer, x, z)
	local hx, hz = math.floor(x/GEN_BIOME_STEP), math.floor(z/GEN_BIOME_STEP)
	local percentX = x / GEN_BIOME_STEP - hx
	local percentZ = z / GEN_BIOME_STEP - hz

	return (layers[layer][hx][hz  ] * (1 - percentX) + layers[layer][hx+1][hz  ] * percentX) * (1 - percentZ)
		+ (layers[layer][hx][hz+1] * (1 - percentX) + layers[layer][hx+1][hz+1] * percentX) * percentZ
end

-- Generate
local function threadTerrain(mapaddr, dx, dy, dz, heightMap, heightLava, startX, endX, layers)
	set_debug_threadname('TerrainGenerator')

	local map = ffi.cast('char*', mapaddr)
	local size = dx * dy * dz + 4

	--local GEN_BIOME_STEP = 20

	local SetBlock = function(x, y, z, id)
		--[[local offset = math.floor(z * dx + y * (dx * dz) + x + 4)
		if offset < size then -- <=
			map[offset] = id
		end]]--
		--map[y * dz * dx + z * dx + x + 4] = id
		map[(y * dz + z) * dx + x + 4] = id
	end

	local height1, biome
	local offsetX, offsetY
	for x = startX, endX do
		local hx = math.floor(x/GEN_BIOME_STEP)
		local percentPosX = x / GEN_BIOME_STEP - hx
		local percentNegX = 1 - percentPosX

		local biomePosX = math.floor(x/GEN_BIOME_STEP)
		local b0 = biomes[biomePosX]
		local b1 = biomes[biomePosX+1]
		local biomePosZOld = nil
		local b00 = nil
		local b01 = b0[0]
		local b10 = nil
		local b11 = b1[0]

		for z = 0, dz - 1 do
			local hz = math.floor(z/GEN_BIOME_STEP)
			local percentZ = z / GEN_BIOME_STEP - hz

			height1 = math.floor(
				  (heightMap[hx][hz  ] * percentNegX + heightMap[hx+1][hz  ] * percentPosX) * (1 - percentZ)
				+ (heightMap[hx][hz+1] * percentNegX + heightMap[hx+1][hz+1] * percentPosX) * percentZ
				+ 0.5
			)

			-- Biom depend
			local biomePosZ = math.floor(z/GEN_BIOME_STEP)
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
				biome = biomes[math.floor(x / GEN_BIOME_STEP + 0.5)][math.floor(z / GEN_BIOME_STEP + 0.5)]
				--biome = getBiome(x + GEN_BIOME_STEP / 2, z + GEN_BIOME_STEP / 2)
			end

			local block = 4
			-- normal or trees
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
				--if layers[layer][biomePosX][biomePosZ] > 0 then
				if multiplier > 0 then
					local layerHeight = dy * layer / (#layers + 1)
					local height2 = (height1 - heightGrass) / 2 * multiplier
					for y = math.floor(layerHeight - height2 + 1), layerHeight + height2 do
						if 1 < y and y < dy-1 then
							map[offset + y * step] = 45
						end
					end
				end
			end
		end
	end
end

-- Main
return function(world, seed)
	seed = seed or (os.clock()*os.time())
	local dx, dy, dz = world:getDimensions()
	dy = math.min(dy, 128)

	math.randomseed(seed)

	ffi.fill(world.ldata + 4, dx * dz, 7)
	ffi.fill(world.ldata + 4 + dx * dz * (dy - 1), dx * dz, 7)

	-- Generate map
	biomsGenerate(dx, dz)

	heightSet(dy)
	heightMapGenerate(dx, dz)

	layersGenerate(dx, dy, dz)

	local mapaddr = world:getAddr()

	local threads = {}

	local count = config:get('generator-threads-count', 2)
	for i = 0, count-1 do
		startX = math.floor(dx * i / count)
		endX = math.floor(dx * (i + 1) / count) - 1

		local terrain_gen = lanes.gen('math,ffi', threadTerrain)
		table.insert(threads, terrain_gen(mapaddr, dx, dy, dz, heightMap, heightLava, startX, endX, layers))
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

	world:setSpawn(x, y+2, z)
	world:setEnvProp(0, 0)
	world:setEnvProp(1, 11)
	world:setEnvProp(2, heightLava + 1)
	world:setEnvProp(3, -10000)
	world:setEnvProp(9, 0)
	world:setEnvColor(EC_SKY, 255, 0, 0)
	world:setEnvColor(EC_FOG, 250, 10, 10)
	world:setData('isNether', true)
	collectgarbage()

	return true
end
