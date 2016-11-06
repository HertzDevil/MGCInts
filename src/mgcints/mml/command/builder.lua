-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A builder class that simplifies creation of commands with MML parameters.
-- @classmod MML.CmdBuilder
-- @alias cls
local cls = {}

local require = require
local type = type
local ipairs = ipairs
local insert = table.insert
local unpack = table.unpack or unpack

local ParamCmd = require "mgcints.mml.command.paramcmd"
local Func = require "mgcints.default.lexers"
local Sv = require "mgcints.util.stringview"
local Class = require "mgcints.util.class"
local join = require "mgcints.util.misc".join
local Ex = require "mgcints.util.exception"
local assert = require "mgcints.default.errors".RuntimeCheck
local ParamError = Ex.typed "ParamError"

--- Builder initializer.
-- @tparam[opt] MML.MacroTable target The table that accepts command
-- definitions.
function cls:__init (target)
  self.target = target
  if target ~= nil then
    assert(Class.instanceof(target, require "mgcints.mml.macrotable"),
           "Builder target is not a macro table")
  end
  self:reset()
end

--- Resets the builder state.
function cls:reset ()
  self.params = {}
  self.delims = {}
  self.isVariadic = false
  self.options = {}
  self.optionorder = {}
  self.defaults = {}
  self._handler = nil
  self._songHandler = nil
end

--- Returns the current target @{MML.MacroTable} object.
function cls:getTable ()
  return self.target
end

--- Installs a target @{MML.MacroTable} object.
--
-- This method does not automatically reset the builder state.
-- @tparam ?MML.MacroTable table New target, or `nil` if commands are to be
-- inserted manually after calling @{MML.CmdBuilder:make}.
function cls:setTable (table)
  self.target = table
end

--- Adds an MML parameter.
-- @tparam func|string kind If it is a string, the associated lexer function is
-- looked up in @{Default.Lexers}. Otherwise, it must be a function which
-- accepts a @{util.StringView} as its sole argument.
-- @treturn MML.CmdBuilder Self.
function cls:param (kind)
  if type(kind) == "string" then
    kind = assert(Func[kind],
                  ('Unknown default lexer function "%s"'):format(kind))
  end
  assert(kind, "Unknown MML parameter type")
  insert(self.params, kind)
  return self
end

--- Enforces a particular delimiter string before or after a parameter.
--
-- This delimiter overrides the default setting; in particular, if `delim` is a
-- comma, that delimiter becomes necessary.
-- @tparam string delim Delimiter string. It should not contain whitespace
-- characters.
-- @treturn MML.CmdBuilder Self.
function cls:delimit (delim)
  self.delims[#self.params] = delim
  return self
end

--- Makes the last parameter optional.
--
-- Every optional parameter creates an extra command object.
-- @tparam ?string def The default value for the last parameter. If not given,
-- this default value is simply `nil,` and @{MML.Command:applyChannel} or
-- @{MML.Command:applySong} handles the optional parameters manually. Otherwise,
-- it must be a string that can be read by the corresponding lexer function,
-- and the default value is computed every time the command is used.
-- @tparam[opt] int prio The order at which the parameter is added to produce
-- the optional variants; the last parameter will be the `prio`-th item added
-- from the command for the parameters added so far, reassigning the priorities
-- for previous items when needed. If not given, the parameter will be added
-- last.
-- @treturn MML.CmdBuilder Self.
function cls:optional (def, prio)
  local id = #self.params
  prio = prio and #self.optionorder - prio + 2 or 1
  assert(type(prio) == "number" and prio >= 1 and
         prio <= #self.optionorder + 1 and prio % 1 == 0,
         "Invalid optional parameter priority")
  assert(not self.options[id], "Duplicate optional parameter call")
  self.options[id] = true
  insert(self.optionorder, prio, id)
  if def ~= nil then self.defaults[id] = Sv(def) end
  return self
end

--- Makes the command variadic.
--
-- A variadic command accepts its last parameter as many times as possible; if
-- it is optional then it may also accept no parameters at all.
-- To avoid the parser from aggressively consuming too many tokens, which may be
-- the case for some lexer functions, variadic commands will stop accepting
-- parameters after encountering a completely blank line. A line containing any
-- comment is not completely blank.
-- @treturn MML.CmdBuilder Self.
function cls:variadic ()
  self.isVariadic = true
  return self
end

--- Changes the command's behaviour on the active channel.
--
-- More precisely, overwrites the @{MML.Command:applyChannel} method of all
-- produced commands.
-- @tparam func f Handler method which receives the current @{Music.Song}
-- object, then the command parameters as its arguments.
-- @tparam[opt] bool full If this evaluates to `true`, then `f` receives also
-- the command object itself before all other arguments.
-- @treturn MML.CmdBuilder Self.
function cls:setHandler (f, full)
  self._handler = full and f or function (...) return f(select(2, ...)) end
  return self
end

--- Changes the command's behaviour on the active song.
--
-- More precisely, overwrites the @{MML.Command:applySong} method of all
-- produced commands.
-- @tparam func f Handler method which receives the current @{Music.Channel}
-- object, then the command parameters as its arguments.
-- @tparam[opt] bool full If this evaluates to `true`, then `f` receives also
-- the command object itself before all other arguments.
-- @treturn MML.CmdBuilder Self.
function cls:setSongHandler (f, full)
  self._songHandler = full and f or function (...) return f(select(2, ...)) end
  return self
end

--- Produces the command.
-- @tparam string name The command name. If this is provided and a macro table
-- is given in the @{MML.CmdBuilder:__init|constructor}, all the generated
-- command objects will be inserted automatically.
-- @tparam bool keep Whether to keep the current builder configuration after
-- producing the command.
-- @treturn class All the @{MML.Command} classes produced.
function cls:make (name, keep)
  local commands = {}
  local addcmd = function (cmd)
    insert(commands, cmd)
    if self.target and name then self.target:addCommand(name, cmd) end
  end
  
  if self.isVariadic and #self.params > 0 then
    local orig = self.params[#self.params]
    self.params[#self.params] = function (sv)
      local vars = join((orig(sv)))
      while sv:len() > 0 do
        local suc, b = true, sv:seek()
        if sv:trim "%s*,?%s*":find "\n%s*\n" then break end
        local newvars = Ex.try(
          orig,
          Ex.typed "ParamError", function ()
            suc = false
            sv:seek(b)
          end
        )(sv)
        if not suc then break end
        vars = vars(newvars)
      end
      return vars()
    end
  end
    
  local p = {unpack(self.params)}
  local count = #p
  local cmd = ParamCmd(unpack(p))
  cmd.applyChannel = self._handler or cmd.applyChannel
  cmd.applySong = self._songHandler or cmd.applySong
  addcmd(cmd)
  
  for _, v in ipairs(self.optionorder) do
    p[v] = nil
    local used, unused = {}, {}
    for i = 1, count do
      if p[i] then
        insert(used, p[i])
      else
        unused[i] = true
      end
    end
    
    local cmd = ParamCmd(unpack(used))
    cmd.applyChannel = self._handler or cmd.applyChannel
    cmd.applySong = self._songHandler or cmd.applySong
    local defaults = self.defaults -- closure
    local params = self.params -- closure
    
    function cmd:getParams (sv)
      local results = {ParamCmd.getParams(self, sv)}
      local pos = 1
      local vars = join
      for i = 1, #params do
        if unused[i] then
          local def = defaults[i]
          if def ~= nil then
            def:restore()
            vars = vars((params[i](def)))
          else
            vars = vars(nil)
          end
        else
          vars = vars(results[pos])
          pos = pos + 1
        end
      end
      return vars()
    end
    addcmd(cmd)
  end
  
  if not keep then self:reset() end
  return unpack(commands)
end

return Class(cls)
