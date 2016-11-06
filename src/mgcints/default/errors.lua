-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

local Ex = require "mgcints.util.exception"

Ex.typed "ParamError"
Ex.typed "ArgumentError"
Ex.typed "RuntimeError"
Ex.typed("SyntaxError", "RuntimeError")
Ex.typed("CommandError", "RuntimeError")

return {
  ParamCheck    = Ex.TypedAssert "ParamError",
  ArgumentCheck = Ex.TypedAssert "ArgumentError",
  RuntimeCheck  = Ex.TypedAssert "RuntimeError",
  SyntaxCheck   = Ex.TypedAssert "SyntaxError",
  CommandCheck  = Ex.TypedAssert "CommandError",
}
