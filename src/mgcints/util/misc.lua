-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Miscellaneous utility functions.
-- @module util.Misc

local setmetatable = setmetatable
local select = select
local load = loadstring or load
local pairs = pairs

local arglist; do
  local cache = {}
arglist = function (n)
  if not cache[n] then
    local t = {}
    for i = 1, n do t[i] = "x" .. i end
    cache[n] = table.concat(t, ",")
  end
  return cache[n]
end; end

--- Partially applies any number of arguments to a function.
-- @tparam func f Function.
-- @param ... Extra arguments, at least one value must be provided.
-- @treturn func A function that returns the same results as applying `\...`
-- and then its arguments to `f`.
-- @usage
-- local disp = papply(table.concat, {1, 2, 3})
-- print(disp())   -- table.concat({1, 2, 3})      == "123"
-- print(disp "-") -- table.concat({1, 2, 3}, "-") == "1-2-3"
-- @function papply
local papply; do
  local cache = setmetatable({}, {__mode = "v"})
  local body = [[
return function (f, %s) return function (...) return f(%s, ...) end end]]
papply = function (f, ...)
  local n = select("#", ...)
  if n == 0 then return function (...) return f(...) end end -- copy of f
--  if n == 0 then return f end
  if not cache[n] then
    cache[n] = load(body:format(arglist(n), arglist(n)), "", "t", {})()
  end
  return cache[n](f, ...)
end; end

--- Wraps arguments into a function.
--
-- This is preferred over @{table.pack} whenever some of the arguments might be
-- `nil`.
-- @param ... Arguments.
-- @return A function that receives no arguments and returns all the wrapped
-- arguments when called.
-- @usage
-- print(table.unpack {nil, 1, nil}     -- may be nothing
-- print(table.unpack {nil, 1, 2, nil}) -- may be nil, 1, 2
-- print(wrap(nil, 1, nil)())           -- always nil, 1, nil
-- print(wrap(nil, 1, 2, nil)())        -- always nil, 1, 2, nil
-- @function wrap
local wrap = function (...)
  local results = papply(select, 1, ...)
  return function () return results() end
end

--- Wraps arguments into a head and a tail function.
-- @param ... Arguments.
-- @return The first argument.
-- @return A function that receives no arguments and returns the rest of the
-- wrapped arguments when called.
-- @treturn int The number of arguments passed.
-- @usage
-- local suc, results = car_cdr(pcall(f)) -- f may return any number of results
-- if suc then print(results()) end       -- print exactly all the results
-- @function car_cdr
local car_cdr = function (...)
  return ..., wrap(select(2, ...)), select("#", ...)
end

--- Returns all results of applying a function to multiple arguments.
-- @tparam func f A callable object. It may return any number of values.
-- @param ... Input to the function. One argument is passed to the function each
-- time.
-- @return The results of calling `f` on the first argument, then the second
-- argument, and so on.
-- @usage
-- local function dec (x)
--   if x <= 0 then return end
--   return x, dec(x - 1)
-- end
-- print(map(dec, dec(4))) -- 4, 3, 2, 1, 3, 2, 1, 2, 1, 1
-- @function map
local map = function (f, ...)
  local results = papply(select, 1)
  for i = 1, select("#", ...) do
    results = papply(results, f((select(i, ...))))
  end
  return results()
end

--- Wraps an object in a weak reference.
--
-- Every call to this function creates a new table and closure. Use with
-- caution.
-- @param x Object.
-- @treturn func A function that accepts no arguments and, when called, returns
-- `x` if it is alive.
-- @usage
-- local t = weak({}); print(type(t())) -- "table"
-- collectgarbage();   print(type(t())) -- "nil"
-- @function weak
local weak; do
  local mt = {__mode = "v"}
weak = function (x)
  local t = setmetatable({x}, mt)
  return function ()
    return t[1]
  end
end; end

--[[
--- Copies key-value pairs to the current environment.
-- @tparam table t Source table containing the key-value pairs.
-- @usage export(table) -- insert, remove, concat, sort etc. are now global
-- @function export
local export = function (t)
  for k, v in pairs(t) do _ENV[k] = v end
end
]]

--- Turns a function into a currying expression.
-- @tparam func f Input function.
-- @treturn func A function which, when called with at least one argument,
-- returns another currying expression that partially applies these arguments.
-- If called with no arguments, it returns the resules of calling `f` with all
-- the captured arguments.
-- @usage local max_c = curry(math.max)
-- max_c = max_c(4)
-- print(max_c())            -- math.max(4) = 4
-- max_c = max_c(5, 3)
-- print(max_c())            -- math.max(4, 5, 3) = 5
-- max_c = max_c(6)
-- print(max_c())            -- math.max(4, 5, 3, 6) = 6
-- @function curry
local curry; do
  local function step (k, ...)
    if select("#", ...) == 0 then return k() end
    return papply(step, papply(k, ...))
  end
curry = function (f)
  return papply(step, f)
end; end

--- Joins multiple variadic expressions.
-- @param ... Arguments.
-- @return[1] A new currying expression that captures the passed arguments.
-- @return[2] If called with no arguments, returns all captured values.
-- @usage print(join(1, 2, 3)(4, 5)(6)()) -- 1, 2, 3, 4, 5, 6
-- @function join
local join = curry(papply(select, 1))

return {
  car_cdr = car_cdr,
  curry = curry,
--  export = export,
  join = join,
  map = map,
  papply = papply,
  weak = weak,
  wrap = wrap,
}
