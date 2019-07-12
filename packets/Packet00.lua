--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

-- return function(player, pver, name, vkey, magic)
return function(player, buf)
	local pver = buf:readByte()
	local name = buf:readString()
	local vkey = buf:readString()
	local magic = buf:readByte()

	if player.handshaked then
		return
	end

	if pver == 0x07 then
		name = trimStr(name)
		vkey = trimStr(vkey)

		local isBanned, reason = checkBan(name, player:getIP())
		if isBanned then
			player:kick(reason, true)
			return
		end

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
		end
	else
		player:kick(KICK_PROTOVER)
	end
end
