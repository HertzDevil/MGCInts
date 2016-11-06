-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Base class for optional MML features.
-- A feature consists of a list of commands, custom callback functions, and
-- additional methods to be injected into song and channel classes directly.
-- Importing a feature is as simple as a single call to
-- @{Music.Engine:importFeature}.
-- @classmod MML.Feature
-- @alias cls
local cls = {}

local setmetatable = setmetatable
local pcall = pcall
local pairs = pairs
local Check = require "mgcints.default.errors".RuntimeCheck

--- Returns the name of the feature.
-- @tparam class cself Class object.
-- @treturn string A string identifying the feature.
function cls.getName (cself)
  return ""
end

--- Obtains a command from the feature.
--
-- This is usually overridden in the form of a constant table lookup.
-- @tparam class cself Class object.
-- @tparam string ident Command identifier.
-- @treturn ?class An @{MML.Command} class.
function cls.getCommandType (cself, ident)
  return nil
end

--- Obtains a default command name from the feature.
--
-- This is usually overridden in the form of a constant table lookup.
-- @tparam class cself Class object.
-- @tparam string ident Command identifier.
-- @treturn string The default name for the command that will be used in the MML
-- macro table.
function cls.getCommandName (cself, ident)
  return ""
end

--- Iterates through all command identifiers available from the feature.
--
-- The returned iterator should not automatically yield the command class.
-- @tparam class cself Class object.
-- @treturn func A generator that, each time it is called, returns an identifier
-- that produces a valid result in @{MML.Feature.getCommandType}.
function cls.identifiers (cself)
  return function () end
end

--- Obtains the extra instance methods to be added to song classes.
-- @tparam class cself Class object.
-- @treturn table A table containing method names and definitions as key-value
-- pairs.
function cls.songMethods (cself)
  return {}
end

--- Obtains the extra instance methods to be added to channel classes.
-- @tparam class cself Class object.
-- @treturn table A table containing method names and definitions as key-value
-- pairs.
function cls.channelMethods (cself)
  return {}
end

--- Obtains a callback function.
-- @tparam class cself Class object.
-- @tparam string kind Either "song" or "channel".
-- @tparam stirng when Either "before" or "after".
-- @treturn func The appropriate selected callback function.
function cls.getCallback (cself, kind, when)
  return function () end
end

--- Obtains help text of a feature.
-- @tparam class cself Class object.
-- @treturn string A string that describes the feature functionality.
function cls.description (cself)
  local str = ("Feature name: %s\nSupported commands:\n"):format(
    cself:getName())
  for v in cself:identifiers() do
    str = str .. (" - %s: %s\n"):format(v, cself:getCommandName(v))
  end
  str = str .. "Song methods:\n"
  for k in pairs(cself:songMethods()) do
    str = str .. (" - %s\n"):format(k)
  end
  str = str .. "Channel methods:\n"
  for k in pairs(cself:channelMethods()) do
    str = str .. (" - %s\n"):format(k)
  end
  return str
end

--- Registers the feature to an engine.
--
-- All returned values, if any, are passed to @{Music.Engine:importFeature}. The
-- base implementation does not return values.
-- @tparam class cself Class object.
-- @tparam Music.Engine engine MML engine definition.
-- @tparam table cmdname MML macro rename pairs.
-- @tparam table mname Method rename pairs.
-- </ul>
function cls.register (cself, engine, cmdname, mname)
  local songcls = engine:getSongClass()
  songcls:beforeCallback(cls:getCallback("song", "before"))
  songcls:afterCallback(cls:getCallback("song", "after"))
  local chcls = engine:getChannelClass()
  chcls:beforeCallback(cls:getCallback("channel", "before"))
  chcls:afterCallback(cls:getCallback("channel", "after"))
  
  local m = engine:getCommandTable()
  for v in cself:identifiers() do
    local cmd = Check(cself:getCommandType(v), "Missing command in feature")
    local name = cmdname[v]
    if name ~= false then
      name = name or cself:getCommandName(v)
      Check(name and name ~= "", "Missing command name in feature")
      m:addCommand(name, cmd)
    end
  end
  
  for k, v in pairs(cself:songMethods()) do
    songcls.__mt.__index[mname[k] or k] = v
  end
  for k, v in pairs(cself:channelMethods()) do
    chcls.__mt.__index[mname[k] or k] = v
  end
end

return require "mgcints.util.class" (cls)
