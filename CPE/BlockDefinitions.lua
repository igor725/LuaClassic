local bd = {
	definedBlocks = {},
	global = true
}

local function defineBlockFor(ply, opts)
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

	ply:sendPacket(
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

function bd:load()
	registerSvPacket(0x23, '>BBc64bbbbbbbbbbbbbb')
	registerSvPacket(0x24, '>BB')
end

function bd:Remove(id)
	playersForEach(function(player)
		if player:isSupported('BlockDefinitions')then
			removeDefinedBlock(player, id)
		end
	end)
end

function bd:Create(opts)
	bd.definedBlocks[opts.id] = opts
	playersForEach(function(ply)
		if ply:isSupported('BlockDefinitions')then
			defineBlockFor(ply, opts)
		end
	end)
end

return bd
