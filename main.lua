io.stdout:setvbuf('no')
require('lng')

do
	local function vermismatch()
		print(CON_LJVER)
		os.exit(1)
	end

	if not (jit or jit.version)then
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

if os.getenv('DEBUG')then
	local path = os.getenv('MDPATH')
	path = path or'../mobdebug.lua'
	loadfile(path)().start()
end

require('utils')
require('commands')
dirForEach('lua', 'lua', function(file)
	require(file:sub(1, -5))
end)

function onConnectionAttempt(ip, port)
end

function postPlayerSpawn(player)
	cpe:extCallHook('postPlayerSpawn', player)
	hooks:call('postPlayerSpawn', player)
	local world = worlds[player.worldName]
	world.players = world.players + 1
	world.emptyfrom = nil
end

function prePlayerSpawn(player)
	cpe:extCallHook('prePlayerSpawn', player)
	hooks:call('prePlayerSpawn', player)
end

function onPlayerClick(...)
	hooks:call('onPlayerClick', ...)
end

function onPlayerDespawn(player)
	cpe:extCallHook('postPlayerDespawn', player)
	hooks:call('onPlayerDespawn', player)
	local world = worlds[player.worldName]
	world.players = world.players - 1
	if world.players == 0 then
		world.emptyfrom = CTIME
	end
end

function onPlayerDestroy(player)
	local msg = printf(MESG_DISCONN, player:getName(), player.leavereason)
	newChatMessage('&e' .. msg)
	cpe:extCallHook('onPlayerDestroy', player)
	hooks:call('onPlayerDestroy', player)
	if player.handshaked then
		local x, y, z = player:getPos()
		local ay, ap = player:getEyePos()
		local world = player.worldName
		local otime
		if player.lastOnlineTime then
			otime = floor(player.lastOnlineTime + (CTIME - player.connectTime))
		end
		if x and world and otime then
			assert(sql:insertData(player:getVeriKey(), {'spawnX', 'spawnY', 'spawnZ', 'spawnYaw', 'spawnPitch', 'lastWorld', 'onlineTime'}, {x, y, z, ay, ap, world, otime}))
		end
	end
end

function onPlayerHandshakeDone(player)
	local msg = printf(MESG_CONN, player:getName())
	newChatMessage('&e' .. msg)
end

function onPlayerChatMessage(player, message)
	local prt = hooks:call('onPlayerChat', player, message)
	if prt ~= nil then
		message = tostring(prt)
	end
	local starts = message:sub(1,1)
	if not message:startsWith('#', '>', '/')then
		message = message:gsub('%%(%x)', '&%1')
	end
	log.chat(('%s: %s'):format(player, message))

	if starts == '#'then
		if player:checkPermission('server.luaexec')then
			local code = message:sub(2)
			if code:sub(1,1) == '='then
				code = 'return ' .. code:sub(2)
			end
			local chunk, err = loadstring(code)
			if chunk then
				world = getWorld(player)
				self = player
				local ret = {pcall(chunk)}
				self = nil
				world = nil
				for i=2, #ret do
					ret[i] = tostring(ret[i])
				end
				if ret[1] then
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
		else
			return err
		end
	elseif starts == '/'then
		local args = message:split(' ')
		if #args > 0 then
			local cmd = table.remove(args, 1):sub(2)
			cmd = cmd:lower()
			local cmf = commands[cmd]
			if cmf then
				if player:checkPermission('commands.' .. cmd)then
					local out = cmf(player, unpack(args))
					if out ~= nil then
						player:sendMessage(out)
					end
				end
			else
				player:sendMessage(MESG_UNKNOWNCMD)
			end
		end
	elseif starts == '>'then
		local wname = message:sub(2)
		wname = wname:lower()
		local succ, msg = player:changeWorld(wname)
		if not succ then
			if msg == 0 then
				player:sendMessage(WORLD_NE)
			end
		end
	elseif starts == '!'then -- Message to global chat
		newChatMessage(player:getName() .. ': ' .. message:sub(2))
	else -- Message to local chat
		local cmsg = player:getName() .. ': ' .. message
		playersForEach(function(ply)
			if ply:isInWorld(player)then
				ply:sendMessage(cmsg)
			end
		end)
	end
end

function onUpdate(dt)
	cpe:extCallHook('onUpdate', dt)
	hooks:call('onUpdate', dt)
	timer.Update(dt)

	if uwa > 0 then
		for _, world in pairs(worlds)do
			if world.emptyfrom then
				if CTIME-world.emptyfrom>uwa then
					world:unload()
					world.emptyfrom = nil
				end
			end
		end
	end
end

function onPlayerMove(player, dx, dy, dz)
	hooks:call('onPlayerMove', player, dx, dy, dz)
	local world = getWorld(player)
	local portals = world.data.portals
	if portals then
		local x, y, z = player:getPos()
		for _, portal in pairs(portals)do
			y = floor(y)
			if (portal.pt1[1] >= x and portal.pt2[1] <= x)
			and(portal.pt1[2] >= y and portal.pt2[2] <= y)
			and(portal.pt1[3] >= z and portal.pt2[3] <= z)then
				player:changeWorld(portal.tpTo, true)
				break
			end
		end
	end
end

function onPlayerRotate(player, dy, dp)
	hooks:call('onPlayerRotate', player, dy, dp)
end

function onPlayerPlaceBlock(player, x, y, z, id)
	local world = getWorld(player)
	if world:isReadOnly()then
		player:sendMessage(WORLD_RO, 100)
		return true
	end
	local prt = hooks:call('onPlayerPlaceBlock', player, dy, dp)
	if prt ~= nil then
		return prt
	end
	if player.onPlaceBlock then
		return player.onPlaceBlock(x, y, z, id)
	end
end

function wsAcceptClients()
	local cl = wsServer:accept()
	if not cl then return end
	cl:settimeout(0)
	wsHandshake[cl] = {
		state = 'initial',
		headers = {}
	}
end

function wsDoHandshake()
	for cl, data in pairs(wsHandshake)do
		local _, status = cl:receive(0)
		if status == 'closed'then
			wsHandshake[cl] = nil
			return
		end

		if data.state == 'initial'then
			local req = cl:receive()
			if req and req:lower():find('get%s*(.+)%s*http/1.1')then
				data.state = 'headers'
			else
				data.state = 'badrequest'
				data.emsg = 'Not a HTTP request'
			end
		elseif data.state == 'headers'then
			local ln = cl:receive()
			if ln == ''then
				data.state = 'genresp'
			elseif ln then
				local k, v = ln:match('(.+)%s*:%s*(.+)')
				if k then
					k = k:lower()
					v = v:lower()
					data.headers[k] = v
				else
					data.state = 'badrequest'
					data.emsg = 'Invalid header'
				end
			end
		elseif data.state == 'genresp'then
			local hdr = data.headers
			local wskey = hdr['sec-websocket-key']
			local wsver = hdr['sec-websocket-version']
			local conn = hdr['connection']
			local upgrd = hdr['upgrade']

			if upgrd and wskey and conn and
			upgrd == 'websocket'and
			conn:find('upgrade')and
			tonumber(wsver) == 13 then
				wskey = wskey .. WSGUID
				wskey = b64enc(sha1(wskey))
				local response =
				('HTTP/1.1 101 Switching Protocols\r\n' ..
				'Upgrade: websocket\r\nConnection: Upgrade\r\n' ..
				'Sec-WebSocket-Accept: %s\r\n\r\n'):format(wskey)
				cl:send(response)
				wsHandshake[cl] = nil
				createPlayer(cl, true)
			else
				data.state = 'badrequest'
			end
		elseif data.state == 'badrequest'then
			local msg = data.emsg or MESG_NOTWSCONN
			local response =
			('HTTP/1.1 400 Bad request\r\n' ..
			'Content-Type: text/plain; charset=utf-8\r\n' ..
			'Content-Length: %d\r\n\r\nBad request: %s')
			:format(#msg + 13, msg)
			cl:send(response)
			cl:close()
			wsHandshake[cl] = nil
		end
	end
end

function createPlayer(cl,isWS)
	local ip = cl:getpeername()
	if not onConnectionAttempt(ip)then
		local player = newPlayer(cl)
		player.isWS = isWS
		player.ip = ip
		local nid = findFreeID(player)

		if nid > 0 then
			player:init(nid)
		else
			player:kick(KICK_SFULL)
		end
	else
		local rawPacket = generatePacket(0x0e, KICK_CONNREJ)
		if isWS then
			cl:send(encodeWsFrame(rawPacket, 0x02))
		else
			cl:send(rawPacket)
		end
	end
end

function handleConsoleCommand(cmd)
	if cmd:sub(1,1) == '#'then
		local code = cmd:sub(2)
		if code:sub(1,1)=='='then
			code = 'return ' .. code:sub(2)
		end

		local chunk, err = loadstring(code)
		if chunk then
			local ret = {pcall(chunk)}
			for i=2, #ret do
				ret[i] = tostring(ret[i])
			end
			if ret[1] then
				log.info(table.concat(ret, ', ', 2))
			else
				log.error((MESG_ERROR):format(ret[2]))
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

		local cmdf = concommands[cmd]
		if cmdf then
			local rtval, str = cmdf(args, argstr)
			if not rtval then
				local str = _G['CU_' .. cmd:upper()]
				if str then log.info((CON_USE):format(str))end
			elseif rtval == true then
				if str == nil then return end
				log.info(str)
			end
		else
			log.error(MESG_UNKNOWNCMD)
		end
	end
end

function acceptClients()
	local cl = server:accept()
	if not cl then return end
	cl:settimeout(.0001)
	createPlayer(cl, false)
end

function serviceMessages()
	playersForEach(function(player)
		player:serviceMessages()
	end)
end

function init()
	local loglvl  = tonumber(os.getenv('LOGLEVEL'))
	if loglvl then
		log.setLevel(loglvl)
	end
	log.info(CON_START)
	players, IDS = {}, {}
	worlds, generators = {}, {}

	permissions:parse()
	config:parse()
	cpe:init()
	sql:init()

	uwa = config:get('unload-world-after')
	local ip = config:get('server-ip')
	local port = config:get('server-port')
	server = bindSock(ip, port)

	local ws = config:get('allow-websocket')
	if ws then
		WSGUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
		wsPort = config:get('websocket-port')
		wsServer = bindSock(ip, wsPort)
		wsHandshake = {}
		require('helper')
	end

	log.info(CON_WLOAD)
	local sdlist = config:get('level-seeds')
	sdlist = sdlist:split(',')

	local wlist = config:get('level-names')
	wlist = wlist:split(',')

	local tlist = config:get('level-types')
	tlist = tlist:split(',')

	local slist = config:get('level-sizes')
	slist = slist:split(',')

	for num, wn in pairs(wlist)do
		wn = wn:lower()
		local st = socket.gettime()
		local world
		local lvlh = io.open('worlds/' .. wn .. '.map', 'rb')
		if lvlh then
			world = newWorld(lvlh, wn)
		else
			local gtype = tlist[num]or'default'
			local dims = slist[num]or'256x256x256'
			local generator = generators[gtype]or assert(openGenerator(gtype))
			generators[gtype] = generator
			local x, y, z = dims:match('(%d+)x(%d+)x(%d+)')
			x = tonumber(x)
			y = tonumber(y)
			z = tonumber(z)
			if not(x and y and z and generator)then
				error(CON_PROPINVALID)
			end
			world = newWorld()
			world:setName(wn)
			if world:createWorld({dimensions=newVector(x, y, z)})then
				generator(world,sdlist[num]or CTIME)
			end
		end
		if world then
			worlds[wn] = world
			world.emptyfrom = CTIME
			if num == 1 then
				worlds['default'] = world
			end
			local tm = (MESG_DONEIN):format((socket.gettime() - st) * 1000)
			log.debug(wn, 'loading', tm)
		end
	end
	generators = nil
	if not worlds['default']then
		log.fatal(CON_WLOADERR)
	end

	local add
	if wsServer then
		add = (CON_WSBINDSUCC):format(wsPort)
	end
	log.info((CON_BINDSUCC):format(ip, port), add)
	cmdh = initCmdHandler(handleConsoleCommand)
	log.info(CON_HELP)
	CTIME = socket.gettime()
	return true
end

succ, err = xpcall(function()
	while not _STOP do
		ETIME = CTIME
		CTIME = socket.gettime()

		if not INITED then INITED=init()end
		if ETIME then
			dt = CTIME - ETIME
			dt = math.min(.1, dt)
			onUpdate(dt)
		end

		acceptClients()
		serviceMessages()

		if wsServer then
			wsAcceptClients()
			wsDoHandshake()
		end

		if cmdh then
			cmdh()
		end
		socket.sleep(.01)
	end
end,debug.traceback)

ecode = 0

if INITED then
	playersForEach(function(ply)
		if _STOP == 'restart'then
			ply:kick(KICK_SVRST)
		else
			ply:kick(KICK_SVSTOP)
		end
	end)

	if config:save()and permissions:save()then
		log.info(CON_SAVESUCC)
	else
		log.error(CON_SAVEERR)
	end

	log.info(CON_WSAVE)
	for wname, world in pairs(worlds)do
		if wname ~= 'default'then
			local s = socket.gettime()
			if world:save()then
				log.debug('World', wname, 'saved')
			else
				log.error(wname,'saving error')
			end
		end
	end
end

if sql then sql:close()end
if server then server:close()end
if wsServer then wsServer:close()end

if not succ then
	err = tostring(err)
	if not err:find('interrupted')then
		print(err)
		ecode = 1
	end
end

if _STOP == 'restart'then
	ecode = 2
else
	log.info(CON_SVSTOP)
end

os.exit(ecode)
