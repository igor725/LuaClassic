permissions = {
	list = {
		default = {}
	}
}

function permissions:parse()
	local h, err, ec = io.open('permissions.txt', 'r')
	local ln = 0
	if h then
		for line in h:lines()do
			if line:byte()~=35 then
				local key, perms = line:match'(.*)%:(.*)'
				if key then
					perms = perms:split(',')
					for i=1,#perms do
						self.list[key] = self.list[key]or{}
						local perm = perms[i]:lower()
						table.insert(self.list[key],perm)
					end
					ln = ln + 1
				else
					print(CONF_INVALIDSYNTAX%{'permissions',ln})
				end
			end
		end
		h:close()
		return true, ln
	else
		if ec==2 then
			return true, 0
		else
			return false, err
		end
	end
end

function permissions:addFor(k, perm)
	self.list[k] = self.list[k]or{}
	local lst = self.list[k]
	if not table.hasValue(lst, perm)then
		table.insert(lst, perm:lower())
	end
	return self
end

function permissions:getFor(key)
	return self.list[key]or self.list.default
end

function permissions:save()
	local h, err = io.open('permissions.txt', 'wb')
	if h then
		for key, plist in pairs(self.list)do
			h:write(key+':'+table.concat(plist,',')+'\n')
		end
		h:close()
		return true
	else
		return false, err
	end
end

return perms
