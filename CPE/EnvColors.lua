local ec = {
	global = true
}

EC_SKY     = 0
EC_CLOUD   = 1
EC_FOG     = 2
EC_AMBIENT = 3
EC_DIFFUSE = 4

time_presets = {
	dawn = {
		[EC_DIFFUSE] = newColor(65,55,55),
		[EC_AMBIENT] = newColor(50,50,50),
		[EC_FOG] = newColor(60,47,40),
		[EC_CLOUD] = newColor(60,47,40),
		[EC_SKY] = newColor(91,43,18)
	},
	night = {
		[EC_DIFFUSE] = newColor(85,85,85),
		[EC_AMBIENT] = newColor(40,40,40),
		[EC_FOG] = newColor(23,28,42),
		[EC_CLOUD] = newColor(36,39,49),
		[EC_SKY] = newColor(23,28,42)
	},
	day = {
		[EC_DIFFUSE] = newColor(),
		[EC_AMBIENT] = newColor(),
		[EC_FOG] = newColor(240,240,240),
		[EC_CLOUD] = newColor(253,253,253),
		[EC_SKY] = newColor(153,204,255)
	}
}

local function updateEnvColorsFor(player, typ, r, g, b)
	if player:isSupported('EnvColors')then
		player:sendPacket(false, 0x19, typ, r or-1, g or-1, b or-1)
	end
end

local function getClrs(world)
	world = getWorld(world)
	local clr = world:getData('colors')
	if not clr then
		clr = {}
		world.data.colors = clr
	end
	return clr
end

function ec:load()
	registerSvPacket(0x19,'>Bbhhh')
	getWorldMT().setEnvColor = function(...)
		return ec:set(...)
	end
	getWorldMT().getEnvColor = function(self, typ)
		local c = self.data.colors[typ]
		return c.r, c.g, c.b
	end
end

function ec:setFor(player, typ, r, g, b)
	updateEnvColorsFor(player, typ, r, g, b)
end

function ec:prePlayerSpawn(player)
	local colors = getClrs(player.worldName)
	for i=0,4 do
		local c = colors[i]
		if c then
			updateEnvColorsFor(player, i, c.r, c.g, c.b)
		else
			updateEnvColorsFor(player, i)
		end
	end
end

function ec:set(world, typ, r, g, b)
	local colors = getClrs(world)
	local clr = colors[typ]
	if clr then
		clr.r, clr.g, clr.b = r, g, b
	else
		colors[typ] = newColor(r,g,b)
	end
	playersForEach(function(player)
		if player:isInWorld(world)then
			updateEnvColorsFor(player, typ, r, g, b)
		end
	end)
	return true
end

return ec
