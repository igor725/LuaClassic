return function(player, unused, message)
	local out
	if cpe.inited then
		if unused==1 then
			player.messageBuffer = player.messageBuffer..message
			return
		end
		message = trimStr(message)
		out = onPlayerChatMessage(player, player.messageBuffer..message)
		player.messageBuffer = ''
	else
		message = trimStr(message)
		out = onPlayerChatMessage(player, message)
	end
	if out then
		player:sendMessage(tostring(out))
	end
end
