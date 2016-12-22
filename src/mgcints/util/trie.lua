-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A trie that matches against both @{util.StringView} objects and raw strings.
-- @classmod util.Trie
-- @alias cls
local cls = {}

local rawget = rawget
local rawset = rawset
local rawequal = rawequal
local type = type
local select = select
local tostring = tostring
local setmetatable = setmetatable
local next = next

--- Trie initializer.
function cls:__init ()
  self.data = {}
end

--- Adds an item to the trie.
-- @tparam string str String key.
-- @param[opt=true] k The corresponding value, must not be `nil` if provided.
-- @treturn bool True if insertion succeeded, false otherwise.
function cls:add (...)
  local str, k = ...
  if type(str) ~= "string" then return false end
  if select("#", ...) == 1 then k = true end
  if k == nil then return false end
  self = self.data
  for ch in str:gmatch "." do
    if self[ch] == nil then self[ch] = {} end
    self = self[ch]
  end
  self[true] = k
  return true
end

--- Removes an item from the trie.
-- @tparam string str String key.
-- @return The removed value, or `nil` if no such key exists.
function cls:remove (str)
  self = self.data
  local cache_k = {}
  local cache_t = {[0] = self}
  for ch in str:gmatch "." do
    self = self[ch]
    if self == nil then return nil end
    cache_k[#cache_k + 1] = ch
    cache_t[#cache_t + 1] = self
  end
  local item = self[true]
  if item == nil then return nil end
  self[true] = nil
  for i = #cache_t, 1, -1 do
    if next(cache_t[i]) ~= nil then break end
    cache_t[i - 1][cache_k[i]] = nil
  end
  return item
end

--- Looks up a value in the trie.
-- @tparam string str String key.
-- @return The value associated to key `str`, or `nil` if no such key exists.
function cls:get (str)
  self = self.data
  for ch in str:gmatch "." do
    self = self[ch]
    if self == nil then return nil end
  end
  return self[true]
end

--- Finds the longest matching key-value pair against the beginning of a string.
-- @tparam util.StringView|string str A string view object or a raw string.
-- @tparam[opt=1] int init Beginning substring index.
-- @treturn[1] string The matched string key.
-- @return[1] The value associated with the matched string.
-- @return[2] Nothing if none of the keys in the trie matched successfully.
function cls:lookup (str, init)
  init = init or 1
  local x = init - 1
  local longest, val
  self = self.data

  repeat
    if self[true] ~= nil then
      longest, val = str:sub(init, x), self[true]
    end
    x = x + 1
    local ch = str:sub(x, x)
    self = self[ch]
  until self == nil;

  if longest ~= nil then return longest, val end
end

do
  local function f (t, prefix)
    for k, v in next, t do
      if k == true then coroutine.yield(prefix, v)
      else f(v, prefix .. k) end
    end
  end
--- Used in a for loop to iterate through all key-value pairs of the trie, in an
-- indeterminate order.
function cls:__pairs ()
  return coroutine.wrap(f), self.data, ""
end; end

return require "mgcints.util.class" (cls)
