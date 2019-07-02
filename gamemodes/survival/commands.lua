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
			count = SURV_STACK_SIZE
		end
	end
	if not player then return MESG_PLAYERNF end

	id = tonumber(id)or 0
	count = tonumber(count)or SURV_STACK_SIZE
	count = math.min(math.max(count, 1), SURV_STACK_SIZE)

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
	if player.health ~= SURV_MAX_HEALTH then
		player.health = SURV_MAX_HEALTH
		survUpdateHealth(player)
	end
	if player.oxygen ~= SURV_MAX_OXYGEN then
		player.oxygen = SURV_MAX_OXYGEN
		survUpdateOxygen(player)
	end
	return (CMD_HEAL):format(player)
end)

addCommand('drop', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end

	local bId = player:getHeldBlock()
	if bId < 1 then
		return
	end

	if #args > 1 then
		local target = getPlayerByName(args[1])or getPlayerByName(args[2])
		local quantity = tonumber(args[2])or tonumber(args[1])or 1
		local x, y, z = player:getPos()

		if not target then
			return MESG_PLAYERNF
		end

		if target == player then
			return false
		end

		if distance(x, y, z, target:getPos()) > 6 then
			return CMD_DROPTOOFAR
		end

		local inv1 = player.inventory
		local inv2 = target.inventory
		quantity = math.min(quantity, SURV_STACK_SIZE - inv2[bId])
		if quantity < 1 then
			return false
		end

		local name = survGetBlockName(bId)
		if inv1[bId] >= quantity then
			inv1[bId] = inv1[bId] - quantity
			inv2[bId] = inv2[bId] + quantity
			survUpdateBlockInfo(player)
			survUpdateBlockInfo(target)
			survUpdateInventory(player, bId)
			survUpdateInventory(target, bId)
			target:sendMessage((MESG_DROP):format(quantity, name, player))
			return (CMD_DROPSUCCP):format(quantity, name, target)
		else
			return (CMD_DROPNE):format(quantity, name)
		end
	end
	return false
end)

addCommand('kill', function(isConsole, player, args)
	if isConsole and #args < 1 then return false end
	player = getPlayerByName(args[1])or player

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
	if player and target ~= player and not player:checkPermission('commands.god-others')then
		return
	end

	target.isInGodmode = not target.isInGodmode
	local state = (target.isInGodmode and ST_ON)or ST_OFF

	local h = target.isInGodmode and 1 or 0
	target:hackControl(h, h, h, 0, 1, -1)

	for i = 1, SURV_INV_SIZE do
		if isValidBlockID(i)then
			survUpdatePermission(target, i)
		end
	end

	if target.isInGodmode then
		survPauseTimers(target)
		target.inCraftMenu = false
	else
		target.health = SURV_MAX_HEALTH
		survResumeTimers(target)
	end

	survUpdateHealth(target)
	survUpdateInventory(target)
	survUpdateBlockInfo(target)

	return (CMD_GOD):format(state, target)
end)

addCommand('home', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end

	local hp = player.homepos
	local ha = player.homeang
	local hw = player.homeworld

	if hp and ha and hw then
		local wld = getWorld(hw)
		if not wld then
			return WORLD_NF
		end
		if player:isInWorld(wld)then
			player:teleportTo(hp.x, hp.y, hp.z, ha.yaw, ha.pitch)
		else
			player:changeWorld(wld, true, hp.x, hp.y, hp.z, ha.yaw, ha.pitch)
		end
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
	player.homeworld = player.worldName
	return CMD_HOMESET
end)

addCommand('pvp', function(isConsole, player, args)
	player.pvpmode = not player.pvpmode
	return (CMD_PVP):format((player.pvpmode and ST_ON)or ST_OFF)
end)
