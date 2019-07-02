--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

--TODO: Refactor dis shiet

local geterror, currerr
local sck = ffi.C
local error_cache = {}

local function isClosed(err)
	return err == 10053 or err == 10054 or
	err == 32 or err == 104 or err == 3425
end

ffi.cdef[[
	struct in_addr {
		uint32_t s_addr;
	};

	struct sockaddr_in {
		uint16_t sin_family;
		uint16_t sin_port;
		struct in_addr sin_addr;
		char sin_zero[8];
	};

	struct sockaddr {
		uint16_t sin_family;
		char sa_data[14];
	};

	struct line {
		uint8_t rcv[1];
		uint8_t line[8192];
		uint16_t linecur;
	};

	uint16_t htons(uint16_t hostshort);
	uint16_t ntohs(uint16_t netshort);
	uint32_t inet_addr(const char* cp);

	const char* inet_ntop(int af, const void* src, char* dst, size_t cnt);

	struct hostent* gethostbyname(const char* hostname);

	int bind(int sockfd, const struct sockaddr* addr, uint32_t addrlen);
	int listen(int sockfd, int backlog);
	int shutdown(int sockfd, int how);
	int accept(int sockfd, struct sockaddr* addr, uint32_t* addrlen);

	int socket(int domain, int type, int protocol);
	int connect(int sockfd, const struct sockaddr* addr, int addrlen);
	int setsockopt(int fd, int level, int optname, const void* optval, uint32_t optlen);

	int recv(int fd, void* buf, size_t count, int flags);
	int send(int fd, const void* buf, size_t count, int flags);

	size_t strlen(const char* string);
]]

INVALID_SOCKET = -1

SOMAXCONN = 128
AF_INET = 2

SOCK_STREAM = 1

SOL_SOCKET = 1
SOL_TCP = 6

TCP_NODELAY = 1

SO_REUSEADDR = 2
SO_SNDBUF = 7
SO_RCVBUF = 8
SO_RCVTIMEO = 20

MSG_OOB		= 0x1
MSG_PEEK	= 0x2
MSG_DONTROUTE	= 0x4
MSG_EOR		= 0x8
MSG_TRUNC	= 0x10
MSG_CTRUNC	= 0x20
MSG_WAITALL	= 0x40
MSG_NOSIGNAL = 0x4000

SHUT_RD = 0
SHUT_WR = 1
SHUT_RDWR = 2

if jit.os == 'Windows'then
	ffi.cdef[[
		struct hostent {
			char  *h_name;
			char  **h_aliases;
			short h_addrtype;
			short h_length;
			char  **h_addr_list;
		};

		uint32_t FormatMessageA(
			uint32_t dwFlags,
			const void* lpSource,
			uint32_t dwMessageId,
			uint32_t dwLanguageId,
			char* lpBuffer,
			uint32_t nSize,
			va_list *Arguments
		);

		int ioctlsocket(int sockfd, long cmd, unsigned long* argp);
		int closesocket(int sockfd);

		int GetLastError();

		int WSAStartup(uint16_t version, void *wsa_data);
		int WSACleanup();
	]]
	sck = ffi.load('ws2_32')

	FIONBIO = -2147195266

	SOMAXCONN = 2147483647

	SOL_SOCKET = 65535

	SO_REUSEADDR = 4
	SO_RCVBUF = 4098
	SO_SNDBUF = 4097
	SO_RCVTIMEO = 4102

	if jit.arch == 'x64'then
		wsa_data = ffi.typeof([[struct {
			uint16_t wVersion;
			uint16_t wHighVersion;
			unsigned short iMax_M;
			unsigned short iMaxUdpDg;
			char* lpVendorInfo;
			char szDescription[257];
			char szSystemStatus[129];
		}]])
	else
		wsa_data = ffi.typeof([[struct {
			uint16_t wVersion;
			uint16_t wHighVersion;
			char szDescription[257];
			char szSystemStatus[129];
			unsigned short iMax_M;
			unsigned short iMaxUdpDg;
			char* lpVendorInfo;
		}]])
	end

	local data = wsa_data()
	if sck.WSAStartup(24616, data) ~= 0 then
		error('WSAStartup failed')
	end

	-- Flags: FORMAT_MESSAGE_FROM_SYSTEM, FORMAT_MESSAGE_IGNORE_INSERTS
	local flags = bit.bor(0x00000200, 0x00001000)

	function currerr()
		return ffi.C.GetLastError()
	end

	function geterror(errno)
		errno = errno or currerr()
		if not error_cache[errno]then
			local buff = ffi.new('char[512]')
			local buffsz = ffi.sizeof(buff)
			local len = ffi.C.FormatMessageA(flags, nil, errno, 0, buff, buffsz, nil)
			error_cache[errno] = ffi.string(buff, len - 2) .. ' (' .. errno .. ')'
		end
		return error_cache[errno]
	end
else -- POSIX
	ffi.cdef[[
		struct hostent {
			char    *h_name;
			char    **h_aliases;
			int     h_addrtype;
			int     h_length;
			char    **h_addr_list;
		};
		char* strerror(int errnum);
		int fcntl(int, int, ...);
		int close(int fd);
	]]

	function currerr()
		return ffi.errno()
	end

	function geterror(errno)
		errno = errno or currerr()
		if not error_cache[errno]then
			error_cache[errno] = ffi.string(ffi.C.strerror(errno)) .. ' (' .. errno .. ')'
		end
		return error_cache[errno]
	end
end

function gethostbyname(hostname)
	local he = sck.gethostbyname(hostname)
	if he ~= nil then
		return parseIPv4(he.h_addr_list[0])
	end
end

function parseIPv4(sin_addr)
	local ptr = sck.inet_ntop(AF_INET, sin_addr, ffi.new('char[16]'), 16)
	return ffi.string(ptr)
end

function acceptClient(sfd)
	local addr = ffi.new('struct sockaddr_in[1]')
	local addrp = ffi.cast('struct sockaddr*', addr)
	local addrsz = ffi.new('unsigned int[1]', ffi.sizeof(addr))
	local cfd, err = sck.accept(sfd, addrp, addrsz)

	if cfd ~= INVALID_SOCKET then
		if jit.os == 'Linux'then
			local flags = ffi.C.fcntl(cfd, 3, 0)
			if flags < 0 then
				return false, geterror()
			end
			flags = bit.bor(flags, 4000)
			if ffi.C.fcntl(cfd, 4, ffi.new('int', flags)) < 0 then
				return false, geterror()
			end
		end
		assert(setSockOpt(cfd, SOL_TCP, TCP_NODELAY, 1))
		return cfd, parseIPv4(addr[0].sin_addr)
	end
	return nil
end

function setSockOpt(fd, level, opt, val)
	local vtype = type(val)

	if vtype == 'boolean'then
		val = ffi.new('int[1]', val and 1 or 0)
	elseif vtype == 'number'then
		val = ffi.new('int[1]', val)
	elseif vtype ~= 'cdata'then
		return false
	end

	local valsz = ffi.sizeof(val)
	val = ffi.cast('void*', val)
	return sck.setsockopt(fd, level, opt, val, valsz) == 0
end

function connectSock(ip, port)
	local fd = sck.socket(AF_INET, SOCK_STREAM, 0)
	local ssa = ffi.new('struct sockaddr_in[1]', {{
		sin_family = AF_INET,
		sin_addr = {
			s_addr = sck.inet_addr(ip)
		},
		sin_port = sck.htons(port)
	}})

	local cssa = ffi.cast('const struct sockaddr*', ssa)
	local ssasz = ffi.sizeof(ssa[0])

	assert(setSockOpt(fd, SOL_TCP, TCP_NODELAY, 1))

	if jit.os == 'Linux'then
		local tv = ffi.new('struct timeval', 1, 0)
		assert(setSockOpt(fd, SOL_SOCKET, SO_RCVTIMEO, tv))
	else
		assert(setSockOpt(fd, SOL_SOCKET, SO_RCVTIMEO, 1000))
	end

	if sck.connect(fd, cssa, ssasz) < 0 then
		return false, geterror()
	end

	return fd
end

function bindSock(ip, port, backlog)
	local fd = sck.socket(AF_INET, SOCK_STREAM, 0)
	local ssa = ffi.new('struct sockaddr_in[1]', {{
		sin_family = AF_INET,
		sin_addr = {
			s_addr = sck.inet_addr(ip)
		},
		sin_port = sck.htons(port)
	}})

	local cssa = ffi.cast('const struct sockaddr*', ssa)
	local ssasz = ffi.sizeof(ssa[0])

	assert(setSockOpt(fd, SOL_TCP, TCP_NODELAY, 1))
	if jit.os == 'Linux'then
		assert(setSockOpt(fd, SOL_SOCKET, SO_REUSEADDR, 1))
	end

	if sck.bind(fd, cssa, ssasz) < 0 then
		return false, geterror()
	end

	if sck.listen(fd, backlog or SOMAXCONN) < 0 then
		return false, geterror()
	end

	if jit.os == 'Windows'then
		if sck.ioctlsocket(fd, FIONBIO, ffi.new('int[1]', 1)) < 0 then
			return false, geterror()
		end
	else
		local flags = ffi.C.fcntl(fd, 3, 0)
		if flags < 0 then
			return false, geterror()
		end
		flags = bit.bor(flags, 4000) -- NON BLOCKING FLAG
		if ffi.C.fcntl(fd, 4, ffi.new('int', flags)) < 0 then
			return false, geterror()
		end
	end

	return fd
end

local dflags = 0
if jit.os ~= 'Windows'then
	dflags = MSG_NOSIGNAL
end

function sendMesg(fd, msg, len, flags)
	if not msg or msg == nil then return false end

	flags = flags or 0
	flags = bit.bor(dflags, flags)
	msg = ffi.cast('const char*', msg)
	len = len or ffi.C.strlen(msg)

	local snlen = sck.send(fd, msg, len, flags)
	if snlen < 0 then
		local errno = currerr()
		if errno == 3406 or errno == 10035 or errno == 11 then -- Uh....
			return sendMesg(fd, msg, len, flags)
		end
		local err = geterror(errno)
		return false, err
	else
		-- Is stack overflow possible here?
		if snlen < len then
			return sendMesg(fd, msg + snlen, len - snlen, flags)
		end
	end
	return true
end

function receiveMesg(fd, buffer, len, flags)
	if not buffer then return end

	flags = flags or 0
	local ret = sck.recv(fd, buffer, len, flags)
	if ret < 0 then
		return 0, isClosed(currerr())
	elseif ret > 0 then
		return ret, false
	else
		return 0, true
	end
end

function receiveString(fd, len, flags)
	if len < 1 then return end

	local buffer = ffi.new('char[?]', len)
	local rlen, err = receiveMesg(fd, buffer, len, flags)
	if rlen > 0 then
		return ffi.string(buffer, rlen), err
	else
		return nil, err
	end
end

local lines = {}

function receiveLine(fd)
	if not lines[fd]then
		lines[fd] = ffi.new('struct line')
	end

	local ln = lines[fd]
	if ln.linecur == 0 then
		ffi.fill(ln.line, 8192)
	end

	while true do
		local len, closed = receiveMesg(fd, ln.rcv, 1)
		
		if closed then
			local str = ffi.string(ln.line, ln.linecur)
			ln.linecur = 0
			return str, 2
		end

		if len and len > 0 then
			local sym = ln.rcv[0]
			if sym == 10 then
				local str = ffi.string(ln.line, ln.linecur)
				ln.linecur = 0
				return str
			elseif sym ~= 13 then
				ln.line[ln.linecur] = sym
				ln.linecur = ln.linecur + 1
				if ln.linecur > 8191 then
					local str = ffi.string(ln.line, ln.linecur)
					ln.linecur = 0
					return str, 0
				end
			end
		else
			return nil, 1
		end
	end
end

function closeSock(fd)
	lines[fd] = nil
	if jit.os == 'Windows'then
		return sck.closesocket(fd) == 0
	else
		return ffi.C.close(fd) == 0
	end
end

function shutdownSock(fd, how)
	if sck.shutdown(fd, how) ~= 0 then
		return false, geterror()
	end
	return true
end

function cleanupSock()
	lines = nil
	if jit.os == 'Windows'then
		return sck.WSACleanup() == 0, geterror()
	end
	return true
end

function htons(short)
	return sck.htons(short)
end

function ntohs(short)
	return sck.ntohs(short)
end
