local ep = {}

function ep:load()
	cpe:RegisterSvPacket(0x07, '>Bbc64iiiBB')
	cpe:RegisterSvPacket(0x08, '>BbiiiBB')
	cpe:RegisterClPacket(0x08, '>biiiBB', 'ExtEntityPositions')
end

return ep
