--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

return function(player, appName, extCount)
	if extCount < 1 then
		player:kick(KICK_CPEEXTCOUNT)
		return
	end
	
	player.appName = trimStr(appName)
	player.waitingExts = extCount
end
