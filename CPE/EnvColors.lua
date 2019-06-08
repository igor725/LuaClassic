local ec = {}

EC_SKY     = 0
EC_CLOUD   = 1
EC_FOG     = 2
EC_AMBIENT = 3
EC_DIFFUSE = 4

time_presets = {
	dawn = {
		[EC_DIFFUSE] = newColor(0x41, 0x37, 0x37),
		[EC_AMBIENT] = newColor(0x32, 0x32, 0x32),
		[EC_FOG]     = newColor(0x3C, 0x2F, 0x28),
		[EC_CLOUD]   = newColor(0x3C, 0x2F, 0x28),
		[EC_SKY]     = newColor(0x5B, 0x2B, 0x12)
	},
	night = {
		[EC_DIFFUSE] = newColor(0x55, 0x55, 0x55),
		[EC_AMBIENT] = newColor(0x28, 0x28, 0x28),
		[EC_FOG]     = newColor(0x17, 0x1C, 0x42),
		[EC_CLOUD]   = newColor(0x24, 0x27, 0x31),
		[EC_SKY]     = newColor(0x17, 0x1C, 0x2A)
	},
	day = {
		[EC_DIFFUSE] = newColor(0xFF, 0xFF, 0xFF),
		[EC_AMBIENT] = newColor(0x9B, 0x9B, 0x9B),
		[EC_FOG]     = newColor(0xFF, 0xFF, 0xFF),
		[EC_CLOUD]   = newColor(0xFF, 0xFF, 0xFF),
		[EC_SKY]     = newColor(0x99, 0xCC, 0xFF)
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
	getWorldMT().getEnvColor = function(world, typ)
		local c = world.data.colors[typ]
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
