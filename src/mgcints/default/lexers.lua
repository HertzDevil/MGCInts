-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Default lexer functions.
-- Sound engines may alter this table directly to support different MML
-- parameters.
-- @see MML.CmdBuilder:param
-- @module Default.Lexers
-- @alias Lexer
local Lexer = {}

local require = require
local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs
local load = loadstring or load
local assert = require "mgcints.default.errors".ParamCheck

--- Matches an unsigned integer.
-- @tparam util.StringView sv String view object.
-- @treturn int Matched value.
Lexer.Uint = function (sv)
  local x = sv:trim "0h%x+"
  if x then return tonumber(x:sub(3), 16) end
  x = sv:trim "0b[01]+"
  if x then return tonumber(x:sub(3), 2) end
  return assert(tonumber(assert(sv:trim "^%d+"), 10))
end

--- Matches an unsigned integer within [0, 255].
-- @tparam util.StringView sv String view object.
-- @treturn int Matched value.
Lexer.Uint8 = function (sv)
  local x = Lexer.Uint(sv)
  assert(x <= 255)
  return x
end

--- Matches an unsigned integer within [0, 65535].
-- @tparam util.StringView sv String view object.
-- @treturn int Matched value.
Lexer.Uint16 = function (sv)
  local x = Lexer.Uint(sv)
  assert(x <= 65535)
  return x
end

--- Matches a signed integer.
-- @tparam util.StringView sv String view object.
-- @treturn int Matched value.
Lexer.Int = function (sv)
  local neg = sv:trim "-"
  local num = Lexer.Uint(sv)
  if neg then num = -num end
  return num
end

--- Matches a signed integer within [-128, 127].
-- @tparam util.StringView sv String view object.
-- @treturn int Matched value.
Lexer.Int8 = function (sv)
  local x = Lexer.Int(sv)
  assert(x >= -128 and x <= 127)
  return x
end

--- Matches a signed integer within [-32768, 32767].
-- @tparam util.StringView sv String view object.
-- @treturn int Matched value.
Lexer.Int16 = function (sv)
  local x = Lexer.Int(sv)
  assert(x >= -32768 and x <= 32767)
  return x
end

--- Matches a signed byte and presents it as an unsigned value.
-- @tparam util.StringView sv String view object.
-- @treturn int Matched value.
Lexer.Byte = function (sv)
  local x = Lexer.Int8(sv)
  if x < 0 then x = x + 0x100 end
  return x
end

--- Matches a signed word and presents it as an unsigned value.
-- @tparam util.StringView sv String view object.
-- @treturn int Matched value.
Lexer.Word = function (sv)
  local x = Lexer.Int16(sv)
  if x < 0 then x = x + 0x10000 end
  return x
end

--- Matches a boolean value.
-- @tparam util.StringView sv String view object.
-- @treturn bool Matched value.
Lexer.Bool = function (sv)
  return assert(sv:trim "[01]") == "1"
end

--- Matches a boolean value as an integer.
-- @tparam util.StringView sv String view object.
-- @treturn int `1` if the matched value is true, `0` otherwise.
Lexer.Ibool = function (sv)
  return Lexer.Bool(sv) and 1 or 0
end

--- Matches a single character. This character must be followed by whitespace.
-- @tparam util.StringView sv String view object.
-- @treturn string Matched value.
Lexer.Char = function (sv)
  local ch = sv:trim "."
  assert(not sv:find "^%S")
  return ch
end

--- Matches a channel string.
--
-- By default, a channel identifier starts from `1` to `9`, then from `A` to
-- `Z`, and `a` to `z`, being able to represent 61 channels. A channel string is
-- simply any string without whitespace characters; each character enables a
-- single channel.
-- @tparam util.StringView sv String view object.
-- @treturn table A possibly empty set containing the channel identifiers as
-- keys.
Lexer.Channel = function (sv)
  local set = {}
  for ch in sv:trim "[^%s]*":gmatch "." do
    set[ch] = true
  end
  return set
end

--- Matches a quoted string.
--
-- A quoted string is enclosed by either single quotation marks or double
-- quotation marks. Quotation marks inside can be escaped by preceding it with
-- `\\`, as can backslashes themselves. Strings cannot span across multiple
-- lines.
-- @tparam util.StringView sv String view object.
-- @treturn string The string content.
-- @function Lexer.QString
do
  local escape = {["\\"] = true, ["'"] = true, ['"'] = true}
Lexer.Qstring = function (sv)
  local line = assert(sv:trim("(['\"])[^\n]-[^\\]%1")):sub(2, -2)
  return (tostring(line):gsub([[\(.)]], function (ch)
    if escape[ch] then return ch end
  end))
end; end

--- Matches an identifier.
--
-- An identifier is any plain string containing digits, letters, or underscores.
-- The first character may be a digit as well.
-- @tparam util.StringView sv String view object.
-- @treturn string The identifier name.
Lexer.Ident = function (sv)
  return assert(sv:trim "[%w_]+")
end

--- Matches a real identifier.
--
-- Unlike @{Ident}, this function does not allow a digit as the first character.
-- @tparam util.StringView sv String view object.
-- @treturn string The identifier name.
Lexer.Ident2 = function (sv)
  return assert(sv:trim "[%a_][%w_]*")
end

--- Matches a key signature.
--
-- A key signature consists of an accidental sign (`+` / `-` / `=`) followed by
-- any number of note names (defualt `a` to `g`, case-insensitive).
-- @tparam util.StringView sv String view object.
-- @treturn table A set with lowercase note names as keys and the corresponding
-- transpose amount of the accidental sign as the value for all keys.
-- @function Lexer.KeySig
do
  local ACCIDENTAL = {["+"] = 1, ["-"] = -1, ["="] = 0}
Lexer.KeySig = function (sv)
  local sign = ACCIDENTAL[tostring(assert(sv:trim "[=+-]"))]
  local t = {}
  for ch in assert(sv:trim "[A-Ga-g]+"):gmatch "." do
    t[ch:lower()] = sign
  end
  return t
end; end

--- Matches an accidental sign.
--
-- An accidental sign consists of an optional `=`, indicating a neutral note,
-- followed by any number of `+` or `-` signs.
-- @tparam util.StringView sv String view object.
-- @treturn table A table containing two fields:<ul>
-- <li> `shift`: The accidental amount;</li>
-- <li> `neutral`: Whether the neutral sign is found.</li>
-- </ul>
Lexer.Acc = function (sv)
  local neutral = sv:trim "=" ~= nil
  local shift = 0
  for ch in sv:trim "[+-]*":gmatch "." do
    shift = shift + (ch == "+" and 1 or -1)
  end
  return {shift = shift, neutral = neutral}
end

--- Matches a binary operator function.
--
-- Matches one of `+`, `-`, `*`, `/`, `^`, and `%`.
-- @tparam util.StringView sv String view object.
-- @treturn func The corresponding binary operator function.
-- @function Lexer.Binop
do
  local op = {}
  local fmt = "return function (x, y) return x %s y end"
  for _, v in ipairs {"+", "-", "*", "/", "^", "%"} do
    op[v] = load(fmt:format(v))()
  end
Lexer.Binop = function (sv)
  return assert(op[sv:trim "."])
end; end

--- Matches a binary comparison function.
--
-- Matches one of `<`, `>`, `<=`, `>=`, `==`, and `!=`.
-- @tparam util.StringView sv String view object.
-- @treturn func The corresponding binary comparison function.
-- @function Lexer.Compare
do
  local op = {}
  local fmt = "return function (x, y) return x %s y end"
  for _, v in ipairs {"<", ">", "<=", ">=", "==", "!="} do
    op[v] = load(fmt:format(v == "!=" and "~=" or v))()
  end
Lexer.Compare = function (sv)
  return assert(op[assert(sv:trim "[!<>=]=?")])
end; end

return Lexer
