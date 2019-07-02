--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

commands = {}
aliases = {}

function addCommand(name, func)
	commands[name] = func
end

function addAlias(name, alias)
	if not aliases[alias]then
		aliases[alias] = name
		return true
	end
	return false
end

addCommand('rc', function(isConsole, player, args)
	if isConsole and #args < 1 then return false end

	local world = getWorld(args[1]or player)
	local rdState = ((world:toggleReadOnly()and ST_ON)or ST_OFF)
	return (CMD_WMODE):format(rdState, world)
end)

addCommand('info', function(isConsole, player)
	local info = (CMD_SVINFO):format(jit.os, jit.arch, jit.version, gcinfo() / 1024)
	if isConsole then
		print(info)
	else
		player:sendMessage(info)
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

addCommand('restart', function(isConsole, player, args)
	if timer.IsCreated('svrestart')then
		timer.Remove('svrestart')
		newChatMessage(CMD_CANCELRST)
		return
	end
	local time = tonumber(args[1])
	if time then
		newChatMessage((CMD_RSTTMR):format(time))
		timer.Create('svrestart', time, 1, function(repLeft)
			if repLeft == 0 then
				_STOP = 'restart'
			elseif repLeft <= 10 then
				newChatMessage((CMD_RSTTMR):format(repLeft))
			elseif repLeft % 30 == 0 then
				newChatMessage((CMD_RSTTMR):format(repLeft))
			end
		end)
	else
		_STOP = 'restart'
	end
end)

addCommand('players', function()
	local list = (CMD_PLISTHDR):format(getCurrentOnline())
	playersForEach(function(player)
		local webClient = (player:isWebClient()and ST_YES)or ST_NO
		list = list .. (CMD_PLISTROW):format(player, webClient)
	end)
	return list
end)

addCommand('goto', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end
	if #args < 1 then return false end

	local wname = args[1]:lower()
	local succ, msg = player:changeWorld(wname)
	if not succ then
		if msg == 0 then
			player:sendMessage(WORLD_NE)
		end
	end
end)

addCommand('uptime', function()
	local tm = gettime() - START_TIME
	return (CMD_UPTIME):format(toDHMS(tm))
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
				SelectionCuboid:create(player, 0, '', player.cuboidP1, player.cuboidP2)
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

addCommand('expand', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end
	if #args < 1 then return false end
	local dir, cnt
	local a1n = tonumber(args[1])
	if a1n then
		cnt = a1n
		dir = args[2]
	else
		cnt = tonumber(args[2])
		dir = args[1]
	end

	cnt = cnt or 1
	local p1 = player.cuboidP1
	local p2 = player.cuboidP2
	if not p1 or not p2 then
		return CMD_SELCUBOID
	end

	local dimx, dimy, dimz = getWorld(player):getDimensions()

	if dir == 'up'then
		if p1[2] > p2[2] then
			p1[2] = math.min(p1[2] + cnt, dimy - 1)
		else
			p2[2] = math.min(p2[2] + cnt, dimy - 1)
		end

	elseif dir == 'down'then
		if p1[2] < p2[2] then
			p1[2] = math.max(p1[2] - cnt, 0)
		else
			p2[2] = math.max(p2[2] - cnt, 0)
		end
	else
		-- 0 is X+, 1 is Z+, 2 is X-, 3 is Z-
		local dirPlayer = math.floor(((player.eye.yaw + 180 + 45 + 90) % 360) / 90)
		local dirOffset

		if dir == 'forward' or dir == 'front'then
			dirOffset = 0
		elseif dir == 'left'then
			dirOffset = 1
		elseif dir == 'backward' or dir == 'back'then
			dirOffset = 2
		elseif dir == 'right'then
			dirOffset = 3
		else
			return 'Invalid direction'
		end

		dirOffset = (dirPlayer - dirOffset + 4) % 4

		-- forward
		if dirOffset == 0 then
			if p1[1] > p2[1] then
				p1[1] = math.min(p1[1] + cnt, dimx - 1)
			else
				p2[1] = math.min(p2[1] + cnt, dimx - 1)
			end
			-- backward
		elseif dirOffset == 2 then
			if p1[1] < p2[1] then
				p1[1] = math.max(p1[1] - cnt, 0)
			else
				p2[1] = math.max(p2[1] - cnt, 0)
			end
			-- right
		elseif dirOffset == 1 then
			if p1[3] > p2[3] then
				p1[3] = math.min(p1[3] + cnt, dimz - 1)
			else
				p2[3] = math.min(p2[3] + cnt, dimz - 1)
			end
			-- left
		else --if dirOffset == 3 then
			if p1[3] < p2[3] then
				p1[3] = math.max(p1[3] - cnt, 0)
			else
				p2[3] = math.max(p2[3] - cnt, 0)
			end
		end
	end

	SelectionCuboid:create(player, 0, '', p1, p2)
end)

addCommand('mkportal', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end
	if #args < 1 then return false end

	local p1, p2 = player.cuboidP1, player.cuboidP2
	if p1 and p2 then
		local cworld = getWorld(player)
		local portalname = args[1]
		local worldname = args[2]or args[1]
		local portals = cworld.data.portals or{}
		cworld.data.portals = portals
		if portals[portalname]then
			return CMD_AEPORTAL
		end
		if getWorld(worldname)then
			local x1, y1, z1, x2, y2, z2 = makeNormalCube(p1, p2)
			portals[portalname] = {
				tpTo = worldname,
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
	id = tonumber(args[1])
	if id then
		local p1, p2 = player.cuboidP1, player.cuboidP2
		if p1 and p2 then
			if not world:fillBlocks(p1, p2, id)then
				return WORLD_RO
			end
		else
			return CMD_SELCUBOID
		end
	else
		return CMD_BLOCKID
	end
end)

addCommand('copy', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end
	local p1, p2 = player.cuboidP1, player.cuboidP2
	if not p1 or not p2 then return CMD_SELCUBOID end

	if player.cpybuf then
		player.cpybuf = nil
		collectgarbage()
	end

	local x1, y1, z1, x2, y2, z2 = makeNormalCube(p1, p2)
	local cdx, cdy, cdz = (x1 - x2) + 1, (y1 - y2) + 1, (z1 - z2) + 1
	local bsz = 6 + cdx * cdy * cdz
	local msz = parseSizeStr(config:get('maxSaveSize'))
	if bsz > msz then
		return 'Selected cuboid is too big'
	end
	local cbuf = ffi.new('uint8_t[?]', bsz)
	local sptr = ffi.cast('uint16_t*', cbuf)
	local pos = 6
	sptr[0] = cdx sptr[1] = cdy sptr[2] = cdz

	local world = getWorld(player)
	local dx, dy, dz = world:getDimensions()
	for y = y2, y1 do
		for z = z2, z1 do
			for x = x2, x1 do
				local offset = z * dx + y * (dx * dz) + x + 4
				cbuf[pos] = world.ldata[offset]
				pos = pos + 1
			end
		end
	end

	player.cpybuf = cbuf
	player.cpybufsz = bsz
	return 'Copied'
end)

addCommand('paste', function(isConsole, player)
	if isConsole then return CON_INGAMECMD end
	local cbuf = player.cpybuf
	if not cbuf then return 'No cpybuf'end

	local px, py, pz = player:getPos()
	px, py, pz = floor(px), floor(py), floor(pz)
	local d = ffi.cast('uint16_t*', cbuf)
	local cdx, cdy, cdz = d[0], d[1], d[2]
	local world = getWorld(player)

	BulkBlockUpdate:start(world)
	for y = 0, cdy - 1 do
		for z = 0, cdz - 1 do
			for x = 0, cdx - 1 do
				local coffset = z * cdx + y * (cdx * cdz) + x + 6
				local woffset = world:getOffset(px + x, py + y, pz + z)
				local id = cbuf[coffset]
				if woffset and world.ldata[woffset] ~= id then
					world.ldata[woffset] = id
					BulkBlockUpdate:write(woffset, id)
				end
			end
		end
	end
	BulkBlockUpdate:done()
end)

addCommand('save', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end
	if #args < 1 then return false end

	local path = 'saves/' .. args[1] .. '.dmp'
	if path:find('%.%.')then return false end

	local f = io.open(path, 'wb')
	C.fwrite(player.cpybuf, player.cpybufsz, 1, f)
	f:close()
	return 'Saved to: ' .. path
end)

addCommand('load', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end
	if #args < 1 then return false end

	local path = 'saves/' .. args[1] .. '.dmp'
	if path:find('%.%.')then return false end

	local f, err = io.open(path)
	if not f then
		return err
	end

	if player.cpybuf then
		player.cpybuf = nil
		collectgarbage()
	end

	local fsz = f:seek('end')
	f:seek('set', 0)
	local cbuf = ffi.new('uint8_t[?]', fsz)
	C.fread(cbuf, fsz, 1, f)
	player.cpybuf = cbuf
	player.cpybufsz = fsz

	return 'Loaded'
end)

addCommand('unload', function(isConsole, player)
	if isConsole then return CON_INGAMECMD end

	if player.cpybuf then
		player.cpybuf = nil
		collectgarbage()
		return 'Unloaded'
	end
	return 'No cpybuf'
end)

addCommand('replace', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end
	if #args < 2 then return false end
	local world = getWorld(player)

	local id1, id2 = args[1], args[2]
	local p1, p2 = player.cuboidP1, player.cuboidP2
	if p1 and p2 then
		if not world:replaceBlocks(
			p1, p2, tonumber(id1), tonumber(id2)
		)then
			return WORLD_RO
		end
	else
		return CMD_SELCUBOID
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
		if args[1] == 'default'then
			config.changed = true
		end
		permissions:addFor(args[1], args[2])
	else
		return false
	end
end)

addCommand('delperm', function(isConsole, player, args)
	if #args == 2 then
		if args[1] == 'default'then
			config.changed = true
		end
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
	local dworld = getWorld('default')
	worldsForEach(function(world, wn)
		if wn ~= 'default'then
			local dfld = (dworld == world and' (default)')or''
			local wstr = '   - ' .. wn .. dfld
			if isConsole then
				print(wstr)
			else
				player:sendMessage(wstr)
			end
		end
	end)
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
		ply1:changeWorld(ply2.worldName, true, ply2)
	else
		ply1:teleportTo(ply2)
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
addAlias('goto', 'g')
addAlias('list', 'worlds')
addAlias('sel', 'cuboid')
