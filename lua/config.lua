--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local smotd = 'serverMotd'
local sname = 'serverName'
local allowws = 'acceptWebsocket'
local sip = 'serverIp'
local sport = 'serverPort'
local mplys = 'maxPlayers'
local gmd = 'serverGamemode'
local hbt = 'heartbeatType'
local hbp = 'heartbeatPublic'
local wmsg = 'welcomeMessage'
local dperms = 'defaultPerms'
local spl = 'storePlayersIn_G'
local texpack = 'texPack'

local lseeds = 'levelSeeds'
local lnames = 'levelNames'
local ltypes = 'levelTypes'
local lvlsz = 'levelSizes'
local unload = 'unloadWorldAfter'
local gthc = 'generatorThreadsCount'

local gzcmplvl = 'gzipCompressionLevel'
local plytimeout = 'playerTimeout'

config = {
	values = {
		[smotd] = DEF_SERVERMOTD,
		[sname] = DEF_SERVERNAME,
		[allowws] = true,
		[sip] = '0.0.0.0',
		[sport] = 25565,
		[mplys] = 20,
		[gmd] = 'none',
		[hbt] = 'none',
		[hbp] = false,
		[wmsg] = '',
		[dperms] = {
			'commands.list',
			'commands.info',
			'commands.seed',
			'commands.spawn',
			'commands.help',
			'commands.clear',
			'commands.craft',
			'commands.uptime'
		},
		[spl] = false,
		[texpack] = '',

		[lseeds] = {},
		[lnames] = {
			'world'
		},
		[ltypes] = {
			'default'
		},
		[unload] = 600,
		[lvlsz] = {
			{256, 256, 256}
		},
		[gthc] = 2,

		[gzcmplvl] = 5,
		[plytimeout] = 10,
	},
	types = {
		[smotd] = 'string',
		[sname] = 'string',
		[allowws] = 'boolean',
		[sip] = 'string',
		[sport] = 'number',
		[mplys] = 'number',
		[gmd] = 'string',
		[hbt] = 'string',
		[hbp] = 'boolean',
		[wmsg] = 'string',
		[dperms] = 'table',
		[spl] = 'boolean',
		[texpack] = 'string',

		[lseeds] = 'table',
		[lnames] = 'table',
		[ltypes] = 'table',
		[unload] = 'number',
		[lvlsz] = 'table',
		[gthc] = 'number',

		[gzcmplvl] = 'number',
		[plytimeout] = 'number'
	}
}

function config:parse()
	local chunk, err = loadfile('cfg.lua')
	if err then
		if err:find('^cannot%sopen')then
			self.changed = true
			self:save()
			return true
		end
		log.error(err)
		return false, err
	end
	chunk(self.values)
	for k, v in pairs(self.values)do
		local etype = self.types[k]
		log.assert(type(v) == etype, ('Parameter %q have invalid type (%s expected)'):format(k, etype))
	end
	return true
end

local function writeLuaString(file, val)
	if val:find('\n')then
		file:write('[[' .. val .. ']]')
	else
		file:write('\'' .. val .. '\'')
	end
end

function config:save()
	if not self.changed then return true end
	local cfg, err = io.open('cfg.lua', 'w')
	if not cfg then
		return false, err
	end
	cfg:write('local t = ...\n')
	for k, v in pairs(self.values)do
		cfg:write(('t.%s = '):format(k))
		local t = self.types[k]
		if t == 'table'then
			cfg:write('{')
			if #v > 0 then
				cfg:write('\n')
				for i = 1, #v do
					cfg:write('\t')
					local vv = v[i]
					if type(vv) == 'table'then
						cfg:write('{' .. table.concat(vv, ', ') .. '}')
					elseif type(vv) == 'string'then
						writeLuaString(cfg, vv)
					else
						cfg:write(tostring(vv) .. '\n')
					end
					if i ~= #v then
						cfg:write(',')
					end
					cfg:write('\n')
				end
			end
			cfg:write('}')
		elseif t == 'string'then
			writeLuaString(cfg, v)
		else
			cfg:write(tostring(v))
		end
		cfg:write('\n')
	end
	self.changed = false
	return true
end

function config:get(key)
	return self.values[key]
end

function config:set(key, value)
	if self.types[key] ~= type(value)then return false end
	self.values[key] = value
	self.changed = true
	return true
end
