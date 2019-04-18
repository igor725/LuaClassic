local epl = {
	disabled = true
}

function epl:load()
	registerSvPacket(0x16, '>Bhc64c64c64B')
	registerSvPacket(0x21, '>Bbc64c64hhhbb')
end

return epl
