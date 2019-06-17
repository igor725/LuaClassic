--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

--TODO: Try to use C structs instead of lua tables
local bd = {
	definedBlocks = {},
	global = true
}

BS_WALK         = 0
BS_SWIM         = 1
BS_SOLID        = 2

BD_OPAQUE       = 0
BD_TRANSPARENT  = 1
BD_CTRANSPARENT = 2
BD_TRANSLUCENT  = 3
BD_GAS          = 4

SND_NO          = 0
SND_WOOD        = 1
SND_GRAVEL      = 2
SND_GRASS       = 3
SND_STONE       = 4
SND_METAL       = 5
SND_GLASS       = 6
SND_WOOL        = 7
SND_SAND        = 8
SND_SNOW        = 9

local function defineBlockFor(player, opts)
	if player:isSupported('BlockDefinitions')then
		opts.name = opts.name or'Unnamed block'
		opts.solidity = opts.solidity or 2
		opts.movespeed = opts.movespeed or 128
		opts.topTex = opts.topTex or 1
		opts.sideTex = opts.sideTex or 1
		opts.bottomTex = opts.bottomTex or 1
		opts.transLight = opts.transLight or 0
		opts.walkSound = opts.walkSound or 2
		opts.fullBright = opts.fullBright or 0
		opts.shape = opts.shape or 16
		opts.blockDraw = opts.blockDraw or 0
		opts.fogDensity = opts.fogDensity or 0
		opts.fogR = opts.fogR or 0
		opts.fogG = opts.fogG or 0
		opts.fogB = opts.fogB or 0

		player:sendPacket(
			false,
			0x23,
			opts.id,
			opts.name,
			opts.solidity,
			opts.movespeed,
			opts.topTex,
			opts.sideTex,
			opts.bottomTex,
			opts.transLight,
			opts.walkSound,
			opts.fullBright,
			opts.shape,
			opts.blockDraw,
			opts.fogDensity,
			opts.fogR,
			opts.fogG,
			opts.fogB
		)
	end
end

local function removeDefinedBlock(player, id)
	if player:isSupported('BlockDefinitions')then
		player:sendPacket(false, 0x24, id)
	end
end

function bd:load()
	hooks:create('onBlockDefined')
	hooks:create('onBlockUndefined')
	registerSvPacket(0x23, 'bbc64bbbbbbbbbbbbbb')
	registerSvPacket(0x24, 'bb')
end

function bd:remove(id)
	if self.definedBlocks[id]and isValidBlockID(id)then
		self.definedBlocks[id] = nil
		playersForEach(function(player)
			removeDefinedBlock(player, id)
		end)
		hooks:call('onBlockUndefined', id)
	end
end

function bd:isDefined(id)
	if not id then return false end
	if self.definedBlocks[id]then
		return true
	end
	return false
end

function bd:prePlayerSpawn(player)
	for id, opts in pairs(self.definedBlocks)do
		defineBlockFor(player, opts)
	end
end

function bd:create(opts)
	if isValidBlockID(opts.id)then return false end
	self.definedBlocks[opts.id] = opts
	playersForEach(function(player)
		defineBlockFor(player, opts)
	end)
	hooks:call('onBlockDefined', opts)
	return true
end

return bd
