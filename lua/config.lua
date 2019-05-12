local smotd = 'server-motd'
local sname = 'server-name'
local allowws = 'allow-websocket'
local wsport = 'websocket-port'
local sip = 'server-ip'
local sport = 'server-port'
local mplys = 'max-players'

local lseeds = 'level-seeds'
local lnames = 'level-names'
local wscripts = 'world-scripts'
local ltypes = 'level-types'
local unload = 'unload-world-after'
local lvlsz = 'level-sizes'
local gthc = 'generator-threads-count'

local gzcmplvl = 'gzip-compression-level'
local plytimeout = 'player-timeout'

config = {
	values = {
		[smotd] = DEF_SERVERMOTD,
		[sname] = DEF_SERVERNAME,
		[allowws] = true,
		[wsport] = 25566,
		[sip] = '0.0.0.0',
		[sport] = 25565,
		[mplys] = 20,

		[lseeds] = '',
		[lnames] = 'world',
		[wscripts] = false,
		[ltypes] = 'default',
		[unload] = 600,
		[lvlsz] = '256x256x256',
		[gthc] = 2,

		[gzcmplvl] = 5,
		[plytimeout] = 10,
	},
	types = {
		[smotd] = 'string',
		[sname] = 'string',
		[allowws] = 'boolean',
		[wsport] = 'number',
		[sip] = 'string',
		[sport] = 'number',
		[mplys] = 'number',

		[lseeds] = 'string',
		[lnames] = 'string',
		[wscripts] = 'boolean',
		[ltypes] = 'string',
		[unload] = 'number',
		[lvlsz] = 'string',
		[gthc] = 'number',

		[gzcmplvl] = 'number',
		[plytimeout] = 'number'
	}
}

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
				log.error(CONF_VTYPERR%{key,typ,gtyp})
				return
			end
			self.values[key] = value
		else
			log.error(CONF_INVALIDSYNTAX%{'properties',ln})
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

function config:get(key)
	local v = self.values[key]
	if v ~= nil then
		return v
	end
end

function config:set(key, value)
	self.values[key] = value
	self.changed = true
	return true
end
