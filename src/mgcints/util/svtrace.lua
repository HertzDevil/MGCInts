-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A @{util.Exception} object which attaches information about a
-- @{util.StringView} object.
-- @classmod util.SvTrace
-- @alias cls
local cls = {}

local require = require

local Ex = require "mgcints.util.exception"
local Sv = require "mgcints.util.stringview"

--- Trace initializer.
-- @tparam util.StringView sv String view object.
-- @tparam[opt] util.exception e Wrapped exception object.
function cls:__init (sv, e)
  self.except = e or Ex()
  self.sv = sv
  self.trace = ""
  self.what = tostring(self.except)
end

function cls:__tostring ()
  -- trace string is not genearted until this is called
  if self.trace ~= "" then return self.trace end
  
  -- obtain row / column / current line
  local _b = self.sv:seek()
  local pre = Sv(self.sv:getfull():sub(1, _b - 1))
  local row = 1
  while pre:trim ".-\n" do row = row + 1 end
  local column = self.sv:seek() - pre:seek() + 1
  self.sv:seek(pre:seek())
  local line = self.sv:trim "[^\n]*"
  self.sv:seek(_b)
  
  -- trim displayed line
  local EXTRA_CHARS = 10
  local abbrcolumn = column
  if column < #line - EXTRA_CHARS then
    line = line:sub(1, column + EXTRA_CHARS) .. " ..."
  end
  if column > EXTRA_CHARS + 1 then
    line = "... " .. line:sub(column - EXTRA_CHARS)
    abbrcolumn = EXTRA_CHARS + 5
  end
  
  -- generate cursor
  local cursorline = line:sub(1, abbrcolumn - 1):gsub("[^\t]", " ")
  
  -- make the trace string
  self.trace = ("%s\nNear row %d, column %d\n%s\n%s^"):format(
    self.what, row, column, line, cursorline)
  
  return self.trace
end

return require "mgcints.util.class" (cls, require "mgcints.util.exception")
