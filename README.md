# LuaClassic
A small Minecraft Classic server written in Lua.

Server supports web clients over websockets and some CPE extensions.

All of necessary libraries already compiled for Linux (arm, x86_64) and Windows mingw-w64 (x86, x86_64).

Server tested on Debian Stretch/Buster, Arch Linux, Raspbian and Windows 10. On other systems stable work is not guaranteed.

Demo server runned [here](http://www.classicube.net/server/play/9ae57bbe1ab6ac3bfaa8b9d2143c80b6/)

Check the [wiki page](https://github.com/igor725/LuaClassic/wiki) for more details.

# Using
1. Run `./start.sh` (on Windows `start.bat`) and let the server to generate config files
3. Modify configuration files as you needed
4. Execute "restart" command

# Deps
* [LuaJIT](http://luajit.org/download.html)
* [zlib](https://www.zlib.net/)
* [LuaLanes](https://github.com/LuaLanes/lanes)
* struct-0.3 library from `src` dir
