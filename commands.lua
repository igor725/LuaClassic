commands = {}
concommands = {}

function addChatCommand(name, func)
	commands[name] = func
end

function addConsoleCommand(name, func)
	concommands[name] = func
end

function addAlias(isChatCommand, name, alias)
	if isChatCommand then
		commands[alias] = commands[name]
	else
		concommands[alias] = concommands[name]
	end
end

--[[
	Ingame commands
]]

addChatCommand('rc', function(player)
	local world = getWorld(player)
	return (CMD_WMODE):format(((world:toggleReadOnly()and ST_ON)or ST_OFF))
end)

addChatCommand('info', function(player)
	player:sendMessage((CMD_SVINFO1):format(jit.os, jit.arch, jit.version))
	player:sendMessage((CMD_SVINFO2):format(gcinfo() / 1024))
end)

addChatCommand('clear', function(player)
	for i = 1, 25 do
		player:sendMessage('')
	end
end)

addChatCommand('stop', function()
	_STOP = true
end)

addChatCommand('restart', function()
	_STOP = 'restart'
end)

addChatCommand('weather', function(player, wname, wtt)
	local world
	if wname == nil then
		world = getWorld(player)
		local cw = world:getData('weather')
		cw = WT[cw]or WT[0]
		return (CMD_WTCURR):format(cw)
	end
	local wnum = tonumber(wname)or WTN[wname]
	if wnum == nil then
		world = getWorld(wname)
		if not world then
			return WORLD_NE
		end
		wtt = tonumber(wtt)or WTN[wtt]
	else
		world = getWorld(player)
		wtt = wnum
	end

	if wtt then
		wtt = math.min(math.max(wtt, 0), 2)
		if world:setWeather(wtt)then
			return (CMD_WTCHANGE):format(world, WT[wtt])
		end
	else
		return CMD_WTINVALID
	end
end)

addChatCommand('time', function(player, wname, name)
	if not wname then return end
	local world, colors
	if time_presets[wname]then
		world = getWorld(player)
		colors = time_presets[wname]
	else
		if not name then
			return CMD_TIMEPRESETNF
		end
		world = getWorld(wname)
		colors = time_presets[name]
		if not world then
			return WORLD_NE
		end
		if not colors then
			return CMD_TIMEPRESETNF
		end
	end

	if world:getData('isNether')then
		return CMD_TIMEDISALLOW
	end

	for i = 0, 4 do
		local c = colors[i]
		world:setEnvColor(i, c.r, c.g, c.b)
	end

	return (CMD_TIMECHANGE):format(world, wname)
end)

local function unsel(player)
	if player.onPlaceBlock then
		player.cuboidP1 = nil
		player.cuboidP2 = nil
		SelectionCuboid:remove(player, 0)
	end
end

addChatCommand('unsel', unsel)

addChatCommand('sel', function(player)
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

addChatCommand('mkportal', function(player, pname, wname)
	local p1, p2 = player.cuboidP1, player.cuboidP2
	if p1 and p2 then
		local cworld = getWorld(player)
		if getWorld(wname)then
			cworld.data.portals = cworld.data.portals or{}
			local x1, y1, z1, x2, y2, z2 = makeNormalCube(p1[1], p1[2], p1[3], unpack(p2))
			cworld.data.portals[pname]={
				tpTo = wname,
				pt1 = {x1, y1, z1},
				pt2 = {x2, y2, z2}
			}
			return CMD_CRPORTAL
		else
			return WORLD_NE
		end
	else
		return CMD_SELCUBOID
	end
end)

addChatCommand('setspawn', function(player)
	local world = getWorld(player)
	local x, y, z = player:getPos()
	local ay, ap = player:getEyePos()
	world:setSpawn(x, y, z, ay, ap)
	return CMD_SPAWNSET
end)

addChatCommand('set', function(player, id)
	local world = getWorld(player)
	if world:isReadOnly()then
		return WORLD_RO
	end
	id = tonumber(id)
	if id then
		id = math.max(0, math.min(255, id))
		local p1, p2 = player.cuboidP1, player.cuboidP2
		if p1 and p2 then
			world:fillBlocks(
				p1[1], p1[2], p1[3],
				p2[1], p2[2], p2[3],
				tonumber(id)
			)
			return MESG_DONE
		else
			return CMD_SELCUBOID
		end
	else
		return CMD_BLOCKID
	end
end)

addChatCommand('delportal', function(player, pname)
	if not pname then return 'Invalid portal name'end
	local world = getWorld(player).data
	if world.portals then
		if world.portals[pname]then
			world.portals[pname] = nil
			return CMD_RMPORTAL
		end
	end
	return CMD_NEPORTAL
end)

addChatCommand('tp', function(player, name, to)
	if name then
		ply = getPlayerByName(name)
		if not ply then
			return (MESG_PLAYERNFA):format(name)
		end
		if to then
			to = getPlayerByName(to)
			if to then
				if not ply:isInWorld(to)then
					ply:changeWorld(to.worldName, true, to:getPos())
				else
					ply:teleportTo(to:getPos())
				end
			else
				return (MESG_PLAYERNFA):format(to)
			end
		else
			if not player:isInWorld(ply)then
				player:changeWorld(ply.worldName, true, ply:getPos())
			end
			player:teleportTo(ply:getPos())
		end
		return CMD_TPDONE
	else
		return MESG_NAMENS
	end
end)

addChatCommand('spawn', function(player)
	player:moveToSpawn()
end)

addChatCommand('list', function(player)
	player:sendMessage(CMD_WORLDLST)
	for wn, world in pairs(worlds)do
		if wn ~= 'default'then
			local dfld = (worlds['default'] == world and' (default)')or''
			player:sendMessage('   - ' .. wn .. dfld)
		end
	end
end)

addChatCommand('regen', function(player, gen, seed)
	local world = getWorld(player.worldName)
	gen = tonumber(gen)or gen

	if type(gen) ~= 'number'then
		gen = gen or'default'
		seed = tonumber(seed)or os.time()
	else
		seed = gen
		gen = 'default'
	end

	player:sendMessage(CMD_GENSTART)
	local ret, tm = regenerateWorld(world, gen, seed)
	if not ret then
		return (CMD_GENERR):format(tm)
	else
		return (MESG_DONEIN):format(tm * 1000)
	end
end)

--[[
	Console commands
]]

addConsoleCommand('stop', function()
	_STOP = true
	return true
end)

addConsoleCommand('restart', function()
	_STOP = 'restart'
	return true
end)

addConsoleCommand('loadworld', function(args)
	if #args == 1 then
		local succ, err = loadWorld(args[1])
		if not succ then
			return true, err
		end
		return true
	end
end)

addConsoleCommand('unloadworld', function(args)
	if #args == 1 then
		local succ, err = unloadWorld(args[1])
		if not succ then
			return true, err
		end
		return true
	end
end)

addConsoleCommand('list', function()
	log.info(CMD_WORLDLST)
	for wn, world in pairs(worlds)do
		if wn ~= 'default'then
			local dfld = (worlds['default'] == world and' (default)')or''
			print('   - ' .. wn .. dfld)
		end
	end
	return true
end)

addConsoleCommand('say', function(args, argstr)
	if #args > 0 then
		newChatMessage(argstr)
		return true
	end
end)

addConsoleCommand('addperm', function(args)
	if #args == 2 then
		permissions:addFor(args[1], args[2])
		return true
	end
end)

addConsoleCommand('delperm', function(args)
	if #args == 2 then
		permissions:addFor(args[1], args[2])
		return true
	end
end)

addConsoleCommand('put', function(args)
	if #args == 2 then
		local player = getPlayerByName(args[1])
		if player then
			player:changeWorld(args[2])
			return true
		else
			return MESG_PLAYERNF
		end
	end
end)

addConsoleCommand('kick', function(args)
	if #args > 0 then
		local p = getPlayerByName(args[1])
		local reason = KICK_NOREASON
		if p then
			if #args > 1 then
				reason = table.concat(args, ' ', 2)
			end
			p:kick(reason)
			return true
		else
			return MESG_PLAYERNF
		end
	end
end)

addConsoleCommand('regen', function(args)
	if #args >= 1 then
		local world = getWorld(args[1])
		local gen = args[2]or'default'
		local seed = tonumber(args[3]or os.time())
		local ret, tm = regenerateWorld(world, gen, seed)
		if not ret then
			return true, (CMD_GENERR):format(tm)
		else
			return true, (MESG_DONEIN):format(tm * 1000)
		end
	end
end)

addConsoleCommand('tp', function(args)
	if #args == 2 then
		local pn1 = args[1]
		local pn2 = args[2]
		local p1 = getPlayerByName(pn1)
		local p2 = getPlayerByName(pn2)
		if not p1 then
			return true, (MESG_PLAYERNFA):format(pn1)
		end
		if not p2 then
			return true, (MESG_PLAYERNFA):format(pn2)
		end
		local wp2 = getWorld(p2)
		if getWorld(p1) ~= wp2 then
			p1:changeWorld(wp2, false, p2:getPos())
		else
			p1:teleportTo(p2:getPos())
		end
	end
end)

addConsoleCommand('help', function()
	for k, v in pairs(_G)do
		if k:startsWith('CU_')then
			print(v)
		end
	end
	return true
end)

addAlias(false, 'help', '?')
