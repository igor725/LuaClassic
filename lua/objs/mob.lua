--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local function spawnMobFor(mob, player)
	if player:isInWorld(mob)then
		local id = mob.id
		local cx, cy, cz = mob:getPos(true)
		local cay, cap = mob:getEyePos(true)
		local cname = ''

		if not player:isSupported('ChangeModel')then
			cname = mob.model
		end

		local buf = player._buf
		buf:reset()
			buf:writeByte(0x07)
			buf:writeByte(id)
			buf:writeString(cname)
			if player:isSupported('ExtEntityPositions')then
				buf:writeVarInt(cx, cy, cz)
			else
				buf:writeVarShort(cx, cy, cz)
			end
				buf:writeVarByte(cay, cap)

		if #cname == 0 then
			buf:writeByte(0x1D)
			buf:writeByte(id)
			buf:writeString(mob.model)
		end

		buf:sendTo(player:getClient())
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
			if player:isInWorld(self)and player.isSpawned then
				local buf = player._buf
				buf:reset()
					buf:writeByte(0x08)
					buf:writeByte(id)
				if player:isSupported('ExtEntityPositions')then
					buf:writeVarInt(cx, cy, cz)
				else
					buf:writeVarShort(cx, cy, cz)
				end
					buf:writeVarByte(cay, cap)
				buf:sendTo(player:getClient())
			end
		end)
	end,

	spawn = function(self)
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
			local buf = player._buf
			buf:reset()
				buf:writeByte(0x0C)
				buf:writeByte(self.id)
			buf:sendTo(player:getClient())
		end)
		self.isSpawned = false
		return true
	end,

	destroy = function(self)
		entities[self.id] = nil
		self:despawn()
		return true
	end,

	isMob = true
}

mob_mt.__index = mob_mt

function findMobFreeID()
	local s = -2
	while entities[s]do
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

	local pos = newVector(x, y, z)
	local eye = newAngle(yaw or 0, pitch or 0)
	local mob = setmetatable({
		id = id,
		pos = pos,
		eye = eye,
		model = type,
		isSpawned = false,
		worldName = world
	}, mob_mt)

	entities[id] = mob
	return mob
end

hooks:add('postPlayerFirstSpawn', 'mobs', function(player)
	for id = -128, -2 do
		local mob = entities[id]
		if mob then
			spawnMobFor(mob, player)
		end
	end
end)
