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
	allowPlace = (allowPlace and 1)or 0
	allowDelete = (allowDelete and 1)or 0
	player:sendPacket(false, 0x1C, id, allowPlace, allowDelete)
end

function bp:load()
	registerSvPacket(0x1C, 'BBBB')
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
