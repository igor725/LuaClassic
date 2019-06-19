-- Broken
local bbu = {
	global = true,
	disabled = true
}

local sbbu = ffi.new([[struct {
	uint8_t id;
	uint8_t count;
	uint8_t indices[1024];
	uint8_t blocks[256];
}]])
local iptr = ffi.cast('uint32_t*', sbbu.indices)
local cptr = ffi.cast('char*', sbbu)

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
	playersForEach(function(player)
		if player:isInWorld(self.world)then
			sendMesg(player:getClient(), cptr, 1282)
		end
	end)
	self:clean()
end

function bbu:write(x, y, z, id)
	iptr[sbbu.count] = self.world:getOffset(x, y, z)
	sbbu.blocks[sbbu.count] = id
	sbbu.count = sbbu.count + 1
	if sbbu.count == 255 then
		self:push()
	end
end

return bbu
