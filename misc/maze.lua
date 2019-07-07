--[[
	Maze generator CraftScript for WorldEdit
	Copyright (C) 2010, 2011 sk89q <http://www.sk89q.com>

	Ported for LuaClassic server
]]

local world, block, w, h, sz, ox, oy, oz = ...

local function push(arr, val)
	table.insert(arr, val)
end

local function pop(arr)
	return table.remove(arr)
end

local function id(x, y)
	return y * (w + 1) + x
end

local function _x(i)
	return i % (w + 1)
end

local function _y(i)
	return floor(i / (w + 1))
end

local function shuffle(arr)
	local i = #arr
	if i == 0 then return false end
	while(i > 0)do
		local j = floor(math.random() * (i + 1))
		local tempi = arr[i]
		local tempj = arr[j]
		arr[i] = tempj
		arr[j] = tempi
		i = i - 1
	end
end

local stack = {id(0, 0)}
local visited = {}
local tsize = (w + 1) * (h + 1)
local noWallLeft = ffi.new('bool[?]', tsize)
local noWallAbove = ffi.new('bool[?]', tsize)

while #stack > 0 do
	local cell = pop(stack)
	local x, y = _x(cell), _y(cell)
	visited[cell] = true

	local neighbors = {}

	if x > 0 then push(neighbors, id(x - 1, y))end
	if x < w -1 then push(neighbors, id(x + 1, y))end
	if y > 0 then push(neighbors, id(x, y - 1))end
	if y < h - 1 then push(neighbors, id(x, y + 1))end

	shuffle(neighbors)

	while #neighbors > 0 do
		local n = pop(neighbors)
		local nx, ny = _x(n), _y(n)

		if visited[n] ~= true then
			push(stack, cell)

			if y == ny then
				if nx < x then
					noWallLeft[cell] = true
				else
					noWallLeft[n] = true
				end
			else
				if ny < y then
					noWallAbove[cell] = true
				else
					noWallAbove[n] = true
				end
			end

			push(stack, n)
			break
		end
	end
end

ox = floor(ox)
oy = floor(oy)
oz = floor(oz)

BulkBlockUpdate:start(world)
for y = 0, h do
	for x = 0, w do
		local cell = id(x, y)
		for i = 0, sz do
			if noWallLeft[cell] ~= true and y < h then
				local o = BulkBlockUpdate:write(ox + (x * 2 - 1), oy + i, oz + y * 2, block)
				if o then world.ldata[o] = block end
			end
			if noWallAbove[cell] ~= true and x < w then
				local o = BulkBlockUpdate:write(ox + x * 2, oy + i, oz + (y * 2 - 1), block)
				if o then world.ldata[o] = block end
			end
			local o = BulkBlockUpdate:write(ox + (x * 2 - 1), oy + i, oz + (y * 2 - 1), block)
			if o then world.ldata[o] = block end
		end
	end
end
BulkBlockUpdate:done()
