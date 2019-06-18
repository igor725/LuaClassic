
local opts

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

for tool = 0, 4 do
	for material = 1, 5 do
		opts = {
			id = 127 + material + tool * 16,
			name = ITEMS_MATERIAL_NAMES[material] .. ITEMS_NAMES[tool+1],
			minX = 16,
			maxX = 16,
			leftTex = 127 + material + tool * 16,
			rightTex = 127 + material + tool * 16,
			blockDraw = BD_TRANSPARENT
		}
		BlockDefinitions:createEx(opts)
	end
end
