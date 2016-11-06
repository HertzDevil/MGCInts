-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- The core modules of MGCInts.
-- The utility modules must be imported manually if necessary.
-- @module MGCInts
-- @alias t
local t = {}

--- The @{Default} module.
-- @table Default
t.Default = require "mgcints.default"

--- The @{MML} module.
-- @table MML
t.MML = require "mgcints.mml"

--- The @{Music} module.
-- @table Music
t.Music = require "mgcints.music"

return t
