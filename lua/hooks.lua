hooks = {
	list = {
		['onUpdate'] = {},
		['onPlayerMove'] = {},
		['onPlayerChat'] = {},
		['onPlayerRotate'] = {},
		['prePlayerSpawn'] = {},
		['onPlayerDespawn'] = {},
		['postPlayerSpawn'] = {},
		['onPlayerPlaceBlock'] = {}
	}
}

function hooks:create(hookname)
	self.list[hookname] = {}
end

function hooks:add(hookname, bname, func)
	self.list[hookname][bname] = func
end

function hooks:remove(hookname, bname)
	self.list[hookname][bname] = nil
end

function hooks:call(hookname, ...)
	local hks = self.list[hookname]
	if hks then
		for _, fnc in pairs(hks)do
			local x = fnc(...)
			if x~=nil then
				return x
			end
		end
	end
end
