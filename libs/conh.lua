function initCmdHandler(cbfunc)
	if type(cbfunc)~='function'then return false end
	local cmdlinda = lanes.linda()
	local thread = lanes.gen('*', function()
		local buffer = ''
		while true do
			local sym = io.read(1)
			if sym == '\10'then
				if #buffer>0 then
					cmdlinda:send('cmd', buffer)
					buffer = ''
				end
			else
				buffer = buffer .. sym
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
