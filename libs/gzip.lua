ffi.cdef[[
typedef void*    (* z_alloc_func)( void* opaque, unsigned items, unsigned size );
typedef void     (* z_free_func) ( void* opaque, void* address );
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
const char*   zlibVersion();
const char*   zError(int);
int deflate(z_stream*, int flush);
int inflate(z_stream*, int flush);
int inflateEnd(z_stream*);
int deflateEnd(z_stream*);
int deflateInit2_(z_stream*, int level, int method, int windowBits,
	int memLevel, int strategy, const char *version, int stream_size);
int inflateInit2_(z_stream*, int windowBits, const char *version, int stream_size);
]]

local Z_NO_FLUSH         =  0
local Z_FINISH           =  4
local Z_STREAM_END       =  1
local Z_OK               =  0
local Z_STREAM_ERROR     = -2
local Z_BUF_ERROR        = -5
local Z_DEFAULT_STRATEGY =  0
local Z_DEFLATED         =  8
local GZ_WINDOWBITS      = 31
local CHUNK_SIZE         = 1024
local GZ_ERR             = 'gzip %s error: %s'
local GZ_DATAERR         = 'ggzip data error'

local zLoaded, _zlib = pcall(ffi.load,'z')
if not zLoaded then
	local path = './bin/%s/z.%s'%{jit.arch,_EXT}
	_zlib = ffi.load(path)
end
local Z_VER = _zlib.zlibVersion()
local outbuff = ffi.new('char[?]',CHUNK_SIZE)
local inbuff = ffi.new('char[?]',CHUNK_SIZE)

local function deflate(_in,len,level,callback)
	level = level or 4
	local stream = ffi.new('z_stream')
	local ret =  _zlib.deflateInit2_(stream,level,Z_DEFLATED,GZ_WINDOWBITS,8,Z_DEFAULT_STRATEGY,Z_VER,ffi.sizeof(stream))
	if ret ~= Z_OK then
		local errstr = ffi.string(_zlib.zError(ret))
		print(GZ_ERR%{'init',errstr})
		_zlib.deflateEnd(stream)
		return false
	end
	stream.avail_in = len
	stream.next_in = _in

	repeat
		stream.next_out = outbuff
		stream.avail_out = CHUNK_SIZE
		ret = _zlib.deflate(stream, Z_FINISH)

		if ret == Z_STREAM_ERROR then
			local errstr = ffi.string(_zlib.zError(ret))
			print(string.format(GZ_ERR, 'compress', errstr))
			_zlib.deflateEnd(stream)
			return false
		end

		callback(outbuff, stream)
	until stream.avail_out ~= 0

	_zlib.deflateEnd(stream)
	return true
end

local function inflate(file,callback)
	local stream = ffi.new('z_stream')
	local ret = _zlib.inflateInit2_(stream,GZ_WINDOWBITS,Z_VER,ffi.sizeof('z_stream'))

	if ret ~= Z_OK then
		local errstr = ffi.string(_zlib.zError(ret))
		print(string.format(GZ_ERR, 'init', errstr))
		_zlib.inflateEnd(stream)
		return false
	end

	repeat
		stream.next_in = inbuff
		stream.avail_in = C.fread(inbuff, 1, CHUNK_SIZE, file)

		if C.ferror(file)~=0 then
			_zlib.inflateEnd(stream)
			return false
		end

		if stream.avail_in == 0 then
			_zlib.inflateEnd(stream)
			return false, GZ_DATERR
		end

		repeat
			stream.next_out = outbuff
			stream.avail_out = CHUNK_SIZE
			ret = _zlib.inflate(stream, Z_NO_FLUSH)
			if ret == Z_BUF_ERROR then ret = Z_OK end
			if ret ~= Z_OK and ret ~= Z_STREAM_END then
				local errstr = ffi.string(_zlib.zError(ret))
				print(string.format(GZ_ERR, 'decompress', errstr))
				_zlib.inflateEnd(stream)
				return false
			end

			callback(outbuff, stream)
		until stream.avail_out ~= 0
	until ret == Z_STREAM_END
	_zlib.inflateEnd(stream)
	return true
end

return {
	compress = deflate,
	decompress = inflate,
	defEnd = _zlib.deflateEnd
}
