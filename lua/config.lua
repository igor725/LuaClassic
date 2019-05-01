config = {
	values = {
		['server-motd'] = 'This server uses LuaClassic',
		['server-name'] = 'A Minecraft server',
		['allow-websocket'] = true,
		['websocket-port'] = 25566,
		['server-ip'] = '0.0.0.0',
		['server-port'] = 25565,
		['max-players'] = 20,

		['level-seeds'] = '',
		['level-names'] = 'world',
		['world-scripts'] = false,
		['level-types'] = 'default',
		['unload-world-after'] = 600,
		['level-sizes'] = '256x256x256',

		['gzip-compression-level'] = 5,
		['player-timeout'] = 10,
	},
	types = {}
}

function config:registerTypeFor(key, typ)
	self.types[key] = typ
	return self
end

function config:parse()
	local f, err, ec = io.open('server.properties', 'rb')
	if not f then
		if ec == 2 then
			self.changed = true
			self:save()
			return true
		else
			return false, err
		end
	end
	local ln = 1
	for line in f:lines()do
		local key, value = line:match'(.*)=(.*)'
		if key then
			if value=='true'or value=='false'then
				value = (value=='true')
			end
			value = tonumber(value)or value
			local typ = self.types[key]
			local gtyp = type(value)
			if typ and gtyp~=typ then
				print(CONF_VTYPERR%{key,typ,gtyp})
				return
			end
			self.values[key] = value
		else
			print(CONF_INVALIDSYNTAX%{'properties',ln})
		end
	end
	f:close()
	return true
end

function config:save()
	if not self.changed then return true end
	local f, err = io.open('server.properties', 'wb')
	if f then
		for key, value in pairs(self.values)do
			value = tostring(value)
			f:write(string.format('%s=%s\n', key, value))
		end
		f:close()
		self.changed = false
		return true
	else
		return false, err
	end
end

function config:get(key, default)
	local v = self.values[key]
	if v ~= nil then
		return v
	end
	if default ~= nil then
		self:set(key, default)
		return default
	end
end

function config:set(key, value)
	self.values[key] = value
	self.changed = true
	return true
end
