local ep = {}

function ep:load()
	cpe:registerSvPacket(0x07, '>bbc64iiibb')
	cpe:registerSvPacket(0x08, '>bbiiibb')
	cpe:registerClPacket(0x08, '>biiibb', 'ExtEntityPositions')
end

return ep
