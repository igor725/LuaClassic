--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

cpe = {
	softwareName = 'LuaClassic',
	extCount = 3,
	psizes = {},
	pexts = {},
	exts = {}
}

local ext_mt = {
	getVersion = function(self)
		return self.version or 1
	end
}
ext_mt.__index = ext_mt

function cpe:init()
	registerSvPacket(0x10, '>Bc64h')
	registerSvPacket(0x11, '>Bc64i')
	registerClPacket(0x10, 66, function(player, buf)
		local appName = buf:readString()
		local extCount = buf:readShort()

		if extCount < 1 then
			player:kick(KICK_CPEEXTCOUNT)
			return
		end

		player.appName = trimStr(appName)
		player.waitingExts = extCount
	end)
	registerClPacket(0x11, 68, function(player, buf)
		local extName = buf:readString()
		local extVer = buf:readInt()

		if player.waitingExts == -1 then
			player:Kick(KICK_CPESEQERR)
			return
		end

		extName = trimStr(extName)
		extName = extName:lower()
		player.extensions[extName] = extVer
		player.waitingExts = player.waitingExts - 1

		if player.waitingExts == 0 then
			player.handshakeStage2 = true
			if onPlayerHandshakeDone then
				onPlayerHandshakeDone(player)
			end
			hooks:call('onPlayerHandshakeDone', player)
		end
	end)

	local f = true
	log.info('Loading Classic Protocol Extensions')
	dirForEach('CPE', 'lua', function(_, fullpath)
		self:loadExt(fullpath)
	end)
	for extn, ext in pairs(self.exts)do
		if ext.load then
			ext:load()
			ext.load = nil
		end
	end
	local emptyExt = setmetatable({}, ext_mt)
	cpe.exts.longermessages = emptyExt
	cpe.exts.fullcp437 = emptyExt
	cpe.exts.fastmap = emptyExt
	log.info('Successfully loaded', self.extCount, 'extensions.')
end

function cpe:loadExt(path)
	local filename = path:match('^.+/(.+)$')
	local chunk = log.eassert(loadfile(path))
	local ext = setmetatable(chunk(), ext_mt)
	local extn = filename:sub(1,-5)

	if not ext.disabled then
		self.exts[extn:lower()] = ext
		if ext.global then
			_G[extn] = ext
		end
		self.extCount = self.extCount + 1
		log.debug('EXT', extn, ext:getVersion())
	end
end

function cpe:generatePacket(id, ...)
	local fmt = self.packets.sv[id]
	if fmt then
		return struct.pack(fmt, id, ...)
	end
end

function cpe:extCallHook(hookName, ...)
	for ename, ext in pairs(cpe.exts)do
		if ext[hookName] then
			ext[hookName](ext, ...)
		end
	end
end

function cpe:startFor(player)
	local buf = player._buf
	buf:reset()
		buf:writeByte(0x10)
		buf:writeString(self.softwareName)
		buf:writeShort(self.extCount)
	for name, ext in pairs(self.exts)do
		buf:writeByte(0x11)
		buf:writeString(name)
		buf:writeInt(ext:getVersion())
	end
	buf:sendTo(player:getClient())
end
