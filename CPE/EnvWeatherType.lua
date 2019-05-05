local wt = {
	global = true
}

WT_SUNNY = 0
WT_RAIN  = 1
WT_SNOW  = 2

local function weatherFor(player, w)
	if player:isSupported('EnvWeatherType')then
		player:sendPacket(false, 0x1f, w)
	end
end

function wt:load()
	registerSvPacket(0x1f, '>BB')
	addChatCommand('weather',function(player,wtt)
		wtt = tonumber(wtt)
		if wtt then
			self:setWeather(player.worldName, wtt)
		end
	end)
	getWorldMT().setWeather = function(...)
		return wt:setWeather(...)
	end
end

function wt:prePlayerSpawn(player)
	weatherFor(player, worlds[player.worldName].data.weather or WT_SUNNY)
end

function wt:setWeather(world, w)
	world = getWorld(world)
	w = math.max(math.min(w,2),0)
	playersForEach(function(player)
		if player:isInWorld(world)then
			weatherFor(player, w)
		end
	end)
	world:setData('weather', w)
	return true
end

return wt
