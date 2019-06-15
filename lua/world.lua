--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local function gBufSize(vec)
	return vec.x * vec.y * vec.z + 4
end

local function getWorldPath(wname)
	return 'worlds/' .. wname .. '.map'
end

local function logWorldWarn(world, str)
	log.warn(world:getName(), ':', str)
end

local function logWorldError(world, str)
	log.error(world:getName(), ':', str)
end

local wReaders = {
	['dimensions'] = {
		format = '>HHH',
		func = function(wdata, x, y, z)
			local dim = newVector(x, y, z)
			local wsize = gBufSize(dim)
			wdata.size = wsize
			return dim
		end
	},
	['spawnpoint'] = {
		format = '>fff',
		func = function(wdata, x, y, z)
			return newVector(x, y, z)
		end
	},
	['spawnpointeye'] = {
		format = '>ff',
		func = function(wdata, yaw, pitch)
			local sp = wdata.spawnpointeye
			if sp then
				sp.yaw, sp.pitch = yaw, pitch
			else
				return newAngle(yaw, pitch)
			end
		end
	},
	['isNether'] = {
		format = 'b',
		func = function(wdata, val)
			return val == 1
		end
	},
	['readonly'] = {
		format = 'b',
		func = function(wdata, val)
			return val == 1
		end
	},
	['portals'] = {
		format = 'tbl:>HHHHHHHc0',
		func = function(wdata, x1, y1, z1, x2, y2, z2, pName)
			wdata.portals = wdata.portals or{}
			table.insert(wdata.portals, {
				pt1 = newVector(x1, y1, z1),
				pt2 = newVector(x2, y2, z2),
				tpTo = pName
			})
		end
	},
	['colors'] = {
		format = 'tbl:>BBBB',
		func = function(wdata, t, r, g, b)
			wdata.colors = wdata.colors or{}
			wdata.colors[t] = newColor(r, g, b)
		end
	},
	['map_aspects'] = {
		format = 'tbl:>BI',
		func = function(wdata, t, v)
			wdata.map_aspects = wdata.map_aspects or{}
			wdata.map_aspects[t] = v
		end
	},
	['weather'] = {
		format = 'b'
	},
	['seed'] = {
		format = '>I'
	},
	['texPack'] = {
		format = 'string'
	}
}

local wWriters = {
	['dimensions'] = {
		format = '>HHH',
		func = function(d)
			return d.x, d.y, d.z
		end
	},
	['spawnpoint'] = {
		format = '>fff',
		func = function(s)
			return s.x, s.y, s.z
		end
	},
	['spawnpointeye'] = {
		format = '>ff',
		func = function(e)
			return e.yaw, e.pitch
		end
	},
	['isNether'] = {
		format = 'b',
		func = function(v)
			return v and 1 or 0
		end
	},
	['readonly'] = {
		format = 'b',
		func = function(v)
			return v and 1 or 0
		end
	},
	['portals'] = {
		format = 'tbl:>HHHHHHHc0',
		func = function(_, p)
			return
				p.pt1.x, p.pt1.y, p.pt1.z,
				p.pt2.x, p.pt2.y, p.pt2.z,
				#p.tpTo, p.tpTo
		end
	},
	['colors'] = {
		format = 'tbl:>BBBB',
		func = function(_, t, c)
			return t, c.r, c.g, c.b
		end
	},
	['map_aspects'] = {
		format = 'tbl:>BI'
	},
	['weather'] = {
		format = 'B'
	},
	['seed'] = {
		format = '>I'
	},
	['texPack'] = {
		format = 'string'
	}
}

local world_mt = {
	__tostring = function(self)
		return self:getName()
	end,

	createWorld = function(self, data)
		local dim = data.dimensions
		local sz = gBufSize(dim)
		if sz > 1533634564 then
			logWorldError(self, WORLD_TOOBIGDIM)
			return false, WORLD_TOOBIGDIM
		end
		data.spawnpoint = data.spawnpoint or newVector(0, 0, 0)
		data.spawnpointeye = data.spawnpointeye or newAngle(0, 0)
		data.size = sz
		self.ldata = ffi.new('uint8_t[?]', sz)
		local szint = ffi.new('int[1]', bswap(sz - 4))
		ffi.copy(self.ldata, szint, 4)
		self.data = data
		return true
	end,
	save = function(self)
		if not self.ldata then return true end
		local pt = self:getPath()
		local wh = assert(io.open(pt, 'wb'))
		writeData(wh, wWriters, 'wdata\0', self.data, self.skipped)
		local gStatus, gErr = gz.compress(self.ldata, self:getData('size'), 4, function(out, stream)
			local chunksz = 1024 - stream.avail_out
			C.fwrite(out, 1, chunksz, wh)
			if C.ferror(wh) ~= 0 then
				logWorldError(self, WORLD_WRITEFAIL)
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
		if offset > 3 and offset < self:getData('size') then
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
		return self:getData('size')
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
		if type(name) ~= 'string'then return false end
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

	fillBlocks = function(self, p1, p2, id)
		if self:isReadOnly()then return false end
		x1, y1, z1, x2, y2, z2 = makeNormalCube(p1, p2)
		local buf = ''
		for x = x2, x1 - 1 do
			for y = y2, y1 - 1 do
				for z = z2, z1 - 1 do
					local offset = self:getOffset(x, y, z)
					self.ldata[offset] = id
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
	replaceBlocks = function(self, p1, p2, id1, id2)
		if self:isReadOnly()then return false end
		x1, y1, z1, x2, y2, z2 = makeNormalCube(p1, p2)
		local buf = ''
		for x = x2, x1 - 1 do
			for y = y2, y1 - 1 do
				for z = z2, z1 - 1 do
					local offset = self:getOffset(x, y, z)
					if self.ldata[offset] == id1 then
						self.ldata[offset] = id2
						buf = buf .. generatePacket(0x06, x, y, z, id2)
					end
				end
			end
		end
		playersForEach(function(player)
			if player:isInWorld(self)then
				player:sendNetMesg(buf)
			end
		end)
		return true
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
		self.data = {}
		self.skipped = {}
		if parseData(wh, wReaders, 'wdata\0', self.data, self.skipped)then
			self.ldata = ffi.new('uint8_t[?]', self:getData('size'))
			return true
		end
		return false
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
		elseif w.isPlayer or w.isMob then
			return worlds[w.worldName]
		end
	elseif t == 'string'then
		w = w:lower()
		return worlds[w]
	end
end

function addWSave(name, fmt, reader, writer)
	wWriters[name] = {
		format = fmt,
		func = writer
	}
	wReaders[name] = {
		format = fmt,
		func = reader
	}
end

function loadWorld(wname)
	if getWorld(wname)then return true end
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
	if world == getWorld('default')then
		return false
	end

	if world then
		playersForEach(function(player)
			if player:isInWorld(wname)then
				player:changeWorld('default')
			end
		end)
		world:save()
		world.ldata = nil
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
	local locked = false
	playersForEach(function(player)
		if player:isInWorld(world)and player.thread then
			locked = true
		end
	end)
	if locked then
		return false, WORLD_LOCKED
	end
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
			ffi.fill(world.ldata + 4, world:getSize())
			local t = gettime()
			local succ, err = pcall(gen, world, seed)
			if not succ then
				logWorldError(world, err)
				return false, err
			end
			local e = gettime()
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

function worldsForEach(func)
	for _, world in pairs(worlds)do
		local ret = func(world)
		if ret ~= nil then
			return ret
		end
	end
end

function newWorld(wh, wn)
	local world = setmetatable({data = {}}, world_mt)

	if wh and wn then
		world:setName(wn)
		if world:readLevelInfo(wh)then
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
