cpe = {
	inited = false,
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

function cpe:Init()
	if self.inited then return end
	self.extCount = 0
	self.inited = true
	self.softwareName = 'LuaClassic'
	registerSvPacket(0x10, '>Bc64h')
	registerSvPacket(0x11, '>Bc64i')
	registerClPacket(0x10, '>c64h')
	registerClPacket(0x11, '>c64i')

	local f = true
	io.write('List of loaded CPE extensions: ')
	dirForEach('CPE','lua', function(filename,fullpath)
		local chunk = assert(loadfile(fullpath))
		local ext = setmetatable(chunk(), ext_mt)
		local extn = filename:sub(1,-5)
		if not ext.disabled then
			if ext.load then
				ext:load()
				ext.load = nil
			end
			self.exts[extn] = ext
			if ext.global then
				_G[extn] = ext
			end
			self.extCount = self.extCount + 1
			io.write('\n\t', extn, ', ', ext:getVersion())
		end
	end)
	io.write('\r\n')
end

function cpe:RegisterSvPacket(id, fmt)
	self.packets.sv[id] = fmt
end

function cpe:RegisterClPacket(id, fmt, ext)
	self.packets.cl[id] = fmt
	self.psizes[id] = struct.size(fmt)
	self.pexts[id] = ext
end

function cpe:GeneratePacket(id, ...)
	local fmt = self.packets.sv[id]
	if fmt then
		return struct.pack(fmt, id, ...)
	else
		return''
	end
end

function cpe:ExtCallHook(hookName, ...)
	if cpe.inited then
		for ename, ext in pairs(cpe.exts)do
			if ext[hookName] then
				ext[hookName](ext, ...)
			end
		end
	end
end

function cpe:StartFor(player)
	if cpe.inited then
		player:sendPacket(false, 0x10, self.softwareName, self.extCount)
		for name, ext in pairs(self.exts)do
			player:sendPacket(false, 0x11, name, ext:getVersion())
		end
	end
end
