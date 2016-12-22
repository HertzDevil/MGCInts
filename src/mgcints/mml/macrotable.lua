-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- An MML macro table which converts text macros to command tables.
-- @classmod MML.MacroTable
-- @alias cls
local cls = {}

local insert = table.insert

local Trie = require "mgcints.util.trie"

--- Macro table initializer.
function cls:__init ()
  self.commands = Trie()
end

--- Adds a command to the table.
--
-- Commands of the same name are scanned in the order they were added.
-- @tparam string name The MML command name.
-- @tparam MML.Command cmd The command object.
function cls:addCommand (name, cmd)
  if not self.commands:get(name) then
    self.commands:add(name, {})
  end
  insert(self.commands:get(name), cmd)
end

--- Renames an MML command.
-- @tparam string old The old command name.
-- @tparam string new The new command name.
function cls:renameCommand (old, new)
  self.commands:add(new, self.commands:remove(old))
end

--- Obtains a command definition.
-- @tparam string name The MML command name.
-- @tparam[opt=1] int pos The command position.
-- @treturn ?class The requested @{MML.Command} class if it exists.
function cls:getCommand (name, pos)
  local t = self.commands:get(name)
  return t and t[pos or 1] or nil
end

--- Reads the next command from an MML string.
-- @tparam util.StringView sv String view object containing the input MML. It is
-- modified if there is a successful match.
-- @treturn ?table A sequence containing all @{MML.Command} candidates in the
-- order they were added, corresponding to the command string matched at the
-- beginning of the string. If no such command exists, returns `nil`.
function cls:readNext (sv)
  local k, ft = self.commands:lookup(sv)
  if not k then return nil end
  sv:advance(#k)
  return ft
end

return require "mgcints.util.class" (cls)
