-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- A singleton instance of @{util.Profiler}.
-- Calling this module object returns a singleton instance.
-- @module util.GlobalProfiler

local require = require

local weak = require "mgcints.util.misc".weak
local instance = weak(require "mgcints.util.profiler" ())
instance():enter "__GLOBAL"
return instance
