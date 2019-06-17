--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

function survUpdateHealth(player)
	local int, fr = math.modf(player.health)
	local str = ''
	if not player.isInGodmode then
		local dmg = SURV_MAX_HEALTH - int - ceil(fr)
		str = '&8' .. ('\3'):rep(dmg)
		if fr ~= 0 then str = str .. '&4\3' end
		str = str .. '&c' ..('\3'):rep(SURV_MAX_HEALTH - dmg - ceil(fr))
	end
	player:sendMessage(str, MT_STATUS2)
end

function survUpdateOxygen(player)
	local str = ''
	if player.oxygen == SURV_MAX_OXYGEN then
		player.oxyshow = false
	else
		str = '&b' .. ('\7'):rep(ceil(player.oxygen))
	end
	player:sendMessage(str, MT_STATUS3)
end

function survUpdateBlockInfo(player)
	local id = player:getHeldBlock()
	if id > 0 then
		local quantity = player.inventory[id]
		if player.isInGodmode then
			quantity = 1
		end
		local name = survGetBlockName(id)
		player:sendMessage(('%s (%d)'):format(name, quantity), MT_BRIGHT3)
		survUpdatePermission(player, id)
	else
		player:sendMessage('', MT_BRIGHT3)
	end
end

function survUpdateMiningProgress(player)
	if player.action == SURV_ACT_BREAK then
		local progress = ('|'):rep(player.breakProgress)
		local punfilled = ('|'):rep(SURV_BRK_DONE - player.breakProgress)
		local msg = ('Mining: [&a%s&0%s&f]'):format(progress, punfilled)
		player:sendMessage(msg, MT_BRIGHT2)
	elseif player.action == SURV_ACT_NONE then
		player:sendMessage('', MT_BRIGHT2)
	end
end

function survUpdateInventory(player, id)
	if player.isInGodmode or player.inCraftMenu then
		for i = 1, SURV_INV_SIZE do
			if not isValidBlockID(i)then break end
			player:setInventoryOrder(i, i)
		end
		return
	end
	if id then
		if not isValidBlockID(i)then return end
		player:setInventoryOrder(id, player.inventory[id] > 0 and 1 or 0)
		return
	end
	for i = 1, SURV_INV_SIZE do
		if not isValidBlockID(i)then break end
		if player.inventory[i] == 0 then
			player:setInventoryOrder(i, 0)
		end
	end
end

hooks:add('postPlayerSpawn', 'surv_gui', function(player)
	survUpdateInventory(player)
	survUpdateOxygen(player)
	survUpdateHealth(player)
end)
