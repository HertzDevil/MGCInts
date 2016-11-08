-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

local require = require
local tonumber = tonumber
local tostring = tostring

local Class = require "mgcints.util.class"
local Song = require "mgcints.music.song"
local Channel = require "mgcints.music.channel"
local Engine = require "mgcints.music.engine"
local Parser = require "mgcints.mml.parser"
local Macros = require "mgcints.default.macros"
local Directives = require "mgcints.default.directives"

local create = function (x, s)
  return Engine {
    song = Class({}, Song),
    channel = Class({}, Channel),
    chcount = tonumber(x) or 1,
    parser = Parser(Macros(), Directives()),
    name = tostring(s or "(Unnamed)"),
  }
end

return create
