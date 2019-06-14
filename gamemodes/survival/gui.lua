--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

function survUpdateOxygen(player)
	if player.oxygen == SURV_MAX_OXYGEN then
		player:sendMessage('', MT_BRIGHT1)
		player.oxyshow = false
	else
		local clr = '&a'
		if player.oxygen <= 3 then
			clr = '&c'
		elseif player.oxygen <= 6 then
			clr = '&e'
		end
		player:sendMessage((clr .. SURV_OXYGEN):format(player.oxygen), MT_BRIGHT1)
	end
end

function survUpdateBlockInfo(player)
	local id = player:getHeldBlock()
	if id > 0 then
		local quantity = player.inventory[id]
		if player.isInGodmode then
			quantity = 1
		end
		local name = survGetBlockName(id)
		player:sendMessage('Block: ' .. name, MT_BRIGHT3)
		player:sendMessage('Quantity: ' .. quantity, MT_BRIGHT2)
		survUpdatePermission(player, id)
	else
		player:sendMessage('', MT_BRIGHT3)
		player:sendMessage('', MT_BRIGHT2)
	end
end

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

function survUpdateInventory(player, id)
	if player.isInGodmode or player.inCraftMenu then
		for i = 1, 65 do
			player:setInventoryOrder(i, i)
		end
		return
	end
	if id then
		player:setInventoryOrder(id, player.inventory[id] > 0 and 1 or 0)
		return
	end
	for i = 1, 65 do
		if player.inventory[i] == 0 then
			player:setInventoryOrder(i, 0)
		end
	end
end

hooks:add('postPlayerSpawn', 'surv_gui', function(player)
	survUpdateInventory(player)
	survUpdateHealth(player)
end)
