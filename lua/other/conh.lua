--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT

	TODO: Improve this code
]]

local cbfunc, cbuf, cbufpos

if jit.os == 'Windows'then
	ffi.cdef[[
		bool _kbhit(void);
		char _getch(void);
	]]

	function initCmdHandler(func)
		if type(func) ~= 'function'then return false end

		cbufpos = 0
		cbfunc = func
		cbuf = ffi.new('char[256]')
	end

	hooks:add('onUpdate', 'cmdhandler', function()
		if C._kbhit()then
			local b = C._getch()
			if b >= 32 and b <= 126 then
				if cbufpos < 255 then
					cbuf[cbufpos] = b
					cbufpos = cbufpos + 1
					io.write(string.char(b))
				end
			elseif b == 13 then
				io.write('\13\10')
				cbfunc(ffi.string(cbuf, cbufpos))
				cbufpos = 0
			elseif b == 8 then
				if cbufpos > 0 then
					cbuf[cbufpos] = 0
					cbufpos = cbufpos - 1
					-- Oh...
					io.write('\8\0\8')
				end
			end
		end
	end)
else
	function initCmdHandler()

	end
end
