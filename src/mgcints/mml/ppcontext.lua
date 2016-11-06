-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The preprocessor context for default directives.
-- Deriving from this class is not recommended, although a derived @{Music.Song}
-- constructor may still manually use another context object.
-- @classmod MML.PPContext
-- @alias cls
local cls = {}

local require = require
local assert = require "mgcints.default.errors".RuntimeCheck
local concat = table.concat
local insert = table.insert

local SYMBOL = require "mgcints.default.symbols"

--- Context initializer.
function cls:__init ()
  self.macro = {}
  self.defines = {}
  self.if_state = {[0] = true}
  self.pre_str = {}
  self.mml_str = {}
end

--- Defines a preprocessor constant.
-- @tparam string id Constant name.
-- @param x Constant value.
-- @raise Raises a Lua error if `id` has already been defined.
function cls:define (id, x)
  assert(not self:isDefined(id), "Macro redefinition")
  self.macro[id] = x
end

--- Undefines a preprocessor constant.
-- @tparam string id Constant name.
function cls:undefine (id)
  self.macro[id] = nil
end

--- Returns whether a preprocessor constant is defined.
-- @tparam string id Constant name.
function cls:isDefined (id)
  return self.macro[id] ~= nil
end

--- Returns the preprocessor constant.
-- @tparam string id Constant name.
-- @return Constant value.
-- @raise Raises a Lua error if the given constant cannot be found.
function cls:getConstant (id)
  return assert(self.macro[id], "Undefined macro")
end

--- Starts a preprocessor if block.
-- @tparam bool enable Whether the preprocessor accepts text on new rows.
function cls:ifStart (enable)
  self.if_state[#self.if_state + 1] = not not enable
end

--- Toggles the state of the current preprocessor if block.
function cls:ifElse ()
  local t = self.if_state
  assert(#t > 0, "Illegal preprocessor if block")
  t[#t] = not t[#t]
end

--- Finishes the current preprocessor if block.
function cls:ifEnd ()
  local t = self.if_state
  assert(#t > 0, "Illegal preprocessor if block")
  t[#t] = nil
end

--- Adds a line to the preprocessor.
-- @tparam string line Input string.
-- @tparam bool preproc Whether the line contains a preprocessor directive.
function cls:pushLine (line, preproc)
  assert(not line:find "[\r\n]", "More than one line pushed")
  insert(self.pre_str, preproc and line or "")
  insert(self.mml_str, preproc and SYMBOL.SINGLECOMMENT or
                       not self.if_state[#self.if_state] and "" or line)
end

--- Returns a copy of the input MML with all MML text removed.
function cls:getPreString ()
  return concat(self.pre_str, "\n")
end

--- Returns a copy of the input MML with all preprocessor text removed.
function cls:getMMLString ()
  return concat(self.mml_str, "\n")
end

return require "mgcints.util.class" (cls)
