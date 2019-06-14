--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

packets = {
	[0x00] = 'Bc64c64B',
	[0x05] = '>hhhBB',
	[0x08] = '>bhhhBB',
	[0x0d] = 'Bc64'
}

svpackets = {
	[0x00] = 'bbc64c64b',
	[0x01] = 'bb',
	[0x04] = '>bhhh',
	[0x06] = '>bhhhb',
	[0x07] = '>bbc64hhhbb',
	[0x08] = '>bbhhhbb',
	[0x09] = 'bbbbbbb',
	[0x0a] = 'bbbbb',
	[0x0b] = 'bbbb',
	[0x0c] = 'bb',
	[0x0d] = 'bbc64',
	[0x0e] = 'bc64',
	[0x0f] = 'bb'
}

psizes = {}
pHandlers = {}

local packetPathFormat = 'packets/Packet%02X.lua'

function registerClPacket(id, fmt, handler)
	packets[id] = fmt
	psizes[id] = struct.size(fmt)
	local path = (packetPathFormat):format(id)
	pHandlers[id] = handler or assert(loadfile(path))()
end

function registerSvPacket(id, fmt)
	svpackets[id] = fmt
end

for id, fmt in pairs(packets)do
	registerClPacket(id, fmt)
end

function generatePacket(id, ...)
	local fmt = svpackets[id]
	if fmt then
		return struct.pack(fmt, id, ...)
	end
end
