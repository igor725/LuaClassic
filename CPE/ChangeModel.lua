local cm = {
	allowed_models = {
		['chicken'] = 1,
		['creeper'] = 1,
		['humanoid'] = 1,
		['pig'] = 1,
		['sheep'] = 1,
		['skeleton'] = 1,
		['spider'] = 1
	}
}

function cm:load()
	registerSvPacket(0x1d, '>Bbc64')
	getPlayerMT().setModel = function(player, model)
		if type(model)=='number'then
			if model<0 or model>49 then
				return false
			end
			model = tostring(model)
		else
			model = model:lower()
			if not self.allowed_models[model]then
				model = 'humanoid'
			end
		end
		player.model = model
		playersForEach(function(ply)
			if player:isSupported('ChangeModel')then
				local id = (ply==player and -1)or ply:getID()
				ply:sendPacket(false, 0x1d,id,model)
			end
		end)
		return true
	end
end

function cm:postPlayerSpawn(player)
	player.model = player.model or'humanoid'
	if player:isSupported('ChangeModel')then
		playersForEach(function(ply)
			if ply.model then
				local id = (ply==player and -1)or ply:getID()
				player:sendPacket(false, 0x1d, id, ply.model)
			end
		end)
	end
end

return cm
