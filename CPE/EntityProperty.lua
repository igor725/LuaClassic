local ep = {}

EP_ROTX = 0
EP_ROTY = 1
EP_ROTZ = 2

local function entPropFor(player, id, ptype, val)
	if player:isSupported('EntityProperty')then
		player:sendPacket(false, 0x2A, id, ptype, val)
	end
end

function ep:load()
	registerSvPacket(0x2A, '>bbbi')
	getPlayerMT().setProp = function(player, ptype, val)
		player.entProps = player.entProps or{}
		player.entProps[ptype] = val
		playersForEach(function(ply)
			local id = (ply == player and -1)or player:getID()
			entPropFor(ply, id, ptype, val)
		end)
	end
	getPlayerMT().getProp = function(player, ptype)
		if not player.entProps then return end
		return player.entProps[ptype]
	end
end

function ep:postPlayerSpawn(player)
	playersForEach(function(ply)
		local eprops = ply.entProps
		if eprops then
			for ptype, val in pairs(eprops)do
				entPropFor(player, ply:getID(), ptype, val)
			end
		end
	end)
end

return ep
