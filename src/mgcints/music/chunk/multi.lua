-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A chunk capable of storing subchunks.
-- @classmod Music.Chunk.Multi
-- @alias cls
local cls = {}

local Class = require "mgcints.util.class"
local Chunk = require "mgcints.music.chunk"

local select = select
local insert = table.insert
local assert = require "mgcints.default.errors".RuntimeCheck

--- Chunk initializer.
-- @tparam Music.Chunk ... Contained chunks.
function cls:__init (...)
  self.data = {}
  for i = 1, select("#", ...) do
    local c = select(i, ...)
    assert(Class.instanceof(c, Chunk))
    insert(self.data, c)
  end
end

function cls:size ()
  local sum = 0
  for _, v in ipairs(self.data) do
    sum = sum + v:size()
  end
  return sum
end

function cls:compile ()
  local cat = 0
  for _, v in ipairs(self.data) do
    cat = cat .. v:compile()
  end
  return cat
end

return Class(cls, Chunk)
