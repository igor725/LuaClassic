WSGUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

--[[
	WebSocket functions
]]

function encodeWsFrame(data,opcode)
	local b1 = bor(0x80, band(opcode, 0x0f))
	local payload_len = #data
	local hdr

	if payload_len<=125 then
		hdr = string.char(b1, payload_len)
	elseif payload_len>125 and payload_len<65536 then
		hdr = struct.pack('>BBH', b1, 126, payload_len)
	else
		return ''
	end
	return hdr..data
end

function encodeWsClose(code, reason)
	reason = reason or''
	local data = struct.pack('>H', code)
	data = data..reason
	return data
end

function readWsHeader(b1, b2)
	local fin = band(rshift(b1, 0x07), 0x01)
	local masked = rshift(b2, 0x07)
	local opcode = band(b1, 0x0F)
	local phint = band(b2, 0x7F)
	return fin==1, masked==1, opcode, phint
end

function unmaskData(data, mask, plen)
	local out = ''
	for i=0, plen-1 do
		local p = i%4+1
		local pp = i+1
		local mbyte = mask:byte(p,p)
		local pbyte = data:byte(pp,pp)
		if mbyte and pbyte then
			out = out..string.char(bxor(pbyte,mbyte))
		end
	end
	return out
end
