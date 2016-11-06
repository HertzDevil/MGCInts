-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Mute support for MML engines.
-- @classmod MML.Feature.Mute
-- @alias cls
local cls = {}

local require = require
local pairs = pairs
local wrap = coroutine.wrap
local yield = coroutine.yield

local ch_muted = setmetatable({}, {__mode = "k"})
local builder = require "mgcints.mml.command.builder" ()

local CMDS = {
  mute = {builder:setHandler(function (ch, x)
    ch_muted[ch] = x
  end):param "Bool":make(), "m"},
}

function cls.getName (_)
  return "Channel muting"
end

function cls.getCommandType (_, ident)
  local t = CMDS[ident]
  return t and t[1]
end

function cls.getCommandName (_, ident)
  local t = CMDS[ident]
  return t and t[2]
end

function cls.identifiers (_)
  return wrap(function ()
    for k in pairs(CMDS) do yield(k) end
  end)
end

function cls.channelMethods (_)
  return {isMuted = function (ch)
    return ch_muted[ch]
  end}
end

function cls.getCallback (_, kind, when)
  if kind == "channel" and when == "before" then
    return function (ch)
      ch_muted[ch] = false
    end
  end
  return function () end
end

return require "mgcints.util.class" (cls, require "mgcints.mml.feature")
