--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

ffi.cdef[[
	struct blockDefEx {
		uint8_t packetId,
		id,
		name[64],
		solidity,
		moveSpeed,
		topTex,
		leftTex,
		rightTex,
		frontTex,
		backTex,
		bottomTex,
		transLight,
		walkSound,
		fullBright,
		minX,
		minY,
		minZ,
		maxX,
		maxY,
		maxZ,
		blockDraw,
		fogDensity,
		fogR,
		fogG,
		fogB;
	};
]]

local blockDefEx = ffi.typeof('struct blockDefEx')
local blockDefExSz = ffi.sizeof(blockDefEx)

local bde = {
	version = 2
}

local function defineExBlockFor(player, bds)
	if not ffi.istype(blockDefEx, bds)then return end
	if not player:isSupported('BlockDefinitionsExt', 2)then return end
	player:sendNetMesg(bds, blockDefExSz)
end

function bde:load()
	local bd = BlockDefinitions
	bd.definedExBlocks = {}

	function bd:createEx(opts)
		opts.packetId = 0x25
		opts.name = opts.name or'Unnamed block'
		opts.solidity = opts.solidity or 2
		opts.moveSpeed = opts.moveSpeed or 128
		opts.topTex = opts.topTex or opts.tex or 1
		opts.leftTex = opts.leftTex or opts.tex or 1
		opts.rightTex = opts.rightTex or opts.tex or 1
		opts.frontTex = opts.frontTex or opts.tex or 1
		opts.backTex = opts.backTex or opts.tex or 1
		opts.bottomTex = opts.bottomTex or opts.tex or 1
		opts.transLight = opts.transLight or 0
		opts.walkSound = opts.walkSound or 2
		opts.fullBright = opts.fullBright or 0
		opts.minX = opts.minX or 0
		opts.minY = opts.minY or 0
		opts.minZ = opts.minZ or 0
		opts.maxX = opts.maxX or 16
		opts.maxY = opts.maxY or 16
		opts.maxZ = opts.maxZ or 16
		opts.blockDraw = opts.blockDraw or 0
		opts.fogDensity = opts.fogDensity or 0
		opts.fogR = opts.fogR or 0
		opts.fogG = opts.fogG or 0
		opts.fogB = opts.fogB or 0

		local bds = blockDefEx(opts)
		local nmlen = #opts.name
		ffi.fill(bds.name + nmlen, 64 - nmlen, 32)
		self.definedBlocks[opts.id] = bds
		playersForEach(function(player)
			defineExBlockFor(player, bds)
		end)
		hooks:call('onBlockDefined', bds, true)
		return true
	end
end

function bde:prePlayerSpawn(player)
	for _, opts in pairs(BlockDefinitions.definedBlocks)do
		defineExBlockFor(player, opts)
	end
end

return bde
