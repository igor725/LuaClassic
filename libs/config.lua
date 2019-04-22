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
					print(CONF_VTYPERR%{key,gtyp,typ})
					return
				end
				self.values[key] = value
			else
				print(CONF_INVALIDSYNTAX%{'properties',ln})
			end
		end
		f:close()
		return true
	else
		if ec==2 then
			return true
		else
			return false, err
		end
	end
end

function config:save()
	local f, err = io.open('server.properties','wb')
	if f then
		for key, value in pairs(self.values)do
			value = tostring(value)
			f:write(string.format('%s=%s\n', key, value))
		end
		f:close()
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
