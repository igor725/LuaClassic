--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

banlist = {
	modified = false
}

function banlist:parse()
	local bfile = io.open('banlist.txt', 'r')
	if bfile then
		for line in bfile:lines()do
			local name, ip, reason = line:match('(.+):(%d+%.%d+%.%d+%.%d+):(.+)')
			if name then
				table.insert(self, {name, ip, reason})
			end
		end
		bfile:close()
		return true
	end
	return false
end

function banlist:save()
	if not self.modified then return true end
	local bfile = io.open('banlist.txt', 'w')
	if bfile then
		for i = 1, #self do
			local banRow = self[i]
			bfile:write(('%s:%s:%s\n'):format(banRow[1], banRow[2], banRow[3]))
		end
		bfile:close()
		return true
	end
	return false
end

function banlist:add(name, ip, reason)
	if not self:check(name, ip)then
		self.modified = true
		if reason == ''then reason = 'No reason'end
		table.insert(self, {name, ip, reason})
		return true
	end
	return false
end

function banlist:remove(name, ip)
	for i = #banlist, 1, -1 do
		local banRow = banlist[i]
		if banRow[1] == name or banRow[2] == ip then
			table.remove(banlist, i)
			banlist.modified = true
			return true
		end
	end
	return false
end

function banlist:check(name, ip)
	for i = 1, #banlist do
		local banRow = banlist[i]
		if banRow[1] == name or banRow[2] == ip then
			return true, banRow[3]
		end
	end
	return false
end
