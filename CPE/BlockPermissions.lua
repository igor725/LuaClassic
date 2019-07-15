--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local bp = {
	global = true,
	defaults = {
		[7] = false,
		[8] = false,
		[9] = false,
		[10] = false,
		[11] = false
	}
}

local function setBlockPermFor(player, id, allowPlace, allowDelete)
	if player:isSupported('BlockPermissions')then
		local buf = player._bufwr
		buf:reset()
			buf:writeByte(0x1C)
			buf:writeByte(id)
			buf:writeByte((allowPlace and 1)or 0)
			buf:writeByte((allowDelete and 1)or 0)
		buf:sendTo(player:getClient())
	end
end

function bp:load()
	getPlayerMT().setBlockPermissions = function(...)
		setBlockPermFor(...)
	end
end

function bp:prePlayerSpawn(player)
	for id, v in pairs(self.defaults)do
		if type(v) == 'boolean'then
			setBlockPermFor(player, id, v, v)
		elseif type(v) == 'table'then
			setBlockPermFor(player, id, unpack(v))
		end
	end
end

return bp
