local function getKickTimeout()
	return config:get('player-timeout')
end

local function sendMap(fd, mapaddr, maplen, cmplvl, isWS)
	set_debug_threadname('MapSender')

	do
		local path = package.searchpath('socket.core', package.cpath)
		if path then
			local lib = package.loadlib(path, 'luaopen_socket_core')
			if not lib then
				lib = package.loadlib(path, 'luaopen_lanes_core')
			end
			if lib then
				socket = lib()
			end
		end
		if not socket then
			error('Can\'t load socket library')
		end
	end

	struct = require('struct')
	ffi = require('ffi')
	require('gzip')

	if isWS then
		require('helper')
	end

	local newTCP = socket.tcp4 or socket.tcp
	local fmt = '>Bhc1024b'
	local cl = newTCP(fd)
	local map = ffi.cast('char*', mapaddr)
	local gErr = nil

	if isWS then
		mapStart = encodeWsFrame('\2', 0x02)
	else
		mapStart = '\2'
	end

	cl:send(mapStart)
	local succ, gErr = gz.compress(map, maplen, cmplvl, function(out, stream)
		local chunksz = 1024 - stream.avail_out
		local cdat = ffi.string(out, 1024)
		local dat = struct.pack(fmt, 3, chunksz, cdat, 100)
		if isWS then
			dat = encodeWsFrame(dat, 0x02)
		end

		local _, err = cl:send(dat)
		if err == 'closed'then
			gz.defEnd(stream)
			gErr = err
		elseif err ~= nil then
			gz.defEnd(stream)
			gErr = err
		end
	end)

	cl:setfd(-1)
	return gErr or 0
end

local player_mt = {
	__tostring = function(self)
		return self:getName()
	end,

	init = function(self, id)
		self.handshaked = false
		self.handshakeStage2 = false
		self:setID(id)
	end,

	getID = function(self)
		return self.id or -1
	end,
	getVeriKey = function(self)
		return self.verikey
	end,
	getPos = function(self, forNet)
		if forNet then
			return self.pos.x * 32, self.pos.y* 32 - 22, self.pos.z * 32
		else
			return self.pos.x, self.pos.y, self.pos.z
		end
	end,
	getEyePos = function(self, forNet)
		local eye = self.eye
		if forNet then
			return floor((eye.yaw / 360) * 255), floor((eye.pitch / 360) * 255)
		else
			return eye.yaw, eye.pitch
		end
	end,
	getOnlineTime = function(self)
		return floor(self.lastOnlineTime + (CTIME - self.connectTime))
	end,
	getWorld = function(self)
		return getWorld(self.worldName)
	end,
	getWorldName = function(self)
		return self.worldName
	end,
	getLeaveReason = function(self)
		return self.leavereason
	end,
	getName = function(self)
		return self.name or'Unnamed'
	end,
	getAppName = function(self)
		return self.appName or'vanilla'
	end,
	getClient = function(self)
		return self.client
	end,
	getClientFd = function(self)
		return self.client:getfd()
	end,

	setID = function(self,id)
		if id > 0 then
			self.id = id
			IDS[id] = self
			players[self] = id
			return true
		else
			return false
		end
	end,
	setVeriKey = function(self, key)
		self.verikey = key
	end,
	setPos = function(self, x, y, z)
		if not self.isSpawned then return false end
		local pos = self.pos
		local lx, ly, lz = pos.x, pos.y, pos.z
		if lx ~= x or ly ~= y or z ~= z then
			pos.x = x
			pos.y = y
			pos.z = z
			onPlayerMove(self, lx - x, ly - y, lz - z)
			return true
		end
	end,
	setEyePos = function(self,y,p)
		if not self.isSpawned then return false end
		local eye = self.eye
		local ly, lp = eye.yaw, eye.pitch
		if ly ~= y or lp ~= p then
			eye.yaw = y
			eye.pitch = p
			onPlayerRotate(self, y, p)
			return true
		end
	end,
	setName = function(self,name)
		local canUse = true
		playersForEach(function(p)
			if p:getName():lower() == name:lower()then
				canUse = false
			end
		end)
		if canUse then
			self.name = name
			return true
		else
			return false
		end
	end,

	checkForWsHandshake = function(self)
		if not self.isWS then return false end
		local data = self:readWsFrame()
		if data then
			if #data ~= 131 then
				self:kick(KICK_PACKETSIZE)
				return false
			end
			return self:readHandShakeData(data)
		end
		return false
	end,
	checkForRawHandshake = function(self)
		if self.isWS then return false end
		local cl = self:getClient()
		local msg = cl:receive(131)
		if msg then
			return self:readHandShakeData(msg)
		end
		return false
	end,
	checkPermission = function(self, nm)
		local sect = nm:match('(.*)%.')
		local perms = permissions:getFor(self.verikey)
		if table.hasValue(perms, '*.*', sect .. '.*', nm)then
			return true
		else
			self:sendMessage((MESG_PERMERROR):format(nm))
			return false
		end
	end,

	isWebClient = function(self)
		return self.isWS
	end,
	isHandshaked = function(self)
		return self.handshakeStage2 and self.handshaked
	end,
	isSupported = function(self, extName, extVer)
		extVer = extVer or 1
		extName = extName:lower()
		local ext = self.extensions[extName]
		return (ext and ext == extVer)or false
	end,
	isInWorld = function(self, wname)
		return worlds[self.worldName] == getWorld(wname)
	end,

	teleportTo = function(self, x, y, z, ay, ap)
		x = floor(x * 32)
		y = floor(y * 32)
		z = floor(z * 32)
		if not ay and not ap then
			ay, ap = self:getEyePos(true)
		else
			ay, ap = ay % 360, ap % 360
			ay = floor(ay / 360 * 255)
			ap = floor(ap / 360 * 255)
		end
		self:sendPacket(self:isSupported('ExtEntityPositions'), 0x08, -1, x, y, z, ay, ap)
	end,
	moveToSpawn = function(self)
		local world = getWorld(self)
		self:teleportTo(world:getSpawnPoint())
	end,
	changeWorld = function(self, wname, force, x, y, z, ay, ap)
		if not force and self:isInWorld(wname)then
			return false, 1
		end
		local world = getWorld(wname)
		if world then
			local sx, sy, sz, say, sap = world:getSpawnPoint()
			self:despawn()
			self.worldName = wname
			self.handshakeStage2 = true
			self.eye.yaw = ay or sap
			self.eye.pitch = ap or say
			self.pos.x = x or sx
			self.pos.y = y or sy
			self.pos.z = z or sz
			return true
		end
		return false, 0
	end,

	readHandShakeData = function(self, data)
		local fmt = packets[0x00]
		local pid, protover, uname, verikey, magicNumber = struct.unpack(fmt, data)
		if protover == 0x07 then
			local name = trimStr(uname)
			local key = trimStr(verikey)

			self:setVeriKey(key)
			if not self:setName(name)then
				self:kick(KICK_NAMETAKEN)
				return
			end
			if not sql:createPlayer(key)then
				self:kick((KICK_INTERR):format(IE_SQL))
				return
			end
			self.handshaked = true
			self.handshakeStage2 = true
			onPlayerHandshakeDone(self)
			local dat = sql:getData(key, 'spawnX, spawnY, spawnZ, spawnYaw, spawnPitch, lastWorld, onlineTime')
			sql:insertData(key, {'lastIP'}, {self.ip})

			self.lastOnlineTime = dat.onlineTime
			self.worldName = dat.lastWorld
			if not worlds[self.worldName]then
				self.worldName = 'default'
			end
			local cwd = worlds[self.worldName].data
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
			self.pos.x = sx
			self.pos.y = sy
			self.pos.z = sz
			self.eye.yaw = ay
			self.eye.pitch = ap

			if magicNumber == 0x42 then
				cpe:startFor(self)
				self.handshakeStage2 = false
			end
			return true
		else
			self:kick(KICK_PROTOVER)
		end
		return false
	end,
	readWsFrame = function(self)
		if not self.isWS then return false end
		local cl = self:getClient()
		if not self.wsHint then
			local hdr = cl:receive(2)
			if not hdr then return end
			local fin, masked, opcode, hint = readWsHeader(hdr:byte(1, 2))
			if not fin or not masked then
				cl:close()
				return
			end
			self.wsHint = hint
			self.wsOpcode = opcode
		elseif not self.wsPacketLen then
			local hint = self.wsHint
			local plen
			if hint > 125 then
				if hint == 126 then
					local data = cl:receive(2)
					if data then
						plen = struct.unpack('>H', data)
					end
				else
					cl:close()
					return
				end
			else
				plen = hint
			end
			self.wsPacketLen = plen
		elseif not self.wsMask then
			self.wsMask = cl:receive(4)
		else
			local data = cl:receive(self.wsPacketLen)
			if data then
				data = unmaskData(data, self.wsMask, #data)
				self.wsHint, self.wsMask, self.wsPacketLen = nil
				return data, self.wsOpcode
			end
		end
	end,
	readWsData = function(self)
		if not self.isWS then return end
		local data, opcode = self:readWsFrame()
		if data then
			if opcode == 0x02 or opcode == 0x01 then
				self.wsBuf = self.wsBuf or''
				self.wsBuf = self.wsBuf .. data
			end
		end
		if self.wsBuf and #self.wsBuf > 0 then
			local id = self.wsBuf:byte()
			local psz = psizes[id]
			if not psz or #self.wsBuf < psz then return end
			local cpesz = cpe.psizes[id]
			if cpesz then
				if self:isSupported(cpe.pexts[id])then
					psz = cpesz
					self.cpeRewrite = true
				end
			end
			local fmt
			if self.cpeRewrite then
				fmt = cpe.packets.cl[id]
				psz = cpe.psizes[id]
			else
				fmt = packets[id]
			end
			self.cpeRewrite = false
			self.kickTimeout = CTIME + getKickTimeout()
			pHandlers[id](self, struct.unpack(fmt, self.wsBuf:sub(2, psz + 1)))
			self.wsBuf = self.wsBuf:sub(psz + 2)
		end
	end,
	readRawData = function(self)
		if self.isWS then return end
		local cl = self:getClient()
		local id = self.waitPacket
		if not id then
			local pId = cl:receive(1)
			if pId then
				id = pId:byte()
				local psz = psizes[id]
				if cpe.inited then
					local cpesz = cpe.psizes[id]
					if cpesz then
						if self:isSupported(cpe.pexts[id])then
							psz = cpesz
							self.cpeRewrite = true
						end
					end
				end
				if psz then
					self.waitPacket = id
				else
					self:kick(KICK_INVALIDPACKET)
				end
			end
		end

		if id then
			local fmt, sz
			if self.cpeRewrite then
				fmt = cpe.packets.cl[id]
				sz = cpe.psizes[id]
			else
				fmt = packets[id]
				sz = psizes[id]
			end
			local data = cl:receive(sz)
			if data then
				self.waitPacket = nil
				self.cpeRewrite = false
				self.kickTimeout = CTIME + getKickTimeout()
				pHandlers[id](self, struct.unpack(fmt, data))
			end
		end
	end,

	sendNetMesg = function(self, msg, opcode)
		local cl = self:getClient()
		local s, err
		if self.isWS then
			s, err = cl:send(encodeWsFrame(msg, opcode or 0x02))
		else
			s, err = cl:send(msg)
		end
		return s ~= nil, err
	end,
	sendPacket = function(self, isCPE, ...)
		local rawPacket
		if isCPE then
			rawPacket = cpe:generatePacket(...)
		else
			rawPacket = generatePacket(...)
		end
		return self:sendNetMesg(rawPacket)
	end,
	sendMap = function(self)
		if not self.handshaked then return end
		local world = worlds[self.worldName]
		if not world.ldata then
			self:sendMessage(MESG_LEVELLOAD, MT_STATUS1)
			world:triggerLoad()
			self:sendMessage('', MT_STATUS1)
		end
		local addr = world:getAddr()
		local size = world:getSize()
		local sendMap_gen = lanes.gen('*', sendMap)
		local cmplvl = config:get('gzip-compression-level')
		self.thread = sendMap_gen(self:getClientFd(), addr, size, cmplvl, self.isWS)
	end,
	sendMOTD = function(self, sname, smotd)
		sname = sname or config:get('server-name')
		smotd = smotd or config:get('server-motd')
		self:sendPacket(
			false,
			0x00,
			0x07,
			sname,
			smotd,
			(self.isOP and 0x64)or 0x00
		)
	end,
	sendMessage = function(self, mesg, id)
		mesg = tostring(mesg)
		id = id or MT_CHAT

		local lastcolor = ''
		if not self:isSupported('FullCP437')then
			mesg = mesg:gsub('.',function(s)
				local bt = s:byte()
				if bt > 127 then
					return ('\\x%02X'):format(bt)
				end
			end)
		end

		local parts
		if id == 0 then
			parts = ceil(#mesg / 62)
		else
			parts = 1
		end
		if parts > 1 then
			for i = 1, parts do
				local mpart = mesg:sub(i * 62 - 61, i * 62)
				if i == parts then
					mpart = lastcolor .. mpart
				end
				self:sendPacket(false, 0x0d, id, lastcolor .. mpart)
				lastcolor = mpart:match('.*(&%x)')or''
			end
		else
			mesg = mesg
			self:sendPacket(false, 0x0d, id, mesg)
		end
	end,

	despawn = function(self)
		if not self.isSpawned then return false end
		self.isSpawned = false
		local sId = self:getID()
		playersForEach(function(ply)
			if ply:isInWorld(self)then
				ply:sendPacket(false, 0x0c, sId)
			end
		end)
		onPlayerDespawn(self)
		return true
	end,
	spawn = function(self)
		if self.isSpawned then return false end
		if not self.handshaked then return false end
		local pId = self:getID()
		local name = self:getName()
		local x, y, z = self:getPos(true)
		local ay, ap = self:getEyePos(true)
		local dat2, dat2cpe

		prePlayerSpawn(self)
		playersForEach(function(ply, id)
			local sId = (pId == id and -1)or id
			local cx, cy, cz = ply:getPos(true)
			local cay, cap = ply:getEyePos(true)
			local cname = ply:getName()

			local dat, datcpe
			if ply:isInWorld(self)then
				if self:isSupported('ExtEntityPositions')then
					datcpe = datcpe or cpe:generatePacket(0x07, sId, cname, cx, cy, cz, cay, cap)
					self:sendNetMesg(datcpe)
				else
					dat = dat or generatePacket(0x07, sId, cname, cx, cy, cz, cay, cap)
					self:sendNetMesg(dat)
				end

				if sId ~= -1 then
					if ply:isSupported('ExtEntityPositions')then
						dat2cpe = dat2cpe or cpe:generatePacket(0x07, pId, name, x, y, z, ay, ap)
						ply:sendNetMesg(dat2cpe)
					else
						dat2 = dat2 or generatePacket(0x07, pId, name, x, y, z, ay, ap)
						ply:sendNetMesg(dat2)
					end
				end
			end
		end)
		postPlayerSpawn(self)
		self.isSpawned = true
		return true
	end,
	destroy = function(self)
		if self.isSpawned then
			self:despawn()
		end
		local id = self:getID()
		players[self] = nil
		IDS[id] = nil
		self.leavereason = self.leavereason or'Disconnected'
		if self.handshaked then
			onPlayerDestroy(self)
		end
		self:getClient():close()
		self.handshaked = false
	end,
	kick = function(self, reason)
		reason = reason or KICK_NOREASON
		self:sendPacket(false, 0x0e, reason)
		self.leavereason = reason
		self.kicked = true
		self:destroy()
	end,

	serviceMessages = function(self)
		local _, status = self:getClient():receive(0)
		if status == 'closed'then
			self:destroy()
			return
		end

		if CTIME > self.kickTimeout then
			if self.isSpawned then
				self:kick(KICK_TIMEOUT)
				return
			end
		end

		if self.thread then
			if self.thread.status == 'error'then
				log.error(self.thread[-1])
				self.thread = nil
				self:kick(KICK_MAPTHREADERR)
				return
			elseif self.thread.status == 'done'then
				local mesg = self.thread[1]
				if mesg then
					if mesg == 0 then
						local dim = getWorld(self):getData('dimensions')
						self:sendPacket(false, 0x04, dim.x, dim.y, dim.z)
						self:spawn()
					else
						log.error('MAPSEND ERROR', mesg)
						self:kick((KICK_INTERR):format(IE_GZ))
					end
					self.thread = nil
					self.kickTimeout = CTIME + getKickTimeout()
					worlds[self.worldName].unloadLocked = false
				end
			elseif self.thread.status == 'running' then --TODO: Improve this
				worlds[self.worldName].unloadLocked = true
			end
			return
		end

		if not self.handshaked then
			if self.isWS then
				self.handshaked = self:checkForWsHandshake()
			else
				self.handshaked = self:checkForRawHandshake()
			end
			return
		else
			if self.handshakeStage2 then
				self:sendMOTD()self:sendMap()
				self.handshakeStage2 = false
				return
			end
		end

		if self.handshaked then
			if self.isWS then
				self:readWsData()
			else
				self:readRawData()
			end
		end
	end,
	isPlayer = true
}
player_mt.__index = player_mt

function playersForEach(func)
	for player, id in pairs(players)do
		local ret = func(player, id)
		if ret ~= nil then
			return ret
		end
	end
end

function getPlayerMT()
	return player_mt
end

function getPlayerByName(name)
	if not name then return end
	name = name:lower()
	return playersForEach(function(ply)
		if ply:getName():lower() == name then
			return ply
		end
	end)
end

function findPlayer(namepart)
	if not namepart then return end
	namepart = namepart:lower()
	return playersForEach(function(ply)
		if ply:getName():lower():find(namepart)then
			return ply
		end
	end)
end

function getPlayerByID(id)
	return IDS[id]
end

function findFreeID(player)
	local s = 1
	while IDS[s]do
		s = s + 1
		if s > 127 then
			return -1
		end
	end
	local mp = config:get('max-players')
	if s > mp then s = -1 end
	return s
end

function newChatMessage(msg, id)
	playersForEach(function(ply)
		ply:sendMessage(msg, id)
	end)
end

function newLocalChatMessage(world, msg, id)
	playersForEach(function(ply)
		if ply:isInWorld(world)then
			ply:sendMessage(msg, id)
		end
	end)
end

function broadcast(str, exid)
	playersForEach(function(player, id)
		if id ~= exid then
			player:sendNetMesg(str)
		end
	end)
end

function newPlayer(cl)
	return setmetatable({
		kickTimeout = CTIME + getKickTimeout(),
		connectTime = CTIME,
		pos = newVector(0, 0, 0),
		isSpawned = false,
		waitingExts = -1,
		eye = newAngle(0, 0),
		extensions = {},
		client = cl
	}, player_mt)
end
