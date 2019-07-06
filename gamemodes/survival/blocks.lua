--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

SURV_STACK_SIZE = 99
SURV_BRK_DONE   = 10

SURV_ACT_NONE   = -1
SURV_ACT_BREAK  = 1

local survTools = {}
local survToolTypes = {}

local survMiningSpeed = {
	[-1] =  1,
	[1]  =  7.5,
	[2]  =  0.9,
	[3]  =  0.75,
	[4]  =  10,
	[5]  =  3,
	[6]  =  0,
	[12] =  0.75,
	[13] =  0.9,
	[14] =  15,
	[15] =  15,
	[16] =  15,
	[17] =  3,
	[18] =  0.35,
	[20] =  0.45,

	[41] = 15,
	[42] = 25,
	[43] = 10,
	[44] = 10,
	[45] = 10,
	[46] = 0,
	[47] = 3,
	[48] = 10,
	[49] = 250,
	[50] = 10,
	[51] = 0,
	[53] = 0.5,
	[54] = 0,
	[64] = 3,
	[65] = 7.5
}

local survMiningSpeedWithTool = {
	-- shovel
	{
		[2] = survMiningSpeed[2] / 2,
		[3] = survMiningSpeed[3] / 2,
		[12] = survMiningSpeed[12] / 2,
		[13] = survMiningSpeed[13] / 2,
		[53] = 0.1
	},
	-- pickaxe
	{
		[1]  =  1.15,
		[4]  =  1.5,
		[14] =  2.25,
		[15] =  2.25,
		[16] =  2.25,

		[41] = 2.25,
		[42] = 3.75,
		[43] = 3,
		[44] = 3,
		[45] = 3,
		[48] = 3,
		[50] = 3,
		[52] = 0.65,
		[65] = 1.15
	},
	-- axe
	{
		[5] = survMiningSpeed[5] / 2,
		[17] = survMiningSpeed[17] / 2,
		[47] = survMiningSpeed[47] / 2,
		[64] = survMiningSpeed[64] / 2
	},
	{
		[18] = 0.2
	}
}

for i = 21, 36 do
	survMiningSpeed[i] = 1.15
	survMiningSpeedWithTool[4][i] = 1.15 / 2
end

for i = 55, 60 do
	survMiningSpeed[i] = 1.15
	survMiningSpeedWithTool[4][i] = 1.15 / 2
end

for i = 37, 40 do
	survMiningSpeed[i] = 0
end

function survAddTool(id, toolType, speed)
	survTools[id] = speed
	survToolTypes[id] = toolType
end

function survSetMiningSpeed(id, speed)
	survMiningSpeed[id] = speed
end

function survPlayerGetTool(player)
	local toolType = survToolTypes[player.heldTool]
	if toolType then
		return survTools[player.heldTool], toolType
	end

	return
end

function survGetDropBlock(player, bid)
	if bid == 1 or bid == 4 then
		if player.heldTool == 0 then
			return 0
		else
			return 4
		end
	elseif bid == 2 then
		return 3
	elseif bid == 18 then
		local r = math.random(0, 100)
		local drp = (player.heldTool ~= 0 and 18)or 0
		return (r < 20 and 6)or(r < 40 and 149)or drp
	elseif bid == 20 or bid == 54 then
		return 0
	elseif
	(bid >= 14 and bid <= 16)or
	(bid >= 41 and bid <= 45)or
	(bid >= 48 and bid <= 50)or
	(bid >= 60 and bid <= 65)then
		if player.heldTool == 0 then
			return 0
		end
	end
	return bid
end

function survStopBreaking(player)
	if player.action ~= SURV_ACT_BREAK then return end

	player.breakProgress = 0
	player.action = SURV_ACT_NONE
	survUpdateMiningProgress(player)
	timer.Remove(player:getName() .. '_surv_brk')
end

function survBreakBlock(player, x, y, z)
	local world = getWorld(player)
	local cbid = world:getBlock(x, y, z)
	local heldBlock = player:getHeldBlock()
	local bid, count = survGetDropBlock(player, cbid)

	if not hooks:call('prePlayerPlaceBlock', player, x, y, z, 0)then
		if bid > 0 then
			if survInvAddBlock(player, bid, dcount or 1) > 0 then
				if heldBlock ~= bid and player.heldTool == 0 then
					player:holdThis(bid)
				end
			end
		end
		world:setBlock(x, y, z, 0)
		hooks:call('postPlayerPlaceBlock', player, x, y, z, 0, cbid)
	end

	survStopBreaking(player)
end

function survBlockAction(player, button, action, x, y, z)
	if player.isInGodmode then return end

	local world = getWorld(player)
	local bid = world:getBlock(x, y, z)
	if bid > 6 and bid < 12 then
		return
	end
	local cb = player.currClickedBlock
	cb.x, cb.y, cb.z = x, y, z

	if action == 0 and player.inventory[bid] < 255 then
		if player.action == SURV_ACT_NONE then
			if button == 0 then
				if world:isReadOnly()then
					player:sendMessage(WORLD_RO, MT_ANNOUNCE)
					return
				end
				player.action = SURV_ACT_BREAK
				player.breakProgress = 0
				local lb = player.lastClickedBlock
				lb.x, lb.y, lb.z = x, y, z
				local tmSpeed = (survMiningSpeed[bid]or survMiningSpeed[-1])
				if tmSpeed <= 0 then
					player.breakProgress = 10
					survBreakBlock(player, x, y, z)
					return
				end
				if player:getFluidLevel() > 1 then
					tmSpeed = tmSpeed * 5
				end

				local tool = player.heldTool
				if tool ~= 0 then
					if player.inventory[tool] > 0 then
						local toolType = survToolTypes[tool]
						if survMiningSpeedWithTool[toolType][bid] then
							tmSpeed = survMiningSpeedWithTool[toolType][bid] / survTools[tool]
						end
					else
						player:sendMessage(MESG_NOTOOL)
						player:holdThis(0)
					end
				end

				survUpdateMiningProgress(player)
				timer.Create(player:getName() .. '_surv_brk', 11, tmSpeed / 10, function()
					local lb = player.lastClickedBlock
					if lb.x ~= cb.x or lb.y ~= cb.y or lb.z ~= cb.z then
						survStopBreaking(player)
						return
					end

					if player.breakProgress == SURV_BRK_DONE then
						survBreakBlock(player, x, y, z)
					else
						player.breakProgress = math.min(player.breakProgress + 1, 100)
						survUpdateMiningProgress(player)
					end
				end)
			end
		end
	elseif action == 1 then
		if player.action == SURV_ACT_BREAK then
			survStopBreaking(player)
		end
	end
end

hooks:add('onPlayerDestroy', 'surv_blocks', function(player)
	survStopBreaking(player)
end)

hooks:add('onPlayerDespawn', 'surv_blocks', function(player)
	survStopBreaking(player)
end)

hooks:add('onHeldBlockChange', 'surv_blocks', function(player, id)
	if survTools[id] then
		player.heldTool = id
	else
		player.heldTool = 0
	end
end)

hooks:add('postPlayerPlaceBlock', 'surv_blocks', function(player, x, y, z, id, prev)
	if id == 0 and prev == 60 then
		if math.random(0, 1) == 1 then
			local world = getWorld(player)
			world:setBlock(x, y, z, 8)
			if doPhysicsFor then
				doPhysicsFor(world, x, y, z)
			end
		end
	elseif id == 6 then
		local world = getWorld(player)
		local dimx, dimy, dimz = world:getDimensions()

		if y == 0 then return end

		local treeType = 1
		if y > 1 and world:getBlock(x, y-1, z) == 53 then
			y = y - 1
			treeType = 2
		end

		if
			y < dimy - 8
			and world:getBlock(x, y-1, z) == 2
			and 3 < x and x < dimx - 4
			and 3 < z and z < dimz - 4
		then
			for i = -1, 1, 2 do
				if world:getBlock(x+i, y, z) == 53 then
					treeType = 2
					break
				end
			end

			for i = -1, 1, 2 do
				if world:getBlock(x, y, z+i) == 53 then
					treeType = 2
					break
				end
			end

			treeCreate(x, y, z, treeType, world)
		end
	end
end)

hooks:add('prePlayerPlaceBlock', 'surv_blocks', function(player, x, y, z, id)
	if player.isInGodmode then
		return false
	end

	if player.inCraftMenu then
		return true
	end

	if id == 0 and player.breakProgress < 10 then
		player:kick(KICK_IGNORE, true)
		return true
	end

	if id > 0 and player.inventory[id] == 0 then
		player:holdThis(0)
		player:sendMessage(MESG_NOTENOUGH)
		return true
	elseif id ~= 0 then
		if not survCanPlace(id)then
			survUpdatePermission(player, id)
			return true
		end
		player.inventory[id] = player.inventory[id] - 1
		survUpdateBlockInfo(player)

		if player.inventory[id] == 0 then
			player:holdThis(0)
			player:setInventoryOrder(id, 0)
		end
	end
end)
