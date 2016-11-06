-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- An engine definition which contains all necessary information for a target
-- sound driver.
-- @classmod Music.Engine
-- @alias cls
local cls = {}

local require = require

local Class = require "mgcints.util.class"

local Validate = require "mgcints.default.errors".ArgumentCheck
local Check = require "mgcints.default.errors".RuntimeCheck
local type = type
local pcall = pcall

--- Engine initializer.
-- @tparam table defs An engine definition, which requires the following
-- fields:<ul>
-- <li> `name`: If present, gives the engine a name;</li>
-- <li> `song`: A subclass of @{Music.Song} which produces song objects for the
-- engine;</li>
-- <li> `channel`: A subclass of @{Music.Channel} which produces channel objects
-- for the engine;</li>
-- <li> `chcount`: The default channel count;</li>
-- <li> `parser`: An @{MML.Parser} object containing command definitions for the
-- engine;</li>
-- <li> `inserter`: A function which has the same parameters as @{insertData}
-- (except `self`).
-- </li>
-- </ul>
function cls:__init (defs)
  self.song = defs.song
  self.chcount = defs.chcount
  self.channel = defs.channel
  self.parser = defs.parser
  self._inserter = defs.inserter
  self.name = defs.name or "(Unnamed)"
  
  self.features = {}
  
  Validate(Class.subclassof(self.song, require "mgcints.music.song") and
           type(self.chcount) == "number" and
           Class.subclassof(self.channel, require "mgcints.music.channel") and
           Class.instanceof(self.parser, require "mgcints.mml.parser") and
           type(self._inserter) == "function" and
           type(self.name) == "string", "Invalid engine definition")
end

--- Returns the name of the sound engine.
function cls:getName ()
  return self.name
end

--- Returns the method table of the channel class.
function cls:getChannelClass ()
  return self.channel
end

--- Returns the method table of the song class.
function cls:getSongClass ()
  return self.song
end

--- Returns the command parser.
function cls:getParser ()
  return self.parser
end

--- Returns the macro table for MML commands.
function cls:getCommandTable ()
  return self.parser.macros
end

--- Returns the macro table for preprocessor directives.
function cls:getDirectiveTable ()
  return self.parser.directives
end

--- Creates a new song.
-- @treturn Music.Song A song object using the parameters provided in the
-- initializer.
function cls:makeSong ()
  local s = self.song(self.chcount, self.channel)
  s:setEngine(self)
  return s
end

--- Sets the inserter function of the engine.
-- @tparam func f A function which has the same parameters as @{insertData}
-- (except `self`).
function cls:setInserter (f)
  self._inserter = f
end

--- Inserts song data into a file.
-- @tparam file rom A file opened in "r+b" mode.
-- @tparam Music.Song song A song object which must be compatible with the
-- engine's song class.
-- @tparam[opt=1] int track Track index.
function cls:insertData (rom, song, track)
  self._inserter(rom, song, track)
end

--- Imports a feature to the engine.
-- @tparam class fea @{MML.Feature} class.
-- @tparam[opt] table cmdname A table containing command identifiers as keys. If
-- the corresponding value is `false`, the command is not imported; otherwise,
-- the command is added to the engine's MML macro table, using this value as the
-- name if provided.
-- @tparam[opt] table mname A table containing method names as both keys and
-- values. For each method added to the channel / song class, if a corresponding
-- value exists in this table, the method is renamed with the value.
-- @treturn func The import function, which accepts the feature's own
-- engine-dependent parameters and returns values of the @{MML.Feature.register}
-- function.
function cls:importFeature (fea, cmdname, mname)
  return function (...)
    Validate(Class.subclassof(fea, require "mgcints.mml.feature"),
      "Not a feature class")
    Check(not self.features[fea], "Feature already imported")
    self.features[fea] = true
    return fea:register(self, cmdname or {}, mname or {}, ...)
  end
end

return require "mgcints.util.class" (cls)
