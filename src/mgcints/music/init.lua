-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The entire music module.
-- @module Music
-- @alias CLASSES
local CLASSES = {}

--- The @{Music.Channel} class.
-- @table Channel
CLASSES.Channel = require "mgcints.music.channel"

--- The @{Music.Chunk} class.
-- @table Chunk
CLASSES.Chunk = require "mgcints.music.chunk"

--- The @{Music.Compiler} class.
-- @table Compiler
CLASSES.Compiler = require "mgcints.music.compiler"

--- The @{Music.Linker} class.
-- @table Linker
CLASSES.Linker = require "mgcints.music.linker"

--- The @{Music.Song} class.
-- @table Song
CLASSES.Song = require "mgcints.music.song"

--- The @{Music.State} class.
-- @table State
CLASSES.State = require "mgcints.music.state"

--- The @{Music.Stream} class.
-- @table Stream
CLASSES.Stream = require "mgcints.music.stream"

return CLASSES
