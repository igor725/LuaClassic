local bbu = {
	global = true,
	unsupport = {}
}

local sbbu = ffi.new([[struct {
	uint8_t id;
	uint8_t count;
	uint8_t indices[1024];
	uint8_t blocks[256];
}]])
local iptr = ffi.cast('uint32_t*', sbbu.indices)

function bbu:start(world)
	ffi.fill(sbbu, 1282)
	self.world = world
	sbbu.id = 0x26
end

function bbu:clean()
	ffi.fill(sbbu, 1282)
	sbbu.id = 0x26
end

function bbu:push()
	if sbbu.count > 0 then
		playersForEach(function(player)
			if player:isInWorld(self.world)then
				if player:isSupported('BulkBlockUpdate')then
					player:sendNetMesg(sbbu, 1282)
				else
					if not table.hasValue(self.unsupport, player)then
						table.insert(self.unsupport, player)
					end
				end
			end
		end)
		self:clean()
	end
end

function bbu:write(x, y, z, id)
	iptr[sbbu.count] = bswap(self.world:getOffset(x, y, z) - 4)
	sbbu.blocks[sbbu.count] = id
	sbbu.count = sbbu.count + 1
	if sbbu.count == 255 then
		self:push()
	end
end

function bbu:done()
	self:push()
	for i = #self.unsupport, 1, -1 do
		table.remove(self.unsupport, 1):sendMap()
	end
end

return bbu
