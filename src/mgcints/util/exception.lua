-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- An exception object that can be thrown and handled in function calls.
-- @classmod util.Exception
-- @alias cls
local cls = {}

local Class = require "mgcints.util.class"

local select = select
local tostring = tostring
local error = error
local pcall = pcall
local assert = assert
local insert = table.insert
local car_cdr = require "mgcints.util.misc".car_cdr

--- Exception initializer.
-- @param what A string or an object convertible to a string that describes the
-- exception.
function cls:__init (...)
  self.what = "User exception"
  if select("#", ...) > 0 then
    self.what = self.what .. ": " .. tostring(...)
  end
end

--- Returns a string description of the exception object.
function cls:__tostring ()
  return self.what
end

--- Throws the exception.
-- This function never returns.
-- @raise Self.
function cls:throw ()
  error(self, 2)
end

--- Asserts that an expression evaluates to true.
-- @static
-- @tparam class cself Class object.
-- @param v Expression.
-- @tparam[opt] string msg The error message, which defualts to "assertion
-- failed!".
-- @return If `v` does not evaluate to `false`, returns `v`.
-- @raise Otherwise, creates a new exception using `msg` as the sole constructor
-- argument, and throws it.
function cls.assert (cself, v, msg)
  if v then return v end
  cself(msg or "assertion failed!"):throw()
end

--- Creates a try-except block.
-- @static
-- @tparam func body The code body.
-- @tparam ?class excls The exception type, or any exception if this is `nil`,
-- including Lua errors.
-- @tparam func msgh The exception handler function which will be called if
-- `body` throws an exception of type `excls`.
-- @param ... More pairs of exception classes and handlers.
-- @treturn func A function with the exception handlers attached in the order
-- they are given, accepting the same function arguments as `body`. Its
-- behaviour is as follows:<ul>
-- <li>If `body` does not throw, it simply returns the same values as `body`
--  would;</li>
-- <li>If `body` throws a Lua error, it re-throws this error;</li>
-- <li>If `body` throws a @{util.Exception} object, and its type matches one of
--  the given exception classes, it returns the same values as the corresponding
--  handler function;</li>
-- <li>Otherwise, it re-throws the exception.</li>
-- </ul>
function cls.try (body, ...)
  local excls, msgh = {}, {}
  local count = 0
  for i = 1, select("#", ...) - 1, 2 do
    local ex = select(i, ...)
    assert(ex == nil or Class.subclassof(ex, cls.__class),
      "Invalid exception type")
    count = count + 1
    excls[count] = ex
    msgh[count] = select(i + 1, ...)
  end
  return function (...)
    local suc, results = car_cdr(pcall(body, ...))
    if suc then return results() end
    results = results() -- the error object
    for i = 1, count do
      if excls[i] == nil or Class.instanceof(results, excls[i]) then
        return msgh[i](results)
      end
    end
    error(results, 3)
  end
end

do
  local cache = setmetatable({}, {__mode = "v"})
--- Obtains a unique exception type for an error string.
-- @static
-- @tparam string str Error type string. Identical strings return identical
-- classes.
-- @tparam[opt] string base Error type string for the base type. If this is
-- given, and `cls.typed(str)` has not been created, then `cls.typed(str)`
-- becomes a subclass of `cls.typed(base)` instead of the exception base class.
-- @treturn class A subclass of @{util.Exception} which accepts one more
-- description string to form the error message.
function cls.typed (str, base)
  if not cache[str] then
    cache[str] = Class({__init = function (self, msg)
      self.what = str .. ": " .. msg
    end}, base and cls.typed(base) or cls.__class)
  end
  return cache[str]
end; end

--- Obtains a typed assertion function.
-- @static
-- @tparam string str Error type string.
-- @treturn func A @{util.Exception.assert} class method as a free function.
function cls.TypedAssert (str)
  return Class.method(cls.typed(str), "assert")
end

return Class(cls)
