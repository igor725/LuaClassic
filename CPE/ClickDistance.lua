local cd = {}

function cd:load()
	registerSvPacket(0x12, '>bH')
	getPlayerMT().setClickDistance = function(player, cdist)
		player:sendPacket(false, 0x12, cdist)
	end
end

return cd
