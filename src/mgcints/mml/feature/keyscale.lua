-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Key scale and signature support for MML engines.
-- @classmod MML.Feature.KeyScale
-- @alias cls
local cls = {}

local require = require
local pairs = pairs
local wrap = coroutine.wrap
local yield = coroutine.yield

local Errors = require "mgcints.default.errors"
local Trie = require "mgcints.util.trie"
local Check = Errors.RuntimeCheck
local Validate = Errors.ArgumentCheck
local ParamAssert = Errors.ParamCheck

local builder = require "mgcints.mml.command.builder" ()

local fea_ = setmetatable({}, {__mode = "k"})

function cls.getName (_)
  return "Key scale"
end

function cls.getCommandType (cself, ident)
end

function cls.register (cself, engine, cmdname, mname, kdef)
  
  cself.__base.register(cself, engine, cmdname, mname)
end

return require "mgcints.util.class" (cls, require "mgcints.mml.feature")
