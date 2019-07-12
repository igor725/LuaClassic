--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local sc = {
	global = true
}

function sc:create(player, id, label, p1, p2, r, g, b, a)
	if not player:isSupported('SelectionCuboid')then
		return false
	end
	label = label or'New selection'
	r = r or 20
	g = g or 250
	b = b or 20
	a = a or 100
	x1, y1, z1, x2, y2, z2 = makeNormalCube(p1, p2)

	local buf = player._buf
	buf:reset()
		buf:writeByte(0x1A)
		buf:writeByte(id)
		buf:writeString(label)
		buf:writeVarShort(x1, y1, z1)
		buf:writeVarShort(x2, y2, z2)
		buf:writeVarShort(r, g, b, a)
	buf:sendTo(player:getClient())
end

function sc:remove(player, id)
	if not player:isSupported('SelectionCuboid')then
		return false
	end
	local buf = player._buf
	buf:reset()
		buf:writeByte(0x1B)
		buf:writeByte(id)
	buf:sendTo(player:getClient())
	return true
end

return sc
