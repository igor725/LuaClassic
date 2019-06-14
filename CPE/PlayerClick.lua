--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local pc = {}

onPlayerClick = onPlayerClick or function(...)hooks:call('onPlayerClick', ...)end

function pc:load()
	hooks:create('onPlayerClick')
	registerClPacket(0x22, '>bbhhbhhhb', onPlayerClick)
end

return pc
