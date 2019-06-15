

-- test	
local opts = {
	id = 41,
	name = 'Golden pickaxe',
	minX = 8,
	maxX = 8,
	leftTex = 16*6,
	rightTex = 16*6,
	blockDraw = BD_TRANSPARENT
}
BlockDefinitions:createEx(opts)
