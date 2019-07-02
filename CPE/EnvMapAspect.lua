--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local ema = {}

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
		world:setData('map_aspects', ma)
	end
	return ma
end

function ema:load()
	registerSvPacket(0x28, 'bc64')
	registerSvPacket(0x29, '>bbi')
	getPlayerMT().setEnvProp = function(player, typ, val)
		updateMapPropertyFor(player, typ, val)
	end
	getWorldMT().setEnvProp = function(world, typ, val)
		getMa(world)[typ] = val
		playersForEach(function(player)
			if player:isInWorld(world)then
				updateMapPropertyFor(player, typ, val)
			end
		end)
	end
	getWorldMT().setTexPack = function(world, tpack)
		world = getWorld(world)
		if tpack:startsWith('http://')or tpack:startsWith('https://')or tpack == ''then
			if #tpack > 64 then
				return false, 'url_too_long'
			end
			world:setData('texPack', tpack)
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
end

function ema:prePlayerSpawn(player)
	if not player.firstSpawn then return end
	
	local world = getWorld(player)

	for typ, val in pairs(getMa(player.worldName))do
		updateMapPropertyFor(player, typ, val)
	end

	local tpack = world:getData('texPack')
	if tpack then
		setTexturePackFor(player, tpack)
	else
		setTexturePackFor(player, config:get('texPack')or'')
	end
end

return ema
