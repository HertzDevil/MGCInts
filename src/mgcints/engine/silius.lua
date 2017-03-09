-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The Journey to Silius MML engine.
-- @module Engine.Silius

local require = require
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local insert = table.insert
local concat = table.concat
local floor = math.floor

local Default = require "mgcints.default"
local MML = require "mgcints.mml"
local Music = require "mgcints.music"
local Class = require "mgcints.util.class"
local ChunkPtr = require "mgcints.music.chunk.pointer"

local Check = Default.Errors.RuntimeCheck
local ParamAssert = Default.Errors.ParamCheck
local CmdAssert = Default.Errors.CommandCheck
local Warn = require "mgcints.util.warning".warn

local CHANNELS = 5
local builder = MML.CmdBuilder()
local engine = Default.Engine(CHANNELS, "Journey to Silius")

engine:importFeature(require "mgcints.mml.feature.mute")()



local Pointer = Class({
  __init = function (self, dest, name)
    ChunkPtr.__init(self, dest, name, 2)
  end,
  compile = function (self)
    local s = CmdAssert(self.dest, "Unknown pointer destination")
    local label = CmdAssert(s:getLabel(self.name), "Unknown pointer label")
    local adr = s:getBase() + label
    return string.char(adr % 0x100, floor(adr / 0x100) % 0x100)
  end,
}, ChunkPtr)

local PatternPointer = Class({
  __init = function (self, pt, dest, name)
    Pointer.__init(self, dest, name)
    self.pt = pt
  end,
  compile = function (self)
    local s = CmdAssert(self.pt[self.dest], "Unknown pattern " .. self.dest)
    local label = CmdAssert(s:getLabel(self.name), "Unknown pointer label")
    local adr = s:getBase() + label
    return string.char(adr % 0x100, floor(adr / 0x100) % 0x100)
  end,
}, Pointer)

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
    return table.remove(self.val)
  end,
}



local lengthLexer; do
  local getvalue = function (sv)
    local raw = sv:trim "%%" ~= nil
    local l = sv:trim "%d*"
    if raw then return 0, 0, tonumber(l) end
    sv:ws()
    local dots = 0
    while true do
      if not sv:trim "%." then break end
      dots = dots + 1
      sv:ws()
    end
    dots = 2 - .5 ^ dots
    if l ~= "" then
      return 0, dots / ParamAssert(tonumber(l)), 0
    end
    return dots, 0, 0
  end
lengthLexer = function (sv)
  local mult, m2, add = getvalue(sv)
  while true do
    sv:ws()
    if not sv:trim "&" then break end
    local a, b, c = getvalue(sv)
    mult, m2, add = mult + a, m2 + b, add + c
  end
  return function (x, ticks)
    local dur = x * mult + ticks * m2 + add
    CmdAssert(dur % 1 == 0 and dur > 0 and dur <= 0xFF, "Invalid note duration")
    return dur
  end
end; end



local Channel = engine:getChannelClass()

Channel:beforeCallback(function (self)
  self.key = {c = 0, d = 0, e = 0, f = 0, g = 0, a = 0, b = 0}
  self.lastnote = nil
  self.octave = Music.State(0)
  self.duration = Music.State(24)
  self.maxticks = 96
  self.fixlen = nil

  self.patterns = {}
  self.loopid = LoopID(2)

  self.hasloop = false

  self.notestream = {}
  self.slurring = false
end)

Channel:afterCallback(function (self)
  self:flushNote(true)
  if self:getID() == 0 then
    self:addData(0xFA)
  elseif self.hasloop then
    self:addData(0xFC, Pointer(self:getStream(), "LOOP"))
  else
    self:addData(0xF0)
  end
end)



local ChannelDefs = Channel.__mt.__index

function ChannelDefs:addData (...)
  local t = self.notestream
  if #t > 0 then
    for _, v in ipairs {...} do t[#t]:push(v) end
  else
    self:addChunk(...)
  end
end

function ChannelDefs:flushNote (force)
  if force then self.slurring = false end
  if self.slurring or self:isMuted() then return end

  if self.notestream.slur then
    self:addChunk(0xE9)
  end
  for i, s in ipairs(self.notestream) do
    self:getStream():join(s)
    if i == #self.notestream and self.notestream.slur then
      self:addChunk(0xE5)
    end
  end
  self.notestream = {}
end

function ChannelDefs:noteHandler (n, durfunc)
  if not self:isMuted() then
    self:addNote(n, durfunc(self.duration:get(), self.maxticks))
  end
end

function ChannelDefs:addNote (n, dur)
  self:flushNote()
  if self:isMuted() then return end
  insert(self.notestream, Music.Stream(n, not self.fixlen and dur or nil))
  self.slurring = false
end

function ChannelDefs:slurNote (durfunc)
  if self:isMuted() then return end
  Check(#self.notestream > 0, "Empty note stream")
  self.slurring = true
  self.notestream.slur = true
--  if durfunc then
--    self:noteHandler(CmdAssert(self.lastnote, "No previous note"), durfunc)
--  end
end



local Song = engine:getSongClass()

Song:beforeCallback(function (self)
  self.volume = {}
  self.pitch = {}
  self.patterns = {}
end)



builder:setTable(engine:getCommandTable())

for name, val in pairs {c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11} do
  builder:setHandler(function (ch, acc, durfunc)
    local n = val + (acc.neutral and 0 or ch.key[name])
            + acc.shift + ch.octave:get() * 12 -- query
    ch:noteHandler(n, durfunc)
    ch.lastnote = n
  end):param "Acc":param(lengthLexer):optional():make(name)
end
builder:setHandler(function (ch, durfunc)
  ch:noteHandler(CmdAssert(ch.lastnote, "No previous note"), durfunc)
end):param(lengthLexer):optional():make "x"
builder:setHandler(function (ch, durfunc)
  ch:noteHandler(0xF1, durfunc)
end):param(lengthLexer):optional():make "r"
builder:setHandler(Channel.slurNote):make "~"
--builder:setHandler(Channel.slurNote):param(lengthLexer):optional():make "~"
builder:setHandler(function (ch, durfunc)
  ch:noteHandler(0xF2, durfunc)
end):param(lengthLexer):optional():make "^"
builder:setHandler(function (ch, rate, durfunc)
  if not ch:isMuted() then
    ch:addData(0xED, rate, durfunc(ch.duration:get(), ch.maxticks))
  end
end):param "Uint8":param(lengthLexer):optional():make "y"

builder:setHandler(function (ch, t)
  for k, v in pairs(t) do
    ch.key[k] = v
  end
end):param "KeySig":make "k"
builder:setHandler(function (ch, x)
  x = ch.maxticks / x
  CmdAssert(x % 1 == 0, "Invalid default note duration")
  ch:flushNote()
  ch.duration:set(x)
end):param "Uint":make "l"
builder:setHandler(function (ch, x)
  local dur = ch.duration:get() / ch.maxticks * x
  CmdAssert(dur % 1 == 0, "Tick count will lead to invalid note durations")
  ch:flushNote()
  ch.duration:set(dur)
  ch.maxticks = x
end):param "Uint":make "T"

builder:setHandler(function (ch)
  local n = ch.octave:get()
  CmdAssert(n > 0, "Octave out of range")
  ch.octave:set(n - 1)
end):make "<"
builder:setHandler(function (ch)
  local n = ch.octave:get()
  CmdAssert(n < 10, "Octave out of range")
  ch.octave:set(n + 1)
end):make ">"
builder:setHandler(function (ch, oct)
  CmdAssert(oct <= 10, "Octave out of range")
  ch.octave:set(oct)
end):param "Uint8":make "o"

builder:setHandler(function (ch, durfunc)
  ch:flushNote()
  local dur = durfunc(ch.duration:get(), ch.maxticks)
  ch:addData(0xF6, dur)
  ch.fixlen = true
end):param(lengthLexer):make "L"
builder:setHandler(function (ch, durfunc)
  ch:flushNote()
  ch:addData(0xF7)
  ch.fixlen = false
end):param(lengthLexer):make "LX"

builder:setHandler(function (ch, x)
  ch:addData(0xEC, x)
end):param "Uint8":make "@"
builder:setHandler(function (ch)
  ch:addData(0xE6)
end):make "@PX"
builder:setHandler(function (ch, id, delay)
  local env = CmdAssert(ch:getParent().pitch[id], "Unknown pitch envelope")
  ch:addData(0xE7, delay, Pointer(env, "START"))
end):param "Ident":param "Uint8":optional "0":make "@P"
builder:setHandler(function (ch, id)
  local env = CmdAssert(ch:getParent().volume[id], "Unknown volume envelope")
  ch:addData(0xEA, Pointer(env, "START"))
end):param "Ident":make "@V"

builder:setHandler(function (ch, det)
  CmdAssert(det >= -127 and det <= 128, "Invalid detune offset")
  ch:addData(0xF8, 0x80 - det)
end):param "Int":make "D"
builder:setHandler(function (ch, gate)
  ch:addData(0xF5, gate)
end):param "Uint8":make "Q"
builder:setHandler(function (ch)
  ch:addData(0xEF)
end):make "QX"
builder:setHandler(function (ch, sweep)
  ch:addData(0xEB, sweep)
end):param "Uint8":make "S"
builder:setHandler(function (ch, trsp)
  CmdAssert(ch:getID() ~= 5, "Cannot use transpose command on DPCM channel")
  ch:addData(0xF9, trsp)
end):param "Int8":make "_"

engine:getCommandTable():getCommand(Default.Symbols.PATTERNINVOKE)
.applyChannel = function (self, ch, id)
  local pat = CmdAssert(ch:getParent():getPseudoCh(id),
    "Unknown pseudo-channel")
  ch:addData(0xFB, Pointer(pat:getStream(), "START"))
end

builder:setHandler(function (ch, id)
  CmdAssert(ch:getID() ~= 0, "Cannot put loop controls here")
  CmdAssert(not ch.patterns[id], "Pattern redefinition")
  ch:flushNote()
  local s = ch:getStream()
  local pos = s:getSize()
  ch.patterns[id] = ch:pushStream()
  ch:getStream().getBase = function (self)
    return s:getBase() + pos
  end
  ch:getStream().isPattern = true
end):param "Ident":param(function (sv) ParamAssert(sv:trim "%)%[") end):make "("
builder:setHandler(function (ch, id)
  CmdAssert(ch:getID() ~= 0, "Cannot put loop controls here")
--  ch:flushNote()
  ch:addData(0xFB, PatternPointer(ch.patterns, id, "START"))
end):param "Ident":param(function (sv) ParamAssert(sv:trim "%)") end):make "("
builder:setHandler(function (ch, id)
  CmdAssert(ch:getID() ~= 0, "Cannot put loop controls here")
  CmdAssert(ch.loopid:size() < 2,
            "TODO: Allow more than 2 levels of nested loops")
  ch:flushNote()
  local s = ch:getStream()
  local pos = s:getSize()
  s:addLabel(ch.loopid:push())
  ch:pushStream().getBase = function (self)
    return s:getBase() + pos
  end
end):make "["
builder:setHandler(function (ch, count)
  CmdAssert(ch:getID() ~= 0, "Cannot put loop controls here")
  ch:flushNote()
  local s = ch:popStream()
  if s.isPattern then
    CmdAssert(not count, "Cannot specify loop count for patterns")
    s:push(0xFA)
  else
    count = count or 1
    CmdAssert(count >= 1 and count <= 256, "Invalid loop count")
    s:push(0xFC + ch.loopid:size())
    s:push(count - 1)
    s:push(Pointer(ch:getStream(), ch.loopid:pop()))
  end
  ch:getStream():join(s)
end):param "Uint":optional():make "]"

builder:setHandler(function (ch)
  CmdAssert(not ch.hasloop, "Duplicate channel loop point")
  CmdAssert(ch:getID() ~= 0, "Cannot put loop controls here")
  ch:flushNote(true)
  ch:getStream():addLabel "LOOP"
  ch.hasloop = true
end):make "/"



local volEnvLexer = function (sv)
  if sv:trim "|" then
    local decay = nil
    if sv:trim "%-" then
      decay = tonumber(sv:trim "%d+")
      ParamAssert(decay and decay <= 0x7F, "Invalid volume decay")
    end
    return {loop = true, decay = decay}
  end
  if sv:trim "/" then return {release = true} end
  if sv:trim "W" then
    sv:ws()
    local duty = tonumber(sv:trim "%d+")
    ParamAssert(duty and duty <= 3, "Invalid duty setting")
    return {duty = duty}
  end
  local vol = tonumber(sv:trim "%d+")
  ParamAssert(vol and vol <= 15, "Invalid volume setting")
  return {vol = vol}
end

builder:setSongHandler(function (song, id, ...)
  local t1, t2 = {}, {}
  local duty = 0x30 -- nil
  local rel, loop1, loop2 = 0
  for _, v in ipairs {...} do
    if v.duty then
      duty = v.duty * 0x40 + 0x30
    elseif v.release then
      CmdAssert(rel == 0, "Multiple envelope release points")
      rel = #t1 + 3
    elseif v.loop then
      if rel > 0 then
        CmdAssert(not loop2, "Multiple envelope loop points")
        loop2 = v.decay and 0x80 + v.decay or #t2 + rel
      else
        CmdAssert(not loop1, "Multiple envelope loop points")
        loop1 = v.decay and 0x80 + v.decay or #t1 + 1
      end
    else
      insert(rel > 0 and t2 or t1, string.char(duty + v.vol))
    end
  end
  CmdAssert((rel > 0 and rel + #t2 + 2 or #t1 + 3) <= 256, "Envelope too long")
  loop1 = loop1 or #t1
  loop2 = loop2 or rel + #t2 - 1
  local env = Music.Stream(rel, concat(t1), 0x00, loop1)
  if rel > 0 then
    for _, v in ipairs {concat(t2), 0x00, loop2} do
      env:push(v)
    end
  end
  if song.volume[id] then
    Warn("Redefinition of volume envelope " .. id)
  end
  song.volume[id] = env
end):param "Ident":param(volEnvLexer):variadic():make "@@V"



local pitchEnvLexer = function (sv)
  if sv:trim "|" then return {loop = true} end
  local offs = tonumber(sv:trim "%-?%d+")
  ParamAssert(offs and offs >= -127 and offs <= 127, "Invalid envelope value")
  return {val = string.char((offs < 0 and 0x80 or 0) + math.abs(offs))}
end

builder:setSongHandler(function (song, id, ...)
  local t = {}
  local looppoint
  for _, v in ipairs {...} do
    if v.loop then
      CmdAssert(not looppoint, "Multiple envelope loop points")
      looppoint = #t
    else
      insert(t, v.val)
    end
  end
  looppoint = looppoint or #t - 1
  CmdAssert(looppoint < #t, "Invalid envelope loop point")
  if song.pitch[id] then
    Warn("Redefinition of pitch envelope " .. id)
  end
  song.pitch[id] = Music.Stream(concat(t), 0x80, looppoint)
end):param "Ident":param(pitchEnvLexer):variadic():make "@@P"



engine:setupEngine(function (self, rom)
  local link = Music.Linker()
  self.link = link

  rom:seek("set", 0x08)
  local delta = rom:read(2):readint(1, 2) - 0x80 -- NSF
  link:setDelta(delta)
  link:writable(0x887F - delta, 0xBFFF - delta)

  self.base = 0xBEFB
  self.volenvs = {}
  self.pitchenvs = {}
end)

engine:setInserter(function (self, rom, song, track)
  local header = Music.Stream()
  for i = 1, CHANNELS - 1 do
    header:push(i - 1)
    header:push(i - 1)
    header:push(Pointer(song:getChannel(i):getStream(), "START"))
  end
  header:push(0x08)
  header:push(Pointer(song:getChannel(CHANNELS):getStream(), "START"))
  header:push(0xFF)

  local link = self.link
  link:seekDelta(rom, self.base + (track - 1) * 2)
  link:setPos(link:seekDelta(rom, rom:read(2):readint(1, 2)))
  link:addStream(header)
  song:doAll(function (ch)
    link:addStream(ch:getStream())
  end)
  for _, ch in song:pseudoChannels() do
    link:addStream(ch:getStream())
  end

  for k, s in pairs(song.volume) do
    if not self.volenvs[k] then
      link:addStream(s)
      self.volenvs[k] = true
    end
  end
  for k, s in pairs(song.pitch) do
    if not self.pitchenvs[k] then
      link:addStream(s)
      self.pitchenvs[k] = true
    end
  end
end)

engine:finishEngine(function (self, rom)
  self.link:flush(rom)
end)



return engine
