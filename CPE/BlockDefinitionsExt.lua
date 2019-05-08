--TODO: Try to use C structs instead of lua tables
local bde = {
	version = 2
}

local function defineExBlockFor(player, opts)
	if player:isSupported('BlockDefinitionsExt', 2)then
		opts.name = opts.name or'Unnamed block'
		opts.solidity = opts.solidity or 2
		opts.movespeed = opts.movespeed or 128
		opts.topTex = opts.topTex or 1
		opts.leftTex = opts.leftTex or 1
		opts.rightTex = opts.rightTex or 1
		opts.frontTex = opts.frontTex or 1
		opts.backTex = opts.backTex or 1
		opts.bottomTex = opts.bottomTex or 1
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

		player:sendPacket(
			false,
			0x25,
			opts.id,
			opts.name,
			opts.solidity,
			opts.movespeed,
			opts.topTex,
			opts.leftTex,
			opts.rightTex,
			opts.frontTex,
			opts.backTex,
			opts.bottomTex,
			opts.transLight,
			opts.walkSound,
			opts.fullBright,
			opts.minX,
			opts.minY,
			opts.minZ,
			opts.maxX,
			opts.maxY,
			opts.maxZ,
			opts.blockDraw,
			opts.fogDensity,
			opts.fogR,
			opts.fogG,
			opts.fogB
		)
	end
end

function bde:load()
	registerSvPacket(0x25, 'bbc64bbbbbbbbbbbbbbbbbbbbbb')
	local bd = BlockDefinitions
	bd.definedExBlocks = {}

	function bd:createEx(opts)
		self.definedExBlocks[opts.id] = opts
		playersForEach(function(player)
			defineExBlockFor(player, opts)
		end)
	end
end

function bde:prePlayerSpawn(player)
	local bd = BlockDefinitions
	for _, opts in pairs(bd.definedExBlocks)do
		defineExBlockFor(player, opts)
	end
end

return bde
