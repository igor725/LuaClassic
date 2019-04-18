return function(player, appName, extCount)
	if extCount<1 then
		player:kick()
		return
	end
	player.appName = trimStr(appName)
	player.waitingExts = extCount
end
