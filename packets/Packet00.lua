return function(player, pver, name, vkey, magic)
	if pver == 0x07 then
		name = trimStr(name)
		vkey = trimStr(vkey)

		player:setVeriKey(vkey)
		if not player:setName(name)then
			player:kick(KICK_NAMETAKEN)
			return
		end
		if not sql:createPlayer(vkey)then
			player:kick((KICK_INTERR):format(IE_SQL))
			return
		end
		player.handshaked = true
		player.handshakeStage2 = true
		onPlayerHandshakeDone(player)
		local dat = sql:getData(vkey, 'spawnX, spawnY, spawnZ, spawnYaw, spawnPitch, lastWorld, onlineTime')
		sql:insertData(vkey, {'lastIP'}, {player:getIP()})

		player.lastOnlineTime = dat.onlineTime
		player.worldName = dat.lastWorld
		if not worlds[player.worldName]then
			player.worldName = 'default'
		end
		local cwd = worlds[player.worldName].data
		local eye = cwd.spawnpointeye
		local spawn = cwd.spawnpoint
		local sx, sy, sz, ay, ap
		if dat.spawnX == 0 and dat.spawnY == 0 and dat.spawnZ == 0 then
			sx, sy, sz = spawn.x, spawn.y, spawn.z
			ay, ap = eye.yaw, eye.pitch
		else
			sx, sy, sz = dat.spawnX, dat.spawnY, dat.spawnZ
			ay, ap = dat.spawnYaw, dat.spawnPitch
		end
		player:setPos(sx, sy, sz)
		player:setEyePos(ay, ap)

		if magic == 0x42 then
			cpe:startFor(player)
			player.handshakeStage2 = false
		end
		return true
	else
		player:kick(KICK_PROTOVER)
	end
end
