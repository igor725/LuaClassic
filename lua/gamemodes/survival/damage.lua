--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

SURV_DMG_PLAYER = 1
SURV_DMG_FALL = 2
SURV_DMG_WATER = 3
SURV_DMG_LAVA = 4
SURV_DMG_FIRE = 5

function survRespawn(player)
	player.health = SURV_MAX_HEALTH
	player.oxygen = SURV_MAX_OXYGEN
	ffi.fill(player.inventory, SURV_INV_SIZE)
	for i = 0, 8 do
		player:setHotBar(i, 0)
	end
	
	survUpdateInventory(player)
	survUpdateBlockInfo(player)
	survUpdateHealth(player)
	survStopBreaking(player)
	player:moveToSpawn()
end

function survHeal(player, addHp)
	player.health = math.min(player.health + addHp, SURV_MAX_HEALTH)
	survUpdateHealth(player)
end

function getKiller(attacker, dmgtype)
	if dmgtype == SURV_DMG_PLAYER then
		return 'player ' .. attacker:getName()
	elseif dmgtype == SURV_DMG_FALL then
		return 'gravitation'
	elseif dmgtype == SURV_DMG_WATER then
		return 'water'
	elseif dmgtype == SURV_DMG_LAVA then
		return 'lava'
	elseif dmgtype == SURV_DMG_FIRE then
		return 'fire'
	end
	return '&dmysterious killer' -- Why not?
end

function survDamage(attacker, victim, damage, dmgtype)
	if not victim.isPlayer then return false end -- Temporarily
	if victim.isInGodmode then return false end
	local world = getWorld(victim)

	if dmgtype == SURV_DMG_PLAYER then
		if not attacker.pvpmode then
			attacker:sendMessage(MESG_PVP)
			return
		end

		if not victim.pvpmode then
			attacker:sendMessage(MESG_PPVP)
			return
		end

		if attacker.isInGodmode and not attacker:checkPermission('god.hurt')then
			return
		end
		-- knockback
		local x, y, z = attacker:getPos()
		local tx, ty, tz = victim:getPos()
		local spawnRad = tonumber(config:get('spawnRadius'))or SURV_DEF_SPAWNRAD

		if spawnRad then
			local sx, sy, sz = world:getSpawnPoint()
			if distance(tx, ty, tz, sx, sy, sz) < spawnRad and not attacker:checkPermission('spawn.hurt')then
				return
			end
		end
		local dx, dy, dz = tx - x, ty - y, tz - z
		local length = math.sqrt(dx^2 + dy^2 + dz^2) * 1.2
		dx, dy, dz = dx / length, dy / length, dz / length

		if world:getBlock(math.floor(tx) + (dx > 0 and 1 or -1), math.floor(ty), math.floor(tz - 0.5)) ~= 0 then
			dx = 0
		end

		if world:getBlock(math.floor(tx), math.floor(ty - 0.5), math.floor(tz) + (dz > 0 and 1 or -1)) ~= 0 then
			dz = 0
		end

		victim:teleportTo(tx + dx, ty + 0.5, tz + dz)
	end

	victim.health = victim.health - damage
	survUpdateHealth(victim)
	victim:setEnvProp(MEP_MAXFOGDIST, 8)
	victim:setEnvColor(EC_FOG, 140, 40, 40)
	timer.Create(victim:getName() .. '_hurt', 1, .1, function()
		local r, g, b = world:getEnvColor(EC_FOG)
		victim:setEnvProp(MEP_MAXFOGDIST, 0)
		victim:setEnvColor(EC_FOG, r, g, b)
	end)
	if victim.health <= 0 then
		victim.deaths = victim.deaths + 1

		-- give victim things to attacker
		if attacker then
			for i = 1, SURV_INV_SIZE do
				if isValidBlockID(i)then
					if victim.inventory[i] > 0 and attacker.inventory[i] == 0 then
						attacker:setInventoryOrder(i, i)
					end
					attacker.inventory[i] = math.min(SURV_STACK_SIZE, attacker.inventory[i] + victim.inventory[i])
				end
			end

			survUpdateBlockInfo(attacker)
		end

		survRespawn(victim)
		playersForEach(function(ply)
			if ply:isInWorld(victim)then
				ply:sendMessage((SURV_KILL):format(victim, getKiller(attacker, dmgtype)))
			end
		end)
	end
	return true
end

hooks:add('onPlayerLanded', 'surv_damage', function(player, blocks)
	if blocks > 3 and player.oldDY2 < -0.3 then
		local pos = player.pos
		local blockInsidePlayer = getWorld(player):getBlock(math.floor(pos.x), math.floor(pos.y-1.5), math.floor(pos.z))

		if not (8 <= blockInsidePlayer and blockInsidePlayer <= 11) then
			survDamage(nil, player, blocks / 2 - 0.5, SURV_DMG_FALL)
		end
	end
end)
