--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

SURV_DNTIME = 480
SURV_SDTIME = 120

local ptime = {
	['day']    = 0,
	['sunset'] = SURV_DNTIME,
	['night']  = SURV_DNTIME + SURV_SDTIME,
	['dawn']   = SURV_DNTIME * 2 + SURV_SDTIME
}

function survUpdateWorldTime(world)
	if world:getData('isNether') then return end
	local ds = SURV_DNTIME + SURV_SDTIME
	local dsn = SURV_DNTIME * 2 + SURV_SDTIME
	local dsns = SURV_DNTIME * 2 + SURV_SDTIME * 2
	local time = world:getData('time')

	if time < SURV_DNTIME then
		if world.ctpreset ~= 'day'then
			world.ctpreset = 'day'
			world:setTime('day')
		end
	elseif time < ds then
		if world.ctpreset ~= 'dawn'then
			world.ctpreset = 'dawn'
			world:setTime('dawn')
		end
	elseif time < dsn then
		if world.ctpreset ~= 'night'then
			world.ctpreset = 'night'
			world:setTime('night')
		end
	elseif time < dsns then
		if world.ctpreset ~= 'sunset'then
			world.ctpreset = 'sunset'
			world:setTime('dawn')
		end
	else
		world:setData('time', -1)
	end
end


addCommand('time', function(isConsole, player, args)
	local world, timeval
	if isConsole then
		if #args < 1 then return false end
		world = getWorld(args[1])
		timeval = args[2]
	else
		if #args < 2 then
			world = getWorld(player)
			timeval = args[1]
		else
			world = getWorld(args[1])
			timeval = args[2]
		end
	end

	local tmp = tonumber(timeval)
	if tmp then
		timeval = tmp
	else
		timeval = ptime[timeval]
	end

	if not timeval and world then
		return ('Time in &a%s&f now is: %d'):format(world, world:getData('time'))
	elseif not world then
		return WORLD_NF
	elseif not timeval then
		return
	end

	world:setData('time', timeval)
	survUpdateWorldTime(world)

	return (CMD_TIMECHANGE):format(world, timeval)
end)

addCommand('freezetime', function(isConsole, player, args)
	local world, timeval
	if isConsole then
		if #args < 1 then return false end
		world = getWorld(args[1])
	else
		if #args < 1 then
			world = getWorld(player)
		else
			world = getWorld(args[1])
		end
	end

	if world then
		local tf = world:getData('timefrozen')
		world.data.timefrozen = (tf == 1 and 0)or 1
		if tf == 1 then
			return 'Time resumed'
		else
			return 'Time is frozen'
		end
	end
end)

timer.Create('daynight_cycle', -1, 1, function()
	worldsForEach(function(world)
		if world:getData('timefrozen') ~= 1 then
			world.data.time = (world.data.time or -1) + 1
			survUpdateWorldTime(world)
		end
	end)
end)

addWSave('time', '>H')
addWSave('timefrozen', 'b')
