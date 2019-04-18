#include "b64.h"
#include "sha1.h"

#include "lua.h"
#include "lauxlib.h"

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
	return 0;
}
