local opts
local offset = 65

local addItem = function(name, texture)
	offset = offset + 1
	opts = {
		id = offset,
		name = name,
		minX = 16,
		maxX = 16,
		leftTex = texture,
		rightTex = texture,
		blockDraw = BD_TRANSPARENT
	}
	BlockDefinitions:createEx(opts)
	print(offset, texture, name)
	
	return offset
end

local ITEMS_MATERIAL_NAMES = {
	'Wooden',
	'Stone',
	'Iron',
	'Diamond',
	'Gold'
}

local ITEMS_NAMES = {
	' sword',
	' shovel',
	' pickaxe',
	' axe',
	' hoe'
}

local STICK_ID = addItem("Stick", 128 + 5 + 48)
survCraft[STICK_ID] = {
	needs = {
		[5] = 2
	},
	count = 4
}
local COAL_ID = addItem("Coal", 128 + 7)
local IRON_ID = addItem("Iron ingot", 128 + 7 + 16)
survCraft[IRON_ID] = {
	needs = {
		[15] = 4,
		[54] = 1
	},
	count = 4
}
local GOLD_ID = addItem("Gold ingot", 128 + 7 + 32)
survCraft[GOLD_ID] = {
	needs = {
		[14] = 4,
		[54] = 1
	},
	count = 4
}
local DIAMOND_ID = addItem("Diamond", 128 + 7 + 48)

local ITEMS_CRAFT_MATERIALS = {5, 4, IRON_ID, DIAMOND_ID, GOLD_ID}

for tool = 0, 4 do
	for material = 1, 5 do
		local id = addItem(ITEMS_MATERIAL_NAMES[material] .. ITEMS_NAMES[tool+1], 127 + material + tool * 16)
		
		survBreakingTools[id] = material * 2
		
		survCraft[id] = {
			needs = {
				[ ITEMS_CRAFT_MATERIALS[material] ] = 3,
				[STICK_ID] = 2
			},
			count = 1
		}
	end
end
