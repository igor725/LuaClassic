commands = {}

function addChatCommand(name, func)
	commands[name] = func
end

addChatCommand('rc',function(player)
	local world = getWorld(player)
	return CMD_WMODE%((world:toggleReadOnly()and'&aro&f')or'&crw&f')
end)

addChatCommand('info',function(player)
	player:sendMessage(CMD_SVINFO1%{jit.os,jit.arch})
	player:sendMessage(CMD_SVINFO2%{collectgarbage('count')/1024})
end)

addChatCommand('clear',function(player)
	for i=1,45 do
		player:sendMessage('')
	end
end)

addChatCommand('stop',function()
	_STOP=true
end)

addChatCommand('time',function(player,name)
	local world = getWorld(player)
	if world.data.isNether then
		return CMD_TIMEDISALLOW
	end
	if name and time_presets[name]then
		for i=0,4 do
			local r, g, b = unpack(time_presets[name][i])
			EnvColors:set(world, i, r, g, b)
		end
		return CMD_TIMECHANGE%name
	end
end)

local function unsel(player)
	if player.onPlaceBlock then
		player.cuboidP1 = nil
		player.cuboidP2 = nil
		SelectionCuboid:remove(player, 0)
	end
end

addChatCommand('unsel',unsel)

addChatCommand('sel',function(player)
	if not player.onPlaceBlock then
		player.onPlaceBlock = function(x, y, z, id)
			if player.cuboidP1 then
				player.cuboidP2 = {x,y,z}
				local sx, sy, sz = unpack(player.cuboidP1)
				SelectionCuboid:create(player, 0, '', sx, sy, sz, x, y, z)
				return true
			end
			player.cuboidP1 = {x,y,z}
			return true
		end
	else
		unsel(player)
		player.onPlaceBlock = nil
		return CMD_SELMODEOFF
	end
	return CMD_SELMODEON
end)

addChatCommand('mkportal',function(player, pname, wname)
	local p1, p2 = player.cuboidP1, player.cuboidP2
	if p1 and p2 then
		local cworld = getWorld(player.worldName)
		if getWorld(wname)then
			cworld.data.portals = cworld.data.portals or{}
			local x1, y1, z1, x2, y2, z2 = makeNormalCube(p1[1],p1[2],p1[3],unpack(p2))
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

addChatCommand('setspawn',function(player)
	local world = getWorld(player)
	local x, y, z = player:getPos()
	local ay, ap = player:getEyePos()
	local wd = world.data
	local sp = wd.spawnpoint
	local eye = wd.spawnpointeye
	sp[1] = x sp[2] = y sp[3] = z
	eye[1] = ay eye[2] = ap
	return CMD_SPAWNSET
end)

addChatCommand('set', function(player, id)
	local world = getWorld(player)
	if world:isInReadOnly()then
		return WORLD_RO
	end
	id = tonumber(id)
	if id then
		id = math.max(0, math.min(255, id))
		local p1, p2 = player.cuboidP1, player.cuboidP2
		if p1 and p2 then
			world:fillBlocks(
				p1[1],p1[2],p1[3],
				p2[1],p2[2],p2[3],
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

addChatCommand('delportal',function(player, pname)
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

addChatCommand('tp',function(player, name, to)
	if name then
		ply = getPlayerByName(name)
		if not ply then
			return MESG_PLAYERNFA%name
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
				return MESG_PLAYERNFA%to
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

addChatCommand('spawn',function(player)
	player:moveToSpawn()
end)

addChatCommand('list',function(player)
	player:sendMessage(CMD_WORLDLST)
	for wn, world in pairs(worlds)do
		if wn~='default'then
			local dfld = (worlds['default']==world and' (default)')or''
			player:sendMessage('   - '+wn+dfld)
		end
	end
end)

addChatCommand('regen',function(player, gen, seed)
	local world = getWorld(player.worldName)
	gen = tonumber(gen)or gen

	if type(gen)~='number'then
		gen = gen or'default'
		seed = tonumber(seed)or os.time()
	else
		seed = gen
		gen = 'default'
	end

	player:sendMessage(CMD_GENSTART)
	local ret, tm = regenerateWorld(world, gen, seed)
	if not ret then
		return CMD_GENERR%tostring(tm)
	else
		return MESG_DONEIN%(tm*1000)
	end
end)
