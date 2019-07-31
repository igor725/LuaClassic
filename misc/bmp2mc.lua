local customBlocksEnabled = true

bitmap = require('bitmap')

-- r, g, b, blockid
local colors = {
	{160, 24, 24, 21},
	{130, 82, 8, 22},
	{166, 166, 0, 23},
	{102, 177, 2, 24},
	{10, 174, 10, 25},
	{6, 174, 106, 26},
	{3, 175, 175, 27},
	{6, 120, 150, 28},
	{90, 90, 162, 29},
	{105, 31, 180, 30},
	{142, 55, 184, 31},
	{168, 38, 168, 32},
	{194, 36, 114, 33},
	{20, 20, 20, 34},
	{111, 111, 111, 35},
	{200, 200, 200, 36}
}

if customBlocksEnabled then
	colors[#colors+1] = {176, 102, 130, 55}
	colors[#colors+1] = {34, 57, 8, 56}
	colors[#colors+1] = {60, 30, 10, 57}
	colors[#colors+1] = {20, 30, 120, 58}
	colors[#colors+1] = {25, 90, 120, 59}
end

function getNearbyWool(r, g, b)
	local mindiff = 999
	local block = 34

	for i = 1, #colors do
		local c = colors[i]
		local diff = math.sqrt((r - c[1]) ^ 2 + (g - c[2]) ^ 2 + (b - c[3]) ^ 2)
		if diff < mindiff then
			mindiff = diff
			block = c[4]
		end
	end

	return block
end

function createBmpPainting(world, x, y, z, direction, image)
	local step = 1
	local dir = 'x'
	if direction == -1 then
		step = -1
	elseif direction == -2 then
		step = -1
		dir = 'y'
	elseif direction == 2 then
		dir = 'y'
	end

	local bmp = bitmapFromFile(image)
	if bmp then
		BulkBlockUpdate:start(world)
		for by = 0, bmp:getHeight() - 1 do
			for bx = 0, bmp:getWidth() - 1 do
				local nx, ny, nz = x, y, z
				if dir == 'x'then
					nx = nx + bx
					nz = nz + by
				else
					nx = nx + bx
					ny = ny + by
				end

				local id = getNearbyWool(assert(bmp:getPixel(bx, by)))
				local offset = world:getOffset(nx, ny, nz)
				if offset and world.ldata[offset] ~= id then
					BulkBlockUpdate:write(offset, id)
					world.ldata[offset] = id
				end
			end
		end
		BulkBlockUpdate:done()
		bmp:close()
		print(bmp.ok)
		return true
	end
	return false, 'Can\'t load bmp file'
end
