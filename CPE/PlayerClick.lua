local pc = {}

onPlayerClick = onPlayerClick or function(...)hooks:call('onPlayerClick', ...)end

function pc:load()
	hooks:create('onPlayerClick')
	registerClPacket(0x22, '>bbhhbhhhb', onPlayerClick)
end

return pc
