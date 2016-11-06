-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Specialization of @{MML.Command} that supports a fixed number of parameters.
-- Almost all MML commands are derived from this class.
-- @classmod MML.Command.ParamCmd
-- @alias cls
local cls = {}

local select = select
local ipairs = ipairs
local join = require "mgcints.util.misc".join

local or_nil = function (...)
  if select("#", ...) == 0 then return nil end
  return ...
end

--- Command initializer.
-- @tparam func ... Lexer functions which accept a @{util.StringView} object as
-- their sole argument.
function cls:__init (...)
  self.scanner = {...}
end

--- Consumes parameters from an input string.
-- This specialization calls the lexer functions in the order they are declared
-- in the initializer. Macro parameters may be separated with whitespace
-- characters, plus an optional comma.
-- @tparam util.StringView sv String view object.
-- @return All the parameters of this command. Lexer functions that return
-- nothing are assumed to return `nil`.
function cls:getParams (sv)
  local results = join
  local n = #self.scanner
  for i, v in ipairs(self.scanner) do
    sv:ws()
    if i > 1 then sv:trim ",?%s*" end
    if i == n then return results(or_nil(v(sv)))() end
    results = results(or_nil(v(sv)))
  end
end

return require "mgcints.util.class" (cls, require "mgcints.mml.command")
