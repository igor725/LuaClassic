ffi.cdef[[
typedef struct {
	char *fpos;
	void *base;
	unsigned short handle;
	short flags;
	short unget;
	unsigned long alloc;
	unsigned short buffincrement;
} FILE;

size_t fread(const void * ptr, size_t size, size_t count, FILE *stream);
size_t fwrite(const void * ptr, size_t size, size_t count, FILE *stream);
int    ferror(FILE *stream);
]]

local function gBufSize(x,y,z)
	return x*y*z+4
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

local world_mt = {
	createWorld = function(self,data)
		local dim = data.dimensions
		local sz = gBufSize(unpack(dim))
		if sz>1533634564 then
			error(WORLD_TOOBIGDIM)
		end
		data.spawnpoint = data.spawnpoint or{0,0,0}
		data.spawnpointeye = data.spawnpointeye or{0,0}
		self.size = sz
		self.ldata = ffi.new('char[?]',sz)
		local szint = ffi.new('int[1]',bswap(sz-4))
		ffi.copy(self.ldata, szint, 4)
		self.data = data
		return true
	end,
	readGZIPData = function(self, wh)
		local a = self:getAddr()
		local ptr = ffi.cast('char*', a)
		gz.decompress(wh, function(out,stream)
			local chunksz = 1024-stream.avail_out
			ffi.copy(ptr, out, chunksz)
			ptr = ptr + chunksz
		end)
	end,
	getDimensions = function(self)
		return unpack(self.data.dimensions)
	end,
	getOffset = function(self,x,y,z)
		if not self.ldata then return false end
		local dx, dy, dz = self:getDimensions()
		local offset = math.floor(z*dx+y*(dx*dz)+x+4)
		local fs = ffi.sizeof(self.ldata)
		offset = math.max(math.min(offset, fs), 4)
		return offset
	end,
	isInReadOnly = function(self)
		return self.data.readonly
	end,
	setReadOnly = function(self,b)
		self.data.readonly = b
		return true
	end,
	toggleReadOnly = function(self)
		self.data.readonly = not self.data.readonly
		return self.data.readonly
	end,
	setBlock = function(self,x,y,z,id)
		if not self.ldata then return false end
		if self:isInReadOnly()then return false end
		local offset = self:getOffset(x,y,z)
		self.ldata[offset] = id
	end,
	setSpawn = function(self,x,y,z,ay,ap)
		local data = self.data
		if x and y and z then
			local sp = data.spawnpoint
			sp[1] = x sp[2] = y sp[3] = z
		end
		if ay and ap then
			local eye = data.spawnpointeye
			eye[1] = ay eye[2] = ap
		end
	end,
	fillBlocks = function(self,x1,y1,z1,x2,y2,z2,id)
		if self:isInReadOnly()then return false end
		x1,y1,z1,x2,y2,z2 = makeNormalCube(x1,y1,z1,x2,y2,z2)
		local buf = ''
		for x=x2,x1-1 do
			for y=y2,y1-1 do
				for z=z2,z1-1 do
					self:setBlock(x,y,z,id)
					buf = buf .. generatePacket(0x06,x,y,z,id)
				end
			end
		end
		playersForEach(function(player)
			if player:isInWorld(self)then
				player:sendNetMesg(buf)
			end
		end)
	end,
	getBlock = function(self,x,y,z)
		if not self.ldata then return false end
		return self.ldata[self:getOffset(x,y,z)]
	end,
	getAddr = function(self)
		return getAddr(self.ldata)
	end,
	getSize = function(self)
		return self.size
	end,
	unload = function(self)
		if self.players>0 then return false end
		self:save()
		self.ldata = nil
		collectgarbage()
		return true
	end,
	readLevelInfo = function(self, wh)
		wh:seek('set', 0)
		if wh:read(4) == 'LCW\0'then
			self.data = {}
			while true do
				local id = wh:read(1)

				if id == '\0'then
					local dx, dy, dz = unpackFrom(wh, '>HHH')
					local sz = gBufSize(dx, dy, dz)
					self.data.dimensions = {dx, dy, dz}
					self.ldata = ffi.new('char[?]', sz)
					self.size = sz
				elseif id == '\1'then
					local sx, sy, sz = unpackFrom(wh, '>fff')
					self.data.spawnpoint = {sx, sy, sz}
				elseif id == '\2'then
					local ay, ap = unpackFrom(wh, '>ff')
					self.data.spawnpointeye = {ay, ap}
				elseif id == '\3'then
					self.data.isNether = wh:read(1)=='\1'
				elseif id == '\4'then
					local ct, r, g, b = unpackFrom(wh, 'BBBB')
					self.data.colors = self.data.colors or{}
					self.data.colors[ct] = {r,g,b}
				elseif id == '\5'then
					local ct, val = unpackFrom(wh, '>bI')
					self.data.map_aspects = self.data.map_aspects or{}
					self.data.map_aspects[ct] = val
				elseif id == '\6'then
					self.data.weather = wh:read(1):byte()
				elseif id == '\7'then
					self.data.isInReadOnly = wh:read(1)=='\1'
				elseif id == '\8'then
					self.data.portals = self.data.portals or{}
					local p1x, p1y, p1z,
					p2x, p2y, p2z, strsz = unpackFrom(wh, '>HHHHHHH')
					table.insert(self.data.portals,{
						pt1 = {p1x, p1y, p1z},
						pt2 = {p2x, p2y, p2z},
						tpTo = wh:read(strsz)
					})
				elseif id == '\255'then
					break
				else
					error('Unsupported map version or file corrupted.')
				end
			end
			return true
		end
		return false
	end,
	save = function(self)
		if not self.ldata then return true end
		local pt = 'worlds/'+self.wname+'.map'
		local wh = assert(io.open(pt, 'wb'))
		wh:write('LCW\0')
		for k, v in pairs(self.data)do
			if k == 'dimensions'then
				packTo(wh, '>bHHH', 0, unpack(v))
			elseif k == 'spawnpoint'then
				packTo(wh, '>bfff', 1, unpack(v))
			elseif k == 'spawnpointeye'then
				packTo(wh, '>bff', 2, unpack(v))
			elseif k == 'isNether'then
				packTo(wh, '>bb', 3, (v and 1)or 0)
			elseif k == 'colors'then
				for id, rgb in pairs(v)do
					packTo(wh, 'bbbbb', 4, id, unpack(rgb))
				end
			elseif k == 'map_aspects'then
				for id, val in pairs(v)do
					packTo(wh, '>bbI', 5, id, val)
				end
			elseif k == 'weather'then
				packTo(nw, '>bb', 6, v)
				print('weatherType', v)
			elseif k == 'readonly'then
				packTo(nw, '>bb', 7, (v and 1)or 0)
				print('isInReadOnly', v)
			elseif k == 'portals'then
				for id, val in pairs(v)do
					local p1x, p1y, p1z = unpack(val.pt1)
					local p2x, p2y, p2z = unpack(val.pt2)
					packTo(nw, '>bHHHHHHH', 8, p1x, p1y, p1z,
					p2x, p2y, p2z, #val.tpTo)
					nw:write(val.tpTo)
					print('portal to', val.tpTo)
				end
			else
				print('Warning: Unknown MAPOPT %q skipped!'%k)
			end
		end
		wh:write('\255')
		gz.compress(self.ldata, self.size, 4, function(out,stream)
			local chunksz = 1024-stream.avail_out
			C.fwrite(out, 1, chunksz, wh)
			if C.ferror(wh)~=0 then
				print(WORLD_WRITEFAIL)
				os.exit(1)
			end
		end)
		wh:close()
		return true
	end,
	triggerLoad = function(self)
		if not self.ldata then
			local pt = 'worlds/'+self.wname
			self.ldata = ffi.new('char[?]',self.size)
			return self:loadLevelData(pt+'/level.dat')
		end
		return false
	end,
	setName = function(self, name)
		if type(name)~='string' then return false end
		self.wname = name
		return true
	end,
	getName = function(self)
		return self.wname
	end,
	isWorld = true,
	players = 0
}
world_mt.__index = world_mt

return function(wh, wn)
	local world =
	setmetatable({}, world_mt)

	if wh then
		world:setName(wn)
		world:readLevelInfo(wh)
		world:readGZIPData(wh)
		wh:close()
	end

	return world
end
