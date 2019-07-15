--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local hc = {
	global = true,
	defaults = {1, 1, 1, 1, 1, -1}
}

HC_FLYING   = 1
HC_NOCLIP   = 2
HC_SPEED    = 3
HC_SPAWNCTL = 4
HC_TPV      = 5
HC_JUMP     = 6

local function hackControlFor(player, ...)
	if not player:isSupported('HackControl')then
		return false
	end
	local buf = player._bufwr
	buf:reset()
		buf:writeByte(0x20)
	for i = 1, 5 do
		buf:writeByte(select(i, ...))
	end
		buf:writeShort(select(6, ...))
	buf:sendTo(player:getClient())
	return true
end

function hc:load()
	getPlayerMT().hackControl = function(...)
		return hackControlFor(...)
	end
end

function hc:prePlayerSpawn(player)
	hackControlFor(player, unpack(self.defaults))
end

function hc:setDefault(typ, val)
	if self.defaults[typ]then
		self.defaults[typ] = val
		playersForEach(function(player)
			hackControlFor(player, unpack(self.defaults))
		end)
		return true
	end
	return false
end

function hc:getDefault(typ)
	return self.defaults[typ]
end

return hc
