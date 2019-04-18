hooks = {
	list = {}
}

function hooks:Create(hookname)
	self.list[hookname] = {}
end

function hooks:Add(hookname, bname, func)
	self.list[hookname][bname] = func
end

function hooks:Remove(hookname, bname)
	self.list[hookname][bname] = nil
end

function hooks:Call(hookname, ...)
	local hks = self.list[hookname]
	if hks then
		for _, fnc in pairs(hks)do
			local x = fnc(...)
			if x~=nil then
				return x
			end
		end
	end
end
