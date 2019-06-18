--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local timers = {'_blocksdamage', '_hp_regen'}

function survPauseTimers(player)
	local name = player:getName()
	for i = 1, #timers do
		timer.Pause(name .. timers[i])
	end
end

function survResumeTimers(player)
	local name = player:getName()
	for i = 1, #timers do
		timer.Resume(name .. timers[i])
	end
end

function survRemoveTimers(player)
	local name = player:getName()
	for i = 1, #timers do
		timer.Remove(name .. timers[i])
	end
end

hooks:add('postPlayerFirstSpawn', 'surv_timers', function(player)
	local name = player:getName()
	timer.Create(name .. '_hp_regen', -1, 5, function()
		local int, fr = math.modf(player.health)
		if fr ~= 0 and fr ~= .5 then fr = .5 end
		local ahp = math.min(SURV_MAX_HEALTH, int + fr + .5)
		player.health = ahp
		survUpdateHealth(player)
	end)

	timer.Create(name .. '_blocksdamage', -1, .4, function()
		local x, y, z = player:getPos()
		x, y, z = floor(x), floor(y - 1), floor(z)
		local world = getWorld(player)

		if world:getBlock(x, y, z) == 54
		or world:getBlock(x, y + 1, z) == 54 then
			survDamage(nil, player, .5, SURV_DMG_FIRE)
		end

		local level, isLava = player:getFluidLevel()
		if isLava then
			survDamage(nil, player, 1, SURV_DMG_LAVA)
			return
		end
		if level > 1 then
			player.oxygen = math.max(player.oxygen - .2, 0)
			if player.oxygen == 0 then
				survDamage(nil, player, 1, SURV_DMG_WATER)
			end
			survUpdateOxygen(player)
			player.oxyshow = true
		else
			if player.oxyshow then
				player.oxygen = math.min(player.oxygen + .05, SURV_MAX_OXYGEN)
				survUpdateOxygen(player)
			end
		end
	end)

	if player.isInGodmode then
		survPauseTimers(player)
	end
end)

hooks:add('postPlayerSpawn', 'surv_timers', function(player)
	if player.isInGodmode then
		survPauseTimers(player)
	else
		survResumeTimers(player)
	end
end)

hooks:add('onPlayerDespawn', 'surv_timers', function(player)
	survPauseTimers(player)
end)

hooks:add('onPlayerDestroy', 'surv_timers', function(player)
	survRemoveTimers(player)
end)
