--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

addCommand('give', function(isConsole, player, args)
	if #args < 1 then return false end

	local id, count
	if isConsole then
		if #args < 2 then return false end
		player = getPlayerByName(args[1])
		id = args[2]
		count = args[3]
	else
		if #args == 2 then
			id = args[1]
			count = args[2]
		elseif #args > 2 then
			player = getPlayerByName(args[1])
			id = args[2]
			count = args[3]
		elseif #args == 1 then
			id = args[1]
			count = 64
		end
	end
	if not player then return MESG_PLAYERNF end

	id = tonumber(id)or 0
	count = tonumber(count)or SURV_MAX_BLOCKS
	count = math.min(math.max(count, 1), SURV_MAX_BLOCKS)

	local given = survInvAddBlock(player, id, count)
	if given > 0 then
		player:holdThis(id)
		return (CMD_GIVE):format(given, survGetBlockName(id), player)
	end
end)

addCommand('heal', function(isConsole, player, args)
	if isConsole and #args < 1 then return false end
	player = getPlayerByName(args[1])or player
	if not player then return MESG_PLAYERNF end

	player.health = SURV_MAX_HEALTH
	survUpdateHealth(player)
	return (CMD_HEAL):format(player)
end)

addCommand('drop', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end

	local bId = player:getHeldBlock()
	if bId < 1 then
		return
	end

	if #args > 1 then
		local target = getPlayerByName(args[1])
		local quantity = tonumber(args[2])or 1
		local x, y, z = player:getPos()

		if not target then
			return MESG_PLAYERNF
		end
		if distance(x, y, z, target:getPos()) > 6 then
			return CMD_DROPTOOFAR
		end

		local inv1 = player.inventory
		local inv2 = target.inventory
		quantity = math.min(quantity, SURV_MAX_BLOCKS - inv2[bId])
		if quantity < 1 then
			return
		end
		if inv1[bId] >= quantity then
			inv1[bId] = inv1[bId] - quantity
			inv2[bId] = inv2[bId] + quantity
			survUpdateBlockInfo(player)
			survUpdateBlockInfo(target)
			survUpdateInventory(player, bId)
			survUpdateInventory(target, bId)
			return (CMD_DROPSUCCP):format(quantity, survGetBlockName(bId), target)
		end
	else
		local inv = player.inventory
		local quantity = tonumber(args[1])or 1
		if inv[bId] >= quantity then
			inv[bId] = inv[bId] - quantity
			player:setInventoryOrder(bId, inv[bId] > 0 and bId or 0)
			survUpdateBlockInfo(player)
			return (CMD_DROPSUCCP):format(quantity, survGetBlockName(bId))
		end
	end
end)

addCommand('kill', function(isConsole, player, args)
	if #args > 0 then
		player = getPlayerByName(args[1])
	end

	if player then
		if not survDamage(nil, player, SURV_MAX_HEALTH, 0)then
			return MESG_NODMG
		end
	else
		return MESG_PLAYERNF
	end
end)

addCommand('god', function(isConsole, player, args)
	if isConsole and #args < 1 then return false end
	local target = getPlayerByName(args[1])or player
	if not target then return MESG_PLAYERNF end
	if target ~= player and not player:checkPermission('commands.god-others')then
		return
	end

	target.isInGodmode = not target.isInGodmode
	local state = (target.isInGodmode and ST_ON)or ST_OFF

	local h = target.isInGodmode and 1 or 0
	target:hackControl(h, h, h, 1, 1, -1)

	for i = 1, SURV_INV_SIZE do
		if isValidBlockID(i)then
			survUpdatePermission(player, i)
		end
	end

	if target.isInGodmode then
		survPauseTimers(target)
		player.inCraftMenu = false
	else
		target.health = SURV_MAX_HEALTH
		survResumeTimers(target)
	end
	survUpdateHealth(target)
	survUpdateInventory(player)
	survUpdateBlockInfo(target)

	return (CMD_GOD):format(state, target)
end)

addCommand('home', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end

	local hp = player.homepos
	local ha = player.homeang

	if hp and ha then
		player:teleportTo(hp.x, hp.y, hp.z, ha.yaw, ha.pitch)
	else
		return CMD_HOMENF
	end
end)

addCommand('sethome', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end

	local hp = player.homepos
	local ha = player.homeang

	if hp and ha then
		hp.x, hp.y, hp.z = player:getPos()
		ha.yaw, ha.pitch = player:getEyePos()
	else
		hp = newVector(player:getPos())
		ha = newAngle(player:getEyePos())
	end
	player.homepos = hp
	player.homeang = ha
	return CMD_HOMESET
end)
