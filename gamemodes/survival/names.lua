--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

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

local function getCustomBlockName(id)
	local name = BlockDefinitions:getOpt(id, 'name')
	if name then
		local len = 63
		for i = len, 0, -1 do
			if name[i] ~= 32 then
				len = i + 1
				break
			end
		end
		name = ffi.string(name, len)
	end
	survBlocknames[id] = name
	return name
end

function survAddBlockName(id, name)
	survBlocknames[id] = name
end

function survGetBlockName(id)
	return survBlocknames[id]
	or getCustomBlockName(id)
	or'Unknown block'
end
