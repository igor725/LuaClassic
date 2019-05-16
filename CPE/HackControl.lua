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
	if player:isSupported('HackControl')then
		return player:sendPacket(false, 0x20, ...)
	end
end

function hc:load()
	registerSvPacket(0x20, 'bbbbbbh')
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
