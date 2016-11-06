-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

local t = {}

t.RAW_INSERT         = "`"
t.SINGLECOMMENT      = ";"
t.MULTICOMMENT_BEGIN = "/*"
t.MULTICOMMENT_END   = "*/"
t.CHANNELSELECT      = "!"
t.DIRECTIVE_PREFIX   = "#"
t.MACRODEFINE        = "$$"
t.MACROINVOKE        = "$"
t.PATTERNDEFINE      = "$<"
t.PATTERNINVOKE      = "$>"

return t
