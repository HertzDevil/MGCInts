-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- An abstract MML command which consumes MML parameters and acts on song
-- objects.
-- @classmod MML.Command
-- @alias cls
local cls = {}

--- Consumes parameters from an input string.
--
-- This is a low-level method which is rarely overridden directly. Some
-- examples are the comment commands defined in @{Default.Macros}.
-- @tparam util.StringView sv String view object.
-- @return The parameters for this command.
function cls:getParams (sv)
  return nil
end

--- Applies the command to a channel.
-- @tparam Music.Channel ch The active channel object.
-- @param ... The parameters it receives from the MML string.
function cls:applyChannel (ch, ...)
end

--- Applies the command to a song.
-- @tparam Music.Song song The song object.
-- @param ... The parameters it receives from the MML string.
function cls:applySong (song, ...)
end

--- Hook function to apply the command to a song and its channels. Do not
-- override this method.
-- @tparam Music.Song song The song object.
-- @param ... The parameters it receives from the MML string.
function cls:apply (song, ...)
  -- apply command to song first
  self:applySong(song, ...)

  -- apply command to all active channels next
  song:doActive(function (ch, ...)
    self:applyChannel(song:current(ch:getID()), ...)
  end, ...)
end

return require "mgcints.util.class" (cls)
