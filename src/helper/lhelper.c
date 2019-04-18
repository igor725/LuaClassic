#include "b64.h"
#include "sha1.h"
#include "lua.h"
#include "lauxlib.h"
#include <string.h>

int meth_encwsframe(lua_State *L)
{
	size_t fdsz;
	int hdrsz = 2;
	const char* fd = luaL_checklstring(L, 1, &fdsz);
	unsigned char opcode = (unsigned char)luaL_checkinteger(L, 2);

	if(fdsz>125) {
		hdrsz = 4;
	}

	size_t outsz = fdsz + hdrsz;
	unsigned char* out = (unsigned char*)malloc(outsz);

	out[0] = 0x80 | (opcode & 0x0f);

	if(hdrsz == 4) {
		uint16_t bs = fdsz;
		out[1] = 126;
		out[2] = (bs >> 8) & 0xff;
		out[3] = bs & 0xff;
	} else
		out[1] = (char)fdsz;
	memcpy(out+hdrsz, fd, fdsz);

	lua_pushlstring(L, out, outsz);
	return 1;
}

int meth_unmask(lua_State *L)
{
	size_t plen;
	const char* masked = luaL_checklstring(L, 1, &plen);
	const char* mask = luaL_checklstring(L, 2, NULL);
	char* unmasked = (char*)malloc(plen);

	for(uint32_t i=0;i<plen;i++) {
		unmasked[i] = masked[i]^mask[i%4];
	}

	lua_pushlstring(L, unmasked, plen);
	return 1;
}

int meth_rdhdr(lua_State *L)
{
	char b1 = luaL_checkinteger(L, 1);
	char b2 = luaL_checkinteger(L, 2);

	lua_pushboolean(L, (b1 >> 0x07) & 0x01);
	lua_pushboolean(L, b2 >> 0x07);
	lua_pushinteger(L, b1 & 0x0F);
	lua_pushinteger(L, b2 & 0x7F);
	return 4;
}

int meth_digest(lua_State *L)
{
	SHA1_CTX ctx;
	size_t sz;
	const char* str = luaL_checklstring(L, 1, &sz);
	unsigned char hash[HASH_SIZE];
	SHA1Init(&ctx);
	SHA1Update(&ctx, str, sz);
	SHA1Final(hash, &ctx);
	lua_pushlstring(L, hash, HASH_SIZE);
	return 1;
}

int meth_b64enc(lua_State *L)
{
	size_t sz;
	const char* str = luaL_checklstring(L, 1, &sz);
	char* b64 = b64_encode(str, sz);
	lua_pushstring(L, b64);
	return 1;
}

int luaopen_helper(lua_State *L)
{
	lua_pushcfunction(L, meth_digest);
	lua_setglobal(L, "sha1");
	lua_pushcfunction(L, meth_b64enc);
	lua_setglobal(L, "b64enc");
	lua_pushcfunction(L, meth_encwsframe);
	lua_setglobal(L, "encodeWsFrame");
	lua_pushcfunction(L, meth_rdhdr);
	lua_setglobal(L, "readWsHeader");
	lua_pushcfunction(L, meth_unmask);
	lua_setglobal(L, "unmaskData");

	return 0;
}
