local hc = {
	global = true,
	disabled = true
}

function hc:load()
	registerSvPacket('BBBBBBh')
end

return hc
