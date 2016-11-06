-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A simple MML stream decompiler for preliminary command discovery.
-- @classmod util.StreamDec
-- @alias cls
local cls = {}

local require = require
local type = type

local Trie = require "mgcints.util.trie"
local Sv = require "mgcints.util.stringview"
local assert = require "mgcints.default.errors".RuntimeCheck

--- Decompiler initializer.
function cls:__init ()
  self.cmdtable = Trie()
  self.suc = false
end

--- Adds a command.
-- @tparam string|int cmd The command name in the data stream. If a number is
-- given, it is converted into a single-character string representing the byte
-- value.
-- @tparam string name The command name used for output.
-- @tparam[opt=0] int argcount The number of bytes the command uses.
-- @tparam[opt=false] bool term Whether this command indicates the end of a data
-- stream.
-- @treturn table A dumper command object containing the following fields:<ul>
-- <li> `name`: Same as the given parameter, possibly converted to a string;
-- </li>
-- <li> `argcount`: Same as the given parameter;</li>
-- <li> `term`: Same as the given parameter, converted to a bool;</li>
-- <li> `callback`: `nil`; if this is added to the returned table then, right
-- before returning each command, the iterator returned from
-- @{util.StreamDec:readStream} calls this function with the decompiler, the
-- current @{util.StringView|string view] object, then the parameter table as
-- arguments, right before returning each command.</li>
-- </ul>
function cls:addCommand (cmd, name, argcount, term)
  if type(cmd) == "number" then
    cmd = string.char(cmd)
  end
  assert(not self.cmdtable:get(cmd), "Duplicate command")
  local t = {name = name, argcount = argcount or 0, term = not not term}
  self.cmdtable:add(cmd, t)
  return t
end

--- Iterates through all commands of a data stream until a terminating command
-- is found.
-- @tparam string str Input stream.
-- @tparam[opt=1] int init Beginning substring index.
-- @treturn An iterator function which, when called, returns the next command's
-- output name, and a table containing the command's parameters as byte values.
function cls:readStream (str, init)
  local sv = Sv(str)
  if init then sv:advance(init - 1) end
  self.suc = false
  local it = function ()
    if self.suc or sv:len() <= 0 then return nil end
    local k, cmd = self.cmdtable:lookup(sv)
    if not k then return nil end
    sv:advance(#k)
    
    if sv:seek() + cmd.argcount > #sv:getfull() + 1 then return nil end
    if cmd.term then self.suc = true end
    local params = {sv:byte(1, cmd.argcount)}
    sv:advance(cmd.argcount)
    if cmd.callback then
      cmd.callback(self, sv, params)
    end
    return cmd.name, params
  end
  return it
end

--- Returns whether the last dumped stream successfully terminated.
function cls:success ()
  return self.suc
end

return require "mgcints.util.class" (cls)
