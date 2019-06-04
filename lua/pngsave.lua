--[[
	This script needs a libPNG binary. It does not load automatically
	because it is not an integral part of the server.

	P.S. libPNG binary can be grabbed here: https://luapower.com/libpng/download
]]

local status, LIB = pcall(ffi.load, 'png15')
if not status then
	status, LIB = pcall(ffi.load, 'png')
end

if not status then
	function pngSave()
		return false, 'libpng not loaded: ' .. tostring(LIB)
	end
	return false
end

local HCOLORS = {
	[-1] = newColor(0x00, 0x00, 0x00),
	[01] = newColor(0x74, 0x74, 0x74),
	[02] = newColor(0x76, 0xB1, 0x4F),
	[03] = newColor(0x79, 0x55, 0x3A),
	[04] = newColor(0x52, 0x52, 0x52),
	[05] = newColor(0xBC, 0x98, 0x62),
	[08] = newColor(0x23, 0x3E, 0x8C),
	[10] = newColor(0xE0, 0x8E, 0x2E),
	[12] = newColor(0xDC, 0xD5, 0x9F),
	[18] = newColor(0x5A, 0xFA, 0x3A),
	[45] = newColor(0xB1, 0x34, 0x11)
}
HCOLORS[9]  = HCOLORS[8]
HCOLORS[11] = HCOLORS[10]
HCOLORS[47] = HCOLORS[5]

ffi.cdef[[
	typedef void (*func)(void*,const char*);
	void  png_init_io(void*,void*);
	void  png_set_IHDR(void*,void*,uint32_t,uint32_t,int,int,int,int,int);
	void* png_create_write_struct(const char*,void*,func,func);
	void  png_destroy_write_struct(void*,void*);
	void* png_create_info_struct(void*);
	void  png_write_info(void*,void*);
	void  png_write_row(void*,const char*);
	void  png_write_end(void*,void*);
]]
local PNG_VER = '1.5.0'
local PNG_ERR

local function eHandler(png, err)
	PNG_ERR = ffi.string(err)
	error('libpng error')
end

local function wHandler(png, warn)
	log.warn(ffi.string(warn))
end

function pngSave(world, filename, flipx, flipz)
	if not world.isWorld then return false, 'Invalid argument #1 (World expected)'end
	local pngfile
	local succ, status, err = pcall(function()
		local png = LIB.png_create_write_struct(PNG_VER, nil, eHandler, wHandler)
		if png == nil then return false, 'PNG struct not created'end
		local info = LIB.png_create_info_struct(png)
		if info == nil then return false, 'INFO struct not created'end
		local iw, wy, ih = world:getDimensions()

		local function getBlockColor(x,z)
			local bid = 0
			for y = wy - 1, 0, -1 do
				local offset = z * iw + y * (iw * ih) + x + 4
				bid = world.ldata[offset]
				if HCOLORS[bid]then
					return HCOLORS[bid]
				end
			end
			return HCOLORS[-1]
		end

		pngfile, err = io.open(filename or'hmap.png', 'wb')
		if not pngfile then return false, err end
		
		LIB.png_init_io(png, pngfile)
		LIB.png_set_IHDR(png, info, iw, ih, 8, 2, 0, 0, 0)
		LIB.png_write_info(png, info)

		local zStart, zEnd, zStep = 0, ih - 1, 1
		if flipz then
			zStart, zEnd, zStep = ih - 1, 0, -1
		end

		local irow = ffi.new('uchar[?]', 3 * iw)
		for z = zStart, zEnd, zStep do
			for x = 0, iw - 1 do
				local col = getBlockColor(x, z)
				if flipx then
					x = iw - 1 - x
				end
				ffi.copy(irow + x * 3, col, 3)
			end
			LIB.png_write_row(png, irow)
		end
		LIB.png_write_end(png, nil)
	end)

	if pngfile then
		pngfile:close()
	end
	return succ and status, PNG_ERR or err
end
