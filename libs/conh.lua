function initCmdHandler(cbfunc)
	if type(cbfunc)~='function'then return false end
	local cmdlinda = lanes.linda()
	local t = {}
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
	t.step = function()
		if thread.status == 'running'then
			local cmd = select(2, cmdlinda:receive(0,'cmd'))
			if cmd then
				cbfunc(cmd)
			end
		elseif thread.status == 'error'then
			print(thread[-1])
		end
		return true
	end
	return t
end
