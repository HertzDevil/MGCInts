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
-- @tparam string name The MML command name.
-- @tparam MML.Command cmd The command object.
function cls:addCommand (name, cmd)
  if not self.commands:get(name) then
    self.commands:add(name, {})
  end
  insert(self.commands:get(name), cmd)
end

--- Reads the next command from an MML string.
-- @tparam util.StringView sv String view object containing the input MML.
-- @treturn table A sequence containing all @{MML.Command} objects in the order
-- they were added.
function cls:readNext (sv)
  local k, ft = self.commands:lookup(sv)
  if not k then return nil end
  sv:advance(#k)
  return ft
end

return require "mgcints.util.class" (cls)
