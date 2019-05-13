ffi = require('ffi')
C = ffi.C
ffi.cdef[[
	typedef unsigned char uchar;

	typedef struct {
		char *fpos;
		void *base;
		unsigned short handle;
		short flags;
		short unget;
		unsigned long alloc;
		unsigned short buffincrement;
	} FILE;

	typedef struct {
		uchar r;
		uchar g;
		uchar b;
	} color;
	typedef struct {
		float x;
		float y;
		float z;
	} vector;
	typedef struct {
		float yaw;
		float pitch;
	} angle;

	size_t fread(const void * ptr, size_t size, size_t count, FILE *stream);
	size_t fwrite(const void * ptr, size_t size, size_t count, FILE *stream);
	int    ferror(FILE *stream);
]]

local ext = (jit.os=='Windows'and'dll')or'so'
package.cpath = ('./bin/%s/?.%s;'):format(jit.arch,ext)
package.path = './lua/?.lua;./?.lua'

function checkEnv(ev, val)
	local evar = os.getenv(ev)
	if evar then
		return evar:lower():find(val:lower())
	else
		return false
	end
end

ENABLE_ANSI = checkEnv('ConEmuANSI', 'on')or checkEnv('TERM', 'xterm')or
checkEnv('TERM', 'screen')
require('log')

local meta = debug.getmetatable('')
meta.__mod = function(self,vars)
	local info = debug.getinfo(2)
	log.warn('Deprecated metamethod used on line', info.currentline, 'in file', info.short_src)
	if type(vars)=='table'then
		return self:format(unpack(vars))
	else
		return self:format(vars)
	end
end
meta.__add = function(self,add)
	if add ~= nil then
		return self..tostring(add)
	else
		return self
	end
end

lanes = require('lanes').configure{
	with_timers = false
}
struct = require('struct')
lfs = require('lfs')

do
	local path = package.searchpath('socket.core', package.cpath)
	if path then
		local lib = package.loadlib(path, 'luaopen_socket_core')
		if not lib then
			lib = package.loadlib(path, 'luaopen_lanes_core')
		end
		if lib then
			socket = lib()
		end
	end
	if not socket then
		error('Can\'t load socket library')
	end
end

function newColor(r,g,b)
	r, g, b = r or 255, g or 255, b or 255
	return ffi.new('color', r, g, b)
end

function newAngle(y,p)
	return ffi.new('angle', y, p)
end

function newVector(x,y,z)
	return ffi.new('vector', x, y, z)
end

floor = math.floor
ceil = math.ceil
bswap = bit.bswap

local colorReplace

if ENABLE_ANSI then
	local rt = {
		['&0'] = '30',
		['&1'] = '34',
		['&2'] = '32',
		['&3'] = '36',
		['&4'] = '31',
		['&5'] = '35',
		['&6'] = '33',
		['&7'] = '1;30',
		['&8'] = '1;30',
		['&9'] = '1;34',
		['&a'] = '1;32',
		['&b'] = '1;36',
		['&c'] = '1;31',
		['&d'] = '1;35',
		['&e'] = '1;33',
		['&f'] = '0'
	}
	colorReplace = function(s)
		s = s:lower()
		return string.format('\27[%sm', rt[s])
	end
else
	colorReplace = function()
		return ''
	end
end

function mc2ansi(str)
	local pattern = '(&%x)'
	if str:find(pattern)then
		str = str:gsub(pattern, colorReplace)
	end
	return str
end

function printf(...)
	local str = string.format(...)
	log.info(str)
	return str
end

function trimStr(str)
	return str:match('^%s*(.-)%s*$')
end

function getAddr(void)
	return tonumber(ffi.cast('uintptr_t', void))
end

function table.hasValue(tbl, ...)
	for k, v in pairs(tbl)do
		local idx = 1
		while true do
			local tv = select(idx, ...)
			if tv == nil then
				break
			end
			if tv == v then
				return true
			end
			idx = idx + 1
		end
	end
	return false
end

function string.split(self, sep)
	local sep, fields = sep or ":", {}
	local pattern = string.format("([^%s]+)", sep)
	self:gsub(pattern, function(c) fields[#fields + 1] = c end)
	return fields
end

function string.startsWith(self, ...)
	local idx = 1
	while true do
		local str = select(idx, ...)
		if str == nil then
			break
		end
		if self:sub(1, #str) == str then
			return true, idx
		end
		idx = idx + 1
	end
	return false
end

function dirForEach(dir, ext, func)
	for file in lfs.dir(dir)do
		local fp = dir + '/' + file
		if lfs.attributes(fp, 'mode')=='file'and
		file:sub(-#ext)==ext then
			func(file,fp)
		end
	end
end

function makeNormalCube(x1, y1, z1, x2, y2, z2)
	local px1, py1, pz1 = x1, y1, z1
	local px2, py2, pz2 = x2, y2, z2

	if x1-x2<0 then
		px1 = x2+1
		px2 = x1
	else
		px1 = x1+1
	end
	if y1-y2<0 then
		py1 = y2+1
		py2 = y1
	else
		py1 = y1+1
	end
	if z1-z2<0 then
		pz1 = z2+1
		pz2 = z1
	else
		pz1 = z1+1
	end

	return px1, py1, pz1, px2, py2, pz2
end

function bindSock(ip, port)
	local sock = (socket.tcp4 and socket.tcp4())or socket.tcp()
	assert(sock:setoption('tcp-nodelay', true))
	assert(sock:setoption('reuseaddr', true))
	assert(sock:settimeout(0))
	assert(sock:bind(ip, port))
	assert(sock:listen())
	return sock
end

function watchThreads(threads)
	while #threads > 0 do
		local thread = threads[#threads]
		if thread then
			if thread.status == 'error'then
				log.error(thread[-1])
				table.remove(threads, #threads)
			elseif thread.status == 'done'then
				table.remove(threads, #threads)
			end
		else
			socket.sleep(.05)
		end
	end
end
