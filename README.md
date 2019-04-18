# LuaClassic
A small Minecraft Classic server written in Lua.

Code of this server is very buggy, shitty and needs refactoring, but it works and i don't want to touch him.
Server supports web clients over websockets and some CPE extensions.

All of necessary libraries already compiled for Linux (arm, x86_64) and Windows (x86, x86_64).

# Using
1. Run ```luajit main.lua``` and let the server to generate config files
2. Press Ctrl+C
3. Modify configuration files as you needed
4. Start server again with ```luajit main.lua```

# Deps
* [LuaJIT](http://luajit.org/git/luajit-2.0.git)
* [luasocket-lanes](https://github.com/LuaDist-testing/luasocket-lanes)
* [lsqlite3](https://github.com/LuaDist/lsqlite3)
* [lua-cjson](https://www.kyne.com.au/~mark/software/lua-cjson.php)
* [luafilesystem](https://github.com/keplerproject/luafilesystem)
* Libraries from src dir
