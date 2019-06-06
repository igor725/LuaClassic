local function getKickTimeout()
	return config:get('player-timeout')
end

local function sendMap(fd, mapaddr, maplen, cmplvl, isWS)
	set_debug_threadname('MapSender')

	ffi = require('ffi')
	require('socket')
	require('gzip')

	if isWS then
		require('helper')
	end

	local map = ffi.cast('char*', mapaddr)
	local gErr = nil

	if isWS then
		mapStart = encodeWsFrame('\2', 0x02)
	else
		mapStart = '\2'
	end

	sendMesg(fd, mapStart)
	local succ, gErr = gz.compress(map, maplen, cmplvl, function(out, stream)
		local chunksz = 1024 - stream.avail_out
		local gzchunk = ffi.string(out, 1024)
		local b1 = math.floor(chunksz / 256)
		local b2 = chunksz % 256
		local dat = string.char(0x03, b1, b2) .. gzchunk .. '\100'
		if isWS then
			dat = encodeWsFrame(dat, 0x02)
		end

		local _, err = sendMesg(fd, dat, #dat)
		if err == 'closed'then
			gz.defEnd(stream)
			gErr = err
		elseif err ~= nil then
			gz.defEnd(stream)
			gErr = err
		end
	end)

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

local savers = {
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
	['name'] = strdata,
	['ip'] = strdata
}

local readers = {
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
			if getWorld(wname) == nil then
				player.worldName = 'default'
			else
				player.worldName = wname
			end
		end
	},
	['lastOnlineTime'] = {
		format = '>f'
	},
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
	getFluidLevel = function(self)
		local world = getWorld(self)
		local x, y, z = self:getPos()
		x, y, z = floor(x), floor(y), floor(z)
		if self:getModelHeight() > 1 then
			local upblock = world:getBlock(x, y, z)
			if upblock >= 8 and upblock <= 11 then
				return 2, upblock == 10 or upblock == 11
			else
				local downblock = world:getBlock(x, y - 1, z)
				if downblock >= 8 and downblock <= 11 then
					return 1, downblock == 10 or downblock == 11
				end
			end
		else
			local downblock = world:getBlock(x, y - 1, z)
			if downblock >= 8 and downblock <= 11 then
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
	setUID = function(self, uid)
		self.uidhex = toHex(sha1(uid))
		self.uid = uid
	end,
	setPos = function(self, x, y, z)
		local pos = self.pos
		local lp = self.lpos
		if not self.isSpawned then
			pos.x, pos.y, pos.z = x, y, z
			lp.x, lp.y, lp.z = x, y, z
			return
		end
		local lx, ly, lz = pos.x, pos.y, pos.z

		if lx ~= x or ly ~= y or z ~= z then
			pos.x, pos.y, pos.z = x, y, z
			if self.isSpawned then
				local dx, dy, dz = lp.x - x, lp.y - y, lp.z - z
				hooks:call('onPlayerMove', self, dx, dy, dz)
				if onPlayerMove then
					onPlayerMove(self, dx, dy, dz)
				end
				self.lposc = self.lposc + 1
				if self.lposc > 2 then
					lp.x, lp.y, lp.z = x, y, z
					self.lposc = 1
				end
				checkForPortal(self, x, y, z)
			end
			return true
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

	checkPermission = function(self, nm)
		local sect = nm:match('(.*)%.')
		local perms = permissions:getFor(self:getUID())
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
		local lp = self.lpos
		lp.x, lp.y, lp.z = x / 32, y / 32, z / 32
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
			self:setEyePos(ay or say, ap or sap)
			self:setPos(x or sx, y or sy, z or sz)
			return true
		end
		return false, 0
	end,

	readWsFrame = function(self)
		if not self:isWebClient()then return false end
		local cl = self:getClient()
		if not self.wsHint then
			local hdr = receiveString(cl, 2)
			if not hdr then return end
			local fin, masked, opcode, hint = readWsHeader(hdr:byte(1, 2))
			if not fin or not masked then
				closeSock(cl)
				return
			end
			self.wsHint = hint
			self.wsOpcode = opcode
		elseif not self.wsPacketLen then
			local hint = self.wsHint
			local plen
			if hint > 125 then
				if hint == 126 then
					local data = receiveString(cl, 2)
					if data then
						plen = struct.unpack('>H', data)
					end
				else
					closeSock(cl)
					return
				end
			else
				plen = hint
			end
			self.wsPacketLen = plen
		elseif not self.wsMask then
			self.wsMask = receiveString(cl, 4)
		else
			local data = receiveString(cl, self.wsPacketLen)
			if data then
				data = unmaskData(data, self.wsMask, #data)
				self.wsHint, self.wsMask, self.wsPacketLen = nil
				return data, self.wsOpcode
			end
		end
	end,
	readWsData = function(self)
		if not self:isWebClient()then return end
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
		if self:isWebClient()then return end
		local cl = self:getClient()
		local id = self.waitPacket
		if not id then
			local pId = receiveString(cl, 1)
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
			if not sz then
				self:kick(KICK_INVALIDPACKET)
				return
			end
			local data = receiveString(cl, sz)
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
		if self:isWebClient()then
			msg = encodeWsFrame(msg, opcode or 0x02)
		end
		return sendMesg(cl, msg, #msg)
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
		local world = getWorld(self)
		if not world.ldata then
			self:sendMessage(MESG_LEVELLOAD, MT_STATUS1)
			world:triggerLoad()
			self:sendMessage('', MT_STATUS1)
		end
		local addr = world:getAddr()
		local size = world:getSize()
		local sendMap_gen = lanes.gen('*', sendMap)
		local cmplvl = config:get('gzip-compression-level')
		self.thread = sendMap_gen(self:getClient(), addr, size, cmplvl, self:isWebClient())
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
				lastcolor = mpart:match('.*(&%x)')or lastcolor or''
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

		cpe:extCallHook('postPlayerSpawn', self)
		hooks:call('postPlayerSpawn', self)
		if self.firstSpawn then
			hooks:call('postPlayerFirstSpawn', self)
			self.firstSpawn = false
		end
		local world = getWorld(self)
		world.players = world.players + 1
		world.emptyfrom = nil
		self.isSpawned = true
		local lp = self.lpos
		lp.x, lp.y, lp.z = x / 32, y / 32, z /32
		if postPlayerSpawn then
			postPlayerSpawn(self)
		end
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
			cpe:extCallHook('onPlayerDestroy', self)
			hooks:call('onPlayerDestroy', self)
			if onPlayerDestroy then
				onPlayerDestroy(self)
			end
		end
		-- Causes incorrect kick-packet sending
		-- closeSock(self:getClient())
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
		local status = checkSock(self:getClient())
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
					getWorld(self).unloadLocked = false
				end
			elseif self.thread.status == 'running' then --TODO: Improve this
				getWorld(self).unloadLocked = true
			end
			return
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
		local f, err, ec = io.open(path, 'rb')
		if not f then
			if ec ~= 2 then
				log.error((SD_RDIOERR):format(path, err))
			end
			return false
		end
		local fend = f:seek('end')
		f:seek('set', 0)

		if f:read(6) ~= 'pdata\1'then
			log.warn((SD_HDRERR):format(self))
			return false
		end

		while f:seek('cur') ~= fend do
			local key = readString(f)
			local len = unpackFrom(f, '>H')
			local reader = readers[key]

			if reader then
				if reader.format == 'string'then
					if reader.func then
						reader.func(self, readString(f))
					else
						self[key] = readString(f)
					end
				else
					if reader.func then
						reader.func(self, unpackFrom(f, reader.format))
					else
						self[key] = unpackFrom(f, reader.format)
					end
				end
			else
				log.warn('No reader for', key)
				local sd = self.skippedData or{}
				sd[key] = f:read(len)
				self.skippedData = sd
			end
		end

		f:close()
		return true
	end,
	saveWrite = function(self)
		local path = self:savePath()
		local f, err = io.open(path, 'wb')
		if not f then
			log.error((SD_WRIOERR):format(path, err))
			return false
		end

		f:write('pdata\1')
		for k, v in pairs(self)do
			local saver = savers[k]
			if saver then
				local format = saver.format
				writeString(f, k)
				if format == 'string'then
					packTo(f, '>H', #v + 1)
					writeString(f, v)
				else
					packTo(f, '>H', struct.size(format))
					if saver.func then
						packTo(f, format, saver.func(v))
					else
						packTo(f, format, v)
					end
				end
			end
		end

		if self.skippedData then
			for key, data in pairs(self.skippedData)do
				writeString(f, key)
				packTo(f, '>H', #data)
				f:write(data)
			end
		end

		f:close()
		return true
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

function saveAdd(key, fmt, rd, sv)
	if type(key) ~= 'string'then return false end
	if type(fmt) ~= 'string'then return false end
	readers[key] = {
		format = fmt,
		func = rd
	}
	savers[key] = {
		format = fmt,
		func = sv
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
	local dworld = getWorld('default')
	local sx, sy, sz, syaw, spitch = dworld:getSpawnPoint()
	local pos = newVector(sx, sy, sz)
	local eye = newAngle(syaw, spitch)
	local lpos = newVector(sx, sy, sz)

	return setmetatable({
		kickTimeout = CTIME + getKickTimeout(),
		connectTime = CTIME,
		worldName = 'default',
		lpos = lpos,
		lposc = 1,
		pos = pos,
		isSpawned = false,
		firstSpawn = true,
		waitingExts = -1,
		eye = eye,
		extensions = {},
		client = cl
	}, player_mt)
end
