local wt = {}

WT_SUNNY = 0
WT_RAIN  = 1
WT_SNOW  = 2
WT = {[0]='sunny','rain','snow'}
WTN = {}
for k, v in pairs(WT)do
	WTN[v] = k
end

local function weatherFor(player, w)
	if player:isSupported('EnvWeatherType')then
		player:sendPacket(false, 0x1f, w)
	end
end

function wt:load()
	registerSvPacket(0x1f, '>BB')
	getWorldMT().setWeather = function(world, w)
		world = getWorld(world)
		if not world then return false end
		w = WTN[w]or w

		w = math.max(math.min(w,2),0)
		playersForEach(function(player)
			if player:isInWorld(world)then
				weatherFor(player, w)
			end
		end)
		world:setData('weather', w)
		return true
	end
	getWorldMT().getWeather = function(world)
		return world:getData('weather')or 0
	end
end

function wt:prePlayerSpawn(player)
	weatherFor(player, getWorld(player):getData('weather') or WT_SUNNY)
end

return wt
