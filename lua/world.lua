WATER_LEAK_SIZE = 6

local function gBufSize(vec)
	return vec.x * vec.y * vec.z + 4
end

local function getWorldPath(wname)
	return 'worlds/' .. wname .. '.map'
end

local function logWorldWarn(world, str)
	log.warn(world:getName() .. ': ' .. str)
end

local function logWorldError(world, str)
	log.error(world:getName() .. ': ' .. str)
end

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
					local p1 = val.pt1
					local p2 = val.pt2
					packTo(wh, '>bHHHHHHH', 8, p1.x, p1.y, p1.z,
					p2.x, p2.y, p2.z, #val.tpTo)
					wh:write(val.tpTo)
				end
			elseif k == 'texPack'then
				if #v > 0 and #v < 65 then
					wh:write(string.char(9, #v))
					wh:write(v)
				else
					logWorldWarn(self, WORLD_TPSTRLEN)
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
						logWorldWarn(self, WORLD_SCRSVERR)
					end
				end
			elseif k == 'seed'then
				packTo(wh, '>bd', 11, tonumber(v)or -1)
			else
				logWorldWarn(self, (WORLD_MAPOPT):format(k))
			end
		end
		wh:write('\255')
		local gStatus, gErr = gz.compress(self.ldata, self.size, 4, function(out, stream)
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
	
	findWaterBlockToRemove = function(self, x, y, z)
		local dirx, dirz = 0, 0
		while true do
			-- Check up
			if self:getBlock(x, y+1, z) == 8 then
				y = y + 1
			
			-- Check up forward
			elseif self:getBlock(x+1, y+1, z) == 8 then
				x = x + 1
				y = y + 1
			
			-- Check up back
			elseif self:getBlock(x-1, y+1, z) == 8 then
				x = x - 1
				y = y + 1
			
			-- Check up left
			elseif self:getBlock(x, y+1, z+1) == 8 then
				z = z + 1
				y = y + 1
			
			-- Check up right
			elseif self:getBlock(x, y+1, z-1) == 8 then
				z = z - 1
				y = y + 1
			
			-- Check forward
			elseif dirx >= 0 and self:getBlock(x+1, y, z) == 8 then
				dirx = 1
				x = x + 1
			
			-- Check back
			elseif dirx <= 0 and self:getBlock(x-1, y, z) == 8 then
				dirx = -1
				x = x - 1
			
			-- Check left
			elseif dirz >= 0 and self:getBlock(x, y, z+1) == 8 then
				dirz = 1
				z = z + 1
			
			-- Check right
			elseif dirz <= 0 and self:getBlock(x, y, z-1) == 8 then
				dirz = -1
				z = z - 1
			
			-- Block found
			else
				return x, y, z
			end
		end
	end,
	
	findWaterBlockToCreate = function(self, x, y, z)
		-- Under
		if self:getBlock(x, y-1, z) == 0 then
			return x, y-1, z
		end
		
		local dirX, dirZ = 0, 0
		
		-- nearest x
		for dx = -1, 1, 2 do
			if self:getBlock(x+dx, y, z) == 0 then
				dirX = dirX + dx
				if dirX == 0 then
					dirX = math.random(0, 1) * 2 - 1
				end
				
				if self:getBlock(x+dx, y-1, z) == 0 then
					return x+dx, y-1, z
				end
			end
		end
		
		-- nearest y
		for dz = -1, 1, 2 do
			if self:getBlock(x, y, z+dz) == 0 then
				dirZ = dirZ + dz
				if dirZ == 0 then
					dirZ = math.random(0, 1) * 2 - 1
				end
				
				if self:getBlock(x, y-1, z+dz) == 0 then
					return x, y-1, z+dz
				end
			end
		end
		
		-- Check if block don't have way to escape
		if dirX == 0 and dirZ == 0 then
			return nil
		end
		
		local limiterX, limiterZ = 0, 0
		
		-- 5 blocks forward
		if dirX > 0 then
			for dx = 2, WATER_LEAK_SIZE do
				if self:getBlock(x+dx, y, z) ~= 0 then
					limiterX = dx - 1
					break
				elseif self:getBlock(x+dx, y-1, z) == 0 then
					return x+1, y, z
				end
			end
		end
		-- 5 blocks back
		if dirX < 0 then
			for dx = 2, WATER_LEAK_SIZE do
				if self:getBlock(x-dx, y, z) ~= 0 then
					limiterX = dx - 1
					break
				elseif self:getBlock(x-dx, y-1, z) == 0 then
					return x-1, y, z
				end
			end
		end
		-- 5 blocks left
		if dirZ > 0 then
			for dz = 2, WATER_LEAK_SIZE do
				if self:getBlock(x, y, z+dz) ~= 0 then
					limiterZ = dz - 1
					break
				elseif self:getBlock(x, y-1, z+dz) == 0 then
					return x, y, z+1
				end
			end
		end
		-- 5 blocks right
		if dirZ < 0 then
			for dz = 2, WATER_LEAK_SIZE do
				if self:getBlock(x, y, z-dz) ~= 0 then
					limiterZ = dz - 1
					break
				elseif self:getBlock(x, y-1, z-dz) == 0 then
					return x, y, z-1
				end
			end
		end
		
		-- Check if block don't have way to escape by diagonal
		if dirX == 0 or dirZ == 0 then
			return nil
		end
		
		-- nearest squares
		if dirX > 0 then
			for dx = 1, limiterX do
				-- forward left square
				if dirZ > 0 then
					for dz = 1, limiterZ do
						if self:getBlock(x+dx, y, z+dz) ~= 0 then
							break
						end
						if self:getBlock(x+dx, y-1, z+dz) == 0 then
							if self:getBlock(x+1, y-1, z) then
								return x+1, y, z
							else
								return x, y, z+1
							end
						end
					end
			
				-- forward right square
				else
					for dz = 1, limiterZ do
						if self:getBlock(x+dx, y, z-dz) ~= 0 then
							break
						end
						if self:getBlock(x+dx, y-1, z-dz) == 0 then
							if self:getBlock(x+1, y-1, z) then
								return x+1, y, z
							else
								return x, y, z-1
							end
						end
					end
				end
			end
		else
			for dx = 1, limiterX do
				-- back left square
				if dirZ > 0 then
					for dz = 1, limiterZ do
						if self:getBlock(x-dx, y, z+dz) ~= 0 then
							break
						end
						if self:getBlock(x-dx, y-1, z+dz) then
							if self:getBlock(x-1, y-1, z) then
								return x-1, y, z
							else
								return x, y, z+1
							end
						end
					end
			
				-- back right square
				else
					for dz = 1, limiterZ do
						if self:getBlock(x-dx, y, z-dz) ~= 0 then
							break
						end
						if self:getBlock(x-dx, y-1, z-dz) == 0 then
							if self:getBlock(x-1, y-1, z) then
								return x-1, y, z
							else
								return x, y, z-1
							end
						end
					end
				end
			end
		end
		
		return nil
	end,
	
	updateWaterBlock = function(self, sx, sy, sz, x, y, z)
		if not x then
			x, y, z = sx, sy, sz
		end
		local id = self:getBlock(x, y, z)
		if id == 8 or id == 9 then
			local newX, newY, newZ = self:findWaterBlockToCreate(x, y, z)
			
			if newX then
				local remX, remY, remZ = self:findWaterBlockToRemove(x, y, z)
				if self:getBlock(remX, remY, remZ) ~= 8 then
					print("[ERROR] Trying to remove non-water block " .. remX .. ", " .. remY .. ", " .. remZ)
				elseif self:getBlock(newX, newY, newZ) ~= 0 then
					print("[ERROR] Trying place water instead " .. (self:getBlock(newX, newY, newZ) == 8 and "water" or "usual") .. " block " .. newX .. ", " .. newY .. ", " .. newZ)
					print("\tDiff: " .. (newX - x) .. ", " .. (newY - y) .. ", " .. (newZ - z))
				else
					self:setBlock(remX, remY, remZ, 0)
				
					self:setBlock(newX, newY, newZ, 8)
					timer.Simple(.2, function()
						self:updateWaterBlock(sx, sy, sz, newX, newY, newZ)
					end)
				end
			end
		-- lava eating water
		--[[elseif id == 10 or id == 11 then
			if self:getBlock(x, y+1, z) == 8 then
				self:setBlock(x, y+1, z, 0)
				timer.Simple(.2, function()
					self:updateWaterBlock(sx, sy, sz, x, y+2, z)
				end)
			end]]--
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
						pt1 = newVector(p1x, p1y, p1z),
						pt2 = newVector(p2x, p2y, p2z),
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
				elseif id == '\11'then
					self:setData('seed', unpackFrom(wh, '>d'))
				elseif id == '\255'then
					break
				else
					logWorldError(self, WORLD_CORRUPT)
					return false
				end
			end
			return true
		end
		return false
	end,

	addScript = function(self, name, body)
		if type(name) ~= 'string'or #name > 255 then return false end
		if type(body) ~= 'string'or #body > 65535 then return false end
		self.data.wscripts = self.data.wscripts or{}
		self.data.wscripts[name] = {
			body = body
		}
		return true
	end,
	addScriptFile = function(self, name, filename)
		if type(name) ~= 'string'or #name > 255 then return false end
		if type(filename) ~= 'string'then return false end
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
