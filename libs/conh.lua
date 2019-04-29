--[[
TODO: Rewrite it sometime.
Threads isn't good idea in
this place.
]]

function initCmdHandler(cbfunc)
	if type(cbfunc)~='function'then return false end
	local cmdlinda = lanes.linda()
	local thread = lanes.gen('*', function()
		while true do
			local line = io.read('*l')
			if not line then break end
			if #line>0 then
				cmdlinda:send('cmd', line)
			end
		end
	end)()
	
	return function()
		if thread and thread.status == 'running'then
			local cmd = select(2, cmdlinda:receive(0,'cmd'))
			if cmd then
				cbfunc(cmd)
			end
			return true
		end
		return false
	end
end
