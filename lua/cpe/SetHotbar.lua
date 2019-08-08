local hb = {}

function hb:load()
	registerSvPacket(0x2D, 'bbb')
	getPlayerMT().setHotBar = function(ply, index, block)
		if not isValidBlockID(block) or index < 0 or index > 8 then
			return false
		end

		if ply:isSupported('SetHotbar')then
			ply:sendPacket(false, 0x2D, block, index)
			return true
		end
		return false
	end
end

return hb
