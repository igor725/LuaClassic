--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

function initCmdHandler(func)
	if type(func) ~= 'function'then return false end

	local linda = lanes.linda()
	local thread = lanes.gen('io', function()
		while true do
			local line = io.read()
			if line == nil then break end
			if #line > 0 then linda:send('cmd', line)end
		end
	end)()

	hooks:add('onUpdate', 'commandsHandler', function()
		local line = select(2, linda:receive(0, 'cmd'))
		if line then func(line)end
	end)
end
