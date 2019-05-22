local cd = {}

function cd:load()
	registerSvPacket(0x12, '>bH')
	getPlayerMT().setClickDistance = function(player, cdist)
		if player:isSupported('ClickDistance')then
			player:sendPacket(false, 0x12, cdist)
		end
	end
end

return cd
