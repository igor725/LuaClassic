--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local cd = {}

function cd:load()
	getPlayerMT().setClickDistance = function(player, cdist)
		if not player:isSupported('ClickDistance')then
			return false
		end
		local buf = player._bufwr
		buf:reset()
			buf:writeByte(0x12)
			buf:writeShort(cdist)
		buf:sendTo(player:getClient())
		return true
	end
end

return cd
