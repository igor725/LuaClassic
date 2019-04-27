local ep = {
	global = true
}

EP_ROTX = 0
EP_ROTY = 1
EP_ROTZ = 2

local function entPropFor(ply, id, ptype, val)
	ply:sendPacket(false, 0x2A, id, ptype, val)
end

function ep:load()
	registerSvPacket(0x2A, '>Bbbi')
end

function ep:postPlayerSpawn(player)
	if player:isSupported('EntityProperty')then
		playersForEach(function(ply)
			local eprops = ply.entProps
			if eprops then
				for ptype, val in pairs(eprops)do
					entPropFor(player, ply:getID(), ptype, val)
				end
			end
		end)
	end
end

function ep:setEntProp(player, ptype, val)
	player.entProps = player.entProps or{}
	player.entProps[ptype] = val
	playersForEach(function(ply)
		if ply:isSupported('EntityProperty')then
			local id = (ply==player and -1)or player:getID()
			entPropFor(ply, id, ptype, val)
		end
	end)
end

return ep
