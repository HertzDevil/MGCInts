-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A profiler with simple benchmarking functionality.
-- @classmod util.Profiler
-- @alias cls
local cls = {}

local require = require
local print = print
local pairs = pairs
local wrap = require "mgcints.util.misc".wrap
local insert = table.insert
local concat = table.concat
local sort = table.sort
local clock = os.clock

--- Profiler initializer.
function cls:__init ()
  self.regions = {}
  self.times = {}
  self.totals = {}
end

--- Profiler finalizer.
--
-- Also exits all active timers and prints the profiler results immediately.
function cls:__gc ()
  self:exitAll()
  print(self)
end

--- Starts or resumes timing for a particular timer.
-- @param name Timer identifier.
function cls:enter (name)
  if self.regions[name] then return end
  self.regions[name] = true
  self.times[name] = clock()
end

--- Finishes timing for a particular timer.
-- @param name Timer identifier.
function cls:exit (name)
  if not self.regions[name] then return end
  local dur = clock() - self.times[name]
  self.totals[name] = (self.totals[name] or 0) + dur
  self.regions[name] = false
end

--- Exits all existing timers.
function cls:exitAll ()
  for k in pairs(self.regions) do
    self:exit(k)
  end
end

--- Displays the current profiler results.
function cls:__tostring ()
  local l = {}
  for k, v in pairs(self.totals) do
    insert(l, {k, v})
  end
  sort(l, function (x, y)
    return x[2] < y[2] or x[2] == y[2] and x[1] < y[1]
  end)
  for k, v in pairs(l) do
    l[k] = ('"%s": %.3f s'):format(v[1], v[2])
  end
  return "Profiler output: \n" .. concat(l, '\n')
end

--- Automatically times all calls to a function.
-- @tparam func f Function.
-- @param name Timer identifier.
-- @treturn func A new function which enables timer `name` while executing
-- `func` and returns the same results.
function cls:wrap (f, name)
  return function (...)
    self:enter(name)
    local results = wrap(f(...))
    self:exit(name)
    return results()
  end
end

return require "mgcints.util.class" (cls)
