return function(player, pver, name, vkey, magic)
	if pver == 0x07 then
		name = trimStr(name)
		vkey = trimStr(vkey)

		local authSucc, authErr = onPlayerAuth(player, name, vkey)
		if not onPlayerAuth or not authSucc then
			player:kick(authErr or KICK_AUTH)
			return
		end

		player.handshaked = true
		player.handshakeStage2 = true

		if magic == 0x42 then
			cpe:startFor(player)
			player.handshakeStage2 = false
		else
			if onPlayerHandshakeDone then
				onPlayerHandshakeDone(player)
			end
			hooks:call('onPlayerHandshakeDone', player)
			SERVER_ONLINE = (SERVER_ONLINE or 0) + 1
		end
	else
		player:kick(KICK_PROTOVER)
	end
end
