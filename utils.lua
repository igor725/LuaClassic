ffi = require('ffi')
C = ffi.C

local meta = debug.getmetatable('')
meta.__mod = function(self,vars)
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

local ext = (jit.os=='Windows'and'dll')or'so'
package.cpath = './bin/%s/?.%s;'%{jit.arch,ext}
package.path = './libs/?.lua;./libs/?/init.lua;./?.lua'

floor = math.floor
ceil = math.ceil
bswap = bit.bswap

function checkEnv(ev, val)
	local evar = os.getenv(ev)
	if evar then
		return evar:lower():find(val:lower())
	else
		return false
	end
end

ENABLE_ANSI = checkEnv('ConEmuANSI','on')or checkEnv('TERM','xterm')

local colorReplace

if ENABLE_ANSI then
	local rt = {
		['&0'] = '30',
		['&1'] = '34',
		['&2'] = '32',
		['&3'] = '36',
		['&4'] = '1;31',
		['&5'] = '35',
		['&6'] = '1;33',
		['&7'] = '1;30',
		['&8'] = '1;30',
		['&9'] = '1;34',
		['&a'] = '1;32',
		['&b'] = '1;36',
		['&c'] = '1;31',
		['&d'] = '1;35',
		['&e'] = '33',
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
		if ENABLE_ANSI then
			str = str..'\27[0m'
		end
		return str
	else
		return str
	end
end

local cprint = print
local cwrite = io.write

function print(...)
	local p = {...}
	for i=1,#p do
		p[i] = mc2ansi(tostring(p[i]))
	end
	cprint(unpack(p))
end
function io.write(...)
	local p = {...}
	for i=1,#p do
		p[i] = mc2ansi(tostring(p[i]))
	end
	cwrite(unpack(p))
end

function trimStr(str)
	return str:match('^%s*(.-)%s*$')
end

function getAddr(void)
	return tonumber(ffi.cast('uint32_t', void))
end

function playersForEach(func)
	for player, id in pairs(players)do
		local ret = func(player, id)
		if ret~=nil then
			return ret
		end
	end
end

function broadcast(str, exid)
	playersForEach(function(player, id)
		if id~=exid then
			player:sendNetMesg(str)
		end
	end)
end

function setID(player)
	local s = 1
	while IDS[s]do
		s = s + 1
		if s>127 then
			return -1
		end
	end
	local mp = config:get('max-players', 20)
	if s>mp then s = -1 end
	return s
end

function table.hasValue(tbl, ...)
	local ch = {...}
	for k, v in pairs(tbl)do
		for k1, v1 in pairs(ch)do
			if v==v1 then
				return true
			end
		end
	end
	return false
end

function string.split(self, sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

function newChatMessage(msg, id)
	playersForEach(function(ply)
		ply:sendMessage(msg, id)
	end)
end

function dirForEach(dir, ext, func)
	for file in lfs.dir(dir)do
		local fp = dir+'/'+file
		if lfs.attributes(fp, 'mode')=='file'and
		file:sub(-#ext)==ext then
			func(file,fp)
		end
	end
end

function getWorld(w)
	if type(w)=='table'then
		if w.isWorld then
			return w
		elseif w.isPlayer then
			return worlds[w.worldName]
		end
	elseif type(w)=='string'then
		w = w:lower()
		return worlds[w]
	end
end

function loadWorld(wname)
	if worlds[wname]then return false end
	local status, world = pcall(newWorld,wname)
	if status then
		worlds[wname] = world
		return true
	end
	return false, world
end

function unloadWorld(wname)
	local world = getWorld(wname)
	if world==worlds['default']then
		return false
	end

	if world then
		playersForEach(function(player)
			if player:isInWorld(wname)then
				player:changeWorld('default')
			end
		end)
		world:save()
		world.buf = nil
		worlds[wname] = nil
		collectgarbage()
		return true
	end
	return false
end

function loadGenerator(name)
	local chunk = assert(loadfile('generators/'+name+'.lua'))
	local generator = chunk()
	generators[name] = generator
	return generator
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

function getPlayerByName(name)
	if not name then return end
	name = name:lower()
	return playersForEach(function(ply)
		if ply:getName():lower()==name then
			return ply
		end
	end)
end

function createWorld(wname, dims, gen, seed)
	local data = {dimensions=dims}
	local tmpWorld = newWorld()
	if tmpWorld:createWorld(data)then
		tmpWorld:setName(wname)
		worlds[wname] = tmpWorld
		return regenerateWorld(wname, gen, seed)
	else
		return false
	end
end

function regenerateWorld(world, gentype, seed)
	world = getWorld(world)
	if not world then return false, WORLD_NE end
	if world:isInReadOnly()then return false, WORLD_RO end
	local p = 'generators/'+gentype+'.lua'
	local chunk, err = loadfile(p)
	if not chunk then
		return false, err
	else
		local status, ret = pcall(chunk)
		if not status then
			return false, tostring(ret)
		else
			if type(ret)=='function'then
				world.data.colors = nil
				world.data.map_aspects = nil
				world.data.texPack = nil
				playersForEach(function(player)
					if player:isInWorld(world)then
						player:despawn()
					end
				end)
				local data = ffi.cast('char*',world:getAddr()+4)
				ffi.fill(data, world.size)
				seed = seed or CTIME
				local t = socket.gettime()
				local succ, err = pcall(ret, world, seed)
				if not succ then
					print(err)
					return false, err
				end
				local e = socket.gettime()
				io.write('done\n')
				playersForEach(function(player)
					if player:isInWorld(world)then
						player.handshakeStage2 = true
					end
				end)
				return true, e-t
			end
		end
	end
	return false, IE_UE
end

function bindSock(ip, port)
	if ip == '*'then
		ip = '0.0.0.0'
	end
	local sock = (socket.tcp4 and socket.tcp4())or socket.tcp()
	assert(sock:setoption('tcp-nodelay', true))
	assert(sock:setoption('reuseaddr', true))
	assert(sock:settimeout(0))
	assert(sock:bind(ip, port))
	assert(sock:listen())
	return sock
end

function printf(...)
	local str = string.format(...)
	print(str)
	return str
end
