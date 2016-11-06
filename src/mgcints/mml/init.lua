-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The entire MML module.
-- @module MML
-- @alias CLASSES
local CLASSES = {}

--- The @{MML.Command} class.
-- @table Command
CLASSES.Command = require "mgcints.mml.command"

--- The @{MML.CmdBuilder} class.
-- @table CmdBuilder
CLASSES.CmdBuilder = require "mgcints.mml.command.builder"

--- The @{MML.MacroTable} class.
-- @table MacroTable
CLASSES.MacroTable = require "mgcints.mml.macrotable"

--- The @{MML.Parser} class.
-- @table Parser
CLASSES.Parser = require "mgcints.mml.parser"

--- The @{MML.PPContext} class.
-- @table PPContext
CLASSES.PPContext = require "mgcints.mml.ppcontext"

return CLASSES
