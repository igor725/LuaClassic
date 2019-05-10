LOG_DEBUG = 5
LOG_WARN  = 4
LOG_CHAT  = 3
LOG_INFO  = 1
LOG_ERROR = 0

local types = {
	[LOG_DEBUG] = 'DEBUG',
	[LOG_WARN]  = 'WARN ',
	[LOG_CHAT]  = 'CHAT ',
	[LOG_INFO]  = 'INFO ',
	[LOG_ERROR] = 'ERROR'
}

log = {
	colors = {
		[LOG_DEBUG] = '1;34',
		[LOG_WARN]  = '35',
		[LOG_CHAT]  = '1;33',
		[LOG_INFO]  = '1;32',
		[LOG_ERROR] = '1;31'
	},
	level = LOG_CHAT
}

if not ENABLE_ANSI then
	log.colors = nil
end

local function printlogline(ltype, ...)
	if log.level < ltype then return end
	local color = (log.colors and log.colors[ltype])or nil
	local fmt
	if color then
		fmt = os.date('%H:%M:%S [\27[%%sm%%s\27[0m] ')
		fmt = string.format(fmt, color, types[ltype])
	else
		fmt = os.date('%H:%M:%S [%%s] ')
		fmt = string.format(fmt, types[ltype])
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

function log.setlevel(lvl)
	lvl = tonumber(lvl)
	if not lvl then return false end
	lvl = math.max(math.min(lvl, 3), 0)
	return true
end

function log.error(...)
	printlogline(LOG_ERROR, ...)
end

function log.fatal(...)
	log.error(...)
	os.exit(1)
end

function log.warn(...)
	printlogline(LOG_WARN, ...)
end

function log.chat(...)
	printlogline(LOG_CHAT, ...)
end

function log.info(...)
	printlogline(LOG_INFO, ...)
end

function log.debug(...)
	printlogline(LOG_DEBUG, ...)
end
