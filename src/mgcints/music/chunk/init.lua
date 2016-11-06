-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- An object representing a compilable token in the target format.
-- @classmod Music.Chunk
-- @alias cls
local cls = {}

local require = require
local abstract = require "mgcints.util.class".abstract

--- Returns the size of the chunk.
-- Derived classes are required to override this method.
-- @function cls:size
cls.size = abstract

--- Returns the size of the chunk.
function cls:__len ()
  return self:size()
end

--- Returns a binary representation of the chunk.
-- Derived classes are required to override this method.
-- @function cls:compile
cls.compile = abstract

return require "mgcints.util.class" (cls)
