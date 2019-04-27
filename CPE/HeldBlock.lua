local hb = {}

function hb:load()
	registerSvPacket(0x14, 'BBB')
	getPlayerMT().getHeldBlock = function(self)
		return self.heldBlock or -1
	end
end

function hb:holdThis(player, block, prevent)
	if player:isSupported('HeldBlock')then
		player:sendPacket(false, 0x14, block, (prevent and 1)or 0)
	end
end

return hb
