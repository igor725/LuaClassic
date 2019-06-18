local canBurn = {
	[5] = true,
	[17] = true,
	[18] = true,
	[47] = true
}

local blocked = {
	[0] = true,
	[51] = true,
	[53] = true,
	[54] = true,
	[60] = true
}

for i = 8, 11 do
	blocked[i] = true
end

for i = 21, 65 do
	if (i >= 21 and i <= 36) or i == 47 or (i >= 55 and i <= 59)or i == 64 then
		canBurn[i] = true
	end
end

local function doFireSpread(world, x, y, z)
	local spreaded = false
	for dy = -2, 2 do
		if spreaded then break end
		for dx = -2, 2 do
			if spreaded then break end
			for dz = -2, 2 do
				if spreaded then break end
				local cx, cy, cz = x + dx, y + dy, z + dz
				local did = world:getBlock(cx, cy, cz)

				if canBurn[did]then
					if math.random(0, 10) == 4 then
						local uy = cy + 1
						local upblock = world:getBlock(cx, uy, cz)
						if upblock == 0 then
							spreaded = true
							world:setBlock(cx, uy, cz, 54)
							survUpdateFireBlock(world, cx, uy, cz)
						end
					end
				end
			end
		end
	end
end

function survUpdateFireBlock(world, x, y, z)
	local id = world:getBlock(x, y, z)

	if id == 54 then
		local name = ('fire_%d%d%d'):format(x, y, z)
		timer.Create(name, 20, 1, function(left)
			local id = world:getBlock(x, y, z)

			if id == 54 then
				if left % 3 == 2 then
					doFireSpread(world, x, y, z)
				end
				if left == 0 then
					world:setBlock(x, y, z, 0)
					local db = world:getBlock(x, y - 1, z)
					if canBurn[db]then
						world:setBlock(x, y - 1, z, 0)
					end
				end
			else
				timer.Remove(name)
			end
		end)
	end
end

hooks:add('onPlayerPlaceBlock', 'surv_fire', function(player, x, y, z, id)
	if id == 54 then
		local down = getWorld(player):getBlock(x, y - 1, z)
		if blocked[down]then
			return true
		end
	end
end)

hooks:add('postPlayerPlaceBlock', 'surv_fire', function(player, x, y, z, id)
	local world = getWorld(player)
	if id == 54 then
		if player:checkPermission('fire.spread')then
			survUpdateFireBlock(world, x, y, z)
		end
	else
		local up = world:getBlock(x, y + 1, z)
		if up == 54 then
			world:setBlock(x, y + 1, z, 0)
		end
	end
end)
