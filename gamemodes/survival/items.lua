-- test
local opts = {
	id = 66,
	name = 'Iron pickaxe',
	minX = 16,
	maxX = 16,
	leftTex = 16*6,
	rightTex = 16*6,
	blockDraw = BD_TRANSPARENT
}
BlockDefinitions:createEx(opts)

opts = {
	id = 67,
	name = 'Iron sword',
	minX = 16,
	maxX = 16,
	leftTex = 16*6+1,
	rightTex = 16*6+1,
	blockDraw = BD_TRANSPARENT
}
BlockDefinitions:createEx(opts)
