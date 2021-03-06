--[[
	Copyright (c) 2019 igor725, scaledteam
	released under The MIT license http://opensource.org/licenses/MIT
]]

PCK_INVALID_HEADER = 1

function parseData(file, readers, hdr, dTable, dSkipped)
	local fcur = file:seek('cur')
	local fend = file:seek('end')
	file:seek('set', fcur)

	if file:read(#hdr) ~= hdr then
		return false, PCK_INVALID_HEADER
	end

	while file:seek('cur') < fend do
		local key = readString(file)
		if key == '_endOfData'then break end
		local dataSize = unpackFrom(file, '>H')
		local reader = readers[key]

		if reader then
			if reader.format == 'string'then
				if reader.func then
					local out = reader.func(dTable, file:read(dataSize))
					if out ~= nil then
						dTable[key] = out
					end
				else
					dTable[key] = file:read(dataSize)
				end
			elseif reader.format == 'bool'then
				dTable[key] = file:read(dataSize) == '\1'
			elseif reader.format:find('^tbl:')then
				local tfmt = reader.format:match('^tbl:(.+)')
				local tfmtsz = struct.size(tfmt)
				for i = 1, dataSize / tfmtsz do
					reader.func(dTable, unpackFrom(file, tfmt))
				end
			elseif reader.format == 'cdata'then
				local cdata = ffi.new(reader.type, dataSize)
				C.fread(cdata, dataSize, 1, file)
				dTable[key] = cdata
			else
				if reader.func then
					local out = reader.func(dTable, unpackFrom(file, reader.format))
					if out ~= nil then
						dTable[key] = out
					end
				else
					dTable[key] = unpackFrom(file, reader.format)
				end
			end
		else
			log.warn('No reader for', key)
			if dSkipped then
				dSkipped[key] = file:read(dataSize)
			else
				file:seek('cur', dataSize)
			end
		end
	end
	return true
end

function writeData(file, writers, hdr, dTable, dSkipped)
	file:write(hdr)
	for key, value in pairs(dTable)do
		local writer = writers[key]
		if writer then
			writeString(file, key)
			if writer.format == 'string'then
				packTo(file, '>H', #value)
				file:write(value)
			elseif writer.format == 'bool'then
				packTo(file, '>H', 1)
				file:write((value and '\1')or'\0')
			elseif writer.format:find('^tbl:')then
				local tfmt = writer.format:match('^tbl:(.+)')
				local tfmtsz = struct.size(tfmt)
				local sz = (writer.getn and writer.getn(value)) or getn(value)
				local psz = sz * tfmtsz
				packTo(file, '>H', psz)
				if type(value) ~= 'cdata'then
					for k, v in pairs(value)do
						if writer.func then
							packTo(file, tfmt, writer.func(dTable, k, v))
						else
							packTo(file, tfmt, k, v)
						end
					end
				else
					if writer.func then
						local csz = 0
						for i = 0, ffi.sizeof(value) - 1 do
							if packTo(file, tfmt, writer.func(value, i))then
								csz = csz + tfmtsz
								if csz == psz then
									break
								elseif csz > psz then
									return false, 'value ' .. key .. ' overflow'
								end
							end
						end
					else
						file:write(ffi.string(value, sz))
					end
				end
			elseif writer.format == 'cdata'then
				local sz = (writer.getsz and writer.getsz(value))or ffi.sizeof(value)
				packTo(file, '>H', sz)
				C.fwrite(value, sz, 1, file)
			else
				packTo(file, '>H', struct.size(writer.format))
				if writer.func then
					packTo(file, writer.format, writer.func(value))
				else
					packTo(file, writer.format, value)
				end
			end
		end
	end

	if dSkipped then
		for key, value in pairs(dSkipped)do
			writeString(file, key)
			packTo(file, '>H', #value)
			file:write(value)
		end
	end
	writeString(file, '_endOfData')

	return true
end
