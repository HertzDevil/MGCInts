-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

local Class = require "mgcints.util.class"
local Cmd = require "mgcints.mml.command"
local MacroTable = require "mgcints.mml.macrotable"
local Builder = require "mgcints.mml.command.builder" ()

local PREFIX = require "mgcints.default.symbols".DIRECTIVE_PREFIX
local assert = require "mgcints.default.errors".RuntimeCheck
local wrap = require "mgcints.util.misc".wrap
local map = require "mgcints.util.misc".map

local create; do
  local DEFINE_CMDS = wrap(Builder:setSongHandler (function (song, id, x)
    song:getPPContext():define(id, x)
  end):param "Ident2":param "Int":optional "1":make())
  local UNDEFINE = Builder:setSongHandler (function (song, id)
    song:getPPContext():undefine(id)
  end):param "Ident2":make()
  local IFDEF = Builder:setSongHandler (function (song, id)
    local cxt = song:getPPContext()
    cxt:ifStart(cxt:isDefined(id))
  end):param "Ident2":make()
  local IFNDEF = Builder:setSongHandler (function (song, id)
    local cxt = song:getPPContext()
    cxt:ifStart(not cxt:isDefined(id))
  end):param "Ident2":make()
  local IF2 = Builder:setSongHandler (function (song, x, op, y)
    local cxt = song:getPPContext()
    if not x:find "[^%d]" then x = tonumber(x) else x = cxt:getConstant(x) end
    if not y:find "[^%d]" then y = tonumber(y) else y = cxt:getConstant(y) end
    cxt:ifStart(op(x, y))
  end):param "Ident":param "Compare":param "Ident":make()
  local ELSE = Builder:setSongHandler (function (song)
    song:getPPContext():ifElse()
  end):make()
  local ENDIF = Builder:setSongHandler (function (song)
    song:getPPContext():ifEnd()
  end):make()
  local REMAP = Builder:setSongHandler (function (song, x, y)
    song:mapChannel(x, y)
  end):param "Uint":param "Char":make()
create = function ()
  local mtable = MacroTable()
  map(function (cmd)
    mtable:addCommand(PREFIX .. "define", cmd)
  end, DEFINE_CMDS())
  mtable:addCommand(PREFIX .. "undef", UNDEFINE)
  mtable:addCommand(PREFIX .. "ifdef", IFDEF)
  mtable:addCommand(PREFIX .. "ifndef", IFNDEF)
  mtable:addCommand(PREFIX .. "if", IF2)
  mtable:addCommand(PREFIX .. "else", ELSE)
  mtable:addCommand(PREFIX .. "endif", ENDIF)
  mtable:addCommand(PREFIX .. "remap", REMAP)
  return mtable
end; end

return create
