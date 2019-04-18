local pc = {}

onPlayerClick = onPlayerClick or function()end

function pc:load()
	registerClPacket(0x22,'>BBhhBhhhB', onPlayerClick)
end

return pc
