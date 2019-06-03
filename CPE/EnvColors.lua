local ec = {}

EC_SKY     = 0
EC_CLOUD   = 1
EC_FOG     = 2
EC_AMBIENT = 3
EC_DIFFUSE = 4

time_presets = {
	dawn = {
		[EC_DIFFUSE] = newColor(065,055,055),
		[EC_AMBIENT] = newColor(050,050,050),
		[EC_FOG]     = newColor(060,047,040),
		[EC_CLOUD]   = newColor(060,047,040),
		[EC_SKY]     = newColor(091,043,018)
	},
	night = {
		[EC_DIFFUSE] = newColor(085,085,085),
		[EC_AMBIENT] = newColor(040,040,040),
		[EC_FOG]     = newColor(023,028,042),
		[EC_CLOUD]   = newColor(036,039,049),
		[EC_SKY]     = newColor(023,028,042)
	},
	day = {
		[EC_DIFFUSE] = newColor(),
		[EC_AMBIENT] = newColor(),
		[EC_FOG]     = newColor(240,240,240),
		[EC_CLOUD]   = newColor(253,253,253),
		[EC_SKY]     = newColor(153,204,255)
	}
}

local function updateEnvColorsFor(player, typ, r, g, b)
	if player:isSupported('EnvColors')then
		player:sendPacket(false, 0x19, typ, r or -1, g or -1, b or -1)
	end
end

local function getClrs(world)
	world = getWorld(world)
	local clr = world:getData('colors')
	if not clr then
		clr = {}
		world:setData('colors', clr)
	end
	return clr
end

function ec:load()
	registerSvPacket(0x19,'>bbhhh')
	getPlayerMT().setEnvColor = function(player, typ, r, g, b)
		updateEnvColorsFor(player, typ, r, g, b)
	end
	getWorldMT().setEnvColor = function(world, typ, r, g, b)
		local colors = getClrs(world)
		local clr = colors[typ]
		if clr then
			clr.r, clr.g, clr.b = r, g, b
		else
			colors[typ] = newColor(r, g, b)
		end
		playersForEach(function(player)
			if player:isInWorld(world)then
				updateEnvColorsFor(player, typ, r, g, b)
			end
		end)
		return true
	end
	getWorldMT().getEnvColor = function(self, typ)
		local c = self.data.colors[typ]
		return c.r, c.g, c.b
	end
end

function ec:prePlayerSpawn(player)
	local colors = getClrs(player.worldName)
	for i = 0, 4 do
		local c = colors[i]
		if c then
			updateEnvColorsFor(player, i, c.r, c.g, c.b)
		else
			updateEnvColorsFor(player, i)
		end
	end
end

return ec
