function survAddItem(texY, texX, name)
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

-- other tools
survAddItem(1, 0, 'Bucket')
--survAddItem(1, 4, 'Door')
survAddItem(1, 5, 'Apple')
survAddItem(1, 6, 'Meat')
survAddItem(1, 7, 'Rotten Meat')
survAddItem(1, 8, 'Bone')
survAddItem(1, 9, 'String')

-- DYES
local DYE_NAMES = {
	'Red',
	'Orange',
	'Yellow',
	'Lime',
	'Green',
	'Teal',
	'Aqua',
	'Cyan',
	'Blue',
	'Indigo',
	'Violet',
	'Magenta',
	'Pink',
	'Black',
	'Gray',
	'White',
	'Light Pink',
	'Forest Green',
	'Brown',
	'Deep Blue',
	'Turquoise'
}

for i = 1, 16 do
	local id = survAddItem(2, i-1, DYE_NAMES[i] .. ' Dye')
	
	survAddCraft(20 + i, {
		needs = {
			[36] = 4,
			[id] = 1
		},
		count = 4
	})
end

for i = 1, 5 do
	local id = survAddItem(3, i-1, DYE_NAMES[i+16] .. ' Dye')
	
	survAddCraft(54 + i, {
		needs = {
			[36] = 4,
			[id] = 1
		},
		count = 4
	})
end

---- Color of zero order
-- Black
local DYE_BLACK = 173
survAddCraft(173, {
	needs = {
		[16] = 1
	},
	count = 4
})

-- White
local DYE_WHITE = 175
survAddCraft(175, {
	needs = {
		[152] = 1
	},
	count = 4
})

-- Gray
local DYE_GRAY = 174
survAddCraft(174, {
	needs = {
		[DYE_WHITE] = 1,
		[DYE_BLACK] = 1
	},
	count = 2
})

---- Color of first order
-- Red
local DYE_RED = 160
survAddCraft(160, {
	needs = {
		[38] = 1
	},
	count = 4
})

-- Green
local DYE_GREEN = 164
survAddCraft(164, {
	needs = {
		[40] = 1
	},
	count = 4
})

-- Blue
local DYE_BLUE = 179
survAddCraft(179, {
	needs = {
		[37] = 1
	},
	count = 4
})


---- Color of second order
-- Yellow
local DYE_YELLOW = 162
survAddCraft(162, {
	needs = {
		[DYE_RED] = 1,
		[DYE_GREEN] = 1
	},
	count = 2
})

-- Aqua
local DYE_AQUA = 166
survAddCraft(166, {
	needs = {
		[DYE_GREEN] = 1,
		[DYE_BLUE] = 1
	},
	count = 2
})

-- Violet
local DYE_VIOLET = 170
survAddCraft(170, {
	needs = {
		[DYE_RED] = 1,
		[DYE_BLUE] = 1
	},
	count = 2
})


---- Color of third order
--- 1
-- Orange
local DYE_ORANGE = 161
survAddCraft(161, {
	needs = {
		[DYE_RED] = 1,
		[DYE_YELLOW] = 1
	},
	count = 2
})

-- Lime
survAddCraft(163, {
	needs = {
		[DYE_YELLOW] = 1,
		[DYE_GREEN] = 1
	},
	count = 2
})

--- 2
-- Teal
survAddCraft(165, {
	needs = {
		[DYE_AQUA] = 1,
		[DYE_GREEN] = 1
	},
	count = 2
})

-- Cyan
local DYE_CYAN = 167
survAddCraft(167, {
	needs = {
		[DYE_AQUA] = 1,
		[DYE_BLUE] = 1
	},
	count = 2
})

-- Blue (named blue)
survAddCraft(168, {
	needs = {
		[DYE_GRAY] = 1,
		[DYE_BLUE] = 1
	},
	count = 2
})

--- 3
-- Indigo
survAddCraft(169, {
	needs = {
		[DYE_BLUE] = 1,
		[DYE_VIOLET] = 1
	},
	count = 2
})

-- Mangenta
survAddCraft(171, {
	needs = {
		[DYE_RED] = 1,
		[DYE_VIOLET] = 1
	},
	count = 2
})

-- Pink
survAddCraft(172, {
	needs = {
		[DYE_RED] = 2,
		[DYE_VIOLET] = 1
	},
	count = 3
})

---- Custom colors
-- Light Pink
survAddCraft(176, {
	needs = {
		[DYE_RED] = 1,
		[DYE_WHITE] = 1
	},
	count = 2
})

-- Forest green
survAddCraft(177, {
	needs = {
		[DYE_GREEN] = 1,
		[DYE_BLACK] = 1
	},
	count = 2
})

-- Brown
survAddCraft(178, {
	needs = {
		[DYE_ORANGE] = 1,
		[DYE_BLACK] = 1
	},
	count = 2
})

-- Turquoise
survAddCraft(180, {
	needs = {
		[DYE_CYAN] = 1,
		[DYE_BLACK] = 1
	},
	count = 2
})


