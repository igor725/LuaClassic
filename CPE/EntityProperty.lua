--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local ep = {}

EP_ROTX = 0
EP_ROTY = 1
EP_ROTZ = 2

local function entPropFor(player, id, ptype, val)
	if player:isSupported('EntityProperty')then
		local buf = player._bufwr
		buf:reset()
			buf:writeByte(0x2A)
			buf:writeByte(id)
			buf:writeByte(ptype)
			buf:writeInt(val)
		buf:sendTo(player:getClient())
	end
end

function ep:load()
	getPlayerMT().setProp = function(player, ptype, val)
		player.entProps = player.entProps or{}
		player.entProps[ptype] = val
		playersForEach(function(ply)
			local id = (ply == player and -1)or player:getID()
			entPropFor(ply, id, ptype, val)
		end)
	end
	getPlayerMT().getProp = function(player, ptype)
		if not player.entProps then return 0 end
		return player.entProps[ptype]or 0
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
