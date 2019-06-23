function survAddItem(texY, texX, name, texture)
	local id = 128 + texX + 16 * texY
	
	local opts = {
		id = id,
		name = name,
		minX = 16,
		maxX = 16,
		leftTex = id,
		rightTex = id,
		blockDraw = BD_TRANSPARENT
	}
	BlockDefinitions:createEx(opts)
	
	return id
end

local ITEMS_MATERIAL_NAMES = {
	'Wooden',
	'Stone',
	'Iron',
	'Gold'
}

local ITEMS_TOOLS_NEEDS = {
	2, 1,
	1, 2,
	3, 2,
	3, 2
}

local ITEMS_TOOLS_NAMES = {
	' sword',
	' shovel',
	' pickaxe',
	' axe'
}

local STICK_ID = survAddItem(1, 1, 'Stick')
survAddCraft(STICK_ID, {
	needs = {
		[5] = 2
	},
	count = 4
})

local IRON_ID = survAddItem(1, 2, 'Iron ingot')
survAddCraft(IRON_ID, {
	needs = {
		[15] = 4,
		[54] = 1
	},
	count = 4
})
local GOLD_ID = survAddItem(1, 3, 'Gold ingot')
survAddCraft(GOLD_ID, {
	needs = {
		[14] = 4,
		[54] = 1
	},
	count = 4
})

local ITEMS_CRAFT_MATERIALS = {5, 4, IRON_ID, GOLD_ID}

for tool = 0, 3 do
	for material = 0, 3 do
		local id = survAddItem(0, material + 4 * tool, ITEMS_MATERIAL_NAMES[material+1] .. ITEMS_TOOLS_NAMES[tool+1])
		
		--sword
		if tool == 0 then
			survAddTool(id, 4, 2 + material / 2)
		-- other tools
		else
			survAddTool(id, tool, 2 ^ (material + 1))
		end
		
		survAddCraft(id, {
			needs = {
				[ ITEMS_CRAFT_MATERIALS[material+1] ] = ITEMS_TOOLS_NEEDS[tool * 2 + 1],
				[STICK_ID] = ITEMS_TOOLS_NEEDS[tool * 2 + 2]
			},
			count = 1
		})
	end
end
