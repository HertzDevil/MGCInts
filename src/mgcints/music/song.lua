-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A song object containing channels and compilation state.
-- @classmod Music.Song
-- @alias cls
local cls = {}

local require = require
local char = string.char
local insert = table.insert
local ipairs = ipairs
local tostring = tostring
local assert = require "mgcints.default.errors".RuntimeCheck

local Class = require "mgcints.util.class"
local Engine = require "mgcints.music.engine"
local Cxt = require "mgcints.mml.ppcontext"

--- Song class initializer.
function cls:__classinit ()
  self.cb = {pre = {}, post = {}}
end

--- Song initializer.
-- @tparam int chcount Number of channels.
-- @tparam class cls The @{Music.Channel} class used to create channels.
-- @param ... Extra engine-dependent parameters. The same parameters are passed
-- to the channel constructor.
function cls:__init (chcount, cls, ...)
  assert(Class.subclassof(cls, require "mgcints.music.channel"),
         "Invalid channel class object")
  self.channel = {}
  self.chmap = {}
  for i = 1, chcount do
    local ch = cls(i, ...)
    ch.parent = self
    if i == 1 then ch:setActive(true) end
    self.channel[i] = ch
    self.chmap[i] = i <= 9 and tostring(i) or
                    i <= 35 and char(0x37 + i) or
                    i <= 61 and char(0x3D + i) or nil
  end
  self.thisch = nil
  self.engine = nil
  self.ppcontext = Cxt()
end

--- Associates a song with an engine.
-- @tparam Music.Engine e Engine object.
function cls:setEngine (e)
  assert(Class.instanceof(e, Engine), "Not a sound engine")
  assert(e:getSongClass().__mt.__index == self.__class.__mt.__index,
    "Sound engine does not support song object class")
  self.engine = e
end

--- Returns the associated sound engine.
-- @treturn Music.Engine The engine installed in @{setEngine}.
-- @raise Raises an exception if no engine has been installed.
function cls:getEngine ()
  return assert(self.engine, "No sound engine associated with song object")
end

--- Accesses one of the song's channels.
-- @tparam string|int id Channel identifier, or channel index starting from 1.
-- @treturn Music.Channel The requested channel.
-- @raise `RuntimeError` if the channel with the given index cannot be found.
function cls:getChannel (id)
  if type(id) == "string" then
    id = assert(self.chmap[id], "Invalid channel identifier")
  end
  return assert(self.channel[id], "Invalid channel index")
end

--- Changes the channel identifier for a channel.
-- @tparam int id Channel index starting from 1.
-- @tparam string name Channel identifier, must be a single character.
function cls:mapChannel (id, name)
  assert(string.len(name) == 1, "Invalid channel identifier")
  self.chmap[id] = name
end

--- Accesses the song's current channel.
-- @tparam[opt] string|int index The new current channel index or identifier.
-- @treturn Music.Channel The current channel.
function cls:current (...)
  if select("#", ...) > 0 then
    self.thisch = self:getChannel((...))
  end
  return self.thisch
end

--- Returns the song's preprocessor context.
function cls:getPPContext ()
  return self.ppcontext
end

--- Applies a function to all channels, active or inactive.
-- @tparam func f A function which accepts a @{Music.Channel} object as its sole
-- argument.
-- @param ... Extra arguments which are passed to `f`.
function cls:doAll (f, ...)
  for _, v in ipairs(self.channel) do
    f(v, ...)
  end
end

--- Applies a function to all active channels.
-- @tparam func f A function which accepts a @{Music.Channel} object as its sole
-- argument.
-- @param ... Extra arguments which are passed to `f`.
-- @local
function cls:doActive (f, ...)
  for _, v in ipairs(self.channel) do if v:isActive() then
    f(v, ...)
  end end
end

--- Performs initialization before compiling. Specifically, it performs the
-- following actions in order:
--
-- - Finalizes the channel identifier mapping;
-- - Invokes all the callback functions in the order they were added using
-- @{beforeCallback};
-- - Initializes each channel.
function cls:beforeDefault ()
  -- invert channel identifier map
  local t = {}
  for i, v in ipairs(self.chmap) do
    assert(not t[v], "Duplicate channel identifier")
    t[v] = i
  end
  self.chmap = t
  
  assert(not self.before, "Music.Song:before is deprecated")
  for _, v in ipairs(self.__class.cb.pre) do
    v(self)
  end
  self:doAll(function (ch) ch:beforeDefault() end)
end

--- Performs clean-up after compiling. Specifically, it performs the following
-- actions in order:
--
-- - Finalizes each channel;
-- - Invokes all the callback functions in the order they were added using
-- @{afterCallback}.
function cls:afterDefault ()
  -- do nothing right now
  self:doAll(function (ch) ch:afterDefault() end)
  assert(not self.after, "Music.Song:after is deprecated")
  for _, v in ipairs(self.__class.cb.post) do
    v(self)
  end
end

--- Adds an action before compiling.
--
-- Callbacks are invoked immediately after the preprocessing phase and before
-- each channel performs its custom action, in the order they are added.
-- @static
-- @tparam class cself Class object.
-- @tparam func f Callback function receiving a @{Music.Song} object as its only
-- argument.
function cls.beforeCallback (cself, f)
  insert(cself.cb.pre, f)
end

--- Adds an action after compiling.
--
-- Callbacks are invoked immediately after the compiling phase, after each
-- channel performs its custom action, in the order they are added.
-- @static
-- @tparam class cself Class object.
-- @tparam func f Callback function receiving a @{Music.Song} object as its only
-- argument.
function cls.afterCallback (cself, f)
  insert(cself.cb.post, f)
end

return Class(cls)
