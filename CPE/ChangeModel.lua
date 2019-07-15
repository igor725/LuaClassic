--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local cm = {
	allowed_models = {
		['chicken'] = 1,
		['creeper'] = 2,
		['zombie'] = 2,
		['humanoid'] = 2,
		['sit'] = 1,
		['chibi'] = 1,
		['pig'] = 1,
		['sheep'] = 1,
		['sheep_nofur'] = 1,
		['skeleton'] = 2,
		['spider'] = 1,
		['head'] = 1
	}
}

local function updateModelFor(player, id, mdl)
	local buf = player._bufwr
	buf:reset()
		buf:writeByte(0x1D)
		buf:writeByte(id)
		buf:writeString(mdl)
	buf:sendTo(player:getClient())
end

function cm:load()
	getPlayerMT().setModel = function(player, model, scale)
		model = model or'humanoid'
		scale = tonumber(scale)or 1

		if model == 'sitting'then
			model = 'sit'
		end

		local mnum = tonumber(model)
		if mnum then
			if not isValidBlockID(mnum)then
				player:setModel('humanoid', scale)
				return false
			end
			model = tostring(mnum)
		else
			model = model:lower()
			if not self.allowed_models[model]then
				player:setModel('humanoid', scale)
				return false
			end
		end

		if player.model == model and scale == player.modelscale then return true end
		player.model = model
		player.modelscale = scale

		local mdstr
		if scale ~= 1 then
			mdstr = ('%s|%.2f'):format(model, scale)
		else
			mdstr = model
		end

		playersForEach(function(ply)
			if ply:isInWorld(player)then
				if ply:isSupported('ChangeModel')then
					local id = (ply == player and -1)or player:getID()
					updateModelFor(ply, id, mdstr)
				end
			end
		end)
		return true
	end

	getPlayerMT().getModelHeight = function(player)
		return self.allowed_models[player.model] * player.modelscale
	end

	saveAdd('model', 'string')
	saveAdd('modelscale', '>f')
end

function cm:postPlayerSpawn(player)
	player.model = player.model or'humanoid'
	player.modelscale = player.modelscale or 1

	if player:isSupported('ChangeModel')then
		playersForEach(function(ply)
			if ply:isInWorld(player)then
				if ply.model then
					local mdstr
					if player.modelscale ~= 1 then
						mdstr = ('%s|%.2f'):format(ply.model, ply.modelscale or 1)
					else
						mdstr = ply.model
					end
					local id = (ply == player and -1)or ply:getID()
					updateModelFor(player, id, mdstr)
				end
			end
		end)
	end
end

return cm
