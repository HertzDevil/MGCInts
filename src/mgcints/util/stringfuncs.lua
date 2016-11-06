-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Additions to Lua's string functions.
-- This module will directly export all its functions to the @{string} table,
-- which is also the metatable of all string objects.
-- @module util.stringfuncs
-- @alias string_mt
local string_mt = string

local find = string_mt.find
local sub = string_mt.sub
local len = string_mt.len
local insert = table.insert
local min = math.min
local error = error

--- Splits a string with a delimiter string.
--
-- Every instance of the delimiter creates a new item in the return table. In
-- particular, an empty string will be created if the delimiter is found at the
-- beginning or the end of the input string.
-- @tparam string str Input string.
-- @tparam string delim Delimiter string. Patterns are not supported.
-- @treturn table A sequence containing all the string items.
-- @usage for k, v in ipairs(("a b  cde "):split(" ")) do print(k, v) end
-- -- 1   a
-- -- 2   b
-- -- 3
-- -- 4   cde
-- -- 5
string_mt.split = function (str, delim)
  if delim == "" then error("Cannot use empty string as delimiter", 2) end
  str = str .. delim
  local b, e = 0, 0
  local pos = 1
  local out = {}
  repeat
    b, e = find(str, delim, pos, true)
    local s = sub(str, pos, b - 1)
    insert(out, s)
    pos = e + 1
  until e == len(str)
  return out
end

--- Iterates through all substrings delimited by a pattern.
--
-- An extra empty string will be returned if the delimiter appears at the start
-- or the end of the input string.
-- @tparam string s Input string.
-- @tparam string pattern Search pattern.
-- @tparam[opt=1] int init Beginning substring index.
-- @tparam[opt=false] bool plain Whether `pattern` is treated as a raw string
-- during searching.
-- @treturn func An iterator function that, each time it is called, returns the
-- longest substring from the current position before the next match of
-- `pattern`.
-- @raise Raises an error if two delimiters share the same position.
-- @usage
-- for str in (" a  b c   d  "):tokenize " +" do
--   print(str) -- "", a, b, c, d, ""
-- end
string_mt.tokenize = function (s, pattern, init, plain)
  init = init or 1
  local last_init = nil
  local size = #s
  local final = false
  
  local it = function ()
    local b, e = find(s, pattern, init, plain)
    if e == size then final = true end
    if not b then
      b, e = find(s, "$")
    end
    if init > size then
      if final then final = false; return "" end
      return nil
    end
    local tok = sub(s, init, b - 1)
    init, last_init = e + 1, init
    if init == last_init then error("Delimiter matched empty string", 2) end
    return tok
  end
  
  return it, s
end

local readint_impl = function (s, size, big, signed, init)
  size = size or 1
  init = min(init or 1, #s + 1)
  
  if string_mt.unpack then -- 5.3 or above
    s = s:sub(init, init + size - 1)
    local ml = #s
    s = s .. ("\x00"):rep(size - ml)
    local z, pos = ("%s%s%d"):format(
      big and ">" or "<", signed and "i" or "I", size):unpack(s)
    return z, min(ml + 1, pos) + init - 1
  end
  
  local val = {}
  for i = 1, size do
    val[i] = s:byte(init) or 0
    if init <= #s then init = init + 1 end
  end
  if signed then val[#val] = (val[#val] + 0x80) % 0x100 - 0x80 end
  
  local z = 0
  if big then
    for i = 1, size do
      z = z * 0x100 + val[i]
    end
  else
    for i = size, 1, -1 do
      z = z * 0x100 + val[i]
    end
  end
  
  return z, init
end

--- Reads a little-endian, unsigned integer from a raw binary string.
-- Missing bytes are interpreted as zeroes.
--
-- The function may be implemented using `string.unpack` where available. The
-- same applies to all the variants below.
-- @tparam string s Input string.
-- @tparam[opt=1] int init Beginning substring index.
-- @tparam[opt=1] int size Number of bytes to read.
-- @treturn int The number read.
-- @treturn int The string position of the first unread byte.
-- @usage
-- print(("\xE8\x03"):readint())       -- 232     2
-- print(("\xE8\x03"):readint(1, 2))   -- 1000    3
-- print(("\x03\xE7"):readint_b(1, 2)) -- 999     3
-- print(("\x03\xE7"):readint(2, 2))   -- 231     3
-- print(("\x03\xE7"):readint_s(2))    -- -25     3
string_mt.readint = function (s, init, size)
  return readint_impl(s, size, false, false, init)
end

--- Reads a big-endian, unsigned integer from a raw binary string.
-- Missing bytes are interpreted as zeroes.
-- @tparam string s Input string.
-- @tparam[opt=1] int init Beginning substring index.
-- @tparam[opt=1] int size Number of bytes to read.
-- @treturn int The number read.
-- @treturn int The string position of the first unread byte.
string_mt.readint_b = function (s, init, size)
  return readint_impl(s, size, true, false, init)
end

--- Reads a little-endian, signed integer from a raw binary string.
-- Missing bytes are interpreted as zeroes.
-- @tparam string s Input string.
-- @tparam[opt=1] int init Beginning substring index.
-- @tparam[opt=1] int size Number of bytes to read.
-- @treturn int The number read.
-- @treturn int The string position of the first unread byte.
string_mt.readint_s = function (s, init, size)
  return readint_impl(s, size, false, true, init)
end

--- Reads a big-endian, signed integer from a raw binary string.
-- Missing bytes are interpreted as zeroes.
-- @tparam string s Input string.
-- @tparam[opt=1] int init Beginning substring index.
-- @tparam[opt=1] int size Number of bytes to read.
-- @treturn int The number read.
-- @treturn int The string position of the first unread byte.
string_mt.readint_sb = function (s, init, size)
  return readint_impl(s, size, true, true, init)
end

return string_mt
