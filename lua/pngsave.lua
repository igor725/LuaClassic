--[[
	This script needs a libPNG binary. It does not load automatically
	because it is not an integral part of the server.

	P.S. libPNG binary can be grabbed here: https://luapower.com/libpng/download
]]

local status, LIB = pcall(ffi.load, 'png')
if not status then
	function pngSave()
		return false, 'libpng not loaded: '+tostring(status)
	end
	return
end
local HCOLORS = {
	[-1] = newColor(0,0,0),
	[1]  = newColor(116,116,116),
	[2]  = newColor(118,177,79),
	[3]  = newColor(121,85,58),
	[4]  = newColor(82,82,82),
	[5]  = newColor(188,152,98),
	[8]  = newColor(35,62,140),
	[10] = newColor(224,142,46),
	[12] = newColor(220,213,159),
	[18] = newColor(90,250,58),
	[45] = newColor(177,52,17)
}
HCOLORS[9] = HCOLORS[8]
HCOLORS[11] = HCOLORS[10]
HCOLORS[47] = HCOLORS[5]

ffi.cdef[[
	typedef void (*func)(void*,const char*);
	void png_init_io(void*,void*);
	void png_set_IHDR(void*,void*,uint32_t,uint32_t,int,int,int,int,int);
	void *png_create_write_struct(const char*,void*,func,func);
	void *png_create_info_struct(void*);
	void png_write_info(void*,void*);
	void png_write_row(void*,const char*);
	void png_write_end(void*,void*);
]]
local PNG_VER = '1.5.14'
local PNG_ERR

local function eHandler(png, err)
	PNG_ERR = ffi.string(err)
	error('libpng error')
end

function pngSave(world, filename, flipx, flipy)
	if not world.isWorld then return false, 'Invalid argument #1 (World expected)' end
	local f, err = io.open(filename or'hmap.png', 'wb')
	if not f then return false, err end
	local succ, err = pcall(function()
		local png = LIB.png_create_write_struct(PNG_VER, nil, eHandler, eHandler)
		if png == 0 then return false, 'PNG struct not created'end
		local info = LIB.png_create_info_struct(png)
		if png == 1 then return false, 'INFO struct not created'end
		local iw, wy, ih = world:getDimensions()

		local function getBlockColor(x,z)
			local bid = 0
			for y=wy-1, 0, -1 do
				local offset = z*iw+y*(iw*ih)+x+4
				bid = world.ldata[offset]
				if HCOLORS[bid]then
					return HCOLORS[bid]
				end
			end
			return HCOLORS[-1]
		end

		LIB.png_init_io(png, f)
		LIB.png_set_IHDR(png, info, iw, ih, 8, 2, 0, 0, 0)
		LIB.png_write_info(png, info)

		local zStart, zEnd, zStep = 0, ih-1, 1
		if flipz then
			zStart, zEnd, zStep = ih-1, 0, -1
		end

		local irow = ffi.new('unsigned char[?]', 3*iw)
		for z = zStart, zEnd, zStep do
			for x = 0, iw-1 do
				local col = getBlockColor(x, z)
				if flipx then
					x = iw-1-x
				end
				ffi.copy(irow+x*3, col, 3)
			end
			LIB.png_write_row(png, irow)
		end
		LIB.png_write_end(png, nil)
	end)

	f:close()
	return succ, PNG_ERR or err
end
