--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

--TODO: Try to use C structs instead of lua tables
local bde = {
	version = 2
}

local function defineExBlockFor(player, opts)
	if player:isSupported('BlockDefinitionsExt', 2) then
		opts.name = opts.name or'Unnamed block'
		opts.solidity = opts.solidity or 2
		opts.movespeed = opts.movespeed or 128
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

local function removeDefinedBlock(player, id)
	if player:isSupported('BlockDefinitions')then
		player:sendPacket(false, 0x24, id)
	end
end

function bde:load()
	registerSvPacket(0x25, 'bbc64bbbbbbbbbbbbbbbbbbbbbb')
	local bd = BlockDefinitions
	bd.definedExBlocks = {}

	function bd:createEx(opts)
		if self.definedBlocks[opts.id]then
			self.definedBlocks[opts.id] = nil
			self:remove(opts.id)
		end
		if isValidBlockID(opts.id)then return false end
		self.definedExBlocks[opts.id] = opts
		playersForEach(function(player)
			defineExBlockFor(player, opts)
		end)
		hooks:call('onBlockDefined', opts)
		return true
	end

	function bd:isDefined(id)
		if not id then return false end
		if self.definedBlocks[id]then
			return true
		elseif self.definedExBlocks and self.definedExBlocks[id]then
			return true
		end
		return false
	end

	function bd:remove(id)
		self.definedBlocks[id] = nil
		self.definedExBlocks[id] = nil
		playersForEach(function(player)
			removeDefinedBlock(player, id)
		end)
	end

	function bd:getOpt(id, optkey)
		local b = self.definedBlocks[id]
		if not b then
			b = self.definedExBlocks[id]
		end
		if b then
			return b[optkey]
		end
	end
end

function bde:prePlayerSpawn(player)
	local bd = BlockDefinitions
	for _, opts in pairs(bd.definedExBlocks)do
		defineExBlockFor(player, opts)
	end
end

return bde
