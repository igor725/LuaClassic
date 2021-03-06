--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local function sendMap(cfd, cmplvl, mapaddr, maplen, isWeb, fmSupport)
	set_debug_threadname('MapSender')

	ffi = require('ffi')
	require('data.zlib')
	require('network.socket')

	if isWeb then
		require('network.websocket')
		wsLoad()
	end

	local map, levelInit, wbuf

	if fmSupport then
		maplen = maplen - 4
		map = ffi.cast('char*', mapaddr + 4)
		local len = ffi.string(ffi.new('int[1]', htonl(maplen)), 4)
		levelInit = '\2' .. len
	else
		levelInit = '\2'
		map = ffi.cast('char*', mapaddr)
	end

	if isWeb then
		sendMesg(cfd, encodeWsFrame(levelInit, #levelInit, 0x02))
	else
		sendMesg(cfd, levelInit, #levelInit)
	end

	local smap = ffi.new[[struct {
		uint8_t id;
		uint8_t chunklen[2];
		uint8_t chunkdata[1024];
		uint8_t complete;
	}]]

	local connClosed = false
	local u16cl = ffi.cast('uint16_t*', smap.chunklen)
	smap.complete = 100
	smap.id = 0x03

	local callback = function(stream)
		u16cl[0] = htons(1024 - stream.avail_out)

		local done

		if isWeb then
			wbuf = wbuf or ffi.new('char[1032]')
			done = sendMesg(cfd, encodeWsFrame(smap, 1028, 0x02, wbuf))
		else
			done = sendMesg(cfd, smap, 1028)
		end

		if not done then
			zlib.defEnd(stream)
			connClosed = true
		end
	end

	local succ, zErr
	if fmSupport then
		succ, zErr = zlib.deflate(map, maplen, -15, cmplvl, callback, smap.chunkdata)
	else
		succ, zErr = zlib.compress(map, maplen, cmplvl, callback, smap.chunkdata)
	end

	wbuf, smap = nil
	collectgarbage()

	return not connClosed and zErr or true
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
			return self.pos.x * 32, self.pos.y * 32, self.pos.z * 32
		else
			return self.pos.x, self.pos.y, self.pos.z
		end
	end,
	getX = function(self)
		return self.pos.x
	end,
	getY = function(self)
		return self.pos.y
	end,
	getZ = function(self)
		return self.pos.z
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
		return floor(self.lastOnlineTime + (ctime - self.connectTime))
	end,
	getWorld = function(self)
		return getWorld(self.worldName)
	end,
	getWorldName = function(self)
		return self.worldName
	end,
	getLeaveReason = function(self)
		if self.silentKick then return end
		return self.leaveReason
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
		x, y, z = floor(x), floor(y - .5), floor(z)
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
			ay = ceil(ay / 360 * 256)
			ap = ceil(ap / 360 * 256)
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
			self.firstSpawn = true
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

	handlePacket = function(self, data)
		local id = data[0]
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

		self.kickTimeout = ctime + config:get('playerTimeout')
		pHandlers[id](self, struct.unpack(fmt, ffi.string(data + 1, psz)))
		return true
	end,

	readWsData = function(self)
		local sframe = self._sframe
		local st, err = receiveFrame(sframe)

		if st == -1 then
			self._sockerr = err
			self:destroy()
		elseif st then
			if sframe.opcode == 0x2 then
				return self:handlePacket(sframe.payload)
			elseif sframe.opcode == 0x8 then
				self:destroy()
			else
				log.debug('Unhandled frame', sframe.opcode)
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
			local len, closed, err = recvSock(fd, self._buf, 1)

			if closed then
				self._sockerr = err
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
				self._waitPacket = id
				self._receivedData = 0
				self._remainingData = psz
			else
				self:kick(KICK_INVALIDPACKET)
			end
		end

		if self._waitPacket then
			local dlen, closed, err = recvSock(fd, self._buf + self._receivedData + 1, self._remainingData)

			if closed then
				self._sockerr = err
				self:destroy()
				return
			end

			self._remainingData = self._remainingData - dlen
			self._receivedData = self._receivedData + dlen

			if self._remainingData == 0 then
				self._waitPacket = nil
				self._receivedData = nil
				self._remainingData = nil
				return self:handlePacket(self._buf)
			end
		end
	end,

	sendNetMesg = function(self, msg, len)
		if not msg then return end
		if not self.canSend then return end

		if self:isWebClient()then
			msg, len = encodeWsFrame(msg, len, 0x02)
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
			self:sendMessage(MESG_LEVELLOAD)
			world:triggerLoad()
		end

		local cfd = self:getClient()
		local mapaddr = world:getAddr()
		local maplen = world:getSize()
		local isWeb = self:isWebClient()
		local fmSupport = self:isSupported('FastMap')
		local cmplvl = config:get('gzipCompressionLevel')

		local sendMap_gen = lanes.gen('*', sendMap)
		self.thread = sendMap_gen(cfd, cmplvl, mapaddr, maplen, isWeb, fmSupport)
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
			0x00
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
		y = y + 22 -- wtf?
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
		world:triggerLoad()
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

		if self._sockerr then
			log.debug('Socket error:', self._sockerr)
		end

		if self.handshaked then
			self.lastOnlineTime = self:getOnlineTime()
			if onPlayerDisconnect then
				onPlayerDisconnect(self)
			end
		end

		entities[self:getID()] = nil
		cpe:extCallHook('onPlayerDestroy', self)
		hooks:call('onPlayerDestroy', self)
		if onPlayerDestroy then
			onPlayerDestroy(self)
		end
		if getCurrentOnline(self) == 0 then
			getWorld(self).emptyfrom = ctime
		end

		local cl = self:getClient()
		table.insert(waitClose, cl)
		shutdownSock(cl, SHUT_WR)
		log.debug(DBG_DESTROYPLAYER, self)
	end,
	kick = function(self, reason, silent)
		reason = reason or KICK_NOREASON
		self:sendPacket(false, 0x0e, reason)
		self.leaveReason = reason
		self.silentKick = silent
		self.kicked = true
		self:destroy()
	end,

	serviceMessages = function(self)
		if self.thread then
			local pworld = getWorld(self)
			if self.thread.status == 'error'then
				self:kick(KICK_MAPTHREADERR, true)
				log.error(self.thread[-1])
				self.thread = nil
			elseif self.thread.status == 'done'then
				local mesg = self.thread[1]
				self.canSend = true
				self.thread = nil

				if mesg == true then
					local dim = pworld:getData('dimensions')
					self:sendPacket(false, 0x04, dim.x, dim.y, dim.z)
					self.kickTimeout = ctime + config:get('playerTimeout')
					self:spawn()
				elseif mesg == false then
					self:destroy()
				else
					local err = zlib.getErrStr(mesg)
					log.error('MAPSEND ERROR', err)
					self:kick((IE_MSG):format(err), true)
				end
				pworld.unloadLocked = false
			elseif self.thread.status == 'running' then --TODO: Improve this
				pworld.unloadLocked = true
				return
			end
		end

		if self.kickTimeout and ctime - dt > self.kickTimeout then
			self:kick(KICK_TIMEOUT)
			return
		end

		if self.handshakeStage2 then
			self:sendMOTD()self:sendMap()
			self.handshakeStage2 = false
			return
		end

		if self:isWebClient()then
			while self:readWsData()do end
		else
			while self:readRawData()do end
		end
	end,

	savePath = function(self)
		if not self.uidhex then return false end
		return 'playerdata/' .. self.uidhex .. '.dat'
	end,
	saveRead = function(self)
		if self.isSpawned then return true end
		local pt = self:savePath()
		if not pt then return false end

		local file, err, ec = io.open(pt, 'rb')
		if not file then
			if ec ~= 2 then
				log.warn((SD_IOERR):format(pt, 'reading', err))
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
			os.rename(pt, pt .. '-corrupted')
			self._dontsave = true
			self:kick(KICK_PDATAERR, true)
			return false
		end

		self.skippedData = sd
		file:close()
		return true
	end,
	saveWrite = function(self)
		if self._dontsave then return end
		local pt = self:savePath()
		if not pt then return true end

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

function isPlayer(val)
	return type(val) == 'table'and val.isPlayer == true
end

function newPlayer(fd)
	local dworld = getWorld('default')
	local sx, sy, sz, syaw, spitch = dworld:getSpawnPoint()
	local pos = newVector(sx, sy, sz)
	local eye = newAngle(syaw, spitch)

	return setmetatable({
		connectTime = ctime,
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
