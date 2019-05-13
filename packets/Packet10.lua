return function(player, appName, extCount)
	if extCount < 1 then
		player:kick(KICK_CPEEXTCOUNT)
		return
	end
	player.appName = trimStr(appName)
	player.waitingExts = extCount
end
