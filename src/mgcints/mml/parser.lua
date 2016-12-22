-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The MML parser which translates MML text into commands.
-- @classmod MML.Parser
-- @alias cls
local cls = {}

local require = require
local ipairs = ipairs
local pcall = pcall
local error = error
local assert = require "mgcints.default.errors".SyntaxCheck
local co_wrap = coroutine.wrap
local yield = coroutine.yield
local car_cdr = require "mgcints.util.misc".car_cdr
local instanceof = require "mgcints.util.class".instanceof

local Symbol = require "mgcints.default.symbols"
local MacroTable = require "mgcints.mml.macrotable"
local Ex = require "mgcints.util.exception"
local SyntaxEx = Ex.typed "SyntaxError"
local Trace = require "mgcints.util.svtrace"

--- Parser initializer.
--
-- Missing arguments are replaced with empty macro tables.
-- @tparam[opt] MML.MacroTable macros The macro table object for MML commands.
-- @tparam[opt] MML.MacroTable dirs The macro table object for preprocessor
-- directives.
function cls:__init (macros, dirs)
  self.macros = macros or MacroTable()
  self.directives = dirs or MacroTable()
end

--- Reads the next MML macro.
-- @tparam util.StringView sv Input MML.
-- @treturn[1] MML.Command The next command.
-- @return[1] All the parameters the command accepts.
-- @return[2] Nothing if the end of the string is reached.
-- @raise `SyntaxError` if it cannot locate a valid MML command.
function cls:readCommand (sv)
  -- skip whitespace
  sv:ws()
  -- end of string reached, finish
  if sv:len() == 0 then return end

  -- get the command table with the given name
  local b_old = sv:seek()
  local ft = self.macros:readNext(sv)
  if not ft then
    Trace(sv, SyntaxEx "Unknown command"):throw()
  end

  -- find first legal interpretation of the command
  -- ParamError in lexer function signals failure
  local b = sv:seek()
  for _, cmd in ipairs(ft) do
    local suc, results = car_cdr(pcall(cmd.getParams, cmd, sv))
    if suc then return cmd, results() end
    local e = results()
    if not instanceof(e, Ex.typed "ParamError") then error(e, 2) end
    sv:seek(b)
  end

  -- cannot find an interpretation in the command table
  sv:seek(b_old)
  Trace(sv, SyntaxEx "Illegal command parameters"):throw()
end

--- Tries to read an preprocessor directive from an input.
-- @tparam util.StringView sv Input MML.
-- @raise `SyntaxError` if it cannot locate a valid directive or there is
-- trailing input.
function cls:readDirective (sv)
  -- get the command table with the given name
  local b_old = sv:seek()
  local ft = self.directives:readNext(sv)
  if not ft then
    Trace(sv, SyntaxEx "Unknown preprocessor directive"):throw()
  end

  -- find first legal interpretation of the command
  -- ParamError in lexer function signals failure
  local b = sv:seek()
  for _, cmd in ipairs(ft) do
    local suc, results = car_cdr(pcall(cmd.getParams, cmd, sv))
    if suc then
      sv:ws() -- consume the rest of the line
      local c = sv:trim(Symbol.SINGLECOMMENT, true)
      assert(c or sv:len() == 0, "Trailing text after preprocessor directive")
      return cmd, results()
    end
    local e = results()
    if not instanceof(e, Ex.typed "ParamError") then error(e, 2) end
    sv:seek(b)
  end

  -- cannot find an interpretation in the command table
  sv:seek(b_old)
  Trace(sv, SyntaxEx "Illegal directive parameters"):throw()
end

--- Iterates through all commands of an MML string.
-- @tparam util.StringView sv Input MML text.
-- @treturn func A generator which, for each MML command, returns an
-- @{MML.Command} object followed by all of its parameters wrapped using
-- @{util.Misc.wrap|wrap}.
function cls:loop (sv)
  return co_wrap(function ()
    while true do
      -- consume whitespace
      sv:ws()

      -- save string view position
      local b = sv:seek()

      -- obtain the next command with all parameters it accepts
      local nextCmd, params, count = car_cdr(self:readCommand(sv))

      -- end of string, no more commands remaining
      if nextCmd == nil and count == 0 then break end

      -- return results
      yield(b, nextCmd, params)
    end
  end)
end

return require "mgcints.util.class" (cls)
