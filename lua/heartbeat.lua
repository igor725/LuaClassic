--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local linda = lanes.linda()
local heartbeatData

local function encodeURI(str)
	if (str) then
		str = string.gsub (str, '\n', '\r\n')
		str = string.gsub (str, '([^%w ])',
		function (c) return string.format ('%%%02X', string.byte(c)) end)
		str = string.gsub (str, ' ', '+')
	end
	return str
end

local function hThread(data)
	ffi = require('ffi')
	require('socket')

	local currServerURL

	local defaultHeaders = {
		['Accept'] = 'application/x-www-form-urlencoded',
		['Cache-Control'] = 'no-cache, no-store',
		['User-Agent'] = 'LC/1.2'
	}

	local sleep
	if jit.os == 'Windows'then
		ffi.cdef'void Sleep(uint32_t);'
		function sleep(ms)
			ffi.C.Sleep(ms)
		end
	else
		ffi.cdef[[
			void usleep(uint32_t);
			struct timeval {
				long tv_sec;
				long tv_usec;
			};
		]]
		function sleep(ms)
			ffi.C.usleep(ms * 1000)
		end
	end

	local function sendHeader(fd, key, value)
		sendMesg(fd, ('%s: %s\n'):format(key, value))
		if data.debug then
			print('request header', key, value)
		end
	end

	local function heartbeatRequest(request)
		local ip = gethostbyname(data.host)
		local fd, err = connectSock(ip, data.hbport or 80)

		if not fd then
			print('heartbeat thread error', err)
			return
		end

		if data.debug then
			print('heartbeat request', request)
		end
		sendMesg(fd, ('GET %s HTTP/1.1\n'):format(request))
		if data.headers then
			for k, v in pairs(data.headers)do
				sendHeader(fd, k, v)
			end
			for k, v in pairs(defaultHeaders)do
				if not data.headers[k]then
					sendHeader(fd, k, v)
				end
			end
		else
			for k, v in pairs(defaultHeaders)do
				sendHeader(fd, k, v)
			end
		end
		sendMesg(fd, '\n')

		local httpOK, delim = true
		local resp = receiveLine(fd)
		if not resp then
			if data.debug then
				print('no heartbeat response')
			end
			closeSock(fd)
			return
		end
		if not resp:lower():find('^http/.+200 ok$')then
			delim = ('*'):rep(20)
			print(delim)
			print('heartbeat server responded', resp)
			print('heartbeat request', request)
			httpOK = false
		end

		local respHdrs = {}
		while true do
			local line = receiveLine(fd)
			if not line or line == ''then break end
			local key, value = line:match('(.-):%s*(.*)$')
			if key then
				respHdrs[key:lower()] = value
				if data.debug then
					print('heartbeat response header', key, value)
				end
			end
		end

		if httpOK then
			while true do
				local line = receiveLine(fd)
				if not line or line == ''then break end
				if line:find(data.valid)then
					return line
				end
			end
		else
			local clen = tonumber(respHdrs['content-length'])
			if clen and clen > 0 then
				if data.debug then
					print('heartbeat response body', receiveString(fd, clen))
				end
			end
		end

		closeSock(fd)
		if not httpOK then
			print(delim)
		end
	end

	local function heartbeatClick()
		local request = (data.request):gsub('%b{}', function(s)
			return tostring(data[s:sub(2, -2)])
		end)

		local url = heartbeatRequest(request)
		if url and url ~= currServerURL then
			linda:send('url', url)
			currServerURL = url
		end
	end

	while true do
		for k, v in pairs(data)do
			local _, newValue = linda:receive(0, k)
			if _ ~= nil then
				data[k] = newValue
				if k == 'salt'then
					linda:send(k, newValue)
				end
			end
		end
		if data.salt and#data.salt > 0 then
			heartbeatClick()
			sleep(data.delay or 10000)
		else
			sleep(100)
		end
	end
end

function updateHbtData(key, value)
	linda:send(key, value)
end

local function sendOnline()
	if heartbeatThread then
		updateHbtData('online', getCurrentOnline())
	end
end

hooks:add('onInitDone', 'heartbeat', function()
	math.randomseed(os.time())
	local hb = config:get('heartbeatType')
	if hb == 'classicube'then
		local ccreq = '/server/heartbeat?name={name}&port={port}&users={online}' ..
		'&max={max}&salt={salt}&public={public}&software={software}&web={webSupport}'
		local sSalt = randomStr(12)

		heartbeatData = {
			valid = '^http://www%.classicube%.net/server/play/',
			headers = {['Host'] = 'www.classicube.net'},
			name = encodeURI(config:get('serverName')),
			webSupport = config:get('acceptWebsocket'),
			public = config:get('heartbeatPublic'),
			port = config:get('serverPort'),
			max = config:get('maxPlayers'),
			software = cpe.softwareName,
			online = getCurrentOnline(),
			host = 'classicube.net',
			request = ccreq,
			salt = sSalt,
			delay = 25000
		}
		heartbeatThread = lanes.gen('*', hThread)(heartbeatData)
		heartbeatSalt = sSalt

		function onPlayerAuth(player, name, key)
			if key ~= md5.sumhexa(heartbeatData.salt .. name)then
				return false, 'Invalid session, restart your client and try to connect again.'
			end
			player:setUID(name)
			if not player:setName(name)then
				return false, KICK_NAMETAKEN
			end
			player:saveRead()
			return true
		end
	end
end)

hooks:add('onUpdate', 'heartbeat', function()
	if heartbeatThread then
		if heartbeatThread.status == 'error'then
			log.error('Heartbeat thread error', heartbeatThread[-1])
			heartbeatThread = nil
			return
		end
		local _, v = linda:receive(0, 'salt')
		if v then
			heartbeatSalt = v
		end
		local _, url = linda:receive(0, 'url')
		if url then
			log.info('Server URL:', url)
		end
	end
end)

hooks:add('onConfigChanged', 'heartbeat', function(key, value)
	if key == 'serverName'then
		updateHbtData('name', encodeURI(value))
	elseif key == 'heartbeatPublic'then
		updateHbtData('public', value)
	end
end)

hooks:add('postPlayerFirstSpawn', 'heartbeat', sendOnline)
hooks:add('onPlayerDestroy', 'heartbeat', sendOnline)
