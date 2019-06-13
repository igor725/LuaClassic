local function spawnMobFor(mob, player)
	if player:isInWorld(mob)then
		local id = mob.id
		local cx, cy, cz = mob:getPos(true)
		local cay, cap = mob:getEyePos(true)
		local cname = ''

		if not player:isSupported('ChangeModel')then
			cname = mob.model
		end

		player:sendPacket(player:isSupported('ExtEntityPositions'), 0x07, id, cname, cx, cy, cz, cay, cap)
		if #cname == 0 then
			player:sendPacket(false, 0x1D, id, mob.model)
		end
	end
end

local mob_mt = {
	getPos = function(self, forNet)
		local p = self.pos
		if forNet then
			return floor(p.x * 32), floor(p.y * 32), floor(p.z * 32)
		else
			return p.x, p.y, p.z
		end
	end,
	getEyePos = function(self, forNet)
		local e = self.eye
		if forNet then
			return floor((e.yaw / 360) * 255), floor((e.pitch / 360) * 255)
		else
			return e.yaw, e.pitch
		end
	end,

	updatePos = function(self)
		if not self.isSpawned then return false end
		local dat, datcpe
		local id = self.id
		local cx, cy, cz = self:getPos(true)
		local cay, cap = self:getEyePos(true)

		playersForEach(function(player)
			if player:isInWorld(self)then
				if player:isSupported('ExtEntityPositions')then
					datcpe = datcpe or cpe:generatePacket(0x08, id, cx, cy, cz, cay, cap)
					player:sendNetMesg(datcpe)
				else
					dat = dat or generatePacket(0x08, id, cx, cy, cz, cay, cap)
					player:sendNetMesg(dat)
				end
			end
		end)
	end,

	spawn = function(self, player)
		if player then
			spawnMobFor(self, player)
			return true
		end
		if self.isSpawned then return false end
		playersForEach(function(player)
			spawnMobFor(self, player)
		end)
		self.isSpawned = true
		return true
	end,

	despawn = function(self)
		if not self.isSpawned then return false end
		playersForEach(function(player)
			player:sendPacket(false, 0x0C, self.id)
		end)
		self.isSpawned = false
		return true
	end,

	destroy = function(self)
		IDS[self.id] = nil
		self:despawn()
		return true
	end,

	isMob = true
}

mob_mt.__index = mob_mt

function findMobFreeID()
	local s = -2
	while IDS[s]do
		s = s - 1
		if s < -128 then
			return false
		end
	end
	return s
end

function newMob(type, world, x, y, z, yaw, pitch)
	world = getWorld(world)
	if not world then return false end
	world = world:getName()
	local id = findMobFreeID()
	if not id then return false end
	IDS[id] = true

	local pos = newVector(x, y, z)
	local eye = newAngle(yaw or 0, pitch or 0)

	return setmetatable({
		id = id,
		pos = pos,
		eye = eye,
		model = type,
		isSpawned = false,
		worldName = world
	}, mob_mt)
end
