local SURV_MOBS_COUNT = 50
local SURV_MOBS_PEACEFUL = {
	'pig', 'sheep', 'chicken'
}
local SURV_MOBS_ANGRY = {
	'zombie', 'skeleton', 'spider', 'creeper'
}

local MOB_STEP = 5
local MOB_STEP_INVERVAL = 2
local MOB_ANGRY_SPAWN_COUNT = 20
local MOB_ANGRY_ATTACK_DISTANCE = 10

local mobs = {}

local mobsLastUpdate

function survMobsSpawnPeaceful(world)
	for i = 1, SURV_MOBS_COUNT do
		local x, z = math.random(world.data.dimensions.x) - 1, math.random(world.data.dimensions.z) - 1

		local mobType = SURV_MOBS_PEACEFUL[math.random(#SURV_MOBS_PEACEFUL)]

		local startScanHeight = math.min(world.data.dimensions.y - 1, math.floor(world.data.dimensions.y / 2 + 10))
		for y = startScanHeight, world.data.dimensions.y / 2, -1 do
			if world:getBlock(x, y, z) ~= 0 then
				local mob = newMob(mobType, world:getName(), x, y + 2.59375, z)
				if not mob then
					return 'Not enough id\'s for mobs. Spawned ' .. (i - 1) .. ' mobs.'
				end

				mob:spawn()
				table.insert(mobs, mob)

				log.debug("Mob spawned in "..x..", "..y..", "..z)
				break
			end
		end
	end
end

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

	survMobsSpawnPeaceful(world)

	if world.ctpreset == 'night' then
		survMobsSpawnAngry(world)
	end

	timer.Resume('Mobs_AI')
	timer.Resume('Mobs_smooth_moving')
end)

addCommand('mobs-delete', function(isConsole, player, args)
	for i = 1, #mobs do
		local Mob = mobs[i]
		Mob:destroy()
	end

	timer.Pause('Mobs_AI')
	timer.Pause('Mobs_smooth_moving')
end)

timer.Create('Mobs_AI', -1, MOB_STEP_INVERVAL, function()
	mobsLastUpdate = gettime()

	for i = 1, #mobs do
		local Mob = mobs[i]
		local world = getWorld(Mob.worldName)

		-- angry mobs
		if Mob.isAngry then
			local distanceTemp
			local distanceMin = MOB_ANGRY_ATTACK_DISTANCE
			local playerMin

			playersForEach(function(player)
				if getWorld(player) == world then
					--distanceTemp = distance(Mob:getPos(), player:getPos())
					distanceTemp = distance(Mob.pos.x, Mob.pos.y, Mob.pos.z, player.pos.x, player.pos.y, player.pos.z)
					if distanceTemp < distanceMin then
						distanceMin = distanceTemp
						playerMin = player
					end
				end
			end)

			if playerMin then
				Mob.startX, Mob.startZ = Mob.pos.x, Mob.pos.z

				Mob.dirX = playerMin.pos.x - Mob.pos.x
				Mob.dirZ = playerMin.pos.z - Mob.pos.z

				Mob.target = true
			else
				Mob.target = false
			end
		end

		-- peaceful mobs
		if not Mob.target then
			if Mob.dirX then
				Mob.dirX, Mob.dirZ = Mob.dirX / 10 + math.random() - .5, Mob.dirZ / 10 + math.random() - .5
			else
				Mob.dirX, Mob.dirZ = math.random() - .5, math.random() - .5
			end

			local length = math.sqrt(Mob.dirX^2 + Mob.dirZ^2)
			Mob.dirX, Mob.dirZ = Mob.dirX / length * MOB_STEP, Mob.dirZ / length * MOB_STEP

			Mob.startX, Mob.startZ = Mob.pos.x, Mob.pos.z

			local dimx, dimy, dimz = world:getDimensions()
			if Mob.startX + Mob.dirX > dimx or Mob.startX + Mob.dirX < 0 then
				Mob.dirX = -Mob.dirX
			end
			if Mob.startZ + Mob.dirZ > dimz or Mob.startX + Mob.dirX < 0 then
				Mob.dirZ = -Mob.dirZ
			end
		end

		Mob.eye.yaw = (toAngle(Mob.dirX, Mob.dirZ) + 90) % 360
	end
end)

timer.Create('Mobs_smooth_moving', -1, 0.1, function()
	local thisTime = gettime()

	for i = 1, #mobs do
		local Mob = mobs[i]
		if not Mob.dirX then break end

		local world = getWorld(Mob.worldName)

		Mob.pos.x = Mob.startX + Mob.dirX * (thisTime - mobsLastUpdate) / MOB_STEP_INVERVAL
		Mob.pos.z = Mob.startZ + Mob.dirZ * (thisTime - mobsLastUpdate) / MOB_STEP_INVERVAL

		local blockInside = world:getBlock(math.floor(Mob.pos.x), math.floor(Mob.pos.y - 1), math.floor(Mob.pos.z))
		local blockUnder = world:getBlock(math.floor(Mob.pos.x), math.floor(Mob.pos.y - 2), math.floor(Mob.pos.z))
		if blockUnder == 0 then
			Mob.pos.y = Mob.pos.y - 1
		elseif blockInside ~= 0 and blockInside ~= 53 then
			Mob.pos.y = Mob.pos.y + 1
		end
		Mob:updatePos()
	end
end)

timer.Pause('Mobs_AI')
timer.Pause('Mobs_smooth_moving')

function survMobsSpawnAngry(world)
	for i = 1, MOB_ANGRY_SPAWN_COUNT do
		local x, z = math.random(world.data.dimensions.x) - 1, math.random(world.data.dimensions.z) - 1

		local mobType = SURV_MOBS_ANGRY[math.random(#SURV_MOBS_ANGRY)]

		local startScanHeight = math.min(world.data.dimensions.y - 1, math.floor(world.data.dimensions.y / 2 + 10))
		for y = startScanHeight, world.data.dimensions.y / 2, -1 do
			if world:getBlock(x, y, z) ~= 0 then
				local mob = newMob(mobType, world:getName(), x, y + 2.59375, z)
				if not mob then
					return
				end

				mob:spawn()
				mob.isAngry = true
				table.insert(mobs, mob)

				log.debug("Mob spawned in "..x..", "..y..", "..z)
				break
			end
		end
	end
end

hooks:add('survOnDayNightChange', 'surv_craft', function(world)
	if world.ctpreset == 'night' then
		survMobsSpawnAngry(world)
	elseif world.ctpreset == 'day' then
		for i = #mobs, 1, -1 do
			local Mob = mobs[i]

			if Mob.isAngry then
				table.remove(mobs, i)
				Mob:destroy()
			end
		end
	end
end)
