--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

local buf_mt = {
	writeByte = function(self, byte)
		local arr, pos = self.array, self.pos
		if pos + 1 > self.len then return false end
		arr[pos] = byte
		self.pos = self.pos + 1
		return self
	end,
	writeVarByte = function(self, ...)
		local arr, pos = self.array, self.pos
		local cnt = select('#', ...)
		if pos + cnt > self.len then return false end
		for i = 1, cnt do
			arr[pos + i - 1] = select(i, ...)
		end
		self.pos = self.pos + cnt
	end,
	writeShort = function(self, short)
		local arr, pos = self.array, self.pos
		if pos + 2 > self.len then return false end
		ffi.cast('uint16_t*', arr + pos)[0] = htons(short)
		self.pos = pos + 2
		return self
	end,
	writeVarShort = function(self, ...)
		local arr, pos = self.array, self.pos
		local cnt = select('#', ...)
		local sz = cnt * 2
		if pos + sz > self.len then return false end
		local u16ptr = ffi.cast('uint16_t*', arr + pos)
		for i = 1, cnt do
			u16ptr[i - 1] = htons(select(i, ...))
		end
		self.pos = pos + sz
		return self
	end,
	writeInt = function(self, int)
		local arr, pos = self.array, self.pos
		if pos + 4 > self.len then return false end
		ffi.cast('uint32_t*', arr + pos)[0] = htonl(int)
		self.pos = pos + 4
		return self
	end,
	writeVarInt = function(self, ...)
		local arr, pos = self.array, self.pos
		local cnt = select('#', ...)
		local sz = cnt * 4
		if pos + sz > self.len then return false end
		local u16ptr = ffi.cast('uint32_t*', arr + pos)
		for i = 1, cnt do
			u16ptr[i - 1] = htonl(select(i, ...))
		end
		self.pos = pos + sz
		return self
	end,
	writeString = function(self, str)
		local arr, pos = self.array, self.pos
		if pos + 64 > self.len then return false end
		local slen = math.min(64, #str)
		ffi.copy(arr + pos, str, slen)
		if slen < 64 then
			ffi.fill(arr + (pos + slen), 64 - slen, 32)
		end
		self.pos = pos + 64
		return self
	end,

	readByte = function(self)
		local pos = self.pos
		self.pos = pos + 1
		return self.array[pos]
	end,
	readSByte = function(self)
		local val = self:readByte()
		if val >= 2 ^ 7 then
			val = val - 2 ^ 8
		end
		return val
	end,
	readShort = function(self)
		local arr, pos = self.array, self.pos
		self.pos = pos + 2
		return ntohs(ffi.cast('int16_t*', arr + pos)[0])
	end,
	readUShort = function(self)
		local arr, pos = self.array, self.pos
		self.pos = pos + 2
		return ntohs(ffi.cast('uint16_t*', arr + pos)[0])
	end,
	readShort3 = function(self)
		return self:readShort(), self:readShort(), self:readShort()
	end,
	readInt = function(self)
		local arr, pos = self.array, self.pos
		self.pos = pos + 4
		return ntohl(ffi.cast('int32_t*', arr + pos)[0])
	end,
	readUInt = function(self)
		local arr, pos = self.array, self.pos
		self.pos = pos + 4
		return ntohl(ffi.cast('uint32_t*', arr + pos)[0])
	end,
	readInt3 = function(self)
		return self:readInt(), self:readInt(), self:readInt()
	end,
	readString = function(self)
		local arr, pos = self.array, self.pos
		local strend

		for i = pos + 63, pos, -1 do
			if arr[i] ~= 32 then
				strend = i + 1
				break
			end
		end

		self.pos = pos + 64
		return ffi.string(arr + pos, strend - pos)
	end,

	seek = function(self, md, pos)
		if md == 'set'then
			self.pos = pos
		elseif md == 'cur'then
			self.pos = self.pos + pos
		elseif md == 'end'then
			self.pos = self.len
		end
		return self.pos
	end,
	reset = function(self)
		ffi.fill(self.array, self.len)
		self.pos = 0
		return self
	end,
	sendTo = function(self, fd, len)
		return sendMesg(fd, self.array, len or self.pos)
	end
}
buf_mt.__index = buf_mt

function newBuffer(len)
	len = len or 70
	return setmetatable({
		array = ffi.new('uint8_t[?]', len),
		len = len,
		pos = 0
	}, buf_mt)
end
