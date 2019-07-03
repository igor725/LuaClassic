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

local function wsaveThread(maddr, mlen, path)
	set_debug_threadname('WorldSave')

	ffi = require('ffi')
	ffi.cdef[[
		size_t fwrite(const void* ptr, size_t size, size_t count, void* stream);
		int    ferror(void* stream);
	]]
	require('data.zlib')
	C = ffi.C

	local wh = io.open(path, 'ab') -- Oh...
	local mapdata = ffi.cast('uint8_t*', maddr)

	local gStatus, gErr = zlib.compress(mapdata, mlen, 4, function(stream)
		local chunksz = 1024 - stream.avail_out
		C.fwrite(stream.next_out - chunksz, 1, chunksz, wh)
		if C.ferror(wh) ~= 0 then
			zlib.defEnd(stream)
			error('file writing error')
		end
	end)
	wh:close()
	if not gStatus then error(gErr)end
	collectgarbage()
	return true
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
		format = 'bool'
	},
	['readonly'] = {
		format = 'bool'
	},
	['portals'] = {
		format = 'tbl:>HHHHHHc16c16',
		func = function(wdata, x1, y1, z1, x2, y2, z2, pName, tpTo)
			wdata.portals = wdata.portals or{}
			wdata.portals[trimStr(pName)] = {
				pt1 = newVector(x1, y1, z1),
				pt2 = newVector(x2, y2, z2),
				tpTo = trimStr(tpTo)
			}
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
		format = 'bool'
	},
	['readonly'] = {
		format = 'bool'
	},
	['portals'] = {
		format = 'tbl:>HHHHHHc16c16',
		func = function(wdata, pname, p)
			return
				p.pt1.x, p.pt1.y, p.pt1.z,
				p.pt2.x, p.pt2.y, p.pt2.z,
				pname, p.tpTo
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
		ffi.cast('int*', self.ldata)[0] = bswap(sz - 4)
		self.data = data
		return true
	end,
	unload = function(self)
		if self.players > 0 or self.unloadLocked then return false end
		self:save()
		self.unloadScheduled = true
		return true
	end,
	triggerLoad = function(self)
		if self.ldata then return false end
		local wh = assert(io.open(self:getPath(), 'rb'))
		if self:readLevelInfo(wh)then
			self:readGZIPData(wh)
			wh:close()
			return true
		end
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
		if not self.ldata then return -1 end
		local offset = self:getOffset(x, y, z)
		if offset then
			return self.ldata[offset]
		else
			return -1
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

	setBlock = function(self, x, y, z, id, exclude)
		if not self.ldata then return false end
		if self:isReadOnly()then return false end
		local offset = self:getOffset(x, y, z)
		if offset then
			self.ldata[offset] = id
			if self.players > 0 then
				playersForEach(function(player)
					if player ~= exclude then
						player:sendPacket(false, 0x06, x, y, z, id)
					end
				end)
			end
			return true
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

		BulkBlockUpdate:start(self)
		local map = self.ldata
		for y = y2, y1 - 1 do
			for z = z2, z1 - 1 do
				local offset = self:getOffset(x2, y, z)
				if offset then
					ffi.fill(map + offset, x1 - x2, id)
					for i = offset, offset + (x1 - x2) - 1 do
						BulkBlockUpdate:write(i, id)
					end
				end
			end
		end
		BulkBlockUpdate:done()

		return true
	end,
	replaceBlocks = function(self, p1, p2, id1, id2)
		if self:isReadOnly()then return false end

		BulkBlockUpdate:start(self)

		x1, y1, z1, x2, y2, z2 = makeNormalCube(p1, p2)
		for x = x2, x1 - 1 do
			for y = y2, y1 - 1 do
				for z = z2, z1 - 1 do
					local offset = self:getOffset(x, y, z)
					if offset and self.ldata[offset] == id1 then
						self.ldata[offset] = id2
						BulkBlockUpdate:write(offset, id2)
					end
				end
			end
		end

		BulkBlockUpdate:done()
		return true
	end,

	readGZIPData = function(self, wh)
		local ptr = self.ldata
		return zlib.decompress(wh, function(out,stream)
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

	save = function(self)
		if self.gzipThread then return true end
		if not self.ldata then return true end
		local pt = self:getPath()
		local pt_tmp = pt .. '.tmp'
		local wh = assert(io.open(pt_tmp, 'wb'))

		local lsucc, succ, werr = pcall(writeData, wh, wWriters, 'wdata\0', self.data, self.skipped)

		if not lsucc or not succ then
			wh:close()
			return false, (not lsucc and succ)or werr
		end

		wh:close()
		local ptr = getAddr(self.ldata)
		self.gzipThread = lanes.gen('*', wsaveThread)(ptr, self:getData('size'), pt_tmp)
		return true
	end,
	update = function(self)
		if self.gzipThread then
			local th = self.gzipThread
			if th.status == 'error'then
				logWorldError(self, th[-1])
				self.gzipThread = nil
				if self.unloadScheduled then
					self.ldata = nil
					collectgarbage()
				end
			elseif th.status == 'done'then
				self.gzipThread = nil
				local pt = self:getPath()
				os.rename(pt .. '.tmp', pt)
				if self.unloadScheduled then
					self.ldata = nil
					collectgarbage()
				end
			end
		else
			if uwa > 0 then
				if self.emptyfrom then
					if CTIME - self.emptyfrom > uwa then
						self:unload()
						self.emptyfrom = nil
					end
				end
			end
		end
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

function isValidBlockID(id)
	if not id then return false end
	return (id >= 0 and id <= 65)or
	BlockDefinitions:isDefined(id)
end

function loadWorld(wname)
	if getWorld(wname)then return true end
	local lvlh = io.open(getWorldPath(wname), 'rb')
	if not lvlh then return false end
	local status, world = pcall(newWorld, lvlh, wname)
	if status then
		worlds[wname] = world
		table.insert(nworlds, world)
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
		if world.gzipThread then return false end
		playersForEach(function(player)
			if player:isInWorld(wname)then
				player:changeWorld('default')
			end
		end)
		world:save()
		world.ldata = nil
		worlds[wname] = nil
		for i = #nworlds, 1, -1 do
			if nworlds[i] == world then
				table.remove(nworlds, i)
				break
			end
		end
		collectgarbage()
		return true
	end
	return false
end

function createWorld(wname, dims, gen, seed)
	if getWorld(wname)then return false end
	local data = {dimensions = dims}
	local tmpWorld = newWorld()
	if tmpWorld:createWorld(data)then
		tmpWorld:setName(wname)
		worlds[wname] = tmpWorld
		table.insert(nworlds, tmpWorld)
		if gen then
			return regenerateWorld(wname, gen, seed)
		else
			return tmpWorld
		end
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
	if world.gzipThread then return false end
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
			ffi.fill(world.ldata + 4, world:getSize() - 4)
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
	for i = 1, #nworlds do
		local world = nworlds[i]
		local name = world:getName()
		local ret = func(world, name)
		if ret ~= nil then
			return ret
		end
	end
end

function newWorld(wh, wn)
	local world = setmetatable({}, world_mt)

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
