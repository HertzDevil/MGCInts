-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A higher-level wrapper class for @{util.StreamDec}.
-- @classmod util.StreamDumper
-- @alias cls
local cls = {}

local require = require
local tostring = tostring
local type = type
local assert = assert
local ipairs = ipairs
local pairs = pairs
local floor = math.floor
local insert = table.insert
local remove = table.remove
local concat = table.concat
local sort = table.sort
local unpack = table.unpack or unpack

local StreamDec = require "mgcints.util.streamdec"

--- Parameter functions accepted by @{util.StreamDumper:add}.
-- @table ARGFUNC
-- @field uint8 Unsigned 8-bit integer.
-- @field int8 Signed 8-bit integer.
-- @field uint16 Little-endian Unsigned 16-bit integer.
-- @field int16 Little-endian Signed 16-bit integer.
-- @field uint16be Big-endian unsigned 16-bit integer.
-- @field int16be Big-endian signed 16-bit integer.
local ARGFUNC = {
  uint8 = function (x)
    return tostring(x)
  end,
  int8 = function (x)
    return tostring(x >= 0x80 and x - 0x100 or x)
  end,
  uint16 = function (x, y)
    return tostring(x + y * 0x100)
  end,
  int16 = function (x, y)
    local z = x + y * 0x100
    return tostring(z >= 0x8000 and z - 0x10000 or z)
  end,
  uint16be = function (y, x)
    return tostring(x + y * 0x100)
  end,
  int16be = function (y, x)
    local z = x + y * 0x100
    return tostring(z >= 0x8000 and z - 0x10000 or z)
  end,
}
cls.ARGFUNC = ARGFUNC

local BYTECOUNT = {
  uint8 = 1, int8 = 1,
  uint16 = 2, int16 = 2, uint16be = 2, int16be = 2
}

--- Dumper initializer.
function cls:__init ()
  self.dec = StreamDec()
  self.lastcmdname = nil
  self.lastfinal = false
  self.namecmd = {}
  self.argparse = {}
  self.argcount = {}
  self.limit = 16
end

--- Gives the next command an output name.
--
-- Otherwise, when @{add} is called, a suitable default string will be used.
-- @tparam string str Command name.
-- @treturn util.StreamDumper Self.
function cls:name (str)
  self.lastcmdname = str
  return self
end

--- Makes the next command a stream terminator.
-- @treturn util.StreamDumper Self.
function cls:final ()
  self.lastfinal = true
  return self
end

--- Adds a command.
-- @tparam string|int cmd The command name in the data stream. If a number is
-- given, it is converted into a single-character string representing the byte
-- value.
-- @tparam string|func ... Functions used to convert binary byte values into
-- strings. Each function returns a string representing the next MML parameter
-- and must be followed by the number of bytes required. If the argument is a
-- string, the function is looked up in @{ARGFUNC} and no byte count is
-- required.
-- @treturn The command table.
function cls:add (cmd, ...)
  if type(cmd) == "number" then cmd = string.char(cmd) end
  assert(not self.argparse[cmd], "Duplicate command")

  local t = {}
  local kind = {...}
  self.argparse[cmd] = {}
  self.argcount[cmd] = {}
  local i, n = 1, #kind
  local tot = 0
  while i <= n do
    local v = kind[i]
    if type(v) == "string" then
      insert(self.argparse[cmd], ARGFUNC[v])
      insert(self.argcount[cmd], BYTECOUNT[v])
      tot = tot + BYTECOUNT[v]
    else
      insert(self.argparse[cmd], v)
      i = i + 1
      insert(self.argcount[cmd], kind[i])
      tot = tot + kind[i]
    end
    i = i + 1
  end

  if not self.lastcmdname then
    self.lastcmdname = "`0h"
    for _, v in ipairs {cmd:byte(1, -1)} do
      self.lastcmdname = self.lastcmdname .. ("%02X"):format(v)
    end
    if n > 0 then
      self.lastcmdname = self.lastcmdname .. ","
    end
  end
  self.namecmd[self.lastcmdname] = cmd
  local c = self.dec:addCommand(cmd, self.lastcmdname, tot, self.lastfinal)
  self.lastcmdname = nil
  self.lastfinal = false
  return c
end

--- Sets the width of the output MML. The default value is 16.
-- @tparam int width The number of bytes each dumped row of MML should contain
-- on average.
function cls:setWidth (width)
  self.limit = width
end

--- Dumps an MML string from a binary string.
-- @tparam string str Input stream.
-- @tparam[opt=1] int init Beginning substring index.
-- @tparam[opt=""] string header The MML stream header.
-- @treturn string An MML string.
function cls:dump (str, init, header)
  local out = {}
  local line = (header or "") .. "\t"
  local l = 0
  for name, params in self.dec:readStream(str, init) do
    local l2 = l + #self.namecmd[name] + #params
    for i = 1, floor(l2 / self.limit) - floor(l / self.limit) do
      insert(out, line)
      line = "\t"
    end
    local argstr = {}
    local cmd = self.namecmd[name]
    for i, f in ipairs(self.argparse[cmd]) do
      local p = {}
      for _ = 1, self.argcount[cmd][i] do
        insert(p, remove(params, 1))
      end
      insert(argstr, f(unpack(p)))
    end
    line = line .. name .. concat(argstr, ",") .. ' '
    l = l2
  end
  insert(out, line)
  local rng = ("; Stream address: $%X - $%X (%d bytes)\n"):format(
    init - 1, init + l - 2, l)
  if not self.dec:success() then
    rng = rng .. "; (Incomplete stream)\n"
  end
  return rng .. concat(out, '\n') .. "\n\n"
end

do
  local ARGFUNC_REV = {
    [ARGFUNC.uint8] = ' "Uint8"',
    [ARGFUNC.uint16] = ' "Uint16"',
    [ARGFUNC.uint16be] = ' "Uint16BE"',
    [ARGFUNC.int8] = ' "Int8"',
    [ARGFUNC.int16] = ' "Int16"',
    [ARGFUNC.int16be] = ' "Int16BE"',
  }
  local CHUNK = {
    [ARGFUNC.uint8] = '#',
    [ARGFUNC.uint16] = '# % 0x100, math.floor(# / 0x100)',
    [ARGFUNC.uint16be] = 'math.floor(# / 0x100), # % 0x100',
    [ARGFUNC.int8] = '#',
    [ARGFUNC.int16] = '# % 0x100, math.floor(# / 0x100)',
    [ARGFUNC.int16be] = 'math.floor(# / 0x100), # % 0x100',
  }
  local fmt = [[
builder:setHandler(function (%s)
  ch:addChunk(%s)
end)%s:make "%s"]]
  local header = [[
local Default = require "mgcints.default"
local MML = require "mgcints.mml"

local CHANNELS = 1
local builder = MML.CmdBuilder()
local engine = Default.Engine(CHANNELS)



local Channel = engine:getChannelClass()

Channel:beforeCallback(function (self)
end)

Channel:afterCallback(function (self)
end)



local Song = engine:getSongClass()



builder:setTable(engine:getCommandTable())


]]
  local footer = [[



builder:setTable(engine:getDirectiveTable())



engine:setupEngine(function (self, rom)
  local link = Music.Linker()
  self.link = link
end)

engine:setInserter(function (self, rom, song, track)
  local link = self.link
end)

engine:finishEngine(function (self, rom)
  self.link:flush(rom)
end)



return engine
]]
--- Obtains a grammar definition which can read the MML data it dumps.
--
-- This method only recognizes parameter functions in @{ARGFUNC}. Custom
-- parameters correspond to the empty function.
-- @treturn string Lua code representing the MML grammar.
function cls:makeGrammar ()
  local t = {}
  for name, cmd in pairs(self.namecmd) do
    insert(t, {name, self.argparse[cmd], cmd})
  end
  sort(t, function (x, y) return x[1] < y[1] end)

  local out = {header}
  for _, v in ipairs(t) do
    local as, fs, ps = {"ch"}, {("0x%02X"):format(v[3]:byte())}, {}
    local i = 1
    for k, f in ipairs(v[2]) do
      local tok = ("x%d"):format(i)
      insert(as, tok)
      if CHUNK[f] then
        insert(fs, (CHUNK[f]:gsub("#", tok)))
      end
      insert(ps, ":param" .. (ARGFUNC_REV[f] or "(function () end)"))
      i = i + 1
    end

    insert(out, fmt:format(
      concat(as, ", "), concat(fs, ", "), concat(ps), v[1]))
  end

  insert(out, footer)
  return concat(out, '\n')
end; end

--- Returns whether the last dumped stream successfully terminated.
function cls:success ()
  return self.dec:success()
end

return require "mgcints.util.class" (cls)
