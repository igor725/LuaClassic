local epl = {
	disabled = true
}

function epl:load()
	registerSvPacket(0x16, '>bhc64c64c64b')
	registerSvPacket(0x21, '>bbc64c64hhhbb')
end

return epl
