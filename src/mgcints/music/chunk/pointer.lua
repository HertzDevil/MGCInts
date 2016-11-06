-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A fixed-size chunk which points to another location in the target format.
-- @classmod Music.Chunk.Pointer
-- @alias cls
local cls = {}

local require = require
local assert = require "mgcints.default.errors".RuntimeCheck

--- Pointer initializer.
-- @tparam Music.Stream dest Target stream.
-- @param name Label identifier.
-- @tparam int count Size of the pointer in bytes.
function cls:__init (dest, name, count)
  self.dest = dest
  self.adr = nil
  self.name = name
  self.count = count
  assert(type(count) == "number", "Invalid pointer size")
end

function cls:size ()
  return self.count
end

--[[
--- Returns the position of the pointer.
function cls:getAddress ()
  return self.adr
end
]]

--- Sets the position of the pointer.
-- @tparam int adr Position of the pointer relative to the start of the stream.
-- @local
function cls:setAddress (adr)
  self.adr = adr
end

return require "mgcints.util.class" (cls, require "mgcints.music.chunk")
