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
		onPlayerHandshakeDone(player)
	end
end
