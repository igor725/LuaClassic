local function getKickTimeout()
	return config:get('player-timeout',10)
end

local function sendMap(fd,mapaddr,maplen,cmplvl,isWS)
	ffi = require('ffi')
	local ext = (jit.os=='Windows'and'dll')or'so'
	package.cpath = './bin/'..jit.arch..'/?.'..ext

	socket = require('socket.core')
	struct = require('struct')
	gz = require('gzip')
	if isWS then
		require('helper')
	end

	local fmt = '>Bhc1024b'
	local cl = socket.tcp4(fd)
	local map = ffi.cast('char*', mapaddr)
	local gErr = nil
	if isWS then
		mapStart = encodeWsFrame('\2', 0x02)
	else
		mapStart = '\2'
	end
	cl:send(mapStart)
	gz.compress(map, maplen, cmplvl, function(out,stream)
		local chunksz = 1024-stream.avail_out
		local cdat = ffi.string(out, 1024)
		local dat = struct.pack(fmt, 3, chunksz, cdat, 100)
		if isWS then
			dat = encodeWsFrame(dat, 0x02)
		end
		local _, err = cl:send(dat)

		if err=='closed'then
			gz.defEnd(stream)
			gErr = err
		elseif err~=nil then
			gz.defEnd(stream)
			gErr = err
		end
	end)
	cl:setfd(-1)
	return gErr or 0
end

local player_mt = {
	__tostring = function(self)
		return 'Player<'+self:getName()+'>'
	end,
	getID = function(self)
		return self.id or -1
	end,
	init = function(self)
		self.handshaked = false
		self.handshakeStage2 = false
	end,
	setID = function(self,id)
		self.id = id
	end,
	checkPermission = function(self,nm)
		local sect, perm = nm:match('(.*)%.(.*)')
		local perms = permissions:getFor(self.verikey)
		if table.hasValue(perms, '*.*', sect+'.*', nm)then
			return true
		else
			self:sendMessage(MESG_PERMERROR%nm)
			return false
		end
	end,
	getVeriKey = function(self)
		return self.verikey
	end,
	setVeriKey = function(self,key)
		self.verikey = key
		return true
	end,
	setPos = function(self,x,y,z)
		if not self.isSpawned then return end
		local pos = self.pos
		local lx, ly, lz = pos.x, pos.y, pos.z
		if lx~=x or ly~=y or z~=z then
			pos.x = x
			pos.y = y
			pos.z = z
			onPlayerMove(self, lx-x, ly-y, lz-z)
		end
	end,
	teleportTo = function(self,x,y,z,ay,ap)
		x = floor(x*32)
		y = floor(y*32)
		z = floor(z*32)
		if not ay and not ap then
			ay, ap = self:getEyePos(true)
		else
			ay = floor(ay/360*255)
			ap = floor(ap/360*255)
		end
		local cl = self:getClient()
		self:sendPacket(self:isSupported('ExtEntityPositions'), 0x08, -1, x, y, z, ay, ap)
	end,
	getPos = function(self,forNet)
		if forNet then
			return self.pos.x*32, self.pos.y*32-22, self.pos.z*32
		else
			return self.pos.x, self.pos.y, self.pos.z
		end
	end,
	setEyePos = function(self,y,p)
		if not self.isSpawned then return end
		local eye = self.eye
		local ly, lp = eye.y, eye.p
		if ly~=y or lp~=p then
			eye.y = y
			eye.p = p
			onPlayerRotate(self, y, p)
		end
	end,
	getEyePos = function(self,forNet)
		if forNet then
			return floor((self.eye.y/360)*255), floor((self.eye.p/360)*255)
		else
			return self.eye.y, self.eye.p
		end
	end,
	setName = function(self,name)
		local canUse = true
		playersForEach(function(p)
			if p:getName():lower()==name:lower()then
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
	sendMessage = function(self,mesg, id)
		mesg = tostring(mesg)
		local lastcolor = ''
		if not self:isSupported('FullCP437')then
			mesg = mesg:gsub('.',function(s)
				local bt = s:byte()
				if bt>127 then
					return '\\x%02X'%bt
				end
			end)
		end
		local cl = self:getClient()
		id = id or 0
		local parts
		if id == 0 then
			parts = ceil(#mesg/62)
		else
			parts = 1
		end
		if parts>1 then
			for i=1,parts do
				local mpart = mesg:sub(i*62-61,i*62)
				if i==parts then
					mpart = lastcolor..mpart
				end
				self:sendPacket(false, 0x0d, id, lastcolor..mpart)
				lastcolor = mpart:match('.*(&%x)')or''
			end
		else
			mesg = mesg
			self:sendPacket(false, 0x0d, id, mesg)
		end
	end,
	getName = function(self)
		return self.name or'Unnamed'
	end,
	moveToSpawn = function(self)
		local world = getWorld(self)
		local ld = world.data
		local sp = ld.spawnpoint
		local eye = ld.spawnpointeye
		self:setPos(unpack(sp))
		self:setEyePos(unpack(eye))
		self:teleportTo(
			sp[1],
			sp[2],
			sp[3],
			eye[1],
			eye[2]
		)
	end,
	readHandShakeData = function(self, data)
		local fmt = packets[0x00]
		local pid, protover, uname, verikey, hsFlag = struct.unpack(fmt, data)
		if protover == 0x07 then
			local name = trimStr(uname)
			local key = trimStr(verikey)

			self:setVeriKey(key)
			if not self:setName(name)then
				self:kick(KICK_NAMETAKEN)
				return
			end
			if not sql.createPlayer(key)then
				self:kick(KICK_INTERR%IE_SQL)
				return
			end
			self.handshaked = true
			self.handshakeStage2 = true
			onPlayerHandshakeDone(self)
			local dat = sql.getData(key, 'spawnX, spawnY, spawnZ, spawnYaw, spawnPitch, lastWorld, onlineTime')
			sql.insertData(key, {'lastIP'}, {self.ip})

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
				sx, sy, sz = unpack(spawn)
				ay, ap = unpack(eye)
			else
				sx, sy, sz = dat.spawnX, dat.spawnY, dat.spawnZ
				ay, ap = dat.spawnYaw, dat.spawnPitch
			end
			self.pos.x = sx
			self.pos.y = sy
			self.pos.z = sz
			self.eye.y = ay
			self.eye.p = ap

			if hsFlag==0x42 then
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
		local fin, masked, opcode, hint, mask, plen
		if not self.wsData then
			local hdr = cl:receive(2)
			if hdr then
				fin, masked, opcode, hint = readWsHeader(hdr:byte(1,2))
				if not fin or not masked then
					cl:close()
					return
				end
				if hint > 125 then
					if hint == 126 then
						local data = cl:receive(2)
						if data then
							plen = struct.unpack('>H', data)
						else
							cl:close()
							return
						end
					else
						cl:close()
						return
					end
				else
					plen = hint
				end
				mask = cl:receive(4)
				if not mask then
					cl:close()
					return
				end
			end
		else
			opcode, plen, mask = unpack(self.wsData)
		end

		if opcode and plen then
			local data = cl:receive(plen)
			if not data and not self.wsData then
				self.wsData = {opcode, plen, mask}
			end
			if data then
				self.wsData = nil
				return unmaskData(data, mask, plen), opcode
			end
		end
	end,
	checkForWsHandshake = function(self)
		if not self.isWS then return false end
		local data = self:readWsFrame()
		if data then
			local psz = psizes[0x00]
			if #data~=psz then
				self:kick(KICK_PACKETSIZE)
				return false
			end
			return self:readHandShakeData(data)
		end
		return false
	end,
	checkForRawHandshake = function(self)
		local cl = self:getClient()
		local psz = psizes[0x00]
		local msg = cl:receive(psz)
		if msg then
			return self:readHandShakeData(msg)
		end
		return false
	end,
	getOnlineTime = function(self)
		local otime = self.lastOnlineTime + (CTIME-self.connectTime)
		return otime
	end,
	sendNetMesg = function(self, msg, opcode)
		local cl = self:getClient()
		if self.isWS then
			cl:send(encodeWsFrame(msg, opcode or 0x02))
		else
			cl:send(msg)
		end
	end,
	sendPacket = function(self, isCPE, ...)
		local rawPacket
		if isCPE then
			rawPacket = cpe:generatePacket(...)
		else
			rawPacket = generatePacket(...)
		end
		self:sendNetMesg(rawPacket)
	end,
	kick = function(self,reason)
		reason = reason or KICK_NOREASON
		self:sendPacket(false, 0x0e, reason)
		self:destroy()
	end,
	sendMap = function(self)
		if not self.handshaked then
			return false
		end
		local world = worlds[self.worldName]
		if not world.ldata then
			self:sendMessage(MESG_LEVELLOAD,1)
			world:triggerLoad()
			self:sendMessage('',1)
		end
		local addr = world:getAddr()
		local size = world:getSize()
		local sendMap_gen = lanes.gen('*', sendMap)
		local cmplvl = config:get('gzip-compression-level', 5)
		self.thread = sendMap_gen(self:getClientFd(), addr, size, cmplvl, self.isWS)
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
		playersForEach(function(ply,id)
			local sId = (pId==id and -1)or id
			local cx, cy, cz = ply:getPos(true)
			local cay, cap = ply:getEyePos(true)
			local cname = ply:getName()

			local dat, datcpe
			if ply:isInWorld(self)then
				local cl = self:getClient()
				if ply:isSupported('ExtEntityPositions')then
					datcpe = datcpe or cpe:generatePacket(0x07, sId, cname, cx, cy, cz, cay, cap)
					self:sendNetMesg(datcpe)
				else
					dat = dat or generatePacket(0x07, sId, cname, cx, cy, cz, cay, cap)
					self:sendNetMesg(dat)
				end
				if sId~=-1 then
					cl = ply:getClient()
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
	end,
	isInWorld = function(self, wname)
		return worlds[self.worldName] == getWorld(wname)
	end,
	changeWorld = function(self, wname, force, x, y, z, ay, ap)
		if not force and self:isInWorld(wname)then
			return false, 1
		end
		local world = getWorld(wname)
		if world then
			local wsp = world.data.spawnpoint
			local wse = world.data.spawnpointeye
			self:despawn()
			self.worldName = wname
			self.handshakeStage2 = true
			self.eye.y = ay or wse[1]
			self.eye.p = ap or wse[2]
			self.pos.x = x or wsp[1]
			self.pos.y = y or wsp[2]
			self.pos.z = z or wsp[3]
			return true
		end
		return false, 0
	end,
	despawn = function(self)
		if not self.isSpawned then return false end
		self.isSpawned = false
		local sId = self:getID()
		playersForEach(function(ply,id)
			if ply:isInWorld(self)then
				ply:sendPacket(false, 0x0c, sId)
			end
		end)
		onPlayerDespawn(self)
		return true
	end,
	sendMOTD = function(self, sname, smotd)
		sname = sname or config:get('server-name', DEF_SERVERNAME)
		smotd = smotd or config:get('server-motd', DEF_SERVERMOTD)
		self:sendPacket(
			false,
			0x00,
			0x07,
			sname,
			smotd,
			(self.isOP and 0x64)or 0x00
		)
	end,
	isWebClient = function(self)
		return self.isWS
	end,
	readWsData = function(self)
		if not self.isWS then return false end
		local data, opcode = self:readWsFrame()
		if data then
			if opcode == 0x02 or opcode == 0x01 then
				self.wsBuf = self.wsBuf or''
				self.wsBuf = self.wsBuf .. data
			end
		end
		if self.wsBuf and#self.wsBuf>0 then
			local id = self.wsBuf:byte()
			local psz = psizes[id]
			if not psz or #self.wsBuf<psz then return end
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
			pHandlers[id](self, struct.unpack(fmt, self.wsBuf:sub(2, psz+1)))
			self.wsBuf = self.wsBuf:sub(psz+2)
		end
	end,
	readRawData = function(self)
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
	serviceMessages = function(self)
		local _, status = self:getClient():receive(0)
		if status == 'closed'then
			self:destroy()
			return
		end
		if CTIME>self.kickTimeout then
			if self.isSpawned then
				self:kick(KICK_TIMEOUT)
				return
			end
		end
		if self.thread then
			if self.thread.status == 'error'then
				print(self.thread[-1])
				self.thread = nil
				self:kick(KICK_MAPTHREADERR)
				return
			elseif self.thread.status == 'done'then
				local mesg = self.thread[1]
				if mesg then
					if mesg == 0 then
						local dim = worlds[self.worldName].data.dimensions
						self:sendPacket(false, 0x04, unpack(dim))
						self:spawn()
					else
						print('MAPSEND ERROR', mesg)
						self:kick(KICK_INTERR%IE_GZ)
					end
					self.thread = nil
					self.kickTimeout = CTIME + getKickTimeout()
				end
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

		if not self.handshaked then return end
		if self.isWS then
			self:readWsData()
		else
			self:readRawData()
		end
	end,
	getAppName = function(self)
		return self.appName or'vanilla'
	end,
	isSupported = function(self,extName,extVer)
		extVer = extVer or 1
		extName = extName:lower()
		local ext = self.extensions[extName]
		return ext and ext==extVer
	end,
	destroy = function(self)
		if self.isSpawned then
			self:despawn()
		end
		local id = self:getID()
		players[self] = nil
		IDS[id] = nil
		if self.handshaked then
			onPlayerDestroy(self)
		end
		self:getClient():close()
		self.handshaked = false
		return true
	end,
	getClient = function(self)
		return self.client
	end,
	getClientFd = function(self)
		return self.client:getfd()
	end,
	isPlayer = true
}
player_mt.__index = player_mt

function getPlayerMT()
	return player_mt
end

return function(cl)
	return setmetatable({
		kickTimeout = CTIME+getKickTimeout(),
		connectTime = CTIME,
		pos = {x=0,y=0,z=0},
		isSpawned = false,
		eye = {y=0,p=0},
		waitingExts = -1,
		extensions = {},
		inited = false,
		client = cl
	}, player_mt)
end
