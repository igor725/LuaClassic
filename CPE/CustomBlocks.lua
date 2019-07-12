--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

-- WIP
local cb = {}

function cb:load()
	registerClPacket(0x13, 1, function()end)
end

function cb:prePlayerSpawn(player)
	if player:isSupported('CustomBlocks')then
		local buf = player._buf
		buf:reset()
			buf:writeByte(0x13)
			buf:writeByte(0x01)
		buf:sendTo(player:getClient())
	end
end

return cb
