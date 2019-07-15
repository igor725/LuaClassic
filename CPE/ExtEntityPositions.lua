--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local ep = {}

function ep:load()
	cpe:registerClPacket(0x08, 15, 'ExtEntityPositions')
end

return ep
