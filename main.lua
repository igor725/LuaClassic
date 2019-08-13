--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

io.stdout:setvbuf('no')

do
	local function vermismatch()
		print('Server requires LuaJIT >= 2.0.0-beta11')
		os.exit(1)
	end

	if not (jit and jit.version)then
		vermismatch()
	elseif jit.version_num == 20000 then
		local ver = jit.version
		local beta = ver:match('.+%-beta(%d+)')
		beta = tonumber(beta)
		if beta and beta < 11 then
			vermismatch()
		end
	elseif jit.version_num < 20000 then
		vermismatch()
	end
end

require('utils')
START_TIME = gettime()

function onPlayerAuth(player, name, key)
	player:setUID(key)
	if not player:setName(name)then
		return false, KICK_NAMETAKEN
	end
	player:saveRead()
	return true
end

function prePlayerFirstSpawn(player)
	if not player.notified then
		local wMsg = config:get('welcomeMessage')
		if wMsg and #wMsg > 0 then
			player:sendMessage(wMsg)
		end
		local msg = printf(MESG_CONN, player)
		newChatMessage('&e' .. msg)
		player.notified = true
	end
end

function onPlayerDisconnect(player)
	local reason = player:getLeaveReason()
	local msg
	if not reason then
		msg = printf(MESG_WORDISCONN, player)
	else
		msg = printf(MESG_DISCONN, player, reason)
	end

	newChatMessage('&e' .. msg)
	if player:isHandshaked()then
		log.eassert(player:saveWrite())
	end
end

function onPlayerChatMessage(player, message)
	local starts = message:sub(1, 1)
	if not message:startsWith('#', '>', '/')then
		message = message:gsub('%%(%x)', '&%1')
	end
	local prefix = ''
	if #player.prefix > 0 then
		prefix = ('[%s&f] '):format(player.prefix)
	end
	if starts == '!'then message = message:sub(2)end
	local formattedMessage = ('%s&3%s&f: %s'):format(prefix, player, message)
	log.chat(formattedMessage)

	if starts == '#'then
		if player:checkPermission('server.luaexec')then
			local code = message:sub(2)
			code = code:gsub('^=', 'return ')
			local chunk, err = loadstring(code)
			if chunk then
				world = getWorld(player)
				self = player
				local ret = {pcall(chunk)}
				self = nil
				world = nil
				for i = 2, #ret do
					ret[i] = tostring(ret[i])
				end
				if ret[1]then
					if #ret > 1 then
						return (MESG_EXECRET):format(table.concat(ret, ', ', 2))
					else
						return MESG_EXEC
					end
				else
					return (MESG_ERROR):format(ret[2])
				end
			else
				return (MESG_ERROR):format(err)
			end
		end
	elseif starts == '/'then
		local args = message:split(' ')
		if #args > 0 then
			local cmd = table.remove(args, 1):sub(2)
			cmd = cmd:lower()
			cmd = aliases[cmd]or cmd
			local cmf = commands[cmd]
			if cmf then
				if player:checkPermission('commands.' .. cmd)then
					local succ, rtval = xpcall(cmf, debug.traceback, false, player, args)
					if not succ then
						player:sendMessage((IE_MSG):format(IE_LE))
						log.error('Command', cmd, 'got error:', rtval)
						return
					end
					if rtval == false then
						local str = _G['CU_' .. cmd:upper()]
						if str then
							player:sendMessage((CON_USE):format(str))
						end
					else
						if rtval == nil then return end
						player:sendMessage(rtval)
					end
				end
			else
				player:sendMessage(MESG_UNKNOWNCMD)
			end
		end
	elseif starts == '@'then
		local name, message = message:match('^@(.-)%s(.+)')
		if name and #name > 0 then
			local target = getPlayerByName(name)
			if target == player then
				player:sendMessage(CMD_WHISPERSELF)
				return
			end
			if target then
				target:sendMessage((CMD_WHISPER):format(player, message))
				player:sendMessage(CMD_WHISPERSUCC)
			else
				player:sendMessage(MESG_PLAYERNF)
			end
		end
	elseif starts == '!'then -- Message to global chat
		newChatMessage('&2G&f ' .. formattedMessage)
	else -- Message to local chat
		newLocalChatMessage(player, formattedMessage)
	end
end

local httpPattern = '^get%s+(.+)%s+http/%d%.%d$'

function wsUpdateHandshake(i)
	local data = wsHandshake[i]
	local fd = data.fd

	if ctime > data.timeout then
		data.state = 'badrequest'
		data.emsg = 'Timed out'
	end

	if data.state == 'testws'then
		local hdr, closed = receiveString(fd, 3, MSG_PEEK)
		if closed then
			closeSock(fd)
			wsHandshake[i] = nil
			return
		end

		if hdr and #hdr == 3 then
			if hdr:lower() == 'get'then
				data.state = 'initial'
				data.timeout = ctime + 1
			else
				wsHandshake[i] = nil
				createPlayer(fd, data.ip, false)
			end
		end
	end

	if data.state == 'initial'then
		local req, closed = receiveLine(fd)
		if closed then
			closeSock(fd)
			wsHandshake[i] = nil
			return
		end

		if req then
			req = req:lower()
			if req:find(httpPattern)then
				data.state = 'headers'
				data.timeout = ctime + 1
			end

			if data.state ~= 'headers'then
				data.state = 'badrequest'
				data.emsg = 'Not a GET request'
			end
		end
	end

	if data.state == 'headers'then
		local ln, err = receiveLine(fd)
		if err == 2 then
			closeSock(fd)
			wsHandshake[i] = nil
			return
		end

		if ln == ''then
			data.state = 'genresp'
			data.timeout = ctime + 1
		elseif ln then
			local k, v = ln:match('(.+)%s*:%s*(.+)')
			if k then
				k = k:lower()
				data.headers[k] = v
			else
				data.state = 'badrequest'
				data.emsg = 'Invalid header'
			end
		end
	end

	if data.state == 'genresp'then
		local hdr = data.headers
		local wskey = hdr['sec-websocket-key']
		local wsver = hdr['sec-websocket-version']
		local wsproto = hdr['sec-websocket-protocol']
		local conn = hdr['connection']
		local upgrd = hdr['upgrade']

		if upgrd and wskey and conn and
		upgrd:lower() == 'websocket'and
		conn:lower():find('upgrade')and
		tonumber(wsver) == 13 then
			wsproto = wsproto or'noproto'
			wskey = wskey .. WSGUID
			wskey = b64enc(sha1(wskey))
			wsHandshake[i] = nil

			if wsproto == 'ClassiCube'then
				local player = createPlayer(fd, data.ip, true)
				player._sframe = ffi.new('struct ws_frame')
				setupWFrameStruct(player._sframe, fd)
			else
				if wsHandlers[wsproto]then
					local frame = ffi.new('struct ws_frame')
					setupWFrameStruct(frame, fd)

					for i = 0, 127 do
						if not wsConnections[i]then
							wsConnections[i] = {
								sframe = frame,
								proto = wsproto,
								fd = fd
							}
							break
						elseif i == 127 then
							data.state = 'badrequest'
							data.emsg = 'Server cannot accept connection'
							return
						end
					end
				else
					data.state = 'badrequest'
					data.emsg = 'Invalid protocol'
					return
				end
			end

			local response =
			('HTTP/1.1 101 Switching Protocols\r\n' ..
			'Upgrade: websocket\r\nConnection: Upgrade\r\n' ..
			'Sec-WebSocket-Protocol: %s\r\n' ..
			'Sec-WebSocket-Accept: %s\r\n\r\n'):format(wsproto, wskey)
			sendMesg(fd, response)
		else
			data.state = 'badrequest'
		end
	end

	if data.state == 'badrequest'then
		local msg = data.emsg or MESG_NOTWSCONN
		local response =
		('HTTP/1.1 400 Bad request\r\n' ..
		'Content-Type: text/plain; charset=utf-8\r\n' ..
		'Content-Length: %d\r\n\r\n%s')
		:format(#msg, msg)
		table.insert(waitClose, fd)
		sendMesg(fd, response)
		wsHandshake[i] = nil
	end
end

function createPlayer(fd, ip, isWS)
	if not onConnectionAttempt or not onConnectionAttempt(ip)then
		local player = newPlayer(fd)
		player.isWS = isWS
		player.ip = ip

		local nid = findFreeID(player)
		if nid >= 0 then
			player:init(nid)
		else
			player:kick(KICK_SFULL)
		end
		hooks:call('onPlayerCreate', player)
		return player
	else
		local rawPacket = generatePacket(0x0e, KICK_CONNREJ)
		if isWS then
			sendMesg(fd, encodeWsFrame(rawPacket, #rawPacket, 0x02))
		else
			sendMesg(fd, rawPacket)
		end
	end
end

function handleConsoleCommand(cmd)
	if cmd:sub(1, 1) == '#'then
		local code = cmd:sub(2)
		code = code:gsub('^=', 'return ')

		local chunk, err = loadstring(code)
		if chunk then
			local ret = {pcall(chunk)}
			for i=2, #ret do
				ret[i] = tostring(ret[i])
			end
			if #ret > 1 then
				if ret[1]then
					log.info(table.concat(ret, ', ', 2))
				else
					log.error((MESG_ERROR):format(ret[2]))
				end
			else
				log.info(MESG_EXEC)
			end
		else
			log.error((MESG_ERROR):format(err))
		end
	else
		local args = cmd:split('%s')
		cmd = table.remove(args, 1)
		if not cmd then return end
		local argstr = table.concat(args,' ')
		cmd = cmd:lower()
		cmd = aliases[cmd]or cmd

		local cmf = commands[cmd]
		if cmf then
			local succ, rtval = xpcall(cmf, debug.traceback, true, nil, args)
			if not succ then
				log.error('Command', cmd, 'got error:', rtval)
				return
			end
			if rtval == false then
				local str = _G['CU_' .. cmd:upper()]
				if str then
					log.info((CON_USE):format(str))
				end
			else
				if rtval == nil then return end
				log.info(rtval)
			end
		else
			log.error(MESG_UNKNOWNCMD)
		end
	end
end

function acceptClients()
	local fd, ip = acceptClient(server)
	if not fd then return end
	log.debug(DBG_INCOMINGCONN, ip)
	if wsHandshake then
		for i = 0, 127 do
			if not wsHandshake[i]then
				wsHandshake[i] = {
					timeout = ctime + 1,
					state = 'testws',
					headers = {},
					fd = fd,
					ip = ip
				}
				break
			end
		end
		return
	end
	createPlayer(fd, ip, false)
end

local cwait = ffi.new('uint8_t[256]')
function serviceMessages()
	playersForEach(function(player)
		player:serviceMessages()
	end)

	if wsConnections then
		for i = 0, 127 do
			if wsHandshake[i]then
				wsUpdateHandshake(i)
			end

			local conn = wsConnections[i]
			if conn then
				local frame = conn.sframe
				local st = receiveFrame(frame)
				if st == -1 then
					wsConnections[i] = nil
					table.insert(waitClose, conn.fd)
				elseif st then
					if frame.opcode == 0x8 then
						wsConnections[i] = nil
						table.insert(waitClose, conn.fd)
					else
						wsHandlers[conn.proto](conn)
					end
				end
			end
		end
	end

	while #waitClose > 0 do
		local fd = table.remove(waitClose)
		while receiveMesg(fd, cwait, 256) > 0 do end
		closeSock(fd)
	end
end

function init()
	log.info(CON_START)
	waitClose = {}
	entities = {}
	nworlds = {}
	worlds = {}

	config:parse()
	banlist:parse()
	permissions:parse()
	cpe:init()

	uwa = config:get('unloadWorldAfter')
	local ip = config:get('serverIp')
	local port = config:get('serverPort')
	server = log.assert(bindSock(ip, port))

	if config:get('acceptWebsocket')then
		wsConnections = {}
		wsHandshake = {}
		wsHandlers = {}
		wsLoad()
	else
		wsLoad = nil
	end

	local gm = config:get('serverGamemode')
	if gm and #gm > 0 and gm ~= 'none'then
		local path = 'lua/gamemodes/' .. gm .. '/%s.lua'
		function gmLoad(fn)
			log.debug(DBG_GMLOAD, fn)
			return assert(loadfile((path):format(fn)))()
		end
		log.info('Loading gamemode', mode)
		local chunk, err = loadfile((path):format('init'))
		if chunk then
			initGamemode = chunk
		else
			log.fatal('Gamemode loading error:', err)
		end

		if initGamemode then
			initGamemode()
			log.info('Gamemode:', gm)
			initGamemode = nil
		end
	end

	log.info(CON_WLOAD)
	local sdlist = config:get('levelSeeds')
	local wlist = config:get('levelNames')
	local tlist = config:get('levelTypes')
	local slist = config:get('levelSizes')

	for num = 1, #wlist do
		local wn = wlist[num]
		wn = wn:lower()
		local world
		local lvlh = io.open('worlds/' .. wn .. '.map', 'rb')
		if lvlh then
			world = newWorld(lvlh, wn)
		else
			local gtype = tlist[num]or'default'
			local dims = slist[num]or{256, 256, 256}
			world = newWorld()
			world:setName(wn)
			if world:createWorld({dimensions = newVector(unpack(dims))})then
				log.eassert(regenerateWorld(world, gtype, sdlist[num]or os.time()))
			end
		end
		if world and world.isWorld then
			worlds[wn] = world
			nworlds[num] = world
			world.emptyfrom = ctime
			if num == 1 then
				worlds['default'] = world
			end
		end
	end

	if not getWorld('default')then
		log.fatal(CON_WLOADERR)
	end

	dirForEach('lua/autorun', 'lua', function(_, path)
		log.assert(loadfile(path))()
	end)

	local asave = config:get('auosaveDelay')
	if asave > 0 then
		timer.Create('autosave', -1, asave, saveAll)
	end

	log.info((CON_BINDSUCC):format(ip, port))
	cmdh = initCmdHandler(handleConsoleCommand)
	log.info(CON_HELP)
	ctime = gettime()
	return true
end

function saveAll()
	playersForEach(function(ply)
		log.eassert(ply:saveWrite())
	end)
	if config:save()and permissions:save()then
		log.debug(CON_SAVESUCC)
	else
		log.error(CON_SAVEERR)
	end
	banlist:save()
	log.debug(CON_WSAVE)
	worldsForEach(function(world, wname)
		log.eassert(world:save())
	end)
	collectgarbage()
end

function mainLoop()
	while not _STOP do
		etime = ctime
		ctime = gettime()

		if not inited then
			if init()then
				hooks:call('onInitDone')
				inited = true
				if _STOP then break end
			end
		end

		if etime then
			dt = ctime - etime
			hooks:call('onUpdate', dt)
			timer.Update(dt)
			worldsForEach(function(world)
				world:update()
			end)
		end

		acceptClients()
		serviceMessages()

		NextUpdate = ctime + 0.02
		if NextUpdate > gettime()then
			sleep((NextUpdate - gettime()) * 1000)
		end

		hasError = false
	end
end

while true do
	succ, err = xpcall(mainLoop, debug.traceback)
	if succ or hasError or not inited then
		break
	else
		log.error(err)
		hasError = true
	end
end

hooks:call('onMainLoopStop')

ecode = 0

if inited then
	log.info(CON_SVDAT)
	playersForEach(function(ply)
		if _STOP == 'restart'then
			ply:kick(KICK_SVRST)
		else
			ply:kick((not succ and KICK_SVERR)or KICK_SVSTOP)
		end
	end)
	saveAll()
	local saveDone = false
	while not saveDone do
		saveDone = true
		worldsForEach(function(world)
			if world.gzipThread then
				world:update()
				saveDone = false
			end
		end)
		sleep(20)
	end
end

if server then closeSock(server)end
cleanupSock()

if not succ then
	err = tostring(err)
	if not err:find('interrupted')then
		if not hooks:call('onMainLoopError', err)then
			print(err)
		end
		ecode = 1
	end
end

if _STOP == 'restart'then
	ecode = 2
end

os.exit(ecode)
