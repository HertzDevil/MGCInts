-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Lightweight class builder.
-- The exported module has a metatable that allows the table itself to be called
-- like @{util.Class.make}.
-- @module util.Class
-- @alias class
local class = {}

local rawget = rawget
local rawset = rawset
local setmetatable = debug.setmetatable
local next = next
local error = error
local type = type
local rawequal = rawequal
local assert = assert

local metaSet = {
  __add    = true, __sub   = true, __mul  = true, __div  = true,
  __pow    = true, __mod   = true, __idiv = true, __unm  = true,
  __bnot   = true, __band  = true, __bor  = true, __bxor = true,
  __shl    = true, __shr   = true,
  __concat = true, __len   = true,
  __eq     = true, __le    = true, __lt   = true, --__newindex = true,
  __gc     = true, __pairs = true, __tostring = true, --__mode = true,
}

local construct = function (self, ...)
  local z = {__class = self, __super = rawget(self, "__base")}
  setmetatable(z, rawget(self, "__mt"))
  return z, assert(z.__init)(z, ...) -- __init is not a true metamethod
end

---The class builder function.
-- 
-- All classes have the following properties:
-- 
-- - The `__mt` field contains the generated metatable used by all instances of
-- this class.
-- - The `__new` field contains the constructor function. This is a static
-- method that does not use an object as the first argument.
-- - The class object itself can be called as the constructor function.
-- - All instance methods will be available as class functions (similar to Lua's
-- @{string} table).
-- - The `methods` table will be given a metatable so that this table can also
-- be used as a constructor function. This allows methods to refer back to the
-- _static_ constructor easily.
-- - The `methods` table will contain a `__class` field which points back to the
-- generated class. It will also become a fully weak table.
-- - The `__init` initializer method will be generated if the class cannot find
-- one.
-- - If `base` is given, the `__base` field will contain this base class.
-- - If `__classinit` is found, then it will be called using the class object as
-- the only argument before returning. The initializer of the superclass may be
-- manually called using `self.__base.__classinit(self)`.
-- 
-- All instances of classes have the following properties:
-- 
-- - All instance methods declared in this class or any of its superclasses will
-- be available.
-- - During the creation of an instance, the `__init` _instance_ method will be
-- called with the instance as the first argument, followed by all arguments
-- passed to the constructor function. All return values of this function will
-- follow the instance after a call to any constructor.
-- - The `__class` field contains the class object from which it is created. The
-- expression `self.__class(...)` represents a _dynamic_ constructor.
-- - If `base` is given, the `__super` field will contain this base class. In
-- particular, the initializer of an instance's superclass may be referred to as
-- `self.__super.__init(self, ...)`.
-- 
-- @tparam table methods A table containing instance methods. It may contain
-- both named methods and metamethods; this function reassigns metamethods to
-- the instance metatable appropriately. Its metatable will be overwritten after
-- a call to this function.
-- @tparam[opt] table base The base class object, or @{util.Class.Universal} if
-- not given.
-- @return A class object. This object itself is not an instance of any other
-- class.
class.make = function (methods, base)
  local cls = {__mt = {__index = {}}}
  
  for k, v in next, methods do
    if metaSet[k] then
      cls.__mt[k] = v
    else
      cls.__mt.__index[k] = v
    end
  end
  
  base = base or class.Universal
  if base then
    cls.__base = base
    local bmt = rawget(base, "__mt")
    setmetatable(cls.__mt.__index, {__index = rawget(bmt, "__index")})
    for k in next, metaSet do if not cls.__mt[k] then
      local f = rawget(bmt, k)
      if f then cls.__mt[k] = f end
    end end
  end
  
  if not cls.__mt.__index.__init then -- this may find the base initializer
    cls.__mt.__index.__init = function () end
  end
  cls.__new = function (...) return construct(cls, ...) end
  rawset(methods, "__class", cls)
  setmetatable(methods, {
    __call = function (_, ...) return construct(cls, ...) end,
    __index = cls.__mt.__index,
    __mode = "kv",
  })

  --- @todo add a __copy static method
  
  setmetatable(cls, {__call = construct, __index = cls.__mt.__index})
  if cls.__classinit then
    cls.__classinit(cls)
  end
  return cls
end

--- Placeholder function to indicate that a method should be implemented in a
-- derived class.
--
-- This function does not return.
-- @raise "Abstract method".
class.abstract = function () error("Abstract method", 2) end

--- Returns whether a class is derived from another.
-- @param d Derived class.
-- @param b Base class.
-- @treturn[1] bool True if `d` is a subclass of `b`.
class.subclassof = function (d, b)
  while d ~= nil do
    if rawequal(d, b) then return true end
    d = rawget(d, "__base")
  end
  return false
end

--- Returns whether an instance belongs to a class or its derived classes.
--
-- To check that an instance is created from a certain class, simply check
-- whether the instance's `__class` field is equal to the class object.
-- @param d Instance object.
-- @param b Class.
-- @treturn[1] bool True if `d` is created from `b` or any of its derived
-- classes.
-- @treturn[2] bool If `d` is not a table, returns whether its @{type} is equal
-- to `b`.
class.instanceof = function (d, b)
  if type(d) ~= "table" then
    return type(d) == b
  end
  return class.subclassof(rawget(d, "__class"), b)
end

--- Obtains a free function for calling methods on instances.
-- @static
-- @tparam string name The method name.
-- @treturn func A function which calls method `name` of its first argument with
-- the rest of the arguments as method parameters.
class.call = function (name)
  return function (t, ...) return t[name](t, ...) end
end

--- Obtains a free function equivalent of an instance method.
-- @static
-- @param t Instance object.
-- @tparam string name The method name.
-- @treturn func A function which calls method `name` of `t` with all arguments 
-- as method parameters.
class.method = function (t, name)
  return function (...) return t[name](t, ...) end
end

--- The common base class of all instances.
-- It has the following methods: @{instanceof}, @{method}.
-- @field Universal
class.Universal = class.make {
  instanceof = class.instanceof,
  method = class.method,
}

setmetatable(class, {
  __call = function (_, ...) return class.make(...) end,
})
return class
