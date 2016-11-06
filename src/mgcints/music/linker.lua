-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A linker that facilitates inserting streams into a binary file.
-- @classmod Music.Linker
-- @alias cls
local cls = {}

local insert = table.insert
local ipairs = ipairs

--- Linker initializer.
function cls:__init ()
  self.pos = 0
  self.offsetdelta = 0
  self.currentblock = nil
  self.blocks = {}
end

--- Sets the offset between file addresses and mapped target addresses.
-- @tparam int x Offset amount.
function cls:setDelta (x)
  self.offsetdelta = x
end

--- Starts a new block of streams at a given file position.
-- @tparam int x File address offset.
function cls:setPos (x)
  self.pos = x
  self.currentblock = {pos = x}
  insert(self.blocks, self.currentblock)
end

--- Adds a stream to the current block.
--
-- Successive calls to this method push stream data sequentially until the next
-- call to @{Music.Linker:setPos}.
-- @tparam Music.Stream s Stream object.
function cls:addStream (s)
  s:setBase(self.pos + self.offsetdelta)
  self.pos = self.pos + s:getSize()
  insert(self.currentblock, s)
end

--- Applies all added streams to a file.
--
-- After calling this method, all the added blocks of streams are freed from the
-- linker.
-- @tparam file fn File handle with write access.
function cls:flush (fn)
  for _, v in ipairs(self.blocks) do
    fn:seek("set", v.pos)
    for _, s in ipairs(v) do fn:write(s:build()) end
  end
  self.currentblock = nil
  self.blocks = {}
end

return require "mgcints.util.class" (cls)
