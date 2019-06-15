--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

SURV_MAX_BLOCKS = 64

SURV_ACT_NONE   = -1
SURV_ACT_BREAK  = 1

local survBreakingTools = {
	[41] = 12,
	[42] = 6,
	[43] = 4,
	[5] = 2
}

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
	[54] = 0,
	[65] = 7.5
}

local survMiningSpeedWithTool = {
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
	[65] = 1.15
}

for i = 21, 36 do
	survMiningSpeed[i] = 1.15
end

for i = 37, 40 do
	survMiningSpeed[i] = 0
end

function survGetDropBlock(held, bid)
	if bid == 1 then
		return 4
	elseif bid == 2 then
		return 3
	elseif bid == 18 then
		return (math.random(0, 100) < 20 and 6)or 18
	elseif bid == 20 then
		return 0
	elseif bid >= 14 and bid <= 16 then
		if (held < 41 or held > 44)and held ~= 5 then
			return 0
		end
	end
	return bid
end

function survStopBreaking(player)
	if player.action ~= SURV_ACT_BREAK then return end
	player.breakProgress = 0
	player.action = SURV_ACT_NONE
	player:sendMessage('', MT_STATUS3)
	timer.Remove(player:getName() .. '_surv_brk')
end

function survBreakBlock(player, x, y, z)
	local world = getWorld(player)
	local cbid = world:getBlock(x, y, z)
	local heldBlock = player:getHeldBlock()
	local bid, count = survGetDropBlock(heldBlock, cbid)

	if bid ~= 0 then
		if survInvAddBlock(player, bid, dcount or 1) > 0 then
			if heldBlock ~= bid and player.heldTool == 0 then
				player:holdThis(bid)
			end
		end
	end
	survStopBreaking(player)
	hooks:call('onPlayerPlaceBlock', player, x, y, z, 0)
	world:setBlock(x, y, z, 0)
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
				player.action = SURV_ACT_BREAK
				player.breakProgress = 0
				local lb = player.lastClickedBlock
				lb.x, lb.y, lb.z = x, y, z
				local tmSpeed = (survMiningSpeed[bid]or survMiningSpeed[-1])
				if tmSpeed <= 0 then
					survBreakBlock(player, x, y, z)
					return
				end
				if player:getFluidLevel() > 1 then
					tmSpeed = tmSpeed * 5
				end

				local tool = player.heldTool
				if tool ~= 0 then
					if player.inventory[tool] > 0 then
						if survMiningSpeedWithTool[bid] then
							tmSpeed = survMiningSpeedWithTool[bid] / survBreakingTools[tool] * 2
						else
							tmSpeed = tmSpeed / survBreakingTools[tool]
						end
					else
						player:sendMessage('You don\'t have this tool in inventory.')
						player:holdThis(0)
					end
				end

				timer.Create(player:getName() .. '_surv_brk', 11, tmSpeed / 10, function()
					local lb = player.lastClickedBlock
					if lb.x ~= cb.x or lb.y ~= cb.y or lb.z ~= cb.z then
						survStopBreaking(player)
						return
					end

					if player.breakProgress == 100 then
						survBreakBlock(player, x, y, z)
					else
						player.breakProgress = math.min(player.breakProgress + 10, 100)
						player:sendMessage((SURV_MINING):format(player.breakProgress), MT_STATUS3)
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

hooks:add('onPlayerDestroy', 'surv_breaking', function(player)
	survStopBreaking(player)
end)

hooks:add('onPlayerDespawn', 'surv_breaking', function(player)
	survStopBreaking(player)
end)

hooks:add('onHeldBlockChange', 'surv_breaking', function(player, id)
	if survBreakingTools[id] then
		player.heldTool = id
	else
		player.heldTool = 0
	end
end)

hooks:add('onPlayerPlaceBlock', 'surv_breaking', function(player, x, y, z, id)
	if player.isInGodmode then
		return false
	end
	if player.inCraftMenu then
		return true
	end
	if id > 0 and id < 65 and player.inventory[id] < 1 then
		if not player.isInGodmode then
			player:sendMessage('&cNot enough blocks')
			return true
		end
	else
		player.inventory[id] = player.inventory[id] - 1
		survUpdateBlockInfo(player)

		if player.inventory[id] == 0 then
			player:holdThis(0)
			player:setInventoryOrder(id, 0)
		end
	end
end)
