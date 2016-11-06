@echo off
setlocal
set LUA_PATH=%MGCINTS_PATH%src/?/init.lua;%LUA_PATH%
set LUA_PATH=%MGCINTS_PATH%src/?.lua;%LUA_PATH%
lua "%MGCINTS_PATH%src/mgcfront.lua" %*
endlocal
