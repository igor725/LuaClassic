packets = {
	[0x00] = '>BBc64c64B',
	[0x05] = '>hhhBB',
	[0x08] = '>bhhhBB',
	[0x0d] = '>Bc64'
}

svpackets = {
	[0x00] = '>BBc64c64B',
	[0x01] = '>Bb',
	[0x04] = '>Bhhh',
	[0x06] = '>BhhhB',
	[0x07] = '>Bbc64hhhBB',
	[0x08] = '>BbhhhBB',
	[0x09] = '>BbbbbBB',
	[0x0a] = '>Bbbbb',
	[0x0b] = '>BbBB',
	[0x0c] = '>Bb',
	[0x0d] = '>Bbc64',
	[0x0e] = '>Bc64',
	[0x0f] = '>BB'
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
	if id>0 then
		registerClPacket(id, fmt)
	end
end

function generatePacket(id, ...)
	local fmt = svpackets[id]
	if fmt then
		return struct.pack(fmt, id, ...)
	else
		return''
	end
end
