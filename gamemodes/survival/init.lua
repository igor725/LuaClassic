--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

SURV_MAX_HEALTH = 10
SURV_MAX_OXYGEN = 10
SURV_INV_SIZE = 255
SURV_DEF_SPAWNRAD = 32

gmLoad('lng')
gmLoad('names')
gmLoad('gui')
gmLoad('blocks')
gmLoad('timers')
gmLoad('craft')
gmLoad('damage')
gmLoad('inventory')
gmLoad('commands')
gmLoad('daynight')
gmLoad('firespread')

gmLoad('items')
-- gmLoad('mob-ai')

config.types.spawnRadius = 'number'
if not config:get('spawnRadius')then
	config:set('spawnRadius', SURV_DEF_SPAWNRAD)
end

function survCanPlace(id)
	return (id < 7 or id > 11)and
	(id < 149 or id > 151)
end

function survUpdatePermission(player, id)
	if not isValidBlockID(id)then return end
	local quantity = player.inventory[id]
	local canPlace = player.isInGodmode or (quantity > 0 and survCanPlace(id))
	player:setBlockPermissions(id, canPlace, player.isInGodmode)
end

hooks:add('onHeldBlockChange', 'surv_init', function(player, id)
	survUpdateBlockInfo(player)
end)

hooks:add('postPlayerFirstSpawn', 'surv_init', function(player)
	player:sendMessage('LuaClassic Survival Dev', MT_STATUS1)
end)

hooks:add('onPlayerHandshakeDone', 'surv_init', function(player)
	if not player:isSupported('PlayerClick')or
	not player:isSupported('HackControl')or
	not player:isSupported('EnvColors')or
	not player:isSupported('EnvMapAspect')or
	not player:isSupported('HeldBlock')then
		player:kick(KICK_SURVCPE, true)
		return
	end
end)

hooks:add('onPlayerCreate', 'surv_init', function(player)
	player.lastClickedBlock = newVector(0, 0, 0)
	player.currClickedBlock = newVector(0, 0, 0)
	player.inventory = ffi.new('uint8_t[?]', SURV_INV_SIZE + 1)
	player.health = SURV_MAX_HEALTH
	player.oxygen = SURV_MAX_OXYGEN
	player.action = SURV_ACT_NONE
	player.oxyshow = false
	player.deaths = 0
	player.heldTool = 0
end)

hooks:add('postPlayerSpawn', 'surv_init', function(player)
	local h = player.isInGodmode and 1 or 0
	player:hackControl(h, h, h, 0, 1, -1)
	for i = 1, SURV_INV_SIZE do
		if isValidBlockID(i)then
			survUpdatePermission(player, i)
		end
	end
end)

hooks:add('onPlayerClick', 'surv_init', function(player, ...)
	local button  = select(1, ...)
	local action  = select(2, ...)
	local tgid    = select(5, ...)
	local x, y, z = select(6, ...)

	if button == 1 and action == 0 then
		local held = player:getHeldBlock()
		if (held < 149 or held > 150)or
		player.action ~= SURV_ACT_NONE then
			return
		end
		local quantity = player.inventory[held]
		if quantity < 1 then
			return
		end
		if player.health < 10 then
			survHeal(player, .5)
			player.inventory[held] = quantity - 1
			survUpdateBlockInfo(player)
			if quantity == 1 then
				survUpdateInventory(player)
				player:holdThis(0)
			end
		else
			player:sendMessage(SURV_NOT_HUNGRY)
		end
		return
	end

	if action == 1 then
		survStopBreaking(player)
		return
	end

	local dist_entity = 9999
	local dist_block = 9999
	local tgentity

	if x ~= -1 and y ~= -1 and z ~= -1 then
		dist_block = distance(x + .5, y + .5, z + .5, player:getPos())
	else
		survStopBreaking(player)
	end

	tgentity = entities[tgid]
	if tgentity then
		x, y, z = player:getPos()
		dist_entity = distance(x, y, z, tgentity:getPos())
	end

	if dist_block < dist_entity then
		survBlockAction(player, button, action, x, y, z)
	elseif dist_entity < dist_block and dist_entity < 3.5 then
		if button == 0 and action == 0 then
			if not player.nextHit then
				player.nextHit = 0
			end
			if tgentity and CTIME > player.nextHit then
				-- get damage from sword
				local power, toolType = survPlayerGetTool(player)

				local damage = 1
				if toolType == 4 then
					damage = power
				end

				-- critical damage
				local blocks = math.max(0, player.fallingStartY and (player.fallingStartY - player.pos.y) or 0)

				survDamage(player, tgentity, damage + blocks, SURV_DMG_PLAYER)
				survStopBreaking(player)

				-- timeout
				player.nextHit = CTIME + 0.5
			end
		end
	end
end)

saveAdd('deaths', '>I')
saveAdd('health', '>f')
saveAdd('oxygen', '>f')
saveAdd('isInGodmode', 'b', function(player, val)
	return val == 1
end, function(val)
	return val and 1 or 0
end)
saveAdd('homepos', '>fff', function(player, x, y, z)
	return newVector(x, y, z)
end, function(val)
	return val.x, val.y, val.z
end)
saveAdd('homeang', '>ff', function(player, y, p)
	return newAngle(y, p)
end, function(val)
	return val.yaw, val.pitch
end)
