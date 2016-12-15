-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The main compiler module.
-- @module Music.Compiler
-- @alias cls
local cls = {}

local require = require
require "mgcints.util.stringfuncs"

local Default = require "mgcints.default"
local StringView = require "mgcints.util.stringview"
local Ex = require "mgcints.util.exception"
local Runtime = Ex.typed "RuntimeError"
local Trace = require "mgcints.util.svtrace"

local assert = Default.Errors.RuntimeCheck
local car_cdr = require "mgcints.util.misc".car_cdr

--- The preprocessing stage.
-- @tparam Music.Song song Input song object.
-- @tparam string input Input MML text.
-- @treturn string MML text after preprocessing.
function cls.preprocess (song, input)
  local engine = assert(song:getEngine(),
    "Song object not associated with music engine")
  local parser = engine:getParser()
  
  -- ignore shebang
  input = input:gsub("^#!.-\n", Default.Symbols.SINGLECOMMENT .. "\n")
  
  -- set up preprocessor context
  local cxt = song:getPPContext()
  
  -- get the directive symbol
  local dirsym = Default.Symbols.DIRECTIVE_PREFIX
  
  -- iterate through all lines
  for line in input:tokenize "[\r\n]" do
    -- a preprocessor directive must start a line
    if line:find(dirsym, 1, true) == 1 then
      cxt:pushLine(line, true)
      
      -- handle it immediately
      local sv = StringView(line)
      local nextCmd, params = car_cdr(parser:readDirective(sv))
      
      -- apply command to song only, should not access active channels
      nextCmd:applySong(song, params())
    else
      cxt:pushLine(line, false)
    end
  end
  
  return cxt:getMMLString()
end

--- Performs initialization after preprocessing and before compiling.
-- @tparam Music.Song song Input song object.
function cls.precompile (song)
  song:beforeDefault()
end

--- The main compilation loop.
-- @tparam Music.Song song Input song object.
-- @tparam string input Input MML text.
function cls.compile (song, input)
  local engine = assert(song:getEngine(),
    "Song object not associated with music engine")
  local parser = engine:getParser()
  
  -- create a new string view from the preprocessed string
  local sv = StringView(input)
  
  -- main processing loop
  for b, cmd, params in parser:loop(sv) do
    -- attach trace if necessary
    Ex.try(cmd.apply,
    Runtime, function (e)
      sv:seek(b) -- restore old position
      Trace(sv, e):throw()
    end)(cmd, song, params())
  end
end

--- Performs validation after compiling and before inserting.
-- @tparam Music.Song song Input song object.
function cls.postcompile (song)
  song:afterDefault()
end

--- The postprocessing stage.
-- @tparam Music.Song song Input song object.
-- @tparam file rom Output file.
-- @tparam int track Track index.
function cls.postprocess (song, rom, track)
  local engine = assert(song:getEngine(),
    "Song object not associated with music engine")
  engine:insertData(rom, song, track)
end

--- The main program.
-- @tparam Music.Engine engine The engine definition.
-- @tparam string|table mml Input MML text, or a list of MML texts.
-- @tparam file rom Output file.
-- @tparam int|table track Track index, or a list of track indices.
function cls.processFile (engine, mml, rom, track)
  engine:callSetup(rom)

  if type(mml) ~= "table" then mml = {mml} end
  if type(track) ~= "table" then track = {track} end
  assert(#mml == #track, "MML / track list mismatch")
  
  for i, v in ipairs(track) do
    local song = engine:makeSong()
    local _mml = cls.preprocess(song, mml[i])
    cls.precompile(song)
    cls.compile(song, _mml)
    cls.postcompile(song)
    cls.postprocess(song, rom, v)
  end

  engine:callFinish(rom)
end

return cls
