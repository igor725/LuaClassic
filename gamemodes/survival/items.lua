-- #gmLoad('items')

-- test	
local opts = {
	id = 41,
	name = 'Iron pickaxe',
	minX = 8,
	maxX = 8,
	leftTex = 16*6,
	rightTex = 16*6,
	blockDraw = BD_TRANSPARENT
}
BlockDefinitions:createEx(opts)

opts = {
	id = 42,
	name = 'Iron sword',
	minX = 8,
	maxX = 8,
	leftTex = 16*6+1,
	rightTex = 16*6+1,
	blockDraw = BD_TRANSPARENT
}
BlockDefinitions:createEx(opts)
