-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A compile-time channel state object.
-- @classmod Music.State
-- @alias cls
local cls = {}

--- State initializer.
-- @param x Default value.
function cls:__init (x)
  self.default = x
  self:reset()
end

--- Resets the state.
function cls:reset ()
  self.value = self.default
  self.last = nil
end

--- Returns the current state value.
function cls:get ()
  return self.value
end

--- Queries the state.
-- @return The current state value.
-- @return The result of the previous call to this function.
function cls:query ()
  local x = self.last
  self.last = self.value
  return self.value, x
end

--- Updates the state value.
-- @param x New value.
function cls:set (x)
  self.value = x
end

return require "mgcints.util.class" (cls)
