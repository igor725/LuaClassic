return function(player, isPartial, message)
	if isPartial==1 then
		player.messageBuffer = player.messageBuffer..message
		return
	end
	message = trimStr(message)
	local out out = onPlayerChatMessage(player, player.messageBuffer..message)
	player.messageBuffer = ''
	if out then
		player:sendMessage(tostring(out))
	end
end
