-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The Castlevania MML engine.
-- @module Engine.CV1

local require = require

local Default = require "mgcints.default"
local MML = require "mgcints.mml"
local Music = require "mgcints.music"
local Class = require "mgcints.util.class"
local ChunkNum = require "mgcints.music.chunk.num"
local ChunkPtr = require "mgcints.music.chunk.pointer"
require "mgcints.util.stringfuncs"

local Check = Default.Errors.RuntimeCheck
local ParamAssert = Default.Errors.ParamCheck
local CmdAssert = Default.Errors.CommandCheck

local CHANNELS = 3
local builder = MML.CmdBuilder()
local engine = Default.Engine(CHANNELS, "Castlevania (NES)")
builder:setTable(engine:getCommandTable())

engine:importFeature(require "mgcints.mml.feature.mute")()



local Pointer = Class({
  __init = function (self, dest, name)
    self.__super.__init(self, dest, name, 2)
  end,
  compile = function (self)
    local s = CmdAssert(self.dest, "Unknown pointer destination")
    local label = CmdAssert(s:getLabel(self.name), "Unknown pointer label")
    return ChunkNum(s:getBase() + label, "2<"):compile()
  end,
}, ChunkPtr)

local DURATION = {[1] = 16, [2] = 8, [4] = 4, [8] = 2, [16] = 1}

local lengthLexer; do
  local getvalue = function (sv)
    local raw = sv:trim "%%" ~= nil
    local l = sv:trim "%d*"
    if raw then return 0, tonumber(l) end
    sv:ws()
    local dot = 2 - .5 ^ #sv:trim "%.*"
    if l ~= "" then
      return 0, ParamAssert(DURATION[tonumber(l)]) * dot
    end
    return dot, 0
  end
lengthLexer = function (sv)
  local mult, add = getvalue(sv)
  while sv:trim "%s*&%s*" ~= nil do
    local a, b = getvalue(sv)
    mult, add = mult + a, add + b
  end
  return function (x)
    local ticks = mult * x + add
    local z = math.floor(ticks)
    CmdAssert(z == ticks and z >= 1 and z <= 16, "Invalid note duration")
    return z
  end
end; end



local Channel = engine:getChannelClass()

Channel:beforeCallback(function (self)
  self.key = {c = 0, d = 0, e = 0, f = 0, g = 0, a = 0, b = 0}
  self.lastnote = nil
  self.duration = Music.State(4)
  self.octave = Music.State(0)
  self.hasloop = false
  self.loopid = 1
end)

Channel:afterCallback(function (self)
  if self.hasloop then
    self:addChunk(0xFE, 0xFF, Pointer(self:getStream(), "LOOP"))
  else
    self:addChunk(0xFF)
  end
end)



builder:setHandler(function (ch, t)
  for k, v in pairs(t) do
    ch.key[k] = v
  end
end):param "KeySig":make "k"
builder:setHandler(function (ch, x)
  CmdAssert(DURATION[x], "Invalid default note duration")
  ch.duration:set(x)
end):param "Uint8":make "l"

for name, val in pairs {c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11} do
  builder:setHandler(function (ch, acc, durfunc)
    local n = val + (acc.neutral and 0 or ch.key[name]) + acc.shift
    CmdAssert(ch:getID() ~= 4, "Not implemented")
    CmdAssert(n >= 0 and n <= 11, "Note out of range")
    if not ch:isMuted() then
      local l = durfunc(DURATION[ch.duration:get()])
      ch:addChunk(n * 0x10 + l - 1)
    end
    ch.lastnote = n
  end):param "Acc":param(lengthLexer):make(name)
end
builder:setHandler(function (ch, durfunc)
  if not ch:isMuted() then
    ch:addChunk(0xC0 + durfunc(DURATION[ch.duration:get()]) - 1)
  end
end):param(lengthLexer):make "r"

builder:setHandler(function (ch, speed, duty, v, d, r)
  CmdAssert(ch:getID() ~= 3, "Cannot use this command on the triangle channel")
  CmdAssert(speed > 0 and speed <= 0xF and duty <= 0x3 and v <= 0xF and d <= v and r <= 0xF)
  ch:addChunk(0xD0 + speed, duty * 0x40 + 0x30 + v, (v - d) * 0x10 + r)
end):param "Uint8":param "Uint8":param "Uint8":param "Uint8":param "Uint8":make "@"
builder:setHandler(function (ch, speed, linear)
  CmdAssert(ch:getID() == 3, "Cannot use this command outside the triangle channel")
  ch:addChunk(0xD0 + speed, linear)
end):param "Uint8":param "Uint8":make "@"

builder:setHandler(function (ch)
  local n = ch.octave:get()
  CmdAssert(n > 0, "Octave out of range")
  ch.octave:set(n - 1)
  ch:addChunk(0xE4 - ch.octave:get())
end):make "<"
builder:setHandler(function (ch)
  local n = ch.octave:get()
  CmdAssert(n < 4, "Octave out of range")
  ch.octave:set(n + 1)
  ch:addChunk(0xE4 - ch.octave:get())
end):make ">"
builder:setHandler(function (ch, oct)
  CmdAssert(oct <= 4, "Octave out of range")
  ch:addChunk(0xE4 - oct)
  ch.octave:set(oct)
end):param "Uint8":make "o"

builder:setHandler(function (ch)
  CmdAssert(ch:getStreamLevel() < 1, "Cannot nest loops")
  local s = ch:getStream()
  s:addLabel(ch.loopid)
  local pos = s:getSize()
  ch:pushStream().getBase = function (self)
    return s:getBase() + pos
  end
end):make "["
builder:setHandler(function (ch, x)
  x = x or 1
  CmdAssert(x > 0 and x < 0xFF, "Invalid loop count")
  local s = ch:popStream()
  s:push(0xFE)
  s:push(x)
  s:push(Pointer(ch:getStream(), ch.loopid))
  ch.loopid = ch.loopid + 1
  ch:getStream():join(s)
end):param "Uint":optional():make "]"
builder:setHandler(function (ch)
  CmdAssert(not ch.hasloop, "Duplicate channel loop point")
  ch:getStream():addLabel "LOOP"
  ch.hasloop = true
end):make "/"

builder:setHandler(function (ch)
  CmdAssert(ch:getID() == 3, "Cannot use this command outside the triangle channel")
  ch:addChunk(0xEA)
end):make "H" --"!h"
builder:setHandler(function (ch)
  CmdAssert(ch:getID() == 3, "Cannot use this command outside the triangle channel")
  ch:addChunk(0xE9)
end):make "S" --"!s"
builder:setHandler(function (ch)
  ch:addChunk(0xE8)
end):make "D" -- detune
--[[
builder:setHandler(function (ch)
  ch:addChunk(0xEC)
end):make "`0hEC"
builder:setHandler(function (ch)
  ch:addChunk(0xED)
end):make "`0hED"
]]
builder:setHandler(function (ch, x1, x2)
  if not ch:isMuted() then
    ch:addChunk(0xF0, x1, x2)
  end
end):param "Uint8":param "Uint8":make "S" -- sweep



engine:setupEngine(function (self, rom)
  local link = Music.Linker()
  local bias, delta
  rom:seek("set", 0)
  if rom:read(6) == "NESM\026\001" then -- NSF
    rom:seek("set", 0x8)
    local LOAD = rom:read(2):readint(1, 2)
    bias = LOAD - 0x80
    delta = bias
  else
    local mapper = math.floor(rom:read(1):byte() / 16)
    mapper = mapper + 16 * math.floor(rom:read(1):byte() / 16)
    bias = mapper == 0x63 and 0x7B0A or 0x7FF0
    delta = 0x8000 - 0x10
    if mapper == 0x63 then
      -- v.s. castlevania has checksums
      Check(false, "V.S. System mapper detected")
    end
  end
  
  rom:seek("set", 0x8185 - bias)
  local tablebase = rom:read(2):readint(1, 2)
  link:writable(tablebase - delta, tablebase - delta + 0x116)
  link:writable(0x8C02 - bias, 0xB500 - bias)
  link:setDelta(delta)
  
  self.link = link
  self.delta = delta
  self.tablebase = tablebase
end)

engine:setInserter(function (self, rom, song, track)
  local tindex = 0x27 + (track - 1) * 3
  local songbase = self.tablebase + tindex * 3
  
  local link = self.link
  local delta = self.delta
  
  local header = Music.Stream()
  header:push(0x80)
  header:push(Pointer(song:getChannel(1):getStream(), "START"))
  header:push(0x04)
  header:push(Pointer(song:getChannel(2):getStream(), "START"))
  header:push(0x08)
  header:push(Pointer(song:getChannel(3):getStream(), "START"))
  link:setPos(rom:seek("set", songbase - delta))
  link:addStream(header)
  
  local base = rom:read(3):readint(2, 2) -- skip first byte
  link:setPos(base - delta)
  song:doAll(function (ch)
    link:addStream(ch:getStream())
  end)
  
  link:flush(rom)
end)

return engine
