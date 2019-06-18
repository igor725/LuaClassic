--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

return function(player, isPartial, message)
	if isPartial == 1 then
		player.messageBuffer = player.messageBuffer .. message
		return
	end
	message = trimStr(message)
	message = player.messageBuffer .. message
	player.messageBuffer = ''

	local out = hooks:call('onPlayerChat', player, message)
	out = (out == false and nil)or(out == nil and message)or tostring(out)
	if out then
		out = onPlayerChatMessage(player, out)
		if out ~= nil then
			player:sendMessage(tostring(out))
		end
	end
end
