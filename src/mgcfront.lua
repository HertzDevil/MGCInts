#!/usr/bin/env lua

-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The main compiler-inserter frontend script.
-- @script mgcfront
-- @author HertzDevil
-- @copyright 2016
-- @license Mozilla Public License Version 2.0
-- @release v0.1.1

local require = require
local tostring = tostring
local tonumber = tonumber
local dofile = dofile
local collectgarbage = collectgarbage
local open = io.open

local has_argparse, argparse = pcall(require, "argparse")
local notice = [[MGCInts Version 0.1.1
(C) HertzDevil 2016
This program is licensed under Mozilla Public License Version 2.0.]]
local getargs; do
  local ipairs = ipairs
  local unpack = table.unpack or unpack
  
  if has_argparse then
    local p = argparse():epilog(notice)
      :name "mgcfront"
      :description [[The MML Generic Compiler Frontend

Compiles a single MML file.]]
      :require_command(false)
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
    p:argument "engine":args "?":action(ec)
      :description "Engine name"
    p:argument "input":args "?":action(ic)
      :description "Input file"
    p:argument "output":args "?":action(oc)
      :description "Output/patch file"
    p:argument "param":args "*":action "concat"
      :description "Engine-dependent parameters"

    local a_o_mutex = function (k, s1, s2)
      local errstr = ("Cannot use both %s and %s"):format(s1, s2)
      return function (arg, _, v)
        if not v then return end
        if arg[k] then p:error(errstr) end
        arg[k] = v
      end
    end
    local em = a_o_mutex("engine", "<engine>", "-e")
    local im = a_o_mutex("input", "<input>", "-i")
    local om = a_o_mutex("output", "<output>", "-o")
    p:option "-e --engine":overwrite(false):action(em)
      :description "Specify the engine name, out of order."
    p:option "-i --input":overwrite(false):action(im)
      :description "Specify the input file, out of order."
    p:option "-o --output":overwrite(false):action(om)
      :description "Specifiy the output/patch file, out of order."
    p:option "-t --track":default "1":convert(tonumber)
        :description "Set the track number."

    p:action(function (arg)
      if not arg.engine then
        p:error "missing argument 'engine'"
      end
    end)

--[[
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
]]
  
    getargs = function (t)
      return p:parse(t)
    end
  else
    getargs = function (t)
      return {
        command = "compile",
        compile = true,
        engine = t[1],
        input = t[2],
        output = t[3],
        track = 1,
        param = {select(4, unpack(t))},
      }
    end
  end
end

local Ex = require "mgcints.util.exception"

local main = Ex.try(function (arg)
  os.setlocale "C"
  local Warning = require "mgcints.util.warning"
  local findEngine = require "mgcints.util.misc".findEngine
  
  if not has_argparse then
    Warning.warn "Module 'argparse' not installed"
    for _, v in ipairs(arg) do if v == "--help" then
      io.stdout:write("Usage: mgcfront <engine> [<input>] [<output>]\n\n",
                      notice, "\n")
      return 0
    end end
  end
  arg = getargs(arg)
  
--  local Profiler = require "mgcints.util.globalprofiler" ()
--  Profiler:enter "pre"
  local Default = require "mgcints.default"
  local Compiler = require "mgcints.music.compiler"
--  Profiler:exit "pre"

  local Check = Default.Errors.RuntimeCheck
  local engine = Check(findEngine(arg.engine), "Bad engine name")
  local f = arg.input and
    Check(open(arg.input, "r"), "Bad MML filename") or io.stdin
  local rom = arg.output and
    Check(open(arg.output, "r+b"), "Bad output filename") or arg.input and
    Check(open(arg.input .. ".out", "r+b"), "Bad output filename") or io.stdout
  local track = arg.track
  local mmlstr = f:read "*a"
  
  if mmlstr:find "[^\001-\127]" then
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
for k, v in pairs(arg) do print(k, v) end
]]
local status = main(arg)
collectgarbage()
os.exit(status, true)
