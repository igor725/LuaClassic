local lm = {}

function lm:prePlayerSpawn(player)
	player.messageBuffer = ''
end

return lm
