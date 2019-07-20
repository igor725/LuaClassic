--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

-- WIP
local cb = {}

function cb:load()
	registerClPacket(0x13, 'b', function(player, b)
	end)
	registerSvPacket(0x13, 'bb')
end

function cb:prePlayerSpawn(player)
	if player:isSupported('CustomBlocks')then
		player:sendPacket(false, 0x13, 1)
	end
end

return cb
