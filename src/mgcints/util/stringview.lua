-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A proxy object representing a suffix of a larger string.
-- All methods of Lua's built-in @{string} table are available as class methods,
-- however only a few are available as instance methods; all class methods from
-- the @{string} table not shown here produce new @{util.StringView} objects.
--
-- Originally, string view objects had an ending index in addition to the
-- beginning index, but this was scrapped because:
--
-- - Only very few string algorithms operate on the end of a string;
-- - In particular, MMLs are regular languages, thus it is possible to work with
-- only the beginning of a string entirely;
-- - Operations such as `StringView("aaa", 1, 2):find "a*"` would fail, and
-- extracting the represented substring defeats the purpose of using a view.
-- @classmod util.StringView
-- @alias cls
local cls = {}

local string = string
local unpack = table.unpack or unpack
local floor = math.floor

-- Normalizes string index values in the same manner as string.sub.
local fix_sub = function (length, i, j)
  assert(i)
  if not j then j = length end
  if i < 0 then i = i + length + 1 end
  if j < 0 then j = j + length + 1 end
  if i < 1 then i = 1 end
  if j > length then j = length end
  return i, j
end

-- Given string indices relative to a stringview object, returns the true string
-- indices relative to the underlying string.
local translate_sub = function (sv, i, j)
  if not i then i = 1 end
  i, j = fix_sub(sv:len(), i, j)
  i, j = i + sv.b - 1, j + sv.b - 1
  return i, j
end
local findresults = function (sv, pattern, init, plain)
  if not init then init = 1 end
  if not plain then plain = false end
  local b, e = translate_sub(sv, init)

  local result = {sv.str:find(pattern, b, plain)}
  if not result[1] then return nil end
  if result[2] > e then return nil end
  return result
end

--- String view initializer.
-- The index value is corrected according to @{string.sub}.
-- @tparam string str Source string.
-- @tparam[opt=1] int b Beginning substring index.
function cls:__init (str, b)
  self.str = str
  self.b = fix_sub(#str, b or 1)
end

--- Returns the represented substring as a raw string.
function cls:extract ()
  return self.str:sub(self.b)
end

--- Returns the represented substring as a raw string.
-- Compatible with @{tostring}.
-- @function cls:__tostring
cls.__tostring = cls.extract
--[[
do
  local fmt = '<String view: %d,, %q>'
function cls:__tostring ()
  return fmt:format(self.b, self.str)
end; end
]]

--- Returns the full underlying string.
function cls:getfull ()
  return self.str
end

--- Returns the length of the represented substring.
function cls:__len ()
  local i, j = fix_sub(#self.str, self.b)
  j = j - i + 1
  return j >= 0 and j or 0
end

--- Returns the length of the represented substring.
-- @function cls:len
cls.len = cls.__len

--- Obtains a substring without creating an intermediate string view.
-- @tparam[opt=1] int i Beginning substring index.
-- @tparam[opt=-1] int j Ending substring index.
-- @treturn string The result of applying @{string.sub} to the represented
-- substring.
function cls:sub (i, j)
  return self.str:sub(translate_sub(self, i, j))
end

--- Returns the results of @{string.byte} on the represented substring.
-- @tparam[opt=1] int i Beginning substring index.
-- @tparam[opt=i] int j Ending substring index.
function cls:byte (i, j)
  if not i then i = 1 end
  if not j then j = i end
  return self.str:byte(translate_sub(self, i, j))
end

--- Returns the results of @{string.find} on the represented substring.
-- The returned string indices are relative to the substring rather than the
-- source string.
-- @tparam string pattern Regular expression or raw string to find.
-- @tparam[opt=1] int init Beginning substring index.
-- @tparam[opt=false] bool plain Whether the search treats `pattern` as a raw
-- string instead of a regex.
function cls:find (pattern, init, plain)
  local result = findresults(self, pattern, init, plain)
  if not result then return nil end
  for i, v in ipairs(result) do if type(v) == "number" then
    result[i] = v - self.b + 1
  end end
  return unpack(result)
end

--- Trims characters at the beginning that match against a pattern.
-- This method modifies the @{util.StringView} object in-place.
-- @tparam string pattern Regex pattern to match.
-- @tparam[opt=false] bool plain Whether the search treats `pattern` as a raw
-- string instead of a regex.
-- @treturn string The trimmed string, or `nil` if the pattern cannot match any
-- string.
function cls:trim (pattern, plain)
  local b, e = self:find(pattern, 1, plain)
  if not b or b ~= 1 then return nil end
  local space = self:sub(b, e)
  self.b = self.b + e
  return space
end

--- Trims leading whitespace characters.
-- @treturn string The removed whitespace.
function cls:ws ()
  local space = ""
  while true do
    local ch = self.str:sub(self.b, self.b)
    if not ch:find "^%s" then break end
    self.b = self.b + 1
    space = space .. ch
  end
  return space
end

--- Moves the string view pointer to a specified location.
-- @tparam[opt] int offset String index.
-- @treturn int The new index of the represented substring, corrected according
-- to Lua's string functions.
function cls:seek (offset)
  if not offset then return self.b end
  self.b = floor(offset)
  local n = #self.str
  if self.b < 0 then self.b = self.b + n + 1 end
  if self.b < 1 then self.b = 1 end
  -- if self.b > n + 1 then self.b = n + 1 end
  return self.b
end

--- Moves the string view pointer relative to the current location.
-- @tparam int offset Offset amount.
-- @treturn int The new index of the represented substring.
function cls:advance (offset)
  return self:seek(self.b + (offset or 0))
end

--- Resets the view to represent the entire source string.
function cls:restore ()
  self.b = 1
end

local StringView = require "mgcints.util.class" (cls)

--- Creates a full @{util.StringView} from another.
-- @static
-- @tparam util.StringView sv String view object.
-- @treturn util.StringView A new string view object whose source is the
-- substring represented by `sv`.
StringView.slice = function (sv)
  return StringView(sv:extract())
end

--- String view wrapper for @{string.char}.
-- @static
-- @tparam int ... Byte values of each character.
StringView.char = function (...)
  return StringView(string.char(...))
end

--- String view wrapper for @{string.dump}.
-- @static
-- @tparam func f Function.
StringView.dump = function (f)
  return StringView(string.dump(f))
end

local strfunc = {
  "upper", "lower", "reverse",
  "rep", "format",
  "pack", "unpack", "packsize",
  "match", "gsub", "gmatch",
}
for _, fn in ipairs(strfunc) do
  StringView[fn] = function (sv, ...)
    return StringView(string[fn](sv:extract(), ...))
  end
end

return StringView
