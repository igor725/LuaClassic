--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local ec = {}

EC_SKY     = 0
EC_CLOUD   = 1
EC_FOG     = 2
EC_AMBIENT = 3
EC_DIFFUSE = 4

time_presets = {
	night = {
		[EC_DIFFUSE] = newColor(0x80, 0x90, 0xA0),
		[EC_AMBIENT] = newColor(0x68, 0x68, 0x70),
		[EC_FOG]     = newColor(0x10, 0x10, 0x20),
		[EC_CLOUD]   = newColor(0x40, 0x40, 0x40),
		[EC_SKY]     = newColor(0x0A, 0x0A, 0x18)
	},
	dawn = {
		[EC_DIFFUSE] = newColor(0xC0, 0xC0, 0xC0),
		[EC_AMBIENT] = newColor(0x80, 0x70, 0x70),
		[EC_FOG]     = newColor(0xFF, 0x92, 0x00),
		[EC_CLOUD]   = newColor(0xC0, 0x90, 0x90),
		[EC_SKY]     = newColor(0x10, 0x10, 0x80)
	},
	day = {
		[EC_DIFFUSE] = newColor(0xFF, 0xFF, 0xFF),
		[EC_AMBIENT] = newColor(0x9B, 0x9B, 0x9B),
		[EC_FOG]     = newColor(0xB9, 0xEC, 0xFF),
		[EC_CLOUD]   = newColor(0xFF, 0xFF, 0xFF),
		[EC_SKY]     = newColor(0x99, 0xCC, 0xFF)
	}
}

local function updateEnvColorsFor(player, typ, r, g, b)
	if player:isSupported('EnvColors')then
		r, g, b = r or -1, g or -1, b or -1
		local buf = player._bufwr
		buf:reset()
			buf:writeByte(0x19)
			buf:writeByte(typ)
			buf:writeVarShort(r, g, b)
		buf:sendTo(player:getClient())
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
	getWorldMT().setTime = function(self, preset)
		local preset = time_presets[preset]
		if preset then
			for i = 0, 4 do
				local c = preset[i]
				self:setEnvColor(i, c.r, c.g, c.b)
			end
			return true
		end
		return false
	end
	getWorldMT().getEnvColor = function(world, typ)
		local c = world.data.colors[typ]
		if c then
			return c.r, c.g, c.b
		else
			return -1, -1, -1
		end
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
