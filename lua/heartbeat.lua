--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local md5func

local function check4md5()
	if not md5 then
		error('no md5 function detected')
	else
		if type(md5) == 'table'then
			md5func = log.assert(md5.sumhexa, 'No sumhexa function in md5 table')
		elseif type(md5) == 'function'then
			md5func = md5
		end
	end
	log.assert(type(md5func) == 'function', 'Variable "md5func" is not a function')
end

local function encodeURI(str)
	if (str) then
		str = string.gsub (str, '\n', '\r\n')
		str = string.gsub (str, '([^%w ])',
		function (c) return string.format ('%%%02X', string.byte(c)) end)
		str = string.gsub (str, ' ', '+')
	end
	return str
end

function _restartHeartbeat(sSalt)
	local hbtype = config:get('heartbeatType')
	if hbtype == 'classicube'then
		sSalt = sSalt or randomStr(6)
		_HEARTBEAT_HOST = 'classicube.net'
		_HEARTBEAT_IP = gethostbyname(_HEARTBEAT_HOST)
		_HEARTBEAT_DELAY = 45
		_HEARTBEAT_PORT = 80
		_HEARTBEAT_VALID = '^http://www%.classicube%.net/server/play/'
		_HEARTBEAT_URL = '/server/heartbeat?name=%s&port=%d&users=%d&max=%d&salt=%s&public=%s&software=%s&web=%s'
		_HEARTBEAT_CLK = function()
			local fd, err = connectSock(_HEARTBEAT_IP, _HEARTBEAT_PORT)

			if not fd then
				log.error('Heartbeat connection error:', err)
				return
			end

			local sName = encodeURI(config:get('serverName'))
			local sPublic = config:get('heartbeatPublic')
			local sWeb = config:get('acceptWebsocket')
			local sPort = config:get('serverPort')
			local sMax = config:get('maxPlayers')
			local sSoftware = cpe.softwareName
			local sOnline = getCurrentOnline()

			local request = (_HEARTBEAT_URL):format(sName, sPort, sOnline, sMax, sSalt, sPublic, sSoftware, sWeb)
			sendMesg(fd, ('GET %s HTTP/1.1\n'):format(request))
			sendMesg(fd, 'Cache-Control: no-cache, no-store\n')
			sendMesg(fd, 'Accept: application/x-www-form-urlencoded\n')
			sendMesg(fd, 'User-Agent: LC/1.1\n')
			sendMesg(fd, ('Host: www.%s\n\n'):format(_HEARTBEAT_HOST))

			local resp = receiveLine(fd)
			if not resp then
				closeSock(fd)
				return
			end

			local ok = true
			if not resp:lower():find('^http/.+200 ok$')then
				log.error('Heartbeat server responded:', resp)
				log.debug('Request:', request)
				ok = false
			end

			local respHdrs = {}
			while true do
				local line = receiveLine(fd)
				if not line or line == ''then break end
				local key, value = line:match('(.-):%s*(.*)$')
				if key then
					respHdrs[key:lower()] = tonumber(value)or value
					if not ok then
						log.debug(line)
					end
				end
			end

			if ok then
				while true do
					local line = receiveLine(fd)
					if not line or line == ''then break end
					if line:find(_HEARTBEAT_VALID)then
						_HEARTBEAT_SALT = sSalt
						if _HEARTBEAT_PLAY ~= line then
							_HEARTBEAT_PLAY = line
							log.info('Server URL:', line)
						end
						break
					end
				end
			else
				local clen = tonumber(respHdrs['content-length'])
				if clen then
					log.debug(receiveString(fd, clen))
				end
			end
			closeSock(fd)
		end

		function onPlayerAuth(player, name, key)
			if key ~= md5func(_HEARTBEAT_SALT .. name)then
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

	if _HEARTBEAT_HOST then
		timer.Create('heartbeat', -1, _HEARTBEAT_DELAY, _HEARTBEAT_CLK)
		_HEARTBEAT_CLK()
	end
end

hooks:add('onInitDone', 'heartbeat', function()
	check4md5()
	math.randomseed(os.time())
	local sSalt = randomStr(6)
	_restartHeartbeat(sSalt)
end)
