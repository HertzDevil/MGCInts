-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A stream object that holds translated commands.
-- @classmod Music.Stream
-- @alias cls
local cls = {}

local require = require
local type = type
local ipairs = ipairs
local insert = table.insert
local remove = table.remove
local concat = table.concat
local assert = require "mgcints.default.errors".RuntimeCheck

local Chunk = require "mgcints.music.chunk"
local ChunkStr = require "mgcints.music.chunk.str"
local ChunkNum = require "mgcints.music.chunk.num"
local ChunkPtr = require "mgcints.music.chunk.pointer"
local Class = require "mgcints.util.class"

--- Stream initializer.
--
-- Every new stream contains a label at the beginning called "START".
-- @param ... Chunks that are inserted on initialization.
function cls:__init (...)
  self.data = {}
  self.size = 0
  self.label = {}
  self.baseadr = 0
  self:addLabel "START"
  for _, s in ipairs {...} do
    self:push(s)
  end
end

--- Inserts a chunk into the stream.
-- @tparam Music.Chunk|string|int x Chunk object, raw string, or byte value. The
-- latter two are automatically converted into @{Music.Chunk.Str} and
-- @{Music.Chunk.Num} objects respectively.
function cls:push (x)
  if type(x) == "string" then
    x = ChunkStr(x)
  elseif type(x) == "number" then
    x = ChunkNum(x)
  else
    assert(Class.instanceof(x, Chunk), "Invalid chunk object pushed to stream")
    if Class.instanceof(x, ChunkPtr) then
      x:setAddress(self.size)
    end
  end
  insert(self.data, x)
  self.size = self.size + x:size()
end

--- Removes a chunk from the stream.
-- @return The last inserted chunk, or nothing (not `nil`) if the stream is
-- empty.
function cls:pop ()
  local x = remove(self.data)
  if x ~= nil then
    self.size = self.size - x:size()
    return x
  end
end

--- Moves all the chunks of another stream.
-- @tparam Music.Stream other Stream object. Its chunks will be appended to the
-- current stream. Its contents remain unchanged after calling this method.
function cls:join (other)
  assert(other ~= self, "Attempt to join a stream to itself")
  for _, v in ipairs(other.data) do self:push(v) end
end

--- Creates a label.
-- @param name Label identifier. Each label must have a unique identifier.
function cls:addLabel (name)
  assert(self.label[name] == nil, "Duplicate stream label")
  self.label[name] = self.size
end

--- Obtains a label position.
-- @param name Label identifier.
-- @treturn The position of the label relative to the beginning of the stream.
function cls:getLabel (name)
  return self.label[name]
end

--- Returns the base address of the stream.
-- This is used by @{Music.Chunk.Pointer} objects.
function cls:getBase ()
  return self.baseadr
end

--- Sets the base address of the stream.
-- @tparam int adr New base address.
function cls:setBase (adr)
  self.baseadr = adr
end

--- Returns the current size of the stream.
function cls:getSize ()
  return self.size
end

--- Compiles the stream.
-- @treturn string A binary string representing the compiled contents.
function cls:build ()
  local out = {}
  for i, v in ipairs(self.data) do
    out[i] = v:compile()
  end
  return concat(out)
end

return require "mgcints.util.class" (cls)
