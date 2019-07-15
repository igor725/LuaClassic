--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

pHandlers = {}
psizes = {}

local packetPathFormat = 'packets/Packet%02X.lua'

function registerClPacket(id, size, handler)
	psizes[id] = size
	local path = (packetPathFormat):format(id)
	pHandlers[id] = handler or log.assert(loadfile(path))()
end

registerClPacket(0x00, 130)
registerClPacket(0x05, 008)
registerClPacket(0x08, 009)
registerClPacket(0x0D, 065)
