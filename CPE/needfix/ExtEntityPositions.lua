--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local ep = {}

function ep:load()
	cpe:registerSvPacket(0x07, '>bbc64iiibb')
	cpe:registerSvPacket(0x08, '>bbiiibb')
	cpe:registerClPacket(0x08, '>Biiibb', 'ExtEntityPositions')
end

return ep
