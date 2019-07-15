--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

ffi.cdef[[
	struct blockDef {
		uint8_t packetId,
		id,
		name[64],
		solidity,
		moveSpeed,
		topTex,
		sideTex,
		bottomTex,
		transLight,
		walkSound,
		fullBright,
		shape,
		blockDraw,
		fogDensity,
		fogR,
		fogG,
		fogB;
	};
]]

local blockDef = ffi.typeof('struct blockDef')
local blockDefSz = ffi.sizeof(blockDef)

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

local function defineBlockFor(player, bds)
	if not ffi.istype(blockDef, bds)then return end
	if not player:isSupported('BlockDefinitions')then return end
	player:sendNetMesg(bds, blockDefSz)
end

local function removeDefinedBlock(player, id)
	if player:isSupported('BlockDefinitions')then
		local buf = player._bufwr
		buf:reset()
			buf:writeByte(0x24)
			buf:writeByte(id)
		buf:sendTo(player:getClient())
	end
end

function bd:load()
	hooks:create('onBlockDefined')
	hooks:create('onBlockUndefined')
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

function bd:getOpt(id, optkey)
	local b = self.definedBlocks[id]
	if b then
		return b[optkey]
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
	for id, bds in pairs(self.definedBlocks)do
		defineBlockFor(player, bds)
	end
end

function bd:create(opts)
	if isValidBlockID(opts.id)then return false end
	opts.packetId = 0x23
	opts.name = opts.name or'Unnamed block'
	opts.solidity = opts.solidity or 2
	opts.moveSpeed = opts.moveSpeed or 128
	opts.topTex = opts.topTex or opts.tex or 1
	opts.sideTex = opts.sideTex or opts.tex or 1
	opts.bottomTex = opts.bottomTex or opts.tex or 1
	opts.transLight = opts.transLight or 0
	opts.walkSound = opts.walkSound or 2
	opts.fullBright = opts.fullBright or 0
	opts.shape = opts.shape or 16
	opts.blockDraw = opts.blockDraw or 0
	opts.fogDensity = opts.fogDensity or 0
	opts.fogR = opts.fogR or 0
	opts.fogG = opts.fogG or 0
	opts.fogB = opts.fogB or 0

	local bds = ffi.new('struct blockDef', opts)
	local nmlen = #opts.name
	ffi.fill(bds.name + nmlen, 64 - nmlen, 32)
	self.definedBlocks[opts.id] = bds
	playersForEach(function(player)
		defineBlockFor(player, bds)
	end)
	hooks:call('onBlockDefined', bds)
	return true
end

return bd
