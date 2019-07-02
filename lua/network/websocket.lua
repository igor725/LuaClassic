--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

function wsLoad()
	WSGUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'
	WS_ST_HDR    = 0
	WS_ST_PLEN   = 1
	WS_ST_MASK   = 2
	WS_ST_RCVPL  = 3
	WS_ST_DONE   = 4

	ffi.cdef[[
		struct ws_frame {
			uint32_t fd;
			uint8_t hdr[2];
			uint8_t state;
			uint8_t opcode;
			uint8_t mask[4];
			uint16_t payload_len[1];
			uint8_t* payload;
			uint16_t _dneed;
			uint16_t _drcvd;
			bool fin;
			bool masked;
			bool ready;
		};
	]]

	function setupWFrameStruct(sframe, fd)
		sframe.state = WS_ST_HDR
		sframe.ready = true
		sframe._dneed = 2
		sframe.fd = fd
	end

	function encodeWsFrame(data, len, opcode, _buf)
		local buf = _buf
		data = ffi.cast('const char*', data)

		if len < 126 then
			buf = buf or ffi.new('char[?]', len + 2)
			ffi.copy(buf + 2, data, len)
			buf[1] = len
			len = len + 2
		elseif len < 65535 then
			buf = buf or ffi.new('char[?]', len + 4)
			ffi.cast('uint16_t*', buf)[1] = htons(len)
			ffi.copy(buf + 4, data, len)
			buf[1] = 126
			len = len + 4
		else
			error('not implemented')
		end

		buf[0] = bit.bor(0x80, bit.band(opcode, 0x0F))

		return buf, len
	end

	function receiveFrame(sframe)
		if not sframe.ready then
			return false
		end
		if sframe.state == WS_ST_DONE then
			sframe.state = WS_ST_HDR
			sframe.payload_len[0] = 0
			sframe.payload = nil
			sframe._dneed = 2
			sframe._drcvd = 0
		end

		if sframe.state == WS_ST_HDR then
			local sz, closed, err = receiveMesg(sframe.fd, sframe.hdr + sframe._drcvd, sframe._dneed)

			if closed then
				return -1, err
			end

			sframe._dneed = sframe._dneed - sz
			sframe._drcvd = sframe._drcvd + sz

			if sframe._dneed == 0 then
				local hdr = sframe.hdr
				sframe.fin = bit.band(bit.rshift(hdr[0], 0x07)) == 1
				sframe.masked = bit.rshift(hdr[1], 0x07) == 1
				sframe.opcode = bit.band(hdr[0], 0x0F)
				local len = bit.band(hdr[1], 0x7F)
				sframe.payload_len[0] = len
				sframe._drcvd = 0
				if len == 126 then
					sframe.state = WS_ST_PLEN
					sframe._dneed = 2
				elseif len < 126 then
					sframe.state = WS_ST_MASK
					sframe._dneed = 4
				else
					return -1
				end
			end
		end

		if sframe.state == WS_ST_PLEN then
			local sz, closed, err = receiveMesg(sframe.fd, sframe.payload_len + sframe._drcvd, sframe._dneed)

			if closed then
				return -1, err
			end

			sframe._dneed = sframe._dneed - sz
			sframe._drcvd = sframe._drcvd + sz

			if sframe._dneed == 0 then
				sframe.payload_len[0] = ntohs(sframe.payload_len[0])
				sframe.state = WS_ST_MASK
				sframe._drcvd = 0
				sframe._dneed = 4
			end
		end

		if sframe.state == WS_ST_MASK then
			local sz, closed, err = receiveMesg(sframe.fd, sframe.mask + sframe._drcvd, sframe._dneed)

			if closed then
				return -1, err
			end

			sframe._dneed = sframe._dneed - sz
			sframe._drcvd = sframe._drcvd + sz

			if sframe._dneed == 0 then
				sframe.state = WS_ST_RCVPL
				sframe._drcvd = 0
				sframe._dneed = sframe.payload_len[0]
			end
		end

		if sframe.state == WS_ST_RCVPL then
			local plen = sframe.payload_len[0]

			if sframe.payload == nil then
				sframe.payload = ffi.new('uint8_t[?]', plen + 1)
			end

			local sz, closed, err = receiveMesg(sframe.fd, sframe.payload + sframe._drcvd, sframe._dneed)

			if closed then
				return -1, err
			end

			sframe._dneed = sframe._dneed - sz
			sframe._drcvd = sframe._drcvd + sz

			if sframe._dneed == 0 then
				if sframe.masked then
					for i = 0, sz - 1 do
						sframe.payload[i] = bit.bxor(sframe.payload[i], sframe.mask[i % 4])
					end
				end
				sframe.state = WS_ST_DONE
			end
		end

		return sframe.state == WS_ST_DONE
	end
end
