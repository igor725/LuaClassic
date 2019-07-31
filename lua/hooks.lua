--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

hooks = {
	list = {}
}

function hooks:recalculatePriority(hookname)
	local prt = self.list[hookname].priority
	table.sort(prt, function(a, b)
		return prt[a] < prt[b]
	end)
end

function hooks:create(hookname)
	self.list[hookname] = {priority = {}}
end

function hooks:add(hookname, bname, func, priority)
	priority = priority or 100
	local hks = self.list[hookname]
	if not table.hasValue(hks.priority, bname)then
		table.insert(hks.priority, bname)
	end
	hks.priority[bname] = priority
	hks[bname] = func

	self:recalculatePriority(hookname)
end

function hooks:remove(hookname, bname)
	local hks = self.list[hookname]
	hks.priority[bname] = nil
	for i = #hks.priority, 1, -1 do
		if hks.priority[i] == bname then
			table.remove(hks.priority, i)
		end
	end
	hks[bname] = nil

	self:recalculatePriority(hookname)
end

function hooks:call(hookname, ...)
	local hks = self.list[hookname]
	if hks then
		for i = 1, #hks.priority do
			local fnc = hks[hks.priority[i]]
			local x = fnc(...)
			if x ~= nil then
				return x
			end
		end
	end
end

hooks:create('preInit')
hooks:create('onUpdate')
hooks:create('onMainLoopError')
hooks:create('onInitDone')
hooks:create('onPlayerMove')
hooks:create('onPlayerChat')
hooks:create('onPlayerLanded')
hooks:create('onPlayerRotate')
hooks:create('prePlayerSpawn')
hooks:create('onPlayerCreate')
hooks:create('onPlayerDespawn')
hooks:create('onPlayerDestroy')
hooks:create('postPlayerSpawn')
hooks:create('onConfigChanged')
hooks:create('postPlayerTeleport')
hooks:create('prePlayerPlaceBlock')
hooks:create('prePlayerFirstSpawn')
hooks:create('postPlayerFirstSpawn')
hooks:create('postPlayerPlaceBlock')
hooks:create('onPlayerHandshakeDone')
