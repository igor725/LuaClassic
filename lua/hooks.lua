--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

hooks = {
	list = {
		['preInit'] = {},
		['onUpdate'] = {},
		['onInitDone'] = {},
		['onPlayerMove'] = {},
		['onPlayerChat'] = {},
		['onPlayerLanded'] = {},
		['onPlayerRotate'] = {},
		['prePlayerSpawn'] = {},
		['onPlayerCreate'] = {},
		['onPlayerDespawn'] = {},
		['onPlayerDestroy'] = {},
		['postPlayerSpawn'] = {},
		['onConfigChanged'] = {},
		['postPlayerTeleport'] = {},
		['onPlayerPlaceBlock'] = {},
		['prePlayerFirstSpawn'] = {},
		['postPlayerFirstSpawn'] = {},
		['postPlayerPlaceBlock'] = {},
		['onPlayerHandshakeDone'] = {}
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
			if x ~= nil then
				return x
			end
		end
	end
end
