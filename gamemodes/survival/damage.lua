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
	ffi.fill(player.inventory, 66)

	survUpdateInventory(player)
	survUpdateBlockInfo(player)
	survUpdateHealth(player)
	survStopBreaking(player)
	player:moveToSpawn()
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
	if victim.isInGodmode then return false end

	if dmgtype == SURV_DMG_PLAYER then
		if attacker.isInGodmode and not attacker:checkPermission('god.hurt')then
			return
		end
		-- knockback
		local x, y, z = attacker:getPos()
		local tx, ty, tz = victim:getPos()
		local dx, dy, dz = tx - x, ty - y, tz - z
		local length = math.sqrt(dx^2 + dy^2 + dz^2)
		dx, dy, dz = dx / length, dy / length, dz / length

		victim:teleportTo(tx + dx, ty + 0.5, tz + dz)
	end

	victim.health = victim.health - damage
	survUpdateHealth(victim)
	victim:setEnvProp(MEP_MAXFOGDIST, 1)
	victim:setEnvColor(EC_FOG, 255, 40, 40)
	timer.Create(victim:getName() .. '_hurt', 1, .07, function()
		local r, g, b = getWorld(victim):getEnvColor(EC_FOG)
		victim:setEnvProp(MEP_MAXFOGDIST, 0)
		victim:setEnvColor(EC_FOG, r, g, b)
	end)
	if victim.health <= 0 then
		victim.deaths = victim.deaths + 1
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
		local blockInsidePlayer = getWorld(player):getBlock(math.floor(pos.x+.5), math.floor(pos.y-1.5), math.floor(pos.z+.5))

		if not (8 <= blockInsidePlayer and blockInsidePlayer <= 11) then
			survDamage(nil, player, blocks / 2 - 0.5, SURV_DMG_FALL)
		end
	end
end)
