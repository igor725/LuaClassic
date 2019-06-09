local md5func

local function check4md5()
	if not md5 then
		error('no md5 function detected')
	else
		if type(md5) == 'table'then
			md5func = assert(md5.sumhexa, 'No sumhexa function in md5 table')
		elseif type(md5) == 'function'then
			md5func = md5
		end
	end
	assert(type(md5func) == 'function', 'Variable "md5func" is not a function')
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

hooks:add('onInitDone', 'heartbeat', function()
	local hbtype = config:get('heartbeat-type')
	if hbtype == 'classicube'then
		check4md5()
		local sSalt = randomStr(6)
		_HEARTBEAT_HOST = 'classicube.net'
		_HEARTBEAT_DELAY = 50
		_HEARTBEAT_PORT = 80
		_HEARTBEAT_VALID = '^http://www%.classicube%.net/server/play/'
		_HEARTBEAT_URL = '/server/heartbeat?name=%s&port=%d&users=%d&max=%d&salt=%s&public=%s&software=LuaClassic&web=true'
		_HEARTBEAT_CLK = function()
			local ip = gethostbyname(_HEARTBEAT_HOST)
			local fd, err = connectSock(ip, _HEARTBEAT_PORT)
			if not fd then
				log.error('Heartbeat error: ' .. err)
				return
			end
			local sName = encodeURI(config:get('server-name'))
			local sPort = config:get('server-port')
			local sOnline = getCurrentOnline()
			local sPublic = config:get('heartbeat-public')
			local sMax = config:get('max-players')

			local request = (_HEARTBEAT_URL):format(sName, sPort, sOnline, sMax, sSalt, sPublic)
			sendMesg(fd, ('GET %s HTTP/1.1\n'):format(request))
			sendMesg(fd, ('Connection: close\n'):format(_HEARTBEAT_HOST))
			sendMesg(fd, ('Accept: */*\n'):format(_HEARTBEAT_HOST))
			sendMesg(fd, ('User-Agent: LC/1.1\n'):format(_HEARTBEAT_HOST))
			sendMesg(fd, ('Host: www.%s\n\n'):format(_HEARTBEAT_HOST))

			local resp = receiveLine(fd)
			local requestOk = false
			local respHdrs = {}
			if resp:lower():find('^http/.+200 ok$')then
				requestOk = true
			end

			while true do
				local line = receiveLine(fd)
				if line == ''then break end
				local key, value = line:match('(.-):%s*(.*)$')
				if key then
					respHdrs[key:lower()] = tonumber(value)or value
				end
			end

			local len = respHdrs['content-length']

			if type(len) == 'number'then
				local respBody = receiveString(fd, len)
				if respBody:find(_HEARTBEAT_VALID)then
					_HEARTBEAT_PLAY = respBody
				else
					log.error('Heartbeat: ' .. respBody)
				end
			else
				while true do
					local line = receiveLine(fd)
					if not line or line == ''then break end
					if line:find(_HEARTBEAT_VALID)then
						_HEARTBEAT_SALT = sSalt
						if _HEARTBEAT_PLAY ~= line then
							_HEARTBEAT_PLAY = line
							log.info('Server URL: ' .. line)
						end
						break
					end
				end
			end
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
end)
