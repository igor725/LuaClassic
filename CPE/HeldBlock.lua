--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local hb = {}

function hb:load()
	hooks:create('onHeldBlockChange')
	getPlayerMT().getHeldBlock = function(player)
		return player.heldBlock or -1
	end
	getPlayerMT().holdThis = function(player, block, preventChange)
		if not player:isSupported('HeldBlock')then
			return false
		end
		local buf = player._buf
		buf:reset()
			buf:writeByte(0x14)
			buf:writeByte(block)
			buf:writeByte(preventChange and 1 or 0)
		buf:sendTo(player:getClient())
		return true
	end
end

return hb
