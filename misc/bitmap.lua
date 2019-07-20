ffi.cdef[[
	void*    fopen(const char* path, const char* mode);
	long int ftell(void* stream);
	int      fseek(void* stream, long offset, int origin);
	int      fclose(void* stream);

	struct bmp {
		uint32_t width, height;
		uint16_t bps, pixel_offset;
		uint32_t fsz;
		uint8_t* data;
		void* file;
		bool ok;
	};
]]

local bmp_mt = {
	getPixel = function(self, x, y)
		if not self.ok then
			return nil, 'BMP image not loaded'
		end
		if x < 0 or x > self.width - 1 or y < 0 or y > self.height - 1 then
			return nil, 'Out of bounds'
		end

		local Bps = self.bps / 8
		local index, r, g, b = self.pixel_offset + (self.height - y - 1) * self.width * Bps + x * Bps
		if self.bps == 24 then
			b = self.data[index + 0]
			g = self.data[index + 1]
			r = self.data[index + 2]
		else
			return nil, 'Unsupported bpp'
		end

		return r, g ,b
	end,
	getDimensions = function(self)
		return self.width, self.height
	end,
	getWidth = function(self)
		return self.width
	end,
	getHeight = function(self)
		return self.height
	end,

	setPixel = function(self, x, y, r, g, b)
		if not self.ok then
			return false, 'BMP image not loaded'
		end
		if x < 0 or x > self.width or y < 0 or y > self.height then
			return false, 'Out of bounds'
		end

		if self.bps == 24 then
			local index = self.pixel_offset + (self.height - y - 1) * self.width * 3 + x * 3
			self.data[index + 0] = b
			self.data[index + 1] = g
			self.data[index + 2] = r
		else
			return nil, 'Unsupported bpp'
		end

		return true
	end,
	writeFile = function(self, name)
		local file = self.file
		local customFile = false

		if name then
			file, err, ec = io.open(name, 'wb')
			customFile = true
			if not file then
				return false, err, ec
			end
		end
		if C.fseek(file, 0, 0) ~= 0 then
			return false
		end
		local written = C.fwrite(self.data, self.fsz, 1, file)
		if customFile then file:close()end
		return written == 1
	end,
	close = function(self)
		self.data = nil
		self.ok = false
		if self.file ~= nil then
			return C.fclose(self.file) == 0
		end
		return true
	end,
	_readData = function(self)
		local data = self.data
		if ffi.cast('uint16_t*', data)[0] ~= 0x4D42 then
			return nil, 'Invalid file header'
		end
		if ffi.cast('uint32_t*', data + 30)[0] ~= 0 then
			return nil, 'Compressed bitmaps not supported'
		end

		self.pixel_offset = ffi.cast('uint16_t*', data + 10)[0]
		self.bps = ffi.cast('uint16_t*', data + 28)[0]
		ffi.copy(self, data + 18, 8)
		return true
	end
}
bmp_mt.__index = bmp_mt

newBitmap = ffi.metatype('struct bmp', bmp_mt)

function bitmapFromFile(name)
	local file = C.fopen(name, 'r+b')
	if file == nil then
		return false
	end

	C.fseek(file, 0, 2)
	local fsz = C.ftell(file)
	C.fseek(file, 0, 0)
	local buf = ffi.new('uint8_t[?]', fsz)
	C.fread(buf, fsz, 1, file)
	local bmp = newBitmap()
	bmp.file = file
	bmp.data = buf
	bmp.fsz = fsz
	if assert(bmp:_readData())then
		bmp.ok = true
		return bmp
	end
	return false
end
