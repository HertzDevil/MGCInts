-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A number chunk.
-- @classmod Music.Chunk.Num
-- @alias cls
local cls = {}

local char = string.char
local floor = math.floor
local tonumber = tonumber
local assert = require "mgcints.default.errors".RuntimeCheck

--- Chunk initializer.
-- @tparam int x Chunk content.
-- @tparam[opt] string fmt A string in the form `[1-4]?[<>]?` which indicates
-- the size in bytes and the endianness of the chunk. If not given, defaults to
-- `1<` (one byte, little-endian).
function cls:__init (x, fmt)
  local size, bigendian = 1, false
  if fmt then
    local x, y = fmt:match "^([1-4]?)([<>]?)$"
    assert(x and y)
    size = tonumber(x) or 1
    bigendian = y == ">"
  end
  self.data = ""
  for _ = 1, size do
    local ch = char(x % 0x100)
    x = floor(x / 0x100)
    if bigendian then
      self.data = ch .. self.data
    else
      self.data = self.data .. ch
    end
  end
end

function cls:size ()
  return #self.data
end

function cls:compile ()
  return self.data
end

return require "mgcints.util.class" (cls, require "mgcints.music.chunk")
