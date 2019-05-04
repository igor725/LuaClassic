# LuaClassic
A small Minecraft Classic server written in Lua.

Code of this server is very buggy, shitty and needs refactoring, but it works and i don't want to touch him.
Server supports web clients over websockets and some CPE extensions.

All of necessary libraries already compiled for Linux (arm, x86_64) and Windows mingw-w64 (x86, x86_64).

Server tested on Debian Stretch/Buster, Arch Linux, Raspbian and Windows 10. On other systems stable work is not guaranteed.

# Using
1. Run ```./start.sh``` (on Windows ```start.bat```) and let the server to generate config files
3. Modify configuration files as you needed
4. Execute "restart" command

# Deps
* [LuaJIT](http://luajit.org/download.html)
* [zlib](https://www.zlib.net/)
* [LuaLanes](https://github.com/LuaLanes/lanes)
* [luasocket-lanes](https://github.com/LuaDist-testing/luasocket-lanes)
* [lsqlite3](https://github.com/LuaDist/lsqlite3)
* [luafilesystem](https://github.com/keplerproject/luafilesystem)
* Libraries from src dir
