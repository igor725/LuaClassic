anticheatEnabled = false

local function haveGround(player)
	local world = getWorld(player)
	local x, y, z = player:getPos()
	x, y, z = floor(x), floor(y - 2), floor(z)

	local haveGround = false
	for _x = -1, 1 do
		if haveGround then break end
		for _z = -1, 1 do
			for _y = -1, 1 do
				local id = world:getBlock(x + _x, y + _y, z + _z)
				if id ~= 0 then
					haveGround = true
					break
				end
			end
		end
	end

	return haveGround
end

hooks:add('postPlayerFirstSpawn', 'anticheat', function(player)
	player.landY = select(2, player:getPos())
	player.acBypass = false
	player.cheatScore = 0
end)

hooks:add('onPlayerMove', 'anticheat', function(player, dx, dy, dz)
	if not anticheatEnabled then return end
	if player.acBypass or player.isInGodmode then return end
	local x, y, z = player:getPos()

	if dy < 0.1 and (dx > 1 or dz > 1)then
		if not haveGround(player)then
			player.cheatScore = player.cheatScore + 10
		else
			player.cheatScore = player.cheatScore + 5
		end
	end

	if dy > 1 then
		player.cheatScore = player.cheatScore + 25
	else
		if (y - player.landY) > 5 then
			if not haveGround(player)then
				player.cheatScore = player.cheatScore + 20
			else
				player.landY = select(2, player:getPos())
			end
		end
	end
	
	if player.cheatScore > 60 then
		player:kick('Kicked 4 cheats')
	end
end)

hooks:add('postPlayerTeleport', 'anticheat', function(player)
	player.cheatScore = 0
end)

hooks:add('onPlayerLanded', 'anticheat', function(player)
	player.cheatScore = 0
	player.landY = select(2, player:getPos())
end)

addCommand('ac', function(isConsole, player, args)
	if args[1] == 'toggle'then
		anticheatEnabled = not anticheatEnabled
	end
	return ('Anticheat %s'):format((anticheatEnabled and ST_ON)or ST_OFF)
end)
