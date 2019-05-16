local pc = {}

onPlayerClick = onPlayerClick or function()end

function pc:load()
	registerClPacket(0x22, '>bbhhbhhhb', onPlayerClick)
end

return pc
