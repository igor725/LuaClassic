commands = {}

function addCommand(name, func)
	commands[name] = func
end

function addAlias(name, alias)
	commands[alias] = commands[name]
end

addCommand('rc', function(isConsole, player, args)
	if isConsole and #args < 1 then return false end

	local world = getWorld(args[1]or player)
	local rdState = ((world:toggleReadOnly()and ST_ON)or ST_OFF)
	return (CMD_WMODE):format(rdState, world)
end)

addCommand('info', function(isConsole, player)
	local str1 = (CMD_SVINFO1):format(jit.os, jit.arch, jit.version)
	local str2 = (CMD_SVINFO2):format(gcinfo() / 1024)
	if isConsole then
		io.write(str1, '\n', str2, '\n')
	else
		player:sendMessage(str1)
		player:sendMessage(str2)
	end
end)

addCommand('clear', function(isConsole, player)
	if isConsole then return CON_INGAMECMD end

	for i = 1, 25 do
		player:sendMessage('')
	end
end)

addCommand('stop', function()
	_STOP = true
end)

addCommand('restart', function()
	_STOP = 'restart'
end)

addCommand('uptime', function()
	local tm = gettime() - START_TIME
	local h = tm / 3600
	local m = (tm/60) % 60
	local s = tm % 60
	return (CMD_UPTIME):format(h, m, s)
end)

addCommand('seed', function(isConsole, player, args)
	if isConsole and #args < 1 then return false end

	local world = getWorld(args[1]or player)
	local seed = world:getData('seed')

	if seed then
		return (CMD_SEED):format(seed)
	end
end)

addCommand('setspawn', function(isConsole, player)
	if isConsole then return CON_INGAMECMD end

	local world = getWorld(player)
	local x, y, z = player:getPos()
	local ay, ap = player:getEyePos()
	world:setSpawn(x, y, z, ay, ap)
	return CMD_SPAWNSET
end)

local function unsel(player)
	if player.onPlaceBlock then
		player.cuboidP1 = nil
		player.cuboidP2 = nil
		SelectionCuboid:remove(player, 0)
	end
end

addCommand('sel', function(isConsole, player)
	if isConsole then return CON_INGAMECMD end

	if not player.onPlaceBlock then
		player.onPlaceBlock = function(x, y, z, id)
			if player.cuboidP1 then
				player.cuboidP2 = {x, y, z}
				local sx, sy, sz = unpack(player.cuboidP1)
				SelectionCuboid:create(player, 0, '', sx, sy, sz, x, y, z)
				return true
			end
			player.cuboidP1 = {x, y, z}
			return true
		end
	else
		unsel(player)
		player.onPlaceBlock = nil
		return (CMD_SELMODE):format(ST_OFF)
	end
	return (CMD_SELMODE):format(ST_ON)
end)

addCommand('unsel', function(isConsole, player)
	if isConsole then return CON_INGAMECMD end

	unsel(player)
end)

addCommand('mkportal', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end
	if #args < 2 then return false end

	local p1, p2 = player.cuboidP1, player.cuboidP2
	if p1 and p2 then
		local cworld = getWorld(player)
		if getWorld(args[2])then
			cworld.data.portals = cworld.data.portals or{}
			local x1, y1, z1, x2, y2, z2 = makeNormalCube(p1[1], p1[2], p1[3], unpack(p2))
			cworld.data.portals[args[1]] = {
				tpTo = args[2],
				pt1 = newVector(x1, y1, z1),
				pt2 = newVector(x2, y2, z2)
			}
			return CMD_CRPORTAL
		else
			return WORLD_NE
		end
	else
		return CMD_SELCUBOID
	end
end)

addCommand('delportal', function(isConsole, player, args)
	if #args < 1 then return false end

	local pname = args[1]
	local world = getWorld(player).data
	if world.portals then
		if world.portals[pname]then
			world.portals[pname] = nil
			return CMD_RMPORTAL
		end
	end
	return CMD_NEPORTAL
end)

addCommand('say', function(isConsole, player, args)
	if #args > 0 then
		newChatMessage(table.concat(args, ' '))
	else
		return false
	end
end)

addCommand('set', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end
	if #args < 1 then return false end

	local world = getWorld(player)
	if world:isReadOnly()then
		return WORLD_RO
	end
	id = tonumber(args[1])
	if id then
		id = math.max(0, math.min(255, id))
		local p1, p2 = player.cuboidP1, player.cuboidP2
		if p1 and p2 then
			world:fillBlocks(
				p1[1], p1[2], p1[3],
				p2[1], p2[2], p2[3],
				tonumber(id)
			)
		else
			return CMD_SELCUBOID
		end
	else
		return CMD_BLOCKID
	end
end)

addCommand('spawn', function(isConsole, player)
	if isConsole then return CON_INGAMECMD end

	player:moveToSpawn()
end)

addCommand('regen', function(isConsole, player, args)
	local world, gen, seed
	if isConsole then
		if #args < 3 then return false end
		world = getWorld(args[1])
		gen = args[2]
		seed = tonumber(args[3])
	else
		if #args > 2 then
			world = getWorld(args[1])
			gen = args[2]
			seed = tonumber(args[3])
		elseif #args >= 1 then
			world = getWorld(player)
			gen = args[1]
			seed = tonumber(args[2])
		else
			return false
		end
	end

	if not world then return WORLD_NE end
	local ret, tm = regenerateWorld(world, gen, seed)
	if not ret then
		return (CMD_GENERR):format(tm)
	else
		return (MESG_DONEIN):format(tm * 1000)
	end
end)

addCommand('addperm', function(isConsole, player, args)
	if #args == 2 then
		permissions:addFor(args[1], args[2])
	else
		return false
	end
end)

addCommand('delperm', function(isConsole, player, args)
	if #args == 2 then
		permissions:delFor(args[1], args[2])
	else
		return false
	end
end)

addCommand('list', function(isConsole, player)
	if isConsole then
		print(CMD_WORLDLST)
	else
		player:sendMessage(CMD_WORLDLST)
	end
	for wn, world in pairs(worlds)do
		if wn ~= 'default'then
			local dfld = (getWorld('default') == world and' (default)')or''
			local wstr = '   - ' .. wn .. dfld
			if isConsole then
				print(wstr)
			else
				player:sendMessage(wstr)
			end
		end
	end
end)

addCommand('put', function(isConsole, player, args)
	if #args == 2 then
		local player = getPlayerByName(args[1])
		if player then
			player:changeWorld(args[2])
		else
			return MESG_PLAYERNF
		end
	end
end)

addCommand('weather', function(isConsole, player, args)
	local world, wtSet

	if isConsole then
		if #args < 1 then return false end
		world = getWorld(args[1])
		wtSet = args[2]
	else
		local aworld = getWorld(args[1])
		world = aworld or getWorld(player)
		wtSet = args[2]or (not aworld and args[1])
	end

	if not wtSet then
		local cw = world:getData('weather')
		return (CMD_WTCURR):format(WT[cw]or WT[0], world)
	end

	wtSet = tonumber(wtSet)or WTN[wtSet]
	if wtSet then
		wtSet = math.min(math.max(wtSet, 0), 2)
		if world:setWeather(wtSet)then
			return (CMD_WTCHANGE):format(world, WT[wtSet])
		end
	else
		return CMD_WTINVALID
	end
end)

addCommand('time', function(isConsole, player, args)
	local world, tName

	if isConsole then
		if #args < 2 then return false end
		world = getWorld(args[1])
		tName = args[2]
	else
		if #args == 1 then
			world = getWorld(player)
			tName = args[1]
		elseif #args > 1 then
			world = getWorld(args[1])
			tName = args[2]
		else
			return false
		end
	end

	if not world then return WORLD_NE end
	if world:getData('isNether')then return CMD_TIMEDISALLOW end
	if not world:setTime(tName)then
		return CMD_TIMEPRESETNF
	end
	return (CMD_TIMECHANGE):format(world, tName)
end)

addCommand('unban', function(isConsole, player, args)
	if #args < 1 then return false end
	if removeBan(args[1], args[2])then
		return 'Player unbanned'
	end
end)

addCommand('ban', function(isConsole, player, args)
	if #args < 1 then return false end
	local target = args[1]
	local isIp = false
	local reason = table.concat(args, ' ', 2)
	if not target:match('(%d+%.%d+%.%d+%.%d+)')then
		target = getPlayerByName(target)
	else
		isIp = true
	end

	if target then
		local tgname, tgip
		if isIp then
			tgname, tgip = '_', target
		else
			tgname, tgip = target:getName(), target:getIP()
		end
		if addBan(tgname, tgip, reason)and not isIp then
			target:kick(reason)
		end
	end
end)

addCommand('kick', function(isConsole, player, args)
	if #args < 1 then return false end

	local p = getPlayerByName(args[1])
	local reason = KICK_NOREASON
	if p then
		if #args > 1 then
			reason = table.concat(args, ' ', 2)
		end
		p:kick(reason)
	else
		return MESG_PLAYERNF
	end
end)

addCommand('tp', function(isConsole, player, args)
	local ply1, ply2

	if isConsole then
		if #args < 2 then return false end
		ply1 = getPlayerByName(args[1])
		ply2 = getPlayerByName(args[2])
	else
		if #args == 1 then
			ply1 = player
			ply2 = getPlayerByName(args[1])
		elseif #args >= 2 then
			ply1 = getPlayerByName(args[1])
			ply2 = getPlayerByName(args[2])
		else
			return false
		end
	end
	if not ply1 then
		return (MESG_PLAYERNFA):format(args[1])
	end
	if not ply2 then
		return (MESG_PLAYERNFA):format(args[2]or args[1])
	end

	if not ply1:isInWorld(ply2)then
		ply1:changeWorld(ply2.worldName, true, ply2:getPos())
	else
		ply1:teleportTo(ply2:getPos())
	end
	return CMD_TPDONE
end)

addCommand('help', function(isConsole)
	if isConsole then
		local str = 'List of server commands:'
		for k, v in pairs(_G)do
			if k:startsWith('CU_')then
				str = str .. '\n' .. v
			end
		end
		print(str)
	end
	return 'Online help page: &ahttps://github.com/igor725/LuaClassic/wiki'
end)

addAlias('help', '?')
