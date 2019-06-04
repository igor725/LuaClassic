local SURVIVAL_ENABLED = true
if not SURVIVAL_ENABLED then return end

local SURV_ACT_NONE  = -1
local SURV_ACT_BREAK = 1

local survBlocknames = {
	'Stone', 'Grass', 'Dirt', 'Cobblestone',
	'Planks', 'Sapling', 'Bedrock', 'Water',
	'Water', 'Lava', 'Lava', 'Sand', 'Gravel',
	'Gold ore', 'Iron ore', 'Coal ore', 'Log',
	'Leaves', 'Sponge', 'Glass', 'Red wool',
	'Orange wool', 'Yellow wool', 'Lime wool',
	'Green wool', 'Teal wool', 'Aqua wool',
	'Cyan wool', 'Blue wool', 'Indigo wool',
	'Violet wool', 'Magenta wool', 'Pink wool',
	'Black wool', 'Gray wool', 'White wool',
	'Dandelion', 'Rose', 'Brown mushroom',
	'Red mushroom', 'Gold block', 'Iron block',
	'Double slab', 'Slab', 'Brick', 'TNT',
	'Bookshelf', 'Mossy stone', 'Obsidian',
	'Cobblestone slab', 'Rope', 'Sandstone',
	'Snow', 'Fire', 'Light pink wool',
	'Forest green wool', 'Brown wool',
	'Deep blue', 'Turquoise wool', 'Ice',
	'Ceramic tile', 'Magma', 'Pillar',
	'Crate', 'Stone brick'
}

local survMiningSpeed = {
	[-1] =  .1,
	[1]  =  .3,
	[4]  =  .3,
	[5]  =  .2,
	[6]  =  .01,
	[12] =  .12,
	[13] =  .12,
	[14] =  .4,
	[15] =  .4,
	[16] =  .4,
	[18] =  .04,
	[20] = .03,

	[46] = 0
}

local function distance(x1, y1, z1, x2, y2, z2)
	return math.sqrt( (x2 - x1) ^ 2 + (y2 - y1) ^ 2 + (z2 - z1) ^ 2 )
end

local function survUpdateHealth(player)
	local hstr = ('\3'):rep(math.ceil(player.health))
	player:sendMessage('&c' .. hstr, MT_STATUS2)
end

local function survUpdateBlockInfo(player)
	local id = player:getHeldBlock()
	if id > 0 then
		local quantity = player.inventory[id]
		local name = survBlocknames[id]or'UNKNOWN_BLOCK'
		player:sendMessage('Block: ' .. name, MT_BRIGHT3)
		player:sendMessage('Quantity: ' .. quantity, MT_BRIGHT2)
		player:setBlockPermissions(id, quantity > 0 and (id < 7 or id > 11), false)
	else
		player:sendMessage('', MT_BRIGHT3)
		player:sendMessage('', MT_BRIGHT2)
	end
end

local function survUpdateOxygen(player)
	if player.oxygen == 10 then
		player:sendMessage('', MT_BRIGHT1)
		player.oxyshow = false
	else
		player:sendMessage(('Oxygen: %.1f'):format(player.oxygen), MT_BRIGHT1)
	end
end

local function survAddHealth(player, add)
	player.health = player.health + add
	survUpdateHealth(player)
end

local function survStopBreaking(player)
	if player.action ~= SURV_ACT_BREAK then return end
	player.breakProgress = 0
	player.action = SURV_ACT_NONE
	player:sendMessage('', MT_STATUS3)
	timer.Remove(player:getName() .. '_surv_brk')
end

local function survRespawn(player)
	player:moveToSpawn()
	player.health = 10
	player.oxygen = 10
	ffi.fill(player.inventory, 65)
	survUpdateHealth(player)
	survStopBreaking(player)
	survUpdateBlockInfo(player)
end

local function survDamage(player, victim, damage)
	survAddHealth(victim, (damage and -damage) or-0.5)
	victim:setEnvProp(MEP_MAXFOGDIST, 1)
	victim:setEnvColor(EC_FOG, 255, 40, 40)
	timer.Create(victim:getName() .. '_hurt', 1, .07, function()
		victim:setEnvProp(MEP_MAXFOGDIST, 0)
		victim:setEnvColor(EC_FOG, -1, -1, -1)
	end)
	if victim.health <= 0 then
		survRespawn(victim)
		victim:sendMessage('You are killed by ' .. ((player and player:getName()) or'world'))
	end
end

local function survBreakBlock(player, x, y, z)
	local world = getWorld(player)
	local bid = world:getBlock(x, y, z)

	if player:getHeldBlock() ~= bid then
		player:holdThis(bid)
	end

	player.inventory[bid] = math.min(player.inventory[bid] + 1, 64)
	survUpdateBlockInfo(player)
	survStopBreaking(player)
	hooks:call('onPlayerPlaceBlock', player, x, y, z, 0)
	world:setBlock(x, y, z, 0)
end

local function survBlockAction(player, button, action, x, y, z)
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
				local tmSpeed = survMiningSpeed[bid]or survMiningSpeed[-1]
				if tmSpeed <= 0 then
					survBreakBlock(player, x, y, z)
					return
				end
				if player:getFluidLevel() > 1 then
					tmSpeed = tmSpeed * 4
				end
				timer.Create(player:getName() .. '_surv_brk', 11, tmSpeed, function()
					local lb = player.lastClickedBlock
					if lb.x ~= cb.x or lb.y ~= cb.y or lb.z ~= cb.z then
						survStopBreaking(player)
						return
					end

					if player.breakProgress == 100 then
						survBreakBlock(player, x, y, z)
					else
						player.breakProgress = math.min(player.breakProgress + 10, 100)
						player:sendMessage(('Mining block: %d%%...'):format(player.breakProgress), MT_STATUS3)
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

function onInitDone()
	log.info('Survival Test Gamemode Loaded!')
	hooks:add('onPlayerCreate', 'survival', function(player)
		player.action = SURV_ACT_NONE
		player.lastClickedBlock = newVector(0, 0, 0)
		player.currClickedBlock = newVector(0, 0, 0)
		player.inventory = ffi.new('uchar[65]')
		player.oxyshow = false
		player.oxygen = 10
		player.health = 10
	end)

	hooks:add('onPlayerHandshakeDone', 'survival', function(player)
		if not player:isSupported('PlayerClick')or
		not player:isSupported('FullCP437')or
		not player:isSupported('HackControl')or
		not player:isSupported('HeldBlock')then
			player:kick('Your client does not support required CPE exts.')
			return
		end
		for i = 1, 65 do
			player:setBlockPermissions(i, false, false)
		end
		player:sendMessage('LuaClassic Survival Dev', MT_STATUS1)
		timer.Create(player:getName() .. '_hp_regen', -1, 5, function()
			local ahp = math.min(10, player.health + .5)
			if ahp ~= player.health then
				survUpdateHealth(player)
			end
			player.health = ahp
		end)
		timer.Create(player:getName() .. '_oxygen', -1, .4, function()
			local level, isLava = player:getFluidLevel()
			if isLava then
				survDamage(nil, player, 1)
				return
			end
			if level > 1 then
				player.oxygen = math.max(player.oxygen - .2, 0)
				if player.oxygen == 0 then
					survDamage(nil, player, 1)
				end
				survUpdateOxygen(player)
				player.oxyshow = true
			else
				if player.oxyshow then
					player.oxygen = math.min(player.oxygen + .05, 10)
					survUpdateOxygen(player)
				end
			end
		end)
	end)

	hooks:add('onPlayerDestroy', 'survival', function(player)
		survStopBreaking(player)
		local name = player:getName()
		timer.Remove(name .. '_oxygen')
		timer.Remove(name .. '_hp_regen')
		timer.Remove(name .. '_surv_brk')
	end)

	hooks:add('onPlayerMove', 'survival', function(player, dx, dy, dz)
		local world = getWorld(player)
		local x, y, z = player:getPos()
		x, y, z = floor(x), floor(y - .5), floor(z)

		local blk = world:getBlock(x, y - ceil(dy), z)

		if blk ~= 0 and(blk < 8 or blk > 11)and dy > .5 then
			survDamage(nil, player, 2.3 * dy)
		end
	end)

	hooks:add('postPlayerSpawn', 'survival', function(player)
		survUpdateHealth(player)
		local name = player:getName()
		local noclip = player:checkPermission('player.noclip')
		player:hackControl(0, (noclip and 1)or 0, 0, 0, 1, -1)
		timer.Resume(name .. '_oxygen')
		timer.Resume(name .. '_hp_regen')
	end)

	hooks:add('onPlayerDespawn', 'survival', function(player)
		survStopBreaking(player)
		local name = player:getName()
		timer.Pause(name .. '_oxygen')
		timer.Pause(name .. '_hp_regen')
	end)

	hooks:add('onPlayerClick', 'survival', function(player, ...)
		local button  = select(1, ...)
		local action  = select(2, ...)
		local tgent   = select(5, ...)
		local x, y, z = select(6, ...)

		if action == 1 then
			survStopBreaking(player)
			return
		end

		local dist_player = 9999
		local dist_block = 9999
		local tgplayer

		if x ~= -1 and y ~= -1 and z ~= -1 then
			dist_block = distance(x + .5, y + .5, z + .5, player:getPos())
		end
		if tgent > 0 then
			tgplayer = getPlayerByID(tgent)
			if tgplayer then
				dist_player = distance(x, y, z, tgplayer:getPos())
			end
		end

		print(dist_block, dist_player)

		if dist_block < dist_player then
			survBlockAction(player, button, action, x, y, z)
		elseif dist_player < dist_block then
			if button == 0 and action == 0 then
				if tgplayer then
					survDamage(player, tgplayer)
				end
			end
		end
	end)

	hooks:add('onPlayerPlaceBlock', 'survival', function(player, x, y, z, id)
		if id > 0 and player.inventory[id] < 1 then
			player:sendMessage('&cNot enough blocks')
			return true
		else
			player.inventory[id] = player.inventory[id] - 1
			survUpdateBlockInfo(player)
		end
	end)

	hooks:add('onHeldBlockChange', 'survival', function(player, id)
		survUpdateBlockInfo(player)
	end)

	addChatCommand('give', function(player, id, count)
		id = tonumber(id)
		count = tonumber(count)or 64
		count = math.min(math.max(count, 1), 64)

		if id and id > 0 and id < 66 then
			player:holdThis(id)
			player.inventory[id] = math.min(64, player.inventory[id] + count)
			survUpdateBlockInfo(player)
			return ('Block %s given'):format(survBlocknames[id])
		else
			return 'Invalid block id'
		end
	end)

	saveAdd('health', function(f, player)
		player.health = unpackFrom(f, '>f')
	end, function(f, val)
		packTo(f, '>f', val)
	end)

	saveAdd('oxygen', function(f, player)
		player.oxygen = unpackFrom(f, '>f')
	end, function(f, val)
		packTo(f, '>f', val)
	end)

	saveAdd('inventory', function(f, player)
		while true do
			local id, quantity = unpackFrom(f, 'BB')
			if id == 255 and quantity == 255 then
				break
			end
			player.inventory[id] = math.min(quantity, 64)
		end
	end, function(f, val)
		for i = 1, 65 do
			if val[i] > 0 then
				packTo(f, 'bb', i, val[i])
			end
		end
		f:write('\255\255')
	end)
end
