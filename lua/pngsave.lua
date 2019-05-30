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
	[-1] = newColor(000, 000, 000),
	[01]  = newColor(116, 116, 116),
	[02]  = newColor(118, 177, 079),
	[03]  = newColor(121, 085, 058),
	[04]  = newColor(082, 082, 082),
	[05]  = newColor(188, 152, 098),
	[08]  = newColor(035, 062, 140),
	[10] = newColor(224, 142, 046),
	[12] = newColor(220, 213, 159),
	[18] = newColor(090, 250, 058),
	[45] = newColor(177, 052, 017)
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

function setlibpngVer(str)
	PNG_VER = str or PNG_VER
end

function pngSave(world, filename, flipx, flipz)
	if not world.isWorld then return false, 'Invalid argument #1 (World expected)' end
	local f, err = io.open(filename or'hmap.png', 'wb')
	if not f then return false, err end
	local succ, err = pcall(function()
		local png = LIB.png_create_write_struct(PNG_VER, nil, eHandler, eHandler)
		if png == 0 then return false, 'PNG struct not created'end
		local info = LIB.png_create_info_struct(png)
		if info == 0 then return false, 'INFO struct not created'end
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

		LIB.png_init_io(png, f)
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
	f:close()
	return succ, PNG_ERR or err
end
