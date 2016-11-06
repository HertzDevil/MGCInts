-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Warning strings that may be displayed for a maximum number of times or
-- turned into exceptions.
-- @module util.Warning
-- @alias cls
local cls = {}

local Exception = require "mgcints.util.exception"

local warningCount = {}
local maxCount = 1
local asExceptions = false

--- Emits a warning.
-- Every distinct format string counts as a unique warning.
-- @tparam string fmt Format string.
-- @param ... Parameters for the format string.
-- @raise The warning string wrapped into an @{util.Exception} object, if
-- @{util.Warning.strict|strict mode} is enabled.
function cls.warn (fmt, ...)
  if asExceptions then
    Exception(fmt:format(...)):throw()
  end
  if not warningCount[fmt] then warningCount[fmt] = 0 end
  if warningCount[fmt] >= maxCount then return end
  warningCount[fmt] = warningCount[fmt] + 1
  if warningCount[fmt] >= maxCount then
    warningCount[fmt] = 1 / 0 -- infinity, prevents further display
  end
  cls.alert(fmt:format(...))
end

--- Sets the number of times a warning may be displayed.
-- At any time, if a warning reaches this count after being displayed, it will
-- stop being displayed even after assigning a new value to this count. Warnings
-- always throw exceptions if @{util.Warning.strict|strict mode} is enabled,
-- regardless of this count.
-- @tparam int x The maximum count.
function cls.setCount (x)
  maxCount = x
end

--- Re-enables all warnings.
function cls.reset ()
  warningCount = {}
end

--- Enables or disables strict mode, which turns warnings into exceptions.
-- @tparam bool enable Whether warnings are thrown as @{util.Exception} objects.
function cls.strict (enable)
  asExceptions = not not enable
end

--- Displays a warning.
-- By default, the warning is written to the standard error stream with the
-- "Warning: " heading. This function may be modified to change how warnings
-- are displayed.
-- @tparam string str The warning string.
function cls.alert (str)
  io.stderr:write("Warning: ", str, "\n")
end

return cls
