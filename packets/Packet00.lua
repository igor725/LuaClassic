return function(player, pver, name, vkey, magic)
	if pver == 0x07 then
		name = trimStr(name)
		vkey = trimStr(vkey)

		if not onPlayerAuth(player, name, vkey)then
			player:kick(KICK_AUTH)
			return
		end

		player.handshaked = true
		player.handshakeStage2 = true
		onPlayerHandshakeDone(player)

		if magic == 0x42 then
			cpe:startFor(player)
			player.handshakeStage2 = false
		end
	else
		player:kick(KICK_PROTOVER)
	end
end
