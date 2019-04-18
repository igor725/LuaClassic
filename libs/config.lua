config = {
	values = {},
	types = {}
}

function config:registerTypeFor(key, typ)
	self.types[key] = typ
	return self
end

function config:parse()
	local f, err, ec = io.open('server.properties','rb')
	if f then
		local ln = 1
		local pr = 0
		for line, num in f:lines()do
			if line:byte()~=35 then
				local key, value = line:match'(.*)=(.*)'
				if key then
					value, cnt = value:gsub('[\r\n]','')
					local cs = value:find(' #')
					if cs then
						value = value:sub(1,cs-1)
					end
					value = value:gsub('%%(%x+)',function(s)
						return string.char(tonumber(s,16))
					end)
					if value=='true'or value=='false'then
						value = (value=='true')
					end
					value = tonumber(value)or value
					local typ = self.types[key]
					local gtyp = type(value)
					if typ and gtyp~=typ then
						print(CONF_VTYPERR%{key,gtyp,typ})
						return
					end
					self.values[key] = value
					pr = pr + 1
				else
					print(CONF_INVALIDSYNTAX%{'properties',ln})
				end
			end
			ln = ln + 1
		end
		f:close()
		return true, pr
	else
		if ec==2 then
			return true, 0
		else
			return false, err
		end
	end
end

function config:save()
	local h, err = io.open('server.properties','wb')
	if h then
		for key, value in pairs(self.values)do
			value = tostring(value)
			value = value:gsub('=','%61')
			value = value:gsub('#','%35')
			h:write(string.format('%s=%s\n', key, value))
		end
		h:close()
		return true
	else
		return false, err
	end
end

function config:get(key,default)
	local v = self.values[key]
	if v ~= nil then
		return v
	end
	self.values[key] = default
	return default
end

function config:set(key, value)
	self.values[key] = value
	return true
end
