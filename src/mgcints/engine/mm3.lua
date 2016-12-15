-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The Mega Man 3 - 6 MML engine.
-- @module Engine.MM3

-- [Commands Reference](https://gist.github.com/HertzDevil/0f868d77a32f92c2877b7ce304f29c53)

local require = require
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local insert = table.insert
local remove = table.remove
local unpack = table.unpack or unpack

local Default = require "mgcints.default"
local MML = require "mgcints.mml"
local Music = require "mgcints.music"
local Class = require "mgcints.util.class"
local Trie = require "mgcints.util.trie"
local ChunkNum = require "mgcints.music.chunk.num"
require "mgcints.util.stringfuncs"

local Check = Default.Errors.RuntimeCheck
local ParamAssert = Default.Errors.ParamCheck
local CmdAssert = Default.Errors.CommandCheck
local Warn = require "mgcints.util.warning".warn

local CHANNELS = 4
local builder = MML.CmdBuilder()
local engine = Default.Engine(CHANNELS, "Mega Man 3 - 6")

engine:importFeature(require "mgcints.mml.feature.mute")()



-- misc

local LOOP_DEPTH = 4
local INST_COUNT = 0x3D

local DUR_TO_BYTE = {
  [ 1] = 0xE0, [ 2] = 0xC0, [ 4] = 0xA0, [8] = 0x80,
  [16] = 0x60, [32] = 0x40, [64] = 0x20
}

local quickcmd = function (builder, mmlname, outbyte, ...)
  builder:setHandler(function (ch, ...)
    ch:addData(outbyte, ...)
  end)
  for _, v in ipairs {...} do builder:param(v) end
  return builder:make(mmlname)
end

-- our pointer implementation
local Pointer = Class({
  __init = function (self, dest, name)
    self.__super.__init(self, dest, name, 2)
  end,
  compile = function (self)
    local s = CmdAssert(self.dest, "Unknown pointer destination")
    local label = CmdAssert(s:getLabel(self.name), "Unknown pointer label")
    local adr = s:getBase() + label
    return string.char(math.floor(adr / 0x100) % 0x100, adr % 0x100)
  end,
}, require "mgcints.music.chunk.pointer")

-- stack for generating loop labels
local LoopID = Class {
  __init = function (self, maxlevels)
    self.maxlv, self.val, self.x = maxlevels, {}, 0
  end,
  size = function (self)
    return #self.val
  end,
  push = function (self)
    Check(#self.val < self.maxlv)
    self.x = self.x + 1
    insert(self.val, self.x)
    return self.x
  end,
  top = function (self)
    Check(#self.val > 0)
    return self.val[#self.val]
  end,
  pop = function (self)
    Check(#self.val > 0)
    return remove(self.val)
  end,
}



-- lexer

local lengthLexer; do
  local LENGTHS = Trie()
  for k in pairs(DUR_TO_BYTE) do
    LENGTHS:add(tostring(k))
  end
lengthLexer = function (sv)
  local k = ParamAssert(LENGTHS:lookup(sv))
  sv.b = sv.b + #k
  return tonumber(k)
end; end



-- channel state

local Channel = engine:getChannelClass()

Channel:beforeCallback(function (self)
  self.isTriplet = false
  self.key = {c = 0, d = 0, e = 0, f = 0, g = 0, a = 0, b = 0}
  self.lastnote = nil
  self.duration = Music.State(4)
  self.octave = Music.State(1)
  self.octcmdval = 0
  self.hasloop = false
  self.loopid = LoopID(LOOP_DEPTH)
  self.notestream = {}
  self.tying = false
end)

Channel:afterCallback(function (self)
  self:flushNote(true)
  if self.hasloop then
    self:addData(0x16, Pointer(self.stream, "LOOP"))
  else
    self:addData(0x17)
  end
end)

local Song = engine:getSongClass()

function Song.__mt.__index:__init (...)
  self.__super.__init(self, ...)
  self.inst = {}
end



local ChannelDefs = Channel.__mt.__index

function ChannelDefs:addData (...)
  local t = self.notestream
  if #t > 0 then
    for _, v in ipairs {...} do t[#t]:push(v) end
  else
    self:addChunk(...)
  end
end

function ChannelDefs:addNote (n)
  self:flushNote()
  insert(self.notestream, Music.Stream(n))
  self.tying = false
end

function ChannelDefs:dotNote ()
  if self:isMuted() then return end
  local t = self.notestream
  Check(#t > 0, "Empty note stream")
  local s = Music.Stream(0x02)
  s:join(t[#t])
  t[#t] = s
end

function ChannelDefs:tieNote (dur)
  if self:isMuted() then return end
  Check(#self.notestream > 0, "Empty note stream")
  self.tying = true
  self.notestream.tie = true
  if dur then
    self:noteHandler(CmdAssert(self.lastnote, "No previous note"), dur)
  end
end

function ChannelDefs:flushNote (force)
  if force then self.tying = false end
  if self.tying or self:isMuted() then return end
  
  if self.notestream.tie then
    self:addChunk(0x01)
  end
  for i, s in ipairs(self.notestream) do
    if i == #self.notestream and self.notestream.tie then
      self:addChunk(0x01)
    end
    self:getStream():join(s)
  end
  self.notestream = {}
end

function ChannelDefs:noteHandler (n, dur)
  if not dur then dur = self.duration:get() end
  dur = CmdAssert(DUR_TO_BYTE[dur], "Invalid note duration")
  if not self:isMuted() then
    self:addNote(dur + n)
  end
end



-- MML command definitions

builder:setTable(engine:getCommandTable())

-- direct input
builder:setHandler(Channel.addData):param "Uint8":make "~"

-- notes, repeat, rest
for name, val in pairs {c = 1, d = 3, e = 5, f = 6, g = 8, a = 10, b = 12} do
  builder:setHandler(function (ch, acc, dur)
    local n = val + (acc.neutral and 0 or ch.key[name])
            + acc.shift + ch.octave:get() * 12 -- query
    CmdAssert(n > 0 and n <= 0x1F, "Note out of range")
    ch:noteHandler(n, dur)
    ch.lastnote = n
  end):param "Acc":param(lengthLexer):optional():make(name)
end
builder:setHandler(function (ch, dur)
  ch:noteHandler(CmdAssert(ch.lastnote, "No previous note"), dur)
end):param(lengthLexer):optional():make "x"
builder:setHandler(function (ch, dur)
  ch:noteHandler(0, dur)
end):param(lengthLexer):optional():make "r"

-- note modifiers
builder:setHandler(function (ch, t)
  for k, v in pairs(t) do
    ch.key[k] = v
  end
end):param "KeySig":make "k"
builder:setHandler(function (ch, x)
  CmdAssert(DUR_TO_BYTE[x], "Invalid default note duration")
  ch.duration:set(x)
end):param "Uint8":make "l"

builder:setHandler(Channel.dotNote):make "."
builder:setHandler(Channel.tieNote):param(lengthLexer):optional():make "^"

-- octave-related
builder:setHandler(function (ch)
  local n = ch.octave:get()
  CmdAssert(n > 0, "Octave out of range")
  ch.octave:set(n - 1)
end):make "<"
builder:setHandler(function (ch)
  local n = ch.octave:get()
  CmdAssert(n < 2, "Octave out of range")
  ch.octave:set(n + 1)
end):make ">"
builder:setHandler(function (ch, x)
  CmdAssert(x < 8, "Octave out of range")
  ch:addData(0x09, x)
  ch.octcmdval = x
  ch.octave:set(1)
end):param "Uint8":make "O"
builder:setHandler(function (ch)
  ch.octcmdval = ch.octcmdval - 1
  CmdAssert(ch.octcmdval >= 0, "Octave out of range")
  ch:addData(0x09, ch.octcmdval)
  ch.octave:set(1)
end):make "O<"
builder:setHandler(function (ch)
  ch.octcmdval = ch.octcmdval + 1
  CmdAssert(ch.octcmdval < 8, "Octave out of range")
  ch:addData(0x09, ch.octcmdval)
  ch.octave:set(1)
end):make "O>"

-- engine commands
builder:setHandler(function (ch)
  CmdAssert(not ch.isTriplet, "Cannot start triplet block here")
  ch:addData(0x00)
  ch.isTriplet = true
end):make "{"
builder:setHandler(function (ch)
  CmdAssert(ch.isTriplet, "Cannot end triplet block here")
  ch:addData(0x00)
  ch.isTriplet = false
end):make "}"
quickcmd(builder, "`" , 0x03)
builder:setHandler(function (ch, x)
  ch:addData(0x05, ChunkNum(x, "2>"))
end):param "Uint16":make "T"
quickcmd(builder, "Q" , 0x06, "Uint8")
builder:setHandler(function (ch, x)
  CmdAssert(x <= 15, "Invalid channel volume")
  ch:addData(0x07, x)
end):param "Uint8":make "V"
builder:setHandler(function (ch, x)
  CmdAssert(x < INST_COUNT, "Invalid instrument index")
  local s = ch:getParent()
  if not s or not s.inst or not s.inst[x + 1] then
    Warn("Instrument " .. x .. " has not been declared")
  end
  ch:addData(0x08, x)
end):param "Uint8":make "@"
quickcmd(builder, "_M", 0x0A, "Int8")
quickcmd(builder, "_" , 0x0B, "Int8")
builder:setHandler(function (ch, x)
  ch:addData(0x0C, (-x) % 0x100)
end):param "Int8":make "D"
quickcmd(builder, "P" , 0x0D, "Uint8")
builder:setHandler(function (ch, x)
  CmdAssert(x <= 3, "Invalid duty setting")
  ch:addData(0x18, x * 0x40)
end):param "Uint8":make "W"

-- looping
builder:setHandler(function (ch)
  CmdAssert(ch:getStreamLevel() < LOOP_DEPTH,
            "TODO: Allow more than 4 levels of nested loops")
  ch:flushNote()
  local s = ch:getStream()
  s:addLabel(ch.loopid:push())
  local pos = s:getSize()
  ch:pushStream().getBase = function (self)
    return s:getBase() + pos
  end
end):make "["
builder:setHandler(function (ch, x)
  CmdAssert(x > 0 and x <= 256, "Invalid loop count")
  ch:flushNote()
  local s = ch:popStream()
  s:push(0x0E + ch:getStreamLevel())
  s:push(x - 1)
  s:push(Pointer(ch:getStream(), ch.loopid:pop()))
  s:addLabel "BREAK"
  ch:getStream():join(s)
end):param "Uint":make "]"
builder:setHandler(function (ch)
  CmdAssert(not ch.stream.hasbreak, "Multiple break points in a loop")
  ch:flushNote()
  ch:getStream().hasbreak = true
  local ptr = Pointer(ch:getStream(), "BREAK")
  ch:addData(0x11 + ch:getStreamLevel(), 0, ptr)
end):make ":"
builder:setHandler(function (ch)
  CmdAssert(not ch.hasloop, "Duplicate channel loop point")
  ch:flushNote(true)
  ch:getStream():addLabel "LOOP"
  ch.hasloop = true
end):make "/"



-- Preprocessor directives

builder:setTable(engine:getDirectiveTable())

builder:setSongHandler(function (song, id, a, d, s, r,
                                 rate, vib, trem, reset, short)
  CmdAssert(id < INST_COUNT, "Insturment index out of bounds") -- TODO: remove
  CmdAssert(a <= 0x1F and d <= 0x1F and s <= 0x0F and r <= 0x1F and rate <= 0x7F,
    "Invalid instrument parameter")
  local dat = string.char(a, d, s * 0x10, r,
    rate + (reset and 0x80 or 0), vib, trem, short and 0x80 or 0)
  if song.inst[id + 1] and song.inst[id + 1] ~= dat then
    Warn("Redefinition of instrument " .. id)
  end
  song.inst[id + 1] = dat
end):param "Uint8":param "Uint8":param "Uint8":param "Uint8":param "Uint8"
    :param "Uint8":optional "0":param "Uint8":optional "0"
    :param "Uint8":optional "0":param "Bool":optional "1"
    :param "Bool":optional "0":make "#inst"



-- music inserter

engine:setupEngine(function (self, rom)
  local link = Music.Linker()
  self.link = link
  
  self.base = 0x8A41
  rom:seek("set", 0x08)
  local delta = rom:read(2):readint(1, 2) - 0x80 -- NSF
  link:setDelta(delta)
  link:writable(self.base - delta, 0xFFFF - delta)
  
  self.instruments = {}
  link:seekDelta(rom, self.base)
  link:seekDelta(rom, (rom:read(2):readint_b(1, 2)))
  for i = 1, INST_COUNT do
    self.instruments[i] = rom:read(8)
  end
end)

engine:setInserter(function (self, rom, song, track)
  local link = self.link

  local header = Music.Stream(0x00)
  song:doAll(function (ch)
    header:push(Pointer(ch:getStream(), "START"))
  end)

  link:setPos(link:seekDelta(rom, self.base + 2 * track))
  link:addStream(Music.Stream(Pointer(header, "START")))

  link:setPos(link:seekDelta(rom, (rom:read(2):readint_b(1, 2))))
  link:addStream(header)
  song:doAll(function (ch)
    link:addStream(ch:getStream())
  end)

  for k, v in pairs(song.inst) do
    self.instruments[k] = v
  end
end)

engine:finishEngine(function (self, rom)
  local link = self.link
  link:seekDelta(rom, self.base)
  link:setPos(link:seekDelta(rom, (rom:read(2):readint_b(1, 2))))
  link:addStream(Music.Stream(unpack(self.instruments)))

  link:flush(rom)
end)



-- export module
return engine
