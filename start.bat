@echo off
:server
luajit main.lua
IF ERRORLEVEL 2 goto server
