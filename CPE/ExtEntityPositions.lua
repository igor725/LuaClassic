local ep = {}

function ep:load()
	cpe:registerSvPacket(0x07, '>Bbc64iiiBB')
	cpe:registerSvPacket(0x08, '>BbiiiBB')
	cpe:registerClPacket(0x08, '>biiiBB', 'ExtEntityPositions')
end

return ep
