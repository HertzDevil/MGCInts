-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A song channel which accepts music data.
-- @classmod Music.Channel
-- @alias cls
local cls = {}

local require = require
local select = select
local assert = require "mgcints.default.errors".RuntimeCheck
local insert = table.insert
local unpack = table.unpack or unpack

local Class = require "mgcints.util.class"
local Stream = require "mgcints.music.stream"

--- Channel class initializer.
function cls:__classinit ()
  self.cb = {pre = {}, post = {}}
end

--- Channel initializer.
-- @tparam int id Channel index.
-- @param ... Extra engine-dependent parameters.
function cls:__init (id, ...)
  self.id = id
  self.state = {}
  self.active = false
  self.loopstream = {[0] = Stream()}
  self.stream = self.loopstream[0]
  self.lastcount = 0
end

--- Returns the channel index.
function cls:getID ()
  return self.id
end

--- Returns whether the channel is active.
function cls:isActive ()
  return self.active
end

--- Sets whether the channel is active.
-- @tparam bool enable If true, MML commands will be sent to this channel.
function cls:setActive (enable)
  self.active = not not enable
end

--- Adds chunk data to the channel.
--
-- This function skips empty strings.
-- @tparam Music.Chunk|string|int ... Chunk objects, raw strings, or byte
-- values.
function cls:addChunk (...)
  self.lastcount = 0
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v ~= "" then
      self.stream:push(v)
      self.lastcount = self.lastcount + 1
    end
  end
end

--- Undoes the last chunk insertion.
--
-- This is only valid for once after each chunk insertion.
-- @return Chunks added in the last call to @{addChunk}, in the order they were
-- added.
function cls:unget ()
  local x = self.lastcount
  self.lastcount = 0
  return self:popChunk(x)
end

--- Removes chunk data from the channel.
--
-- Invalidates @{unget} if any data is popped.
-- @tparam int n Number of chunks to pop.
-- @return Chunks at the top, in the order they were added.
function cls:popChunk (n)
  local t = {}
  for _ = 1, n do
    local x = self.stream:pop()
    if x == nil then break end
    insert(t, 1, x)
  end
  return unpack(t)
end

--- Returns the channel's active stream.
function cls:getStream ()
  return self.stream
end

--- Replaces the channel's active stream directly.
-- @tparam Music.Stream s The stream object.
function cls:setStream (s)
  assert(Class.instanceof(s, Stream), "Not a stream object")
  self.stream = s
end

--- Adds a new command stream to the channel.
-- @treturn Music.Stream The stream object.
function cls:pushStream ()
  local n = self:getStreamLevel()
  local t = Stream()
  self.stream, self.loopstream[n + 1] = t, t
  self.lastcount = 0
  return t
end

--- Releases a command stream from the channel.
-- @treturn Music.Stream The current stream object.
function cls:popStream ()
  local n = self:getStreamLevel()
  assert(n > 0, "Cannot pop base stream")
  local t = self.loopstream[n]
  self.stream, self.loopstream[n] = self.loopstream[n - 1], nil
  self.lastcount = 0
  return t
end

--- Returns the current number of streams pushed.
function cls:getStreamLevel ()
  return #self.loopstream
end

--- Performs initialization before compiling. Specifically, it invokes all the
-- callback functions in the order they were added using @{beforeCallback}.
function cls:beforeDefault ()
  assert(not self.before, "Music.Channel:before is deprecated")
  for _, v in ipairs(self.__class.cb.pre) do
    v(self)
  end
end

--- Performs clean-up after compiling. Specifically, it performs the following
-- actions in order:
--
-- - Checks that the channel has no unclosed loops;
-- - Adds an `END` label to the channel's active stream;
-- - Invokes all the callback functions in the order they were added using
-- @{afterCallback}.
function cls:afterDefault ()
  assert(self:getStreamLevel() == 0, "Unclosed loop")
  self.stream:addLabel "END" -- only the base stream has this label
  assert(not self.after, "Music.Channel:after is deprecated")
  for _, v in ipairs(self.__class.cb.post) do
    v(self)
  end
end

--- Adds an action before compiling.
-- @static
-- @tparam class cself Class object.
-- @tparam func f Callback function receiving a @{Music.Channel} object as its
-- only argument.
function cls.beforeCallback (cself, f)
  insert(cself.cb.pre, f)
end

--- Adds an action after compiling.
-- @static
-- @tparam class cself Class object.
-- @tparam func f Callback function receiving a @{Music.Channel} object as its
-- only argument.
function cls.afterCallback (cself, f)
  insert(cself.cb.post, f)
end

return require "mgcints.util.class" (cls)
