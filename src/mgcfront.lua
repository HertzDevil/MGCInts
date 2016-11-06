#!/usr/bin/env lua

-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The main compiler-inserter frontend script.
--
-- For a given engine name such as `test`, the compiler frontend searches for
-- the engine definition at the following locations, in the given order:
--
-- - `test.lua` at the current working directory;
-- - `$(MGCFRONT_INCLUDE)/test.lua`. This extra search path must be manually
-- added;
-- - `$(MGCINTS_PATH)/include/engine/test.lua`. This is where work-in-progress
-- engine definitions go in the distribution;
-- - `$(MGCINTS_PATH)/src/mgcints/engine/test.lua`. Complete engine definitions
-- can be found there;
-- - A Lua module called `mgcints.engine.test`, possibly using the `$(LUA_PATH)`
-- environment variable.
-- @script mgcfront
-- @author HertzDevil
-- @copyright 2016
-- @license Mozilla Public License Version 2.0
-- @release v0.1.0

local require = require
local tostring = tostring
local tonumber = tonumber
local dofile = dofile
local collectgarbage = collectgarbage
local open = io.open

local getargs; do
  local ipairs = ipairs
  local argparse = require "argparse"
  local notice = [[MGCInts Version 0.1.0
  (C) HertzDevil 2016
  This program is licensed under Mozilla Public License Version 2.0.]]
  local p = argparse():epilog(notice)
    :name "mgcfront"
    :description "The MML Generic Compiler Frontend"
  p:command_target "command"

  local cascade = function (t)
    return function (arg, _, v)
      if not v then return end
      for _, k in ipairs(t) do if not arg[k] then
        arg[k] = v; return
      end end
      if not arg.param then arg.param = {} end
      table.insert(arg.param, v)
    end
  end
  local ec = cascade {"engine", "input", "output"}
  local ic = cascade {"input", "output"}
  local oc = cascade {"output"}
  local compile = p:command "compile":epilog(notice)
    :description "Compiles a single MML file."
  compile:argument "engine":args "?":action(ec)
    :description "Engine name"
  compile:argument "input":args "?":action(ic)
    :description "Input file"
  compile:argument "output":args "?":action(oc)
    :description "Output/patch file"
  compile:argument "param":args "*":action "concat"
    :description "Engine-dependent parameters"

  local a_o_mutex = function (k, s1, s2)
    local errstr = ("Cannot use both %s and %s"):format(s1, s2)
    return function (arg, _, v)
      if not v then return end
      if arg[k] then compile:error(errstr) end
      arg[k] = v
    end
  end
  local em = a_o_mutex("engine", "<engine>", "-e")
  local im = a_o_mutex("input", "<input>", "-i")
  local om = a_o_mutex("output", "<output>", "-o")
  compile:option "-e --engine":overwrite(false):action(em)
    :description "Specify the engine name, out of order."
  compile:option "-i --input":overwrite(false):action(im)
    :description "Specify the input file, out of order."
  compile:option "-o --output":overwrite(false):action(om)
    :description "Specifiy the output/patch file, out of order."
  compile:option "-t --track":default "1":convert(tonumber)
      :description "Set the track number."

  compile:action(function (arg)
    if not arg.engine then
      compile:error "missing argument 'format'"
    end
  end)

  local multi = p:command "multi":epilog(notice)
    :description "Compiles multiple songs."
  multi:action(function ()
    multi:error "not implemented"
  end)

  local info = p:command "info":epilog(notice)
    :description "Displays information about a resource."
  info:action(function ()
    info:error "not implemented"
  end)
getargs = function (t)
  return p:parse(t)
end; end

local Ex = require "mgcints.util.exception"

local findEngine; do
  local fileExists = function (fname)
    if type(fname) == "string" then
      local f = io.open(fname, "r")
      if f then
        f:close()
        return fname
      end
    end
  end
  local envPath = function (value, fname)
    local data = os.getenv(value)
    if data then
      if not data:find "[/\\]$" then
        data = data .. "/"
      end
      return fileExists(data .. fname)
    end
  end
findEngine = function (name)
  if not name then return end
  if not name:find "%.lua$" then
    name = name .. ".lua"
  end
  local md = "mgcints.engine." .. name:gsub("%.lua$", "")
  local fn = fileExists(name)
    or envPath("MGCFRONT_INCLUDE", name)
    or envPath("MGCINTS_PATH", "include/engine/" .. name)
    or envPath("MGCINTS_PATH", "src/mgcints/engine/" .. name)
  if fn then
    return dofile(fn)
  end
  
  if type((package.searchers or package.loaders)[2](md)) == "function" then
    return require(md)
  end
end; end

local main = Ex.try(function (arg)
  os.setlocale "C"
  
--  local Profiler = require "mgcints.util.globalprofiler" ()
--  Profiler:enter "pre"
  local Default = require "mgcints.default"
  local Compiler = require "mgcints.music.compiler"
  local Warning = require "mgcints.util.warning"
--  Profiler:exit "pre"

  local Check = Default.Errors.RuntimeCheck
  local engine = Check(findEngine(arg.engine), "Bad engine name")
  local f = Check(open(arg.input, "r"), "Bad MML filename")
  local rom = Check(open(arg.output, "r+b"), "Bad output filename")
  local track = arg.track
  local mmlstr = f:read "*a"
  
  if mmlstr:find "[^\x00-\x7F]" then
    Warning.warn "Input MML file contains non-ASCII characters"
  end

  io.stdout:write("Current MML engine: ", engine:getName(), '\n')
  Compiler.processFile(engine, mmlstr, rom, track)
  f:close()
  rom:close()
  
  io.stdout:write "Finished.\n"
  return 0
end,
Ex, function (e)
  io.stderr:write(tostring(e), '\n')
  return 1
end)

--[[
if #arg == 0 then
  arg = {
    [-2] = arg[-2], [-1] = arg[-1],
    "compile", "rc2", "../usr/rc2.mml", "../usr/rc2.nsf"
  }
end
]]
local status = main(getargs(arg))
collectgarbage()
os.exit(status)
