permissions = {
	list = {
		default = {}
	}
}

function permissions:parse()
	local h, err, ec = io.open('permissions.txt', 'r')
	if not h then return end
	local key
	for line in h:lines()do
		if not key then
			key = line
		else
			perm = line:match('\t(.+)')
			if perm then
				self.list[key] = self.list[key]or{}
				table.insert(self.list[key],perm)
			else
				if line ~= ''then
					key = line
				else
					key = nil
				end
			end
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

function permissions:delFor(k, perm)
	self.list[k] = self.list[k]or{}
	local lst = self.list[k]
	for i=#lst, 1, -1 do
		if perm:lower()==lst[i]then
			table.remove(lst, i)
		end
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
			h:write(key..'\n')
			for i=1,#plist do
				h:write('\t%s\n'%plist[i])
			end
		end
		h:close()
		return true
	else
		return false, err
	end
end

return perms
