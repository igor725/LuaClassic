--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local epl = {
	disabled = true
}

function epl:load()
	registerSvPacket(0x16, '>bhc64c64c64b')
	registerSvPacket(0x21, '>bbc64c64hhhbb')
end

return epl
