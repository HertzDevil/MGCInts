-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A string chunk.
-- @classmod Music.Chunk.Str
-- @alias cls
local cls = {}

local tostring = tostring

--- Chunk initializer.
-- @param str Chunk content. It is automatically converted into a string.
function cls:__init (str)
  self.data = tostring(str)
end

function cls:size ()
  return #self.data
end

function cls:compile ()
  return self.data
end

return require "mgcints.util.class" (cls, require "mgcints.music.chunk")
