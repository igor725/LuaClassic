--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

cpe = {
	softwareName = 'LuaClassic',
	extCount = 3,
	packets = {
		sv = {},
		cl = {}
	},
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
	registerClPacket(0x10, '>c64h')
	registerClPacket(0x11, '>c64i')

	local f = true
	log.info('Loading Classic Protocol Extensions')
	dirForEach('lua/network/cpe', 'lua', function(_, fullpath)
		self:loadExt(fullpath)
	end)
	for extn, ext in pairs(self.exts)do
		if ext.load then
			ext:load()
			ext.load = nil
		end
	end
	local emptyExt = setmetatable({}, ext_mt)
	cpe.exts.LongerMessages = emptyExt
	cpe.exts.FullCP437 = emptyExt
	cpe.exts.FastMap = emptyExt
	log.info('Successfully loaded', self.extCount, 'extensions.')
end

function cpe:loadExt(path)
	local filename = path:match('^.+/(.+)$')
	local chunk = log.eassert(loadfile(path))
	local ext = setmetatable(chunk(), ext_mt)
	local extn = filename:sub(1,-5)

	if not ext.disabled then
		self.exts[extn] = ext
		if ext.global then
			_G[extn] = ext
		end
		self.extCount = self.extCount + 1
		log.debug('EXT', extn, ext:getVersion())
	end
end

function cpe:registerSvPacket(id, fmt)
	self.packets.sv[id] = fmt
end

function cpe:registerClPacket(id, fmt, ext)
	self.packets.cl[id] = fmt
	self.psizes[id] = struct.size(fmt)
	self.pexts[id] = ext
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
	player:sendPacket(false, 0x10, self.softwareName, self.extCount)
	for name, ext in pairs(self.exts)do
		player:sendPacket(false, 0x11, name, ext:getVersion())
	end
end
