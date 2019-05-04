local ema = {
	global = true
}

MEP_SIDESBLOCK     = 0
MEP_EDGEBLOCK      = 1
MEP_EDGELEVEL      = 2
MEP_CLOUDSLEVEL    = 3
MEP_MAXFOGDIST     = 4
MEP_CLOUDSPEED     = 5
MEP_WEATHERSPEED   = 6
MEP_WEATHERFADE    = 7
MEP_EXPFOG         = 8
MEP_MAPSIDESOFFSET = 9

local function updateMapPropertyFor(player, typ, val)
	if player:isSupported('EnvMapAspect')then
		player:sendPacket(false, 0x029, typ, val)
	end
end

local function setTexturePackFor(player, tpack)
	if player:isSupported('EnvMapAspect')then
		player:sendPacket(false, 0x28, tpack)
	end
end

local function getMa(world)
	world = getWorld(world)
	local ma = world:getData('map_aspects')
	if not ma then
		ma = {}
		world.data.map_aspects = ma
	end
	return ma
end

function ema:load()
	registerSvPacket(0x28,'Bc64')
	registerSvPacket(0x29,'>BBi')
	getWorldMT().setEnvProp = function(...)
		return ema:set(...)
	end
	getWorldMT().setTexPack = function(...)
		return ema:setTexturePack(...)
	end
end

function ema:prePlayerSpawn(player)
	local wn = player.worldName
	local world = getWorld(wn)

	for typ, val in pairs(getMa(wn))do
		updateMapPropertyFor(player, typ, val)
	end
	if world.data.texPack then
		setTexturePackFor(player, world.data.texPack)
	else
		setTexturePackFor(player, '')
	end
end

function ema:setTexturePack(world, tpack)
	world = getWorld(world)
	if tpack:sub(1,7)=='http://'or tpack:sub(1,8)=='https://'or tpack==''then
		if #tpack>64 then
			return false, 'url_too_long'
		end
		world.data.texPack = tpack
		playersForEach(function(player)
			if player:isInWorld(world)then
				setTexturePackFor(player, tpack)
			end
		end)
		return true
	else
		return false, 'invalid_protocol'
	end
end

function ema:set(world, typ, val)
	getMa(world)[typ] = val
	playersForEach(function(player)
		if player:isInWorld(world)then
			updateMapPropertyFor(player, typ, val)
		end
	end)
end

return ema
