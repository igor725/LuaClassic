GEN_ENABLE_CAVES = true
GEN_ENABLE_TREES = true
GEN_ENABLE_ORES = true

local STEP = 20
local heightStone
local heightNetherrack
local heightWater


-- Height map
local heightMap

function heightSet(dy)
	heightNetherrack = dy / 8
	heightWater = heightNetherrack
	heightLava = 7
end

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

	local radius = 2
	local BIOME_COUNT = dx * dz / STEP / radius / 64 + 1
	local radius2 = radius * radius

	for i = 1, BIOME_COUNT do
		local x = math.random(biomesSizeX)
		local z = math.random(biomesSizeZ)
		local biome = math.random(1, 2)

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

function heightMapGenerate(dx, dz)
	heightMap = {}
	for x = 0, dx / STEP + 1 do
		heightMap[x] = {}
		for z = 0, dz / STEP + 1 do
			heightMap[x][z] = heightNetherrack + math.random(-6, 15)
		end
	end
end

function heightMapGenerate2(dx, dz)
	heightMap = {}
	for x = 0, dx / STEP + 1 do
		heightMap[x] = {}
		for z = 0, dz / STEP + 1 do
			heightMap[x][z] = math.random(-30, 30)
		end
	end
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

local function getHeightMiddle(x, z)
	local hx, hz = math.floor(x/STEP), math.floor(z/STEP)
	local percentX = x / STEP - hx
	local percentZ = z / STEP - hz

	return math.floor(
		  (heightMapMiddle[hx][hz  ] * (1 - percentX) + heightMapMiddle[hx+1][hz  ] * percentX) * (1 - percentZ)
		+ (heightMapMiddle[hx][hz+1] * (1 - percentX) + heightMapMiddle[hx+1][hz+1] * percentX) * percentZ
		--+ 0.5
	)
end



local function getBiome(x, z)
	return biomes[math.floor(x/STEP)][math.floor(z/STEP)]
end

-- Generate
local function generateTerrain(world, dimx, dimy, dimz)
	local height1, heightStone1, biome
	local offsetX, offsetY
	for x = 0, dimx - 1 do
		for z = 0, dimz - 1 do
			height1 = getHeight(x, z)

			-- Badrock
			world:SetBlock(x, 0, z, 7)
			world:SetBlock(x, dimy-1, z, 7)

			-- Biom depend
			--local biome = getBiome(x, z)

			offsetX = math.random(0, STEP)
			if x + offsetX > dimx then
				offsetX = 0
			end

			offsetZ = math.random(0, STEP)
			if z + offsetZ > dimz then
				offsetZ = 0
			end

			local biome = getBiome(x + offsetX, z + offsetZ)

			if biome == 1 then
				-- Stone
				for y = 1, height1 do
					world:SetBlock(x, y, z, 45)
					--world:SetBlock(x, dimy - y - 1, z, 45)
				end
			elseif biome == 2 then
				-- Stone
				for y = 1, height1 do
					world:SetBlock(x, y, z, 3)
					--world:SetBlock(x, dimy - y - 1, z, 45)
				end
			end


			-- normal or trees
			if height1 <= heightWater then
				for y = height1 + 1, heightWater do
					world:SetBlock(x, y, z, 11)
				end
			end
		end
	end
end


local function generateTerrainUp(world, dimx, dimy, dimz)
	local height1, heightStone1, biome
	local offsetX, offsetY
	for x = 0, dimx - 1 do
		for z = 0, dimz - 1 do
			height1 = getHeight(x, z)

			world:SetBlock(x, dimy-1, z, 7)

			for y = 1, height1 + math.random(0, 2) do
				world:SetBlock(x, dimy - y - 1, z, 45)
			end
		end
	end
end


function heightMapGenerateMiddle(dx, dimy, dz)
	heightMapMiddle = {}
	for x = 0, dx / STEP + 1 do
		heightMapMiddle[x] = {}
		for z = 0, dz / STEP + 1 do
			if math.random(0, 6) == 0 then
				heightMapMiddle[x][z] = math.random(0, dimy / 2)
			else
				heightMapMiddle[x][z] = math.random(-10, 10)
			end
		end
	end
end


local function generateMiddleTerrain(world, dimx, dimy, dimz)
	local height1, height2, biome
	local offsetX, offsetY
	for x = 0, dimx - 1 do
		for z = 0, dimz - 1 do
			height1 = getHeightMiddle(x, z)
			height2 = getHeight(x, z)

			-- Stone
			for y = math.floor(dimy / 2) - height1 + height2 - math.random(0, 2), math.floor(dimy / 2) + height1 + height2 do
				world:SetBlock(x, y, z, 45)
				--world:SetBlock(x, dimy - y, z, 45)
				--world:SetBlock(x, getHeight(x, z) - y, z, 45)
			end
		end
	end
end

-- Main
return function(world, seed)
	seed = seed or (os.clock()*os.time())
	local dx, dy, dz = world:GetDimensions()
	math.randomseed(seed)

	dy = 128

	-- Generate map
	biomsGenerate(dx, dz)

	heightSet(dy)
	heightMapGenerate(dx, dz)

	io.write("terrain, ")
	generateTerrain(world, dx, dy, dz)

	heightMapGenerate(dx, dz)
	generateTerrainUp(world, dx, dy, dz)

	io.write("middle terrain, ")
	heightMapGenerate2(dx, dz)
	heightMapGenerateMiddle(dx, dy, dz)
	generateMiddleTerrain(world, dx, dy, dz)

	local x, z = math.random(50, dx), math.random(50, dz)
	local y = getHeight(x,z)
	world:SetSpawn(x,y+2,z,0,0)

	local ma = {
		['0'] = 0,
		['1'] = 11,
		['2'] = heightWater + 1,
		['3'] = -10000,
		['9'] = 0
	}
	world.data.map_aspects = ma

	world.data.colors = {
		['0'] = {255,0,0},
		['2'] = {250,10,10}
	}
	-- world.data.texPack = 'http://91.135.213.120/nether.png'
	world.data.isNether = true

	return true
end
