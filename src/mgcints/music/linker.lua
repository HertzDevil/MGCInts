-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A linker that facilitates inserting streams into a binary file.
-- @classmod Music.Linker
-- @alias cls
local cls = {}

local insert = table.insert
local remove = table.remove
local ipairs = ipairs
local setmetatable = setmetatable
local Check = require "mgcints.default.errors".RuntimeCheck

local Class = require "mgcints.util.class"
local Stream = require "mgcints.music.stream"

-- properties
local _pos = setmetatable({}, {__mode = "k"})
local _offsetdelta = setmetatable({}, {__mode = "k"})
local _currentblock = setmetatable({}, {__mode = "k"})
local _blocks = setmetatable({}, {__mode = "k"})
local _writerange = setmetatable({}, {__mode = "k"})

local function isProtected (link, b, e)
  local w = _writerange[link]
  if not w then return true end
  for _, v in ipairs(w) do if b >= v[1] and e <= v[2] then
    return false
  end end
  return true
end

--- Linker initializer.
function cls:__init ()
  _pos[self] = 0
  _offsetdelta[self] = 0
  _currentblock[self] = nil
  _blocks[self] = {}
  _writerange[self] = {}
end

--- Sets the offset between file addresses and mapped target addresses.
-- @tparam int x Offset amount.
function cls:setDelta (x)
  _offsetdelta[self] = x
end

--- Sets the current position of a file using a mapped address.
-- @tparam file fn File handle.
-- @tparam int x Target address value.
-- @treturn int The corresponding real file address.
function cls:seekDelta (fn, x)
  return fn:seek("set", x - _offsetdelta[self])
end

--- Starts a new block of streams at a given file position.
-- @tparam int x File address offset.
function cls:setPos (x)
  _pos[self] = x
  _currentblock[self] = {pos = x}
  insert(_blocks[self], _currentblock[self])
end

--- Adds a stream to the current block.
--
-- Successive calls to this method push stream data sequentially until the next
-- call to @{Music.Linker:setPos}.
-- @tparam Music.Stream s Stream object.
-- @raise Throws an error if any part of the stream lies in a protected range.
-- The range must be writable at the time this method is called.
function cls:addStream (s)
  Check(Class.instanceof(s, Stream), "Not a stream object")
  s:setBase(_pos[self] + _offsetdelta[self])
  local size = s:getSize()
  if isProtected(self, _pos[self], _pos[self] + size - 1) then
    Check(false, ("Writing to protected range near $%X - $%X"):format(
      _pos[self], _pos[self] + size - 1))
  end
  _pos[self] = _pos[self] + size
  insert(_currentblock[self], s)
end

--- Marks a range as writable.
-- @tparam int b Start address, inclusive.
-- @tparam int e End address, inclusive.
function cls:writable (b, e)
  if b > e then b, e = e, b end
  local w = _writerange[self]
  local i = 1
  while i <= #w do
    local v = w[i]
    if b <= v[2] + 1 and e >= v[1] - 1 then
      if b > v[1] then b = v[1] end
      if e < v[2] then e = v[2] end
      remove(w, i)
    else
      i = i + 1
    end
  end
  insert(_writerange[self], {b, e})
end

--- Applies all added streams to a file.
--
-- After calling this method, all the added blocks of streams are freed from the
-- linker.
-- @tparam file fn File handle with write access.
function cls:flush (fn)
  local writes = {}
  for _, v in ipairs(_blocks[self]) do
    local bin = {}
    for _, s in ipairs(v) do insert(bin, s:build()) end
    insert(writes, {v.pos, table.concat(bin)})
  end
  _currentblock[self] = nil
  _blocks[self] = {}
  
  -- now only file i/o errors could happen
  for _, v in ipairs(writes) do
    fn:seek("set", v[1])
    fn:write(v[2])
  end
end

return require "mgcints.util.class" (cls)
