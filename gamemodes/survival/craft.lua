--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

survCraft = {
	[1] = {
		needs = {
			[4] = 4,
			[54] = 1
		},
		count = 4
	},
	[2] = {
		needs = {
			[18] = 1,
			[3] = 1
		},
		count = 1
	},
	[3] = {
		needs = {
			[2] = 1
		},
		count = 1
	},
	[4] = {
		needs = {
			[1] = 1
		},
		count = 1
	},
	[5] = {
		needs = {
			[17] = 1
		},
		count = 4
	},
	[13] = {
		needs = {
			[3] = 1,
			[12] = 1
		},
		count = 2
	},
	[20] = {
		needs = {
			[54] = 1,
			[12] = 1
		},
		count = 1
	},
	[41] = {
		needs = {
			[14] = 4,
			[54] = 1
		},
		count = 1
	},
	[42] = {
		needs = {
			[15] = 4,
			[54] = 1
		},
		count = 1
	},
	[43] = {
		needs = {
			[44] = 2
		},
		count = 1
	},
	[44] = {
		needs = {
			[1] = 3
		},
		count = 6
	},
	[45] = {
		needs = {
			[13] = 4,
			[54] = 1
		},
		count = 4
	},
	[46] = {
		needs = {
			[54] = 9
		},
		count = 1
	},
	[47] = {
		needs = {
			[5] = 6
		},
		count = 1
	},
	[48] = {
		needs = {
			[4] = 4,
			[18] = 1
		},
		count = 4
	},
	[50] = {
		needs = {
			[4] = 3
		},
		count = 6
	},
	[52] = {
		needs = {
			[12] = 4
		},
		count = 4
	},
	[54] = {
		needs = {
			[16] = 1
		},
		count = 4
	},
	[65] = {
		needs = {
			[1] = 4,
			[54] = 1
		},
		count = 4
	}
}

function survCraftInfo(id)
	local recipe = survCraft[id]

	if recipe then
		local lacks = ''

		for nId, amount in pairs(recipe.needs) do
			lacks = lacks .. ('%d %s, '):format(amount, survGetBlockName(nId))
		end

		return (CMD_CRAFTRECIPE):format(lacks:sub(1, -3), recipe.count, survGetBlockName(id))
	else
		return CMD_CANTCRAFT
	end
end

function survCanCraft(player, bid, quantity)
	if not isValidBlockID(bid)then return false end
	local inv = player.inventory
	local recipe = survCraft[bid]
	local lacks

	if recipe then
		local canCraft = true
		for nId, amount in pairs(recipe.needs)do
			local cnt = quantity * amount
			if inv[nId] < cnt then
				canCraft = false
				lacks = lacks or''
				lacks = lacks .. ('%d %s, '):format(cnt - inv[nId], survGetBlockName(nId))
			end
		end
		return canCraft, lacks and lacks:sub(1, -3)
	end
	return false
end

addCommand('craft', function(isConsole, player, args)
	if isConsole then return CON_INGAMECMD end
	if player.isInGodmode then return CMD_CRAFTGOD end

	if #args > 0 then
		if args[1] == 'info'then
			return survCraftInfo(player:getHeldBlock())
		end

		-- craft if arg is number
		local bId = player:getHeldBlock()
		local quantity = tonumber(args[1])

		if quantity and bId ~= 0 then
			if quantity < 0 then
				return CMD_CRAFTNEG
			end
			local recipe = survCraft[bId]
			local inv = player.inventory

			if recipe then
				local oQuantity = recipe.count * quantity
				local bName = survGetBlockName(bId)
				if(64 - inv[bId]) < (quantity * recipe.count)then
					return (CMD_CRAFTTOOMANY):(bName)
				end
				local canBeCrafted, lacks = survCanCraft(player, bId, quantity)
				if canBeCrafted then
					for nId, ammount in pairs(recipe.needs)do
						inv[nId] = inv[nId] - ammount * quantity
					end
					inv[bId] = inv[bId] + oQuantity
					survUpdateBlockInfo(player)

					-- Close craft menu if craft was successful
					player.inCraftMenu = false

					survUpdateInventory(player)

					return (CMD_CRAFTSUCC):format(oQuantity, bName)
				else
					return (CMD_LCRAFT):format(lacks, oQuantity, bName)
				end
			else
				return CMD_CANTCRAFT
			end
		end
	end

	-- open/close craft menu if argument is wrong
	if not player.inCraftMenu then
		player.inCraftMenu = true
		survUpdateInventory(player)

		player.heldBlockBeforeCrafting = player:getHeldBlock()
		player:holdThis(0)

		return CMD_CRAFTHELP
	else
		player.inCraftMenu = false
		survUpdateInventory(player)

		player:holdThis(player.heldBlockBeforeCrafting)

		return CMD_CRAFTQUIT
	end
end)

hooks:add('onHeldBlockChange', 'surv_craft', function(player, id)
	if player.inCraftMenu then
		if id > 0 then
			player:sendMessage(survCraftInfo(id))
			if survCraft[id]then
				player:sendMessage(CMD_CRAFTHELP2)
			end
		end
	end
end)
