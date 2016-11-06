-- MGCInts library
-- this imports most modules except those in util
local MGCInts = require "mgcints"

-- create a default engine with 4 channels
local engine = MGCInts.Default.Engine(4, "test driver")
local macros = engine:getCommandTable()
local builder = MGCInts.MML.CmdBuilder()

-- this one-liner gives everything we need
engine:importFeature(require "mgcints.mml.feature.mute")()

-- build some dummy commands
for k, v in pairs {c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11} do
  local cmd = builder:setHandler(function (ch)
    if not ch:isMuted() then -- this method is provided by the feature
      ch:addChunk(("  Note: %d (%s)\n"):format(60 + v, k:upper()))
    end
  end):make()
  macros:addCommand(k, cmd)
  macros:addCommand(k:upper(), cmd)
end

-- volume command
builder:setTable(macros)
builder:setHandler(function (ch, v)
  ch:addChunk(("  Volume: %d\n"):format(v))
end):param "Uint8":optional "100":make "v"

-- channel header / footer
engine:getChannelClass():beforeCallback(function (self)
  self:addChunk("Channel " .. self:getID() .. ": \n")
end)
engine:getChannelClass():afterCallback(function (self)
  self:addChunk "End of data\n\n"
end)

-- test inserter, we will use standard output
engine:setInserter(function (rom, song, track)
  rom:write("MGCInts test\nTrack: " .. track .. "\n\n")
  song:doAll(function (ch)
    rom:write(ch:getStream():build())
  end)
end)

-- compile an MML string
-- m1 mutes, m0 unmutes
-- volume commands apply even when muted (in some engines like amk, volume
-- slides convert to single volume commands while the channel is muted)
local mmlstr = [[
!13 v 72
!2  m1 v108
!4  v
!1 cd !23 eF m0
!1234 gAb m1
!4 cde
]]
MGCInts.Music.Compiler.processFile(engine, mmlstr, io.stdout, 1)
