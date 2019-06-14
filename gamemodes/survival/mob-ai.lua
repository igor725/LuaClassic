-- Mobs only for testing! It's not ready!!!
addCommand('mob', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end

	local world = getWorld(player)
	local mobType = 'pig'
	if #args > 0 then
		mobType = args[1]
	end

	local Mob = newMob(mobType, world:getName(), player:getPos())

	Mob:spawn()

	timer.Create('Mobs timer' .. (os.time()*math.random()), -1, 1, function()
		local MOB_STEP = 2

		--local lpX, lpY, lpZ = Mob.pos.x, Mob.pos.y, Mob.pos.z
		local dx, dz = MOB_STEP * (math.random() * 2 - 1), MOB_STEP * (math.random() * 2 - 1)

		Mob.pos.x = Mob.pos.x + dx
		Mob.pos.z = Mob.pos.z + dz

		if world:getBlock(math.floor(Mob.pos.x), math.floor(Mob.pos.y - 2), math.floor(Mob.pos.z)) == 0 then
			Mob.pos.y = Mob.pos.y - 1
		elseif world:getBlock(math.floor(Mob.pos.x), math.floor(Mob.pos.y - 1), math.floor(Mob.pos.z)) ~= 0 then
			Mob.pos.y = Mob.pos.y + 1
		end

		Mob.eye.yaw = (toAngle(dx, dz) + 90) % 360

		Mob:updatePos()
	end)
end)

-- Mobs only for testing! It's not ready!!!
addCommand('mobs', function(isConsole, player, args)
	local world = nil
	if isConsole then
		if #args > 0 then
			world = getWorld(args[1])
		else
			return false
		end
	else
		world = getWorld(player)
	end

	local SURV_MOBS_COUNT = 20
	local SURV_MOBS_PEACEFUL = {
		'pig', 'sheep', 'chicken'
	}
	local SURV_MOBS_ANGRY = {
		'zombie', 'skeleton', 'spider', 'creeper'
	}

	local mobsEngineMobs = {}

	for i = 1, SURV_MOBS_COUNT do
		local x, z = math.random(world.data.dimensions.x) - 1, math.random(world.data.dimensions.z) - 1

		local mobType = SURV_MOBS_PEACEFUL[math.random(#SURV_MOBS_PEACEFUL)]

		local startScanHeight = math.min(world.data.dimensions.y - 1, math.floor(world.data.dimensions.y / 2 + 10))
		for y = startScanHeight, world.data.dimensions.y / 2, -1 do
			if world:getBlock(x, y, z) ~= 0 then
				local mob = newMob(mobType, world:getName(), x, y + 2, z)
				mob:spawn()
				mobsEngineMobs[#mobsEngineMobs+1] = mob

				log.debug("Mob spawned in "..x..", "..y..", "..z)
				break
			end
		end
	end

	timer.Create('Mobs engine moving' .. (os.time()*math.random()), -1, 0.1, function()
		if mobsEngineLastUpdate then
			local thisTime = gettime()

			for i = 1, #mobsEngineMobs do
				local Mob = mobsEngineMobs[i]

				Mob.pos.x = Mob.startX + Mob.dirX * (thisTime - mobsEngineLastUpdate) / 3
				Mob.pos.y = Mob.startY + Mob.dirY * (thisTime - mobsEngineLastUpdate) / 3
				Mob.pos.z = Mob.startZ + Mob.dirZ * (thisTime - mobsEngineLastUpdate) / 3
				Mob:updatePos()
			end
		end
	end)

	timer.Create('Mobs engine' .. (os.time()*math.random()), -1, 3, function()
		local MOB_STEP = 5
		mobsEngineLastUpdate = gettime()

		for i = 1, #mobsEngineMobs do
			local Mob = mobsEngineMobs[i]
			local world = getWorld(Mob.worldName)

			Mob.dirX, Mob.dirZ = MOB_STEP * (math.random() * 2 - 1), MOB_STEP * (math.random() * 2 - 1)
			Mob.startX, Mob.startY, Mob.startZ = Mob.pos.x, Mob.pos.y, Mob.pos.z

			if world:getBlock(math.floor(Mob.pos.x), math.floor(Mob.pos.y - 2), math.floor(Mob.pos.z)) == 0 then
				Mob.dirY = -1
			elseif world:getBlock(math.floor(Mob.pos.x), math.floor(Mob.pos.y - 1), math.floor(Mob.pos.z)) ~= 0 then
				Mob.dirY = 1
			else
				Mob.dirY = 0
			end

			Mob.eye.yaw = (toAngle(Mob.dirX, Mob.dirZ) + 90) % 360

			--Mob:updatePos()
		end
	end)
end)
