--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local function getKickTimeout()
	return config:get('playerTimeout')
end

local function sendMap(fd, mapaddr, maplen, cmplvl, isWS)
	set_debug_threadname('MapSender')

	ffi = require('ffi')
	require('socket')
	require('gzip')

	if isWS then
		struct = require('struct')
		require('websocket')
		wsLoad()
	end

	local map = ffi.cast('char*', mapaddr)
	local gErr = nil

	if isWS then
		mapStart = encodeWsFrame('\2', 1, 0x02)
	else
		mapStart = '\2'
	end

	local smap = ffi.new[[struct {
		uint8_t id;
		uint8_t chunklen[2];
		uint8_t chunkdata[1024];
		uint8_t complete;
	}]]
	local u16cl = ffi.cast('uint16_t*', smap.chunklen)
	smap.complete = 100
	smap.id = 0x03

	sendMesg(fd, mapStart, #mapStart)
	local succ, gErr = gz.compress(map, maplen, cmplvl, function(stream)
		u16cl[0] = htons(1024 - stream.avail_out)

		local err

		if isWS then
			local wframe = encodeWsFrame(ffi.string(smap, 1028), 1028, 0x02)
			err = select(2, sendMesg(fd, wframe, 1032))
		else
			err = select(2, sendMesg(fd, smap, 1028))
		end

		if err == 'closed'or err == 'nonsock'then
			gz.defEnd(stream)
		end
	end, smap.chunkdata)

	return gErr or 0
end

local function checkForPortal(player, x, y, z)
	local world = getWorld(player)
	local portals = world:getData('portals')
	if portals then
		for _, portal in pairs(portals)do
			y = floor(y)
			if (portal.pt1.x >= x and portal.pt2.x <= x)
			and(portal.pt1.y >= y and portal.pt2.y <= y)
			and(portal.pt1.z >= z and portal.pt2.z <= z)then
				player:changeWorld(portal.tpTo, true)
				break
			end
		end
	end
end

local strdata = {format = 'string'}

local pWriters = {
	['pos'] = {
		format = '>fff',
		func = function(v)
			return v.x, v.y, v.z
		end
	},
	['eye'] = {
		format = '>ff',
		func = function(v)
			return v.yaw, v.pitch
		end,
	},
	['worldName'] = strdata,
	['lastOnlineTime'] = {
		format = '>f'
	},
	['prefix'] = strdata,
	['name'] = strdata,
	['ip'] = strdata
}

local pReaders = {
	['pos'] = {
		format = '>fff',
		func = function(player, x, y, z)
			player:setPos(x, y, z)
		end
	},
	['eye'] = {
		format = '>ff',
		func = function(player, yaw, pitch)
			player:setEyePos(yaw, pitch)
		end
	},
	['worldName'] = {
		format = 'string',
		func = function(player, wname)
			if getWorld(wname) ~= nil then
				return wname
			end
			return 'default'
		end
	},
	['lastOnlineTime'] = {
		format = '>f'
	},
	['prefix'] = strdata,
	['ip'] = {
		format = 'string',
		func = function(player, ip)
			player.lastip = ip
		end
	},
	['name'] = {
		format = 'string',
		func = function(player, name)
			player.lastname = name
		end
	},
}

local player_mt = {
	__tostring = function(self)
		return self:getName()
	end,

	init = function(self, id)
		self.handshaked = false
		self.handshakeStage2 = false
		SERVER_ONLINE = (SERVER_ONLINE or 0) + 1
		self:setID(id)
	end,

	getID = function(self)
		return self.id or -1
	end,
	getUID = function(self)
		return self.uid
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
	getForward = function(self)
		local eye = self.eye
		local ry = math.rad(eye.yaw)
		local rp = math.rad(eye.pitch)
		local x = math.sin(ry) * math.cos(rp)
		local y = math.sin(-rp)
		local z = math.cos(ry + math.pi) * math.cos(rp)
		return x, y, z
	end,
	getFluidLevel = function(self)
		local world = getWorld(self)
		local x, y, z = self:getPos()
		x, y, z = floor(x), floor(y), floor(z)
		if self:getModelHeight() > 1 then
			local upblock = world:getBlock(x, y, z)
			if upblock and upblock >= 8 and upblock <= 11 then
				return 2, upblock == 10 or upblock == 11
			else
				local downblock = world:getBlock(x, y - 1, z)
				if downblock and downblock >= 8 and downblock <= 11 then
					return 1, downblock == 10 or downblock == 11
				end
			end
		else
			local downblock = world:getBlock(x, y - 1, z)
			if downblock and downblock >= 8 and downblock <= 11 then
				return 2, downblock == 10 or downblock == 11
			end
		end
		return 0
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
	getIP = function(self)
		return self.ip
	end,

	setID = function(self, id)
		if id >= 0 then
			self.id = id
			entities[id] = self
			return true
		else
			return false
		end
	end,
	setUID = function(self, uid)
		self.uidhex = sha1hex(uid)
		self.uid = uid
	end,
	setPos = function(self, x, y, z)
		local pos = self.pos
		if not self.isSpawned then
			pos.x, pos.y, pos.z = x, y, z
			return
		elseif self.isTeleported then
			self.isTeleported = false
			hooks:call('postPlayerTeleport', self)
			pos.x, pos.y, pos.z = x, y, z
			return
		elseif pos.x ~= x or pos.y ~= y or pos.z ~= z then
			local dx, dy, dz = x - pos.x, y - pos.y, z - pos.z
			pos.x, pos.y, pos.z = x, y, z

			hooks:call('onPlayerMove', self, dx, dy, dz)
			if onPlayerMove then
				onPlayerMove(self, dx, dy, dz)
			end
			checkForPortal(self, x, y, z)

			if self.oldDY < 0 then
				if dy >= 0 then
					hooks:call('onPlayerLanded', self, self.fallingStartY and math.max(0, self.fallingStartY - pos.y) or 0)
					self.fallingStartY = nil
				else
					if not self.fallingStartY or pos.y > self.fallingStartY then
						self.fallingStartY = pos.y
					end
				end
			end

			self.oldDY2 = self.oldDY
			self.oldDY = dy
			return true
		elseif self.oldDY < 0 then
			self.oldDY = 0

			hooks:call('onPlayerLanded', self, self.fallingStartY and math.max(0, self.fallingStartY - pos.y) or 0)
			self.fallingStartY = nil
			return
		end
	end,
	setEyePos = function(self, y, p)
		local eye = self.eye
		if not self.isSpawned then
			eye.yaw, eye.pitch = y, p
			return
		end
		local ly, lp = eye.yaw, eye.pitch
		if ly ~= y or lp ~= p then
			eye.yaw, eye.pitch = y, p
			if self.isSpawned then
				hooks:call('onPlayerRotate', self, y, p)
				if onPlayerRotate then
					onPlayerRotate(self, y, p)
				end
			end
			return true
		end
	end,
	setChatPrefix = function(self, prefix)
		self.prefix = prefix or''
	end,
	setName = function(self, name)
		local canUse = true
		playersForEach(function(p)
			if p:getName():lower() == name:lower()then
				canUse = false
			end
		end)
		if canUse then
			self.name = name
			if config:get('storePlayersIn_G')then
				if _G[name] == nil then
					_G[name] = self
				end
			end
			return true
		else
			return false
		end
	end,

	checkPermission = function(self, nm, silent)
		local sect = nm:match('(.*)%.')
		local perms = permissions:getFor(self:getUID())

		if (perms and table.hasValue(perms, '-*.*', '-' .. sect .. '.*', '-' .. nm))then
			if not silent then
				self:sendMessage((MESG_PERMERROR):format(nm))
			end
			return false
		end

		local a, b, c = '*.*', sect .. '.*', nm
		if (perms and table.hasValue(perms, a, b, c))or
		table.hasValue(permissions.list.default, a, b, c)then
			return true
		else
			if not silent then
				self:sendMessage((MESG_PERMERROR):format(nm))
			end
			return false
		end
	end,

	isWebClient = function(self)
		return self.isWS
	end,
	isHandshaked = function(self)
		return (not self.handshakeStage2) and self.handshaked
	end,
	isSupported = function(self, extName, extVer)
		extVer = extVer or 1
		extName = extName:lower()
		local ext = self.extensions[extName]
		return (ext and ext == extVer)or false
	end,
	isInWorld = function(self, wname)
		return getWorld(self) == getWorld(wname)
	end,

	teleportTo = function(self, x, y, z, ay, ap)
		self.isTeleported = true
		if isPlayer(x)then
			ay, ap = x:getEyePos()
			x, y, z = x:getPos()
		end
		local pos = self.pos
		pos.x, pos.y, pos.z = x, y, z
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
			self:despawn()
			self.oldDY = 0
			self.oldDY2 = 0
			self.fallingStartY = nil
			self.handshakeStage2 = true
			self.worldName = world:getName()
			if isPlayer(x)then
				self:setEyePos(x:getEyePos())
				self:setPos(x:getPos())
			else
				local sx, sy, sz, say, sap = world:getSpawnPoint()
				self:setEyePos(ay or say, ap or sap)
				self:setPos(x or sx, y or sy, z or sz)
			end
			return true
		end
		return false, 0
	end,

	handlePacket = function(self, id, data)
		local psz = psizes[id]
		local fmt = packets[id]

		local cpesz = cpe.psizes[id]
		if cpesz then
			if self:isSupported(cpe.pexts[id])then
				psz = cpesz
				fmt = cpe.packets.cl[id]
			end
		end

		if not psz then
			self:kick(KICK_INVALIDPACKET)
			return
		end
		self.kickTimeout = CTIME + getKickTimeout()
		pHandlers[id](self, struct.unpack(fmt, ffi.string(data, psz)))
	end,

	readWsData = function(self)
		local sframe = self._sframe

		if not self._sframe then
			local fd = self:getClient()
			sframe = ffi.new('struct ws_frame')
			setupWFrameStruct(sframe, fd)
			self._sframe = sframe
		end

		local st = receiveFrame(sframe)

		if st == -1 then
			self:destroy()
		elseif st then
			if sframe.opcode == 0x2 then
				local id = sframe.payload[0]
				self:handlePacket(id, sframe.payload + 1)
			elseif sframe.opcode == 0x8 then
				self:destroy()
			else
				log.warn('Unhandled frame', sframe.opcode, 'from', fd)
			end
		end
	end,
	readRawData = function(self)
		local fd = self:getClient()
		if not self._buf then
			self._buf = ffi.new('uint8_t[256]')
		end
		local id = self._waitPacket
		if not id then
			local len, closed = receiveMesg(fd, self._buf, 1)

			if closed then
				self:destroy()
				return
			end
			if len < 1 then return end

			id = self._buf[0]
			local psz = psizes[id]
			local cpesz = cpe.psizes[id]
			if cpesz then
				if self:isSupported(cpe.pexts[id])then
					psz = cpesz
				end
			end
			if psz then
				self._receivedData = 0
				self._remainingData = psz
				self._waitPacket = id
			end
		end

		if self._waitPacket then
			local dlen, closed = receiveMesg(fd, self._buf + self._receivedData + 1, self._remainingData)
			if closed then
				self:destroy()
				return
			end
			if not dlen then return end

			self._remainingData = self._remainingData - dlen

			if self._remainingData == 0 then
				self._waitPacket = nil
				self._remainingData = nil
				self._receivedData = nil
				self:handlePacket(id, self._buf + 1)
			else
				self._receivedData = self._receivedData + dlen
			end
		end
	end,

	sendNetMesg = function(self, msg, len)
		if not msg then return end
		if not self.canSend then return end

		if self:isWebClient()then
			msg = encodeWsFrame(msg, len, 0x02)
			len = #msg
		end
		msg = ffi.cast('char*', msg)
		return sendMesg(self:getClient(), msg, len)
	end,
	sendPacket = function(self, isCPE, ...)
		local rawPacket
		if isCPE then
			rawPacket = cpe:generatePacket(...)
		else
			rawPacket = generatePacket(...)
		end
		return self:sendNetMesg(rawPacket, #rawPacket)
	end,
	sendMap = function(self)
		if self.thread then return end
		if not self.handshaked then return end
		local world = getWorld(self)
		if not world then return end
		self.canSend = false
		if not world.ldata then
			self:sendMessage(MESG_LEVELLOAD, MT_STATUS1)
			world:triggerLoad()
			self:sendMessage('', MT_STATUS1)
		end
		local addr = world:getAddr()
		local size = world:getSize()
		local sendMap_gen = lanes.gen('*', sendMap)
		local cmplvl = config:get('gzipCompressionLevel')
		self.thread = sendMap_gen(self:getClient(), addr, size, cmplvl, self:isWebClient())
		log.debug(DBG_NEWTHREAD, self.thread)
	end,
	sendMOTD = function(self, sname, smotd)
		sname = sname or config:get('serverName')
		smotd = smotd or config:get('serverMotd')
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

		if mesg:find('[\r\n]')then
			for line in mesg:gmatch("[^\r\n]+") do
				if #line > 0 then
		    	self:sendMessage(line, id)
				end
			end
			return
		end

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
			parts = ceil(#mesg / 60)
		else
			parts = 1
		end
		if parts > 1 then
			for i = 1, parts do
				local mpart = mesg:sub(i * 60 - 59, i * 60)
				if i == parts then
					mpart = lastcolor .. mpart
				end
				self:sendPacket(false, 0x0D, id, ((i > 1 and '> ')or'') .. lastcolor .. mpart)
				lastcolor = mpart:match('.*(&%x)')or lastcolor or''
			end
		else
			self:sendPacket(false, 0x0D, id, mesg)
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
		cpe:extCallHook('postPlayerDespawn', self)
		hooks:call('onPlayerDespawn', self)
		local world = getWorld(self)
		world.players = world.players - 1
		if world.players == 0 then
			world.emptyfrom = CTIME
		end
		if onPlayerDespawn then
			onPlayerDespawn(self)
		end
		log.debug(DBG_DESPAWNPLAYER, self)
		return true
	end,
	spawn = function(self)
		if self.isSpawned then return false end
		if not self.handshaked then return false end

		if prePlayerSpawn and prePlayerSpawn(self)then
			return
		end
		if cpe:extCallHook('prePlayerSpawn', self)or
		hooks:call('prePlayerSpawn', self)then
			return
		end
		if self.firstSpawn then
			if hooks:call('prePlayerFirstSpawn', self)then
				return
			end
			if prePlayerFirstSpawn and prePlayerFirstSpawn(self)then
				return
			end
		end

		local pId = self:getID()
		local name = self:getName()
		local x, y, z = self:getPos(true)
		local ay, ap = self:getEyePos(true)
		local dat2, dat2cpe
		playersForEach(function(ply, id)
			local sId = (pId == id and -1)or id
			local cx, cy, cz = ply:getPos(true)
			local cay, cap = ply:getEyePos(true)
			local cname = ply:getName()

			local dat, datcpe
			if ply:isInWorld(self) and (ply.isSpawned or sId == -1)then
				if self:isSupported('ExtEntityPositions')then
					datcpe = datcpe or cpe:generatePacket(0x07, sId, cname, cx, cy, cz, cay, cap)
					self:sendNetMesg(datcpe, #datcpe)
				else
					dat = dat or generatePacket(0x07, sId, cname, cx, cy, cz, cay, cap)
					self:sendNetMesg(dat, #dat)
				end

				if sId ~= -1 then
					if ply:isSupported('ExtEntityPositions')then
						dat2cpe = dat2cpe or cpe:generatePacket(0x07, pId, name, x, y, z, ay, ap)
						ply:sendNetMesg(dat2cpe, #dat2cpe)
					else
						dat2 = dat2 or generatePacket(0x07, pId, name, x, y, z, ay, ap)
						ply:sendNetMesg(dat2, #dat2)
					end
				end
			end
		end)

		local world = getWorld(self)
		world.players = world.players + 1
		world.emptyfrom = nil
		self.isSpawned = true
		cpe:extCallHook('postPlayerSpawn', self)
		hooks:call('postPlayerSpawn', self)
		if postPlayerSpawn then
			postPlayerSpawn(self)
		end
		if self.firstSpawn then
			hooks:call('postPlayerFirstSpawn', self)
			self.firstSpawn = false
		end
		log.debug(DBG_SPAWNPLAYER, self)
		return true
	end,
	destroy = function(self)
		if self.isSpawned then
			self:despawn()
		end
		if config:get('storePlayersIn_G')then
			local name = self:getName()
			if _G[name] == self then
				_G[name] = nil
			end
		end
		entities[self:getID()] = nil
		SERVER_ONLINE = math.max((SERVER_ONLINE or 1) - 1, 0)

		if self.handshaked then
			self.lastOnlineTime = self:getOnlineTime()
			if onPlayerDisconnect then
				onPlayerDisconnect(self)
			end
		end

		cpe:extCallHook('onPlayerDestroy', self)
		hooks:call('onPlayerDestroy', self)
		if onPlayerDestroy then
			onPlayerDestroy(self)
		end

		local cl = self:getClient()
		table.insert(waitClose, cl)
		shutdownSock(cl, SHUT_WR)
		log.debug(DBG_DESTROYPLAYER, self)
	end,
	kick = function(self, reason, silent)
		reason = reason or KICK_NOREASON
		self:sendPacket(false, 0x0e, reason)
		self.leavereason = reason
		self.silentKick = silent
		self.kicked = true
		self:destroy()
	end,

	serviceMessages = function(self)
		if self.thread then
			local pworld = getWorld(self)
			if self.thread.status == 'error'then
				log.error(self.thread[-1])
				self.thread = nil
				self:kick(KICK_MAPTHREADERR, true)
				return
			elseif self.thread.status == 'done'then
				local mesg = self.thread[1]
				self.thread = nil

				if mesg then
					if mesg == 0 then
						self.canSend = true
						local dim = pworld:getData('dimensions')
						self:sendPacket(false, 0x04, dim.x, dim.y, dim.z)
						self:spawn()
					else
						log.error('MAPSEND ERROR', mesg)
						self:kick((IE_MSG):format(IE_GZ), true)
					end
					self.kickTimeout = CTIME + 60
					pworld.unloadLocked = false
				end
			elseif self.thread.status == 'running' then --TODO: Improve this
				pworld.unloadLocked = true
			end
			return
		end

		if CTIME > self.kickTimeout then
			if self.isSpawned then
				self:kick(KICK_TIMEOUT)
				return
			end
		end

		if self.handshakeStage2 then
			self:sendMOTD()self:sendMap()
			self.handshakeStage2 = false
			return
		end

		if self:isWebClient()then
			self:readWsData()
		else
			self:readRawData()
		end
	end,

	savePath = function(self)
		return 'playerdata/' .. self.uidhex .. '.dat'
	end,
	saveRead = function(self)
		if self.isSpawned then return true end
		local path = self:savePath()
		local file, err, ec = io.open(path, 'rb')
		if not file then
			if ec ~= 2 then
				log.warn((SD_IOERR):format(path, 'reading', err))
			end
			return false
		end
		local sd = {}
		local lsucc, succ, err = pcall(parseData, file, pReaders, 'pdata\2', self, sd)
		if not lsucc or not succ then
			local etext
			if err == PCK_INVALID_HEADER then
				etext = (SD_ERR):format(self, SD_HDRERR)
			elseif not lsucc then
				etext = (SD_ERR):format(self, tostring(succ))
			end
			file:close()
			log.error(etext)
			os.rename(path, path .. '-corrupted')
			self._dontsave = true
			self:kick(KICK_PDATAERR, true)
			return false
		end
		self.skippedData = sd
		file:close()
		return true
	end,
	saveWrite = function(self)
		local pt = self:savePath()
		local pt_tmp = pt .. '.tmp'
		local file, err = io.open(pt_tmp, 'wb')
		if not file then
			return false, (SD_IOERR):format(path, 'writing', err)
		end

		local lsucc, succ, werr = pcall(writeData, file, pWriters, 'pdata\2', self, self.skippedData)
		file:close()

		if not lsucc or not succ then
			os.remove(pt_tmp)
			return false, (not lsucc and succ)or werr
		end
		os.rename(pt_tmp, pt)
		return true
	end,
	isPlayer = true
}
player_mt.__index = player_mt

function playersForEach(func)
	for id = 0, config:get('maxPlayers')do
		local player = entities[id]
		if player then
			local ret = func(player, id)
			if ret ~= nil then
				return ret
			end
		end
	end
end

function getPlayerMT()
	return player_mt
end

function saveAdd(key, fmt, rd, wr, gn)
	if type(key) ~= 'string'then return false end
	if type(fmt) ~= 'string'then return false end

	pReaders[key] = {
		format = fmt,
		func = rd
	}

	pWriters[key] = {
		format = fmt,
		getn = gn,
		func = wr
	}

	return true
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

function findFreeID(player)
	local s = 0
	while entities[s]do
		s = s + 1
		if s > 127 then
			return -1
		end
	end
	if s > config:get('maxPlayers')then s = -1 end
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
			player:sendNetMesg(str, #str)
		end
	end)
end

function isPlayer(val)
	return type(val) == 'table'and val.isPlayer == true
end

function newPlayer(fd)
	local dworld = getWorld('default')
	local sx, sy, sz, syaw, spitch = dworld:getSpawnPoint()
	local pos = newVector(sx, sy, sz)
	local eye = newAngle(syaw, spitch)

	return setmetatable({
		kickTimeout = CTIME + getKickTimeout(),
		connectTime = CTIME,
		worldName = 'default',
		messageBuffer = '',
		prefix = '',
		pos = pos,
		lastOnlineTime = 0,
		isSpawned = false,
		oldDY = 0,
		oldDY2 = 0,
		fallingStartY = 0,
		firstSpawn = true,
		canSend = true,
		waitingExts = -1,
		eye = eye,
		extensions = {},
		client = fd,
		isTeleported = false
	}, player_mt)
end
