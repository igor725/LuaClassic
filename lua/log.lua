--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

LOG_DEBUG = 5
LOG_WARN  = 4
LOG_CHAT  = 3
LOG_INFO  = 1
LOG_ERROR = 0

log = {
	types = {
		[LOG_DEBUG] = {'DEBUG', '1;34'},
		[LOG_WARN ] = {'WARN ', '35'  },
		[LOG_CHAT ] = {'CHAT ', '1;33'},
		[LOG_INFO ] = {'INFO ', '1;32'},
		[LOG_ERROR] = {'ERROR', '1;31'}
	},
	level = tonumber(os.getenv('LOGLEVEL'))or LOG_WARN
}

local function printlogline(ltype, ...)
	if log.level < ltype then return end
	local ltdata = log.types[ltype]
	local color = enableConsoleColors and ltdata[2]
	local fmt
	local time, mtime = math.modf(gettime())
	mtime = mtime * 999

	if color then
		fmt = os.date('%H:%M:%S.%%03d [\27[%%sm%%s\27[0m] ', time)
		fmt = (fmt):format(mtime, color, ltdata[1])
	else
		fmt = os.date('%H:%M:%S.%%03d [%%s] ', time)
		fmt = (fmt):format(mtime, ltdata[1])
	end
	io.write(fmt)

	local idx = 1
	while true do
		local val = select(idx, ...)
		if val == nil then
			break
		end
		if idx > 1 then
			io.write(' ')
		end
		if type(val) == 'string'then
			io.write(mc2ansi(val))
		else
			io.write(tostring(val))
		end
		idx = idx + 1
	end
	io.write('\27[0m\n')
end

function log.setLevel(lvl)
	lvl = tonumber(lvl)
	if not lvl then return false end
	log.level = math.max(math.min(lvl, LOG_DEBUG), LOG_ERROR)
	return true
end

function log.debug(...)
	local info = debug.getinfo(3)
	printlogline(LOG_DEBUG, info.short_src, info.currentline, '|', ...)
end

function log.warn(...)
	printlogline(LOG_WARN, ...)
end

function log.info(...)
	printlogline(LOG_INFO, ...)
end

function log.chat(...)
	printlogline(LOG_CHAT, ...)
end

function log.error(...)
	printlogline(LOG_ERROR, ...)
end

function log.fatal(...)
	log.error(...)
	_STOP = true
end

function log.assert(val, ...)
	if not val then
		log.fatal(...)
	end
	return val, ...
end

function log.eassert(val, ...)
	if not val then
		log.error(...)
	end
	return val, ...
end
