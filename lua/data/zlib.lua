--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

ffi.cdef[[
	typedef void* (* z_alloc_func) (void*, unsigned, unsigned);
	typedef void  (* z_free_func)  (void*, void*);
	typedef struct z_stream_s {
		char*         next_in;
		unsigned      avail_in;
		unsigned long total_in;
		char*         next_out;
		unsigned      avail_out;
		unsigned long total_out;
		char*         msg;
		void*         state;
		z_alloc_func  zalloc;
		z_free_func   zfree;
		void*         opaque;
		int           data_type;
		unsigned long adler;
		unsigned long reserved;
	} z_stream;

	const char* zlibVersion();
	const char* zError(int);
	int         inflateEnd(z_stream*);
	int         deflateEnd(z_stream*);
	int         deflate(z_stream*, int);
	int         inflate(z_stream*, int);
	int         inflateInit2_(z_stream*, int, const char *, int);
	int         deflateInit2_(z_stream*, int, int, int, int, int, const char *, int);
]]

local Z_NO_FLUSH         =  0
local Z_FINISH           =  4
local Z_STREAM_END       =  1
local Z_OK               =  0
local Z_STREAM_ERROR     = -2
local Z_BUF_ERROR        = -5
local Z_DEFAULT_STRATEGY =  0
local Z_DEFLATED         =  8
local Z_MEMLEVEL         =  8
local GZ_WINDOWBITS      = 31
local CHUNK_SIZE         = 1024

local zLoaded, _zlib = pcall(ffi.load, 'z')
if not zLoaded then
	local ext = (jit.os=='Windows'and'dll')or'so'
	local path = ('./bin/%s/z.%s'):format(jit.arch, ext)
	_zlib = ffi.load(path)
end

local zlibVersion = ffi.string(_zlib.zlibVersion())
local outbuff = ffi.new('char[?]', CHUNK_SIZE)
local inbuff = ffi.new('char[?]', CHUNK_SIZE)

local function gzerrstr(code)
	return ffi.string(_zlib.zError(code))
end

local function defstreamend(stream)
	return _zlib.deflateEnd(stream)
end

local function infstreamend(stream)
	return _zlib.inflateEnd(stream)
end

local function initDeflate(level, bits)
	local stream = ffi.new('z_stream')
	local streamsz = ffi.sizeof(stream)
	local ret = _zlib.deflateInit2_(stream, level, Z_DEFLATED, bits, Z_MEMLEVEL, Z_DEFAULT_STRATEGY, zlibVersion, streamsz)

	if ret ~= Z_OK then
		defstreamend(stream)
		return nil, ret
	end

	return stream
end

local function processDeflate(stream, _in, len, out, callback)
	stream.avail_in = len
	stream.next_in = _in

	repeat
		stream.next_out = out
		stream.avail_out = CHUNK_SIZE
		ret = _zlib.deflate(stream, Z_FINISH)

		if ret == Z_STREAM_ERROR then
			defstreamend(stream)
			return false, ret
		end

		callback(stream)
	until stream.avail_out ~= 0

	defstreamend(stream)

	return true
end

local function deflate(_in, len, bits, level, callback, out)
	out = out or outbuff
	level = level or 4
	local stream, err = initDeflate(level, bits)
	if stream == nil then
		return false, err
	end

	return processDeflate(stream, _in, len, out, callback)
end

local function gzip(_in, len, level, callback, out)
	return deflate(_in, len, GZ_WINDOWBITS, level, callback, out)
end

local function ungzip(file, callback)
	local stream = ffi.new('z_stream')
	local ret = _zlib.inflateInit2_(stream, GZ_WINDOWBITS, zlibVersion, ffi.sizeof('z_stream'))

	if ret ~= Z_OK then
		infstreamend(stream)
		return false, ret
	end

	repeat
		stream.next_in = inbuff
		stream.avail_in = C.fread(inbuff, 1, CHUNK_SIZE, file)

		if stream.avail_in == 0 then
			break
		end

		local ferr = C.ferror(file)
		if ferr ~= 0 then
			infstreamend(stream)
			return false
		end

		repeat
			stream.next_out = outbuff
			stream.avail_out = CHUNK_SIZE
			ret = _zlib.inflate(stream, Z_NO_FLUSH)

			if ret ~= Z_OK and ret ~= Z_STREAM_END and
			ret ~= Z_BUF_ERROR then
				infstreamend(stream)
				return false, ret
			end

			callback(outbuff, stream)
		until stream.avail_out ~= 0
	until ret == Z_STREAM_END
	infstreamend(stream)

	return true
end

zlib = {
	deflate = deflate,
	compress = gzip,
	decompress = ungzip,
	defEnd = defstreamend,
	infEnd = infstreamend,
	getErrStr = gzerrstr,
	version = zlibVersion
}
