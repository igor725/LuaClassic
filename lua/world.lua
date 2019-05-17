local function gBufSize(vec)
	return vec.x * vec.y * vec.z + 4
end

local function packTo(file, fmt, ...)
	local data = struct.pack(fmt, ...)
	return file:write(data)
end

local function unpackFrom(file, fmt)
	local sz = struct.size(fmt)
	local data = file:read(sz)
	return struct.unpack(fmt, data)
end

local function distance(x1, z1, x2, z2)
	return math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
end

local function delayedWaterCreate(world, sx, sy, sz, x, y, z)
	--local dst = distance(sx, sz, x, z)
	--if dst < 25 then
		timer.Simple(.2, function()
			if world:getBlock(x, y, z) == 0 then
				world:setBlock(x, y, z, 8)
				world:updateWaterBlock(sx, sy, sz, x, y, z)
			end
		end)
		timer.Simple(2, function()
			if world:getBlock(x, y, z) == 8 then
				world:setBlock(x, y, z, 0)
				world:updateWaterBlock(sx, sy, sz, x, y, z)
			end
		end)
	--end
end

local function getWorldPath(wname)
	return 'worlds/' .. wname .. '.map'
end

local world_mt = {
	__tostring = function(self)
		return self:getName()
	end,

	createWorld = function(self, data)
		local dim = data.dimensions
		local sz = gBufSize(dim)
		if sz > 1533634564 then
			log.error(WORLD_TOOBIGDIM)
			return false, WORLD_TOOBIGDIM
		end
		data.spawnpoint = data.spawnpoint or newVector(0, 0, 0)
		data.spawnpointeye = data.spawnpointeye or newAngle(0, 0)
		self.size = sz
		self.ldata = ffi.new('uchar[?]', sz)
		local szint = ffi.new('int[1]', bswap(sz - 4))
		ffi.copy(self.ldata, szint, 4)
		self.data = data
		return true
	end,
	save = function(self)
		if not self.ldata then return true end
		local pt = self:getPath()
		local wh = assert(io.open(pt, 'wb'))
		wh:write('LCW\0')
		for k, v in pairs(self.data)do
			if k == 'dimensions'then
				packTo(wh, '>bHHH', 0, v.x, v.y, v.z)
			elseif k == 'spawnpoint'then
				packTo(wh, '>bfff', 1, v.x, v.y, v.z)
			elseif k == 'spawnpointeye'then
				packTo(wh, '>bff', 2, v.yaw, v.pitch)
			elseif k == 'isNether'then
				packTo(wh, '>bb', 3, (v and 1)or 0)
			elseif k == 'colors'then
				for id, c in pairs(v)do
					packTo(wh, 'bbbbb', 4, id, c.r, c.g, c.b)
				end
			elseif k == 'map_aspects'then
				for id, val in pairs(v)do
					packTo(wh, '>bbI', 5, id, val)
				end
			elseif k == 'weather'then
				packTo(wh, '>bb', 6, v)
			elseif k == 'readonly'then
				packTo(wh, '>bb', 7, (v and 1)or 0)
			elseif k == 'portals'then
				for id, val in pairs(v)do
					local p1x, p1y, p1z = unpack(val.pt1)
					local p2x, p2y, p2z = unpack(val.pt2)
					packTo(wh, '>bHHHHHHH', 8, p1x, p1y, p1z,
					p2x, p2y, p2z, #val.tpTo)
					wh:write(val.tpTo)
				end
			elseif k == 'texPack'then
				if #v > 0 and #v < 65 then
					wh:write(string.char(9, #v))
					wh:write(v)
				else
					log.warn(WORLD_TPSTRLEN)
				end
			elseif k == 'wscripts'then
				for name, script in pairs(v)do
					local slen = math.min(#script.body, 65535)
					local nlen = math.min(#name, 255)
					if slen > 0 and nlen > 0 then
						packTo(wh, '>bBH', 10, nlen, slen)
						wh:write(name)
						wh:write(script.body)
					else
						log.warn(WORLD_SCRSVERR)
					end
				end
			else
				log.warn((WORLD_MAPOPT):format(k))
			end
		end
		wh:write('\255')
		local gStatus, gErr = gz.compress(self.ldata, self.size, 4, function(out, stream)
			local chunksz = 1024 - stream.avail_out
			C.fwrite(out, 1, chunksz, wh)
			if C.ferror(wh) ~= 0 then
				log.error(WORLD_WRITEFAIL)
				gz.defEnd(stream)
			end
		end)
		wh:close()
		return gStatus, gErr
	end,
	unload = function(self)
		if self.players > 0 or self.unloadLocked then return false end
		self:save()
		self.ldata = nil
		collectgarbage()
		return true
	end,
	triggerLoad = function(self)
		if not self.ldata then
			local wh = assert(io.open(self:getPath(), 'rb'))
			if self:readLevelInfo(wh)then
				self:readGZIPData(wh)
				wh:close()
				return true
			else
				return false
			end
		end
		return false
	end,

	getDimensions = function(self)
		local dim = self.data.dimensions
		return dim.x, dim.y, dim.z
	end,
	getOffset = function(self, x, y, z)
		if not self.ldata then return false end
		if x < 0 or y < 0 or z < 0 then return false end
		local dx, dy, dz = self:getDimensions()
		local offset = math.floor(z * dx + y * (dx * dz) + x + 4)
		if offset > 3 and offset < self.size then
			return offset
		end
		return false
	end,
	getBlock = function(self, x, y, z)
		if not self.ldata then return false end
		local offset = self:getOffset(x, y, z)
		if offset then
			return self.ldata[offset]
		else
			return 0
		end
	end,
	getAddr = function(self)
		return getAddr(self.ldata)
	end,
	getSize = function(self)
		return self.size
	end,
	getPath = function(self)
		return getWorldPath(self:getName())
	end,
	getName = function(self)
		return self.wname
	end,
	getData = function(self,key)
		return self.data[key]
	end,
	getSpawnPoint = function(self)
		local sp = self:getData('spawnpoint')
		local spe = self:getData('spawnpointeye')
		return sp.x, sp.y, sp.z, spe.yaw, spe.pitch
	end,

	setBlock = function(self, x, y, z, id)
		if not self.ldata then return false end
		if self:isReadOnly()then return false end
		local offset = self:getOffset(x, y, z)
		if offset then
			self.ldata[offset] = id
			playersForEach(function(player)
				player:sendPacket(false, 0x06, x, y, z, id)
			end)
		end
	end,
	setSpawn = function(self, x, y, z, ay, ap)
		if not x or not y or not z then return false end
		ay, ap = ay or 0, ap or 0
		local sp = self:getData('spawnpoint')
		local eye = self:getData('spawnpointeye')

		sp.x, sp.y, sp.z = x, y, z
		eye.yaw, eye.pitch = ay, ap
		return true
	end,
	setName = function(self, name)
		if type(name) ~= 'string' then return false end
		self.wname = name
		return true
	end,
	setData = function(self, key, val)
		if not self.data then return false end
		self.data[key] = val
		return val
	end,
	setDataInv = function(self, key)
		return self:setData(key, not self:getData(key))
	end,
	setReadOnly = function(self, b)
		self:setData('readonly', b)
		return true
	end,
	toggleReadOnly = function(self)
		self:setDataInv('readonly')
		return self.data.readonly
	end,

	isReadOnly = function(self)
		return self.data.readonly
	end,

	fillBlocks = function(self, x1, y1, z1, x2, y2, z2, id)
		if self:isReadOnly()then return false end
		x1, y1, z1, x2, y2, z2 = makeNormalCube(x1, y1, z1, x2, y2, z2)
		local buf = ''
		for x = x2, x1 - 1 do
			for y = y2, y1 - 1 do
				for z = z2, z1 - 1 do
					self:setBlock(x, y, z, id)
					buf = buf .. generatePacket(0x06, x, y, z, id)
				end
			end
		end
		playersForEach(function(player)
			if player:isInWorld(self)then
				player:sendNetMesg(buf)
			end
		end)
	end,
	updateWaterBlock = function(self, sx, sy, sz, x, y, z)
		if not x then
			x, y, z = sx, sy, sz
		end
		local id = self:getBlock(x, y, z)
		if id == 8 or id == 9 then
			local under = self:getBlock(x, y - 1, z)
			if under == 0 then
				delayedWaterCreate(self, sx, sy, sz, x, y - 1, z)
			elseif under ~= 8 and under ~= 9 then
				if self:getBlock(x + 1, y, z) == 0 then
					delayedWaterCreate(self, sx, sy, sz, x + 1, y, z)
				elseif self:getBlock(x - 1, y, z) == 0 then
					delayedWaterCreate(self, sx, sy, sz, x - 1, y, z)
				elseif self:getBlock(x, y, z + 1) == 0 then
					delayedWaterCreate(self, sx, sy, sz, x, y, z + 1)
				elseif self:getBlock(x, y, z - 1) == 0 then
					delayedWaterCreate(self, sx, sy, sz, x, y, z - 1)
				end
			end
		end
	end,

	readGZIPData = function(self, wh)
		local ptr = self.ldata
		return gz.decompress(wh, function(out,stream)
			local chunksz = 1024 - stream.avail_out
			ffi.copy(ptr, out, chunksz)
			ptr = ptr + chunksz
		end)
	end,
	readLevelInfo = function(self, wh)
		if wh:read(4) == 'LCW\0'then
			self.data = {}
			while true do
				local id = wh:read(1)

				if id == '\0'then
					local dim = newVector(unpackFrom(wh, '>HHH'))
					local sz = gBufSize(dim)
					self.data.dimensions = dim
					self.ldata = ffi.new('char[?]', sz)
					self.size = sz
				elseif id == '\1'then
					local sp = self.data.spawnpoint
					if sp then
						sp.x, sp.y, sp.z = unpackFrom(wh, '>fff')
					else
						self:setData('spawnpoint', newVector(unpackFrom(wh, '>fff')))
					end
				elseif id == '\2'then
					local sp = self.data.spawnpointeye
					if sp then
						sp.yaw, sp.pitch = unpackFrom(wh, '>ff')
					else
						self:setData('spawnpointeye', newAngle(unpackFrom(wh, '>ff')))
					end
				elseif id == '\3'then
					self:setData('isNether', wh:read(1) == '\1')
				elseif id == '\4'then
					self:setEnvColor(unpackFrom(wh, 'BBBB'))
				elseif id == '\5'then
					self:setEnvProp(unpackFrom(wh, '>bI'))
				elseif id == '\6'then
					self:setData('weather', wh:read(1):byte())
				elseif id == '\7'then
					self:setData('readonly', wh:read(1) == '\1')
				elseif id == '\8'then
					self.data.portals = self.data.portals or{}
					local p1x, p1y, p1z,
					p2x, p2y, p2z, strsz = unpackFrom(wh, '>HHHHHHH')
					table.insert(self.data.portals, {
						pt1 = {p1x, p1y, p1z},
						pt2 = {p2x, p2y, p2z},
						tpTo = wh:read(strsz)
					})
				elseif id == '\9'then
					local len = wh:read(1):byte()
					self:setTexPack(wh:read(len))
				elseif id == '\10'then
					local nl, sl = unpackFrom(wh, '>BH')
					local name = wh:read(nl)
					local body = wh:read(sl)
					self:addScript(name, body)
					self:executeScript(name)
				elseif id == '\255'then
					break
				else
					log.error(WORLD_CORRUPT)
					return false
				end
			end
			return true
		end
		return false
	end,

	addScript = function(self, name, body)
		if type(name) ~= 'string' or #name > 255 then return false end
		if type(body) ~= 'string' or #body > 65535 then return false end
		self.data.wscripts = self.data.wscripts or{}
		self.data.wscripts[name] = {
			body = body
		}
		return true
	end,
	addScriptFile = function(self, name, filename)
		if type(name) ~= 'string' or #name > 255 then return false end
		if type(filename) ~= 'string' then return false end
		local f = io.open(filename, 'rb')
		if not f then return false end
		local body = f:read(65535)
		f:close()
		self.data.wscripts = self.data.wscripts or{}
		self.data.wscripts[name] = {
			body = body
		}
		return true
	end,
	removeScript = function(self, name)
		if not self.data.wscripts then return false end
		self.data.wscripts[name] = nil
		return true
	end,
	executeScript = function(self, name)
		if not self.data.wscripts then return false end
		local sctbl = self.data.wscripts[name]
		if not sctbl then return false end

		if config:get('world-scripts')then
			local scret, succ
			local chunk, err = loadstring(sctbl.body, name)
			if not chunk then
				sctbl.succ = false
				sctbl.ret = err
			else
				succ, scret = pcall(chunk, self)
			end
			sctbl.ret = scret
			sctbl.succ = succ
			return true
		end
		return false
	end,
	scriptStatus = function(self, name)
		if not self.data.wscripts then return false end
		local sc = self.data.wscripts[name]
		if not sc then return false end
		return sc.succ, sc.ret
	end,

	isWorld = true,
	players = 0
}
world_mt.__index = world_mt

function getWorldMT()
	return world_mt
end

function getWorld(w)
	local t = type(w)
	if t == 'table'then
		if w.isWorld then
			return w
		elseif w.isPlayer then
			return worlds[w.worldName]
		end
	elseif t == 'string'then
		w = w:lower()
		return worlds[w]
	end
end

function loadWorld(wname)
	if worlds[wname]then return true end
	local lvlh = io.open(getWorldPath(wname), 'rb')
	if not lvlh then return false end
	local status, world = pcall(newWorld, lvlh, wname)
	if status then
		worlds[wname] = world
		return true
	end
	return false, world
end

function unloadWorld(wname)
	local world = getWorld(wname)
	if world == worlds['default']then
		return false
	end

	if world then
		playersForEach(function(player)
			if player:isInWorld(wname)then
				player:changeWorld('default')
			end
		end)
		world:save()
		world.buf = nil
		worlds[wname] = nil
		collectgarbage()
		return true
	end
	return false
end

function createWorld(wname, dims, gen, seed)
	if world[wname]then return false end
	local data = {dimensions = dims}
	local tmpWorld = newWorld()
	if tmpWorld:createWorld(data)then
		tmpWorld:setName(wname)
		worlds[wname] = tmpWorld
		return regenerateWorld(wname, gen, seed)
	else
		return false
	end
end

function openGenerator(name)
	local chunk, err = loadfile('generators/' .. name .. '.lua')
	if chunk then
		local status, ret = pcall(chunk)
		return status and ret, ret
	end
	return false, err
end

function regenerateWorld(world, gentype, seed)
	world = getWorld(world)
	if not world then return false, WORLD_NE end
	if world:isReadOnly()then return false, WORLD_RO end
	local gen, err = openGenerator(gentype)
	if not gen then
		return false, err
	else
		if type(gen) == 'function'then
			world.data.colors = nil
			world.data.map_aspects = nil
			world.data.texPack = nil
			world.data.weather = nil
			playersForEach(function(player)
				if player:isInWorld(world)then
					player:despawn()
				end
			end)
			ffi.fill(world.ldata + 4, world.size)
			seed = seed or CTIME
			local t = socket.gettime()
			local succ, err = pcall(gen, world, seed)
			if not succ then
				log.error(err)
				return false, err
			end
			local e = socket.gettime()
			playersForEach(function(player)
				if player:isInWorld(world)then
					player.handshakeStage2 = true
				end
			end)
			return true, e - t
		end
	end
	return false, IE_UE
end

function newWorld(wh, wn)
	local world = setmetatable({data = {}}, world_mt)

	if wh and wn then
		if world:readLevelInfo(wh)then
			world:setName(wn)
			if not world:readGZIPData(wh)then
				wh:close()
				return false
			end
			wh:close()
		else
			return false
		end
	end

	return world
end
