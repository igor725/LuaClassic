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

local world_mt = {
	CreateWorld = function(self,data)
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
	end,
	LoadLevelData = function(self,fn)
		local wfile = io.open(fn,'rb')
		local mapUncompressed = false
		if not wfile then
			wfile = assert(io.open(fn+'.raw','rb'))
			if wfile then
				mapUncompressed = true
			end
		end
		if mapUncompressed then
			C.fread(self.ldata, 1, self.size, wfile)
		else
			local a = self:GetAddr()
			local ptr = ffi.cast('char*', a)
			gz.decompress(wfile, function(out,stream)
				local chunksz = 1024-stream.avail_out
				ffi.copy(ptr, out, chunksz)
				ptr = ptr + chunksz
			end)
		end
		wfile:close()
		local fsz = ffi.cast('int*', self.ldata)
		if bswap(fsz[0])~=self.size-4 then
			error(WORLD_INVALID)
		end
	end,
	GetDimensions = function(self)
		return unpack(self.data.dimensions)
	end,
	GetOffset = function(self,x,y,z)
		if not self.ldata then return false end
		local dx, dy, dz = self:GetDimensions()
		local offset = math.floor(z*dx+y*(dx*dz)+x+4)
		local fs = ffi.sizeof(self.ldata)
		offset = math.max(math.min(offset, fs), 4)
		return offset
	end,
	IsInReadOnly = function(self)
		if not self.data then return false end
		return self.data.readonly
	end,
	SetReadOnly = function(self,b)
		if not self.data then return false end
		self.data.readonly = b
	end,
	ToggleReadOnly = function(self)
		if not self.data then return false end
		self.data.readonly = not self.data.readonly
		return self.data.readonly
	end,
	SetBlock = function(self,x,y,z,id)
		if not self.ldata then return false end
		if self:IsInReadOnly()then return false end
		local offset = self:GetOffset(x,y,z)
		self.ldata[offset] = id
	end,
	SetSpawn = function(self,x,y,z,ay,ap)
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
	FillBlocks = function(self,x1,y1,z1,x2,y2,z2,id)
		if self:IsInReadOnly()then return false end
		x1,y1,z1,x2,y2,z2 = makeNormalCube(x1,y1,z1,x2,y2,z2)
		local buf = ''
		for x=x2,x1-1 do
			for y=y2,y1-1 do
				for z=z2,z1-1 do
					self:SetBlock(x,y,z,id)
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
	GetBlock = function(self,x,y,z)
		if not self.ldata then return false end
		return self.ldata[self:GetOffset(x,y,z)]
	end,
	GetAddr = function(self)
		return getAddr(self.ldata)
	end,
	GetSize = function(self)
		return self.size
	end,
	Unload = function(self)
		local locked = false
		playersForEach(function(player)
			if player:isInWorld(self)then
				locked = true
			end
		end)
		if locked then return end
		self:Save()
		self.ldata = nil
		collectgarbage()
	end,
	Save = function(self)
		if not self.ldata then return true end
		local pt = 'worlds/'+self.wname
		if lfs.attributes(pt,'mode')~='directory'then
			os.remove(pt)
			lfs.mkdir(pt)
		end

		local wfile = assert(io.open(pt+'/level.dat','wb'))
		gz.compress(self.ldata, self.size, 4, function(out,stream)
			local chunksz = 1024-stream.avail_out
			C.fwrite(out, 1, chunksz, wfile)
			if C.ferror(wfile)~=0 then
				print(WORLD_WRITEFAIL)
				os.exit(1)
			end
		end)
		wfile:close()
		os.remove(pt+'/level.dat.raw')

		local json = json.encode(self.data)
		local dfile = assert(io.open(pt+'/data.json','wb'))
		dfile:write(json)
		dfile:close()
		return true
	end,
	TriggerLoad = function(self)
		if not self.ldata then
			local pt = 'worlds/'+self.wname
			self.ldata = ffi.new('char[?]',self.size)
			self:LoadLevelData(pt+'/level.dat')
		end
	end,
	SetName = function(self, name)
		self.wname = name
	end,
	GetName = function(self)
		return self.wname
	end,
	isWorld = true,
	players = 0
}
world_mt.__index = world_mt

return function(nm)
	local world =
	setmetatable({}, world_mt)

	if nm then
		local pt = 'worlds/'+nm
		world.wname = nm
		local data = assert(io.open(pt+'/data.json','r'))
		local pdata = json.decode(data:read('*a'))
		data:close()
		world:CreateWorld(pdata)
		world:LoadLevelData(pt+'/level.dat')
	end

	return world
end
