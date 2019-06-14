--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

return function(player, extName, extVer)
	if player.waitingExts == -1 then
		player:Kick(KICK_CPESEQERR)
		return
	end
	extName = trimStr(extName)
	extName = extName:lower()
	player.extensions[extName] = extVer
	player.waitingExts = player.waitingExts - 1
	if player.waitingExts == 0 then
		player.handshakeStage2 = true
		if onPlayerHandshakeDone then
			onPlayerHandshakeDone(player)
		end
		hooks:call('onPlayerHandshakeDone', player)
		SERVER_ONLINE = (SERVER_ONLINE or 0) + 1
	end
end
