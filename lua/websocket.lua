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
			uint8_t mask[3];
			uint16_t payload_len[1];
			uint8_t* payload;
			bool fin;
			bool masked;
			bool ready;
		};
	]]

	function setupWFrameStruct(sframe, fd)
		sframe.state = WS_ST_HDR
		sframe.ready = true
		sframe.fd = fd
	end
	
	function encodeWsFrame(data, opcode)
		local plen = #data
		local shortenc = false
		if plen > 125 then
			shortenc = true
		end

		local b1 = bit.bor(0x80, bit.band(opcode, 0x0F))
		if shortenc then
			return struct.pack('>BBH', b1, 126, plen) .. data
		else
			return string.char(
				b1,
				plen
			) .. data
		end
	end

	function receiveFrame(sframe)
		if not sframe.ready then
			return false
		end
		if sframe.state == WS_ST_DONE then
			sframe.state = WS_ST_HDR
			sframe.payload_len[0] = 0
			sframe.payload = nil
		end

		if sframe.state == WS_ST_HDR then
			local sz = receiveMesg(sframe.fd, sframe.hdr, 2)
			if sz == 2 then
				local hdr = sframe.hdr
				sframe.fin = bit.band(bit.rshift(hdr[0], 0x07)) == 1
				sframe.masked = bit.rshift(hdr[1], 0x07) == 1
				sframe.opcode = bit.band(hdr[0], 0x0F)
				local len = bit.band(hdr[1], 0x7F)
				sframe.payload_len[0] = len
				if len == 126 then
					sframe.state = WS_ST_PLEN
				elseif len < 126 then
					sframe.state = WS_ST_MASK
				end
			end
		end

		if sframe.state == WS_ST_PLEN then
			local sz = receiveMesg(sframe.fd, sframe.payload_len, 2)
			if sz == 2 then
				sframe.payload_len[0] = ntohs(sframe.payload_len[0])
				sframe.state = WS_ST_MASK
			end
		end

		if sframe.state == WS_ST_MASK then
			local sz = receiveMesg(sframe.fd, sframe.mask, 4)
			if sz == 4 then
				sframe.state = WS_ST_RCVPL
			end
		end

		if sframe.state == WS_ST_RCVPL then
			local plen = sframe.payload_len[0]
			if sframe.payload == nil then
				sframe.payload = ffi.new('uint8_t[?]', plen + 1)
			end
			local sz = receiveMesg(sframe.fd, sframe.payload, plen)
			if sz == plen then
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
