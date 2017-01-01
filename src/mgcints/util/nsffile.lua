-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Helper class for reading NSF files.
-- Writing and creating NSF files is not supported.
-- @classmod util.NSFFile
-- @alias cls
local cls = {}

local insert = table.insert
local floor = math.floor

require "mgcints.util.stringfuncs"
local Check = require "mgcints.default.errors".RuntimeCheck

-- properties
local _LOAD = setmetatable({}, {__mode = "k"})
local _INIT = setmetatable({}, {__mode = "k"})
local _PLAY = setmetatable({}, {__mode = "k"})

local _TITLE = setmetatable({}, {__mode = "k"})
local _AUTHOR = setmetatable({}, {__mode = "k"})
local _COPYRIGHT = setmetatable({}, {__mode = "k"})
local _SONGS = setmetatable({}, {__mode = "k"})
local _FIRST = setmetatable({}, {__mode = "k"})
local _REGION = setmetatable({}, {__mode = "k"})
local _DUAL = setmetatable({}, {__mode = "k"})

local _RATE = setmetatable({}, {__mode = "k"})
local _BANK = setmetatable({}, {__mode = "k"})
local _CHIP = setmetatable({}, {__mode = "k"})

local _DATA = setmetatable({}, {__mode = "k"})
local _RAW = setmetatable({}, {__mode = "k"})

local _ptr = setmetatable({}, {__mode = "k"})

--- NSF initializer.
-- @tparam string fname File name.
function cls:__init (fname)
  local f = io.open(fname, "rb")
  Check(f and f:read(6) == "NESM\026\001", "Invalid NSF file")

  _ptr[self] = 0x8000
  f:seek("set", 0)
  _RAW[self] = f:read "*a"

  f:seek("set", 0)
  local header = f:read(0x80)
  _SONGS[self] = (header:readint(0x07) - 1) % 0x100 + 1
  _FIRST[self] = (header:readint(0x08) - 1) % 0x100 + 1
  _LOAD[self] = header:readint(0x09, 2)
  _INIT[self] = header:readint(0x0B, 2)
  _PLAY[self] = header:readint(0x0D, 2)
  _TITLE[self] = header:sub(0x0F, 0x2E):match "^[\001-\255]*"
  _AUTHOR[self] = header:sub(0x2F, 0x4E):match "^[\001-\255]*"
  _COPYRIGHT[self] = header:sub(0x4F, 0x6E):match "^[\001-\255]*"
  _RATE[self] = {NTSC = header:readint(0x6F, 2), PAL = header:readint(0x79, 2)}
  local region = header:readint(0x7B)
  _REGION[self] = region % 0x02 ~= 0 and "PAL" or "NTSC"
  _DUAL[self] = floor(region / 0x02) % 0x02 ~= 0
  _CHIP[self] = header:readint(0x7C)

  _BANK[self] = {}
  local switch = false
  for i = 8, 15 do
    local x = header:readint(0x69 + i)
    _BANK[self][i] = x
    switch = switch or x ~= 0
  end
  if not switch then
    _BANK[self] = {}
    local bank = 0
    for i = floor(_LOAD[self] / 0x1000) - 8, 7 do if i >= 0 then
      _BANK[self][i + 8] = bank
      bank = bank + 1
    end end
  end
  if self:hasChip "FDS" then
    _BANK[self][6] = _BANK[self][14]
    _BANK[self][7] = _BANK[self][15]
  end

  local d = {}
  local bsize = 0x1000 - _LOAD[self] % 0x1000
  while true do
    local str = f:read(bsize)
    if not str then break end
    if #d == 0 then
      str = ("\x00"):rep(0x1000 - #str) .. str
      bsize = 0x1000
    end
    str = str .. ("\x00"):rep(0x1000 - #str)
    insert(d, str)
  end
  _DATA[self] = d

  f:close()
end

--- Returns the LOAD address of the NSF.
function cls:getLOAD ()
  return _LOAD[self]
end

--- Returns the INIT address of the NSF.
function cls:getINIT ()
  return _INIT[self]
end

--- Returns the PLAY address of the NSF.
function cls:getPLAY ()
  return _PLAY[self]
end

--- Obtains NSF metadata information.
-- @treturn table A new table with the following fields:<ul>
-- <li> `title`: The NSF title, without trailing null characters;</li>
-- <li> `author`: The NSF author, without trailing null characters;</li>
-- <li> `copyright`: The NSF copyright, without trailing null characters;</li>
-- <li> `songs`: The number of songs in the NSF;</li>
-- <li> `first`: The initial song number of the NSF;</li>
-- <li> `region`: The default region as a string;<li>
-- <li> `dual`: Whether dual region is supported.</li>
-- </ul>
function cls:getInfo ()
  return {
    title = _TITLE[self],
    author = _AUTHOR[self],
    copyright = _COPYRIGHT[self],
    songs = _SONGS[self],
    first = _FIRST[self],
    region = _REGION[self],
    dual = _DUAL[self],
  }
end

--- Checks the NSF for a sound chip. The following sound chips are accepted:
-- - Internal: `APU`
-- - Konami VRC6: `VRC6`
-- - Konami VRC7: `VRC7`
-- - Nintendo FDS: `FDS`, `2C33`
-- - Nintendo MMC5: `MMC5`
-- - Namco 163: `N163`, `N106`
-- - Sunsoft 5B: `5B`, `FME7`
-- @tparam string chip The sound chip name. Case-insensitive.
-- @treturn bool Whether the given sound chip is used.
-- @function cls:hasChip
do
  local apu  = function () return true end
  local vrc6 = function (self) return       _CHIP[self]         % 0x02 ~= 0 end
  local vrc7 = function (self) return floor(_CHIP[self] / 0x02) % 0x02 ~= 0 end
  local fds  = function (self) return floor(_CHIP[self] / 0x04) % 0x02 ~= 0 end
  local mmc5 = function (self) return floor(_CHIP[self] / 0x08) % 0x02 ~= 0 end
  local n163 = function (self) return floor(_CHIP[self] / 0x10) % 0x02 ~= 0 end
  local s5b  = function (self) return floor(_CHIP[self] / 0x20) % 0x02 ~= 0 end
  local ftable = {
    APU = apu,
    VRC6 = vrc6,
    VRC7 = vrc7,
    FDS = fds, ["2C33"] = fds,
    MMC5 = mmc5,
    N163 = n163, N106 = n163,
    ["5B"] = s5b, FME7 = s5b,
  }
function cls:hasChip (chip)
  local f = ftable[chip:upper()]
  return f ~= nil and f(self)
end; end

--- Swaps to a different bank.
-- @tparam int adr Address where the bankswitching will take place, must be
-- between 0x6000 and 0xFFFF (inclusive).
-- @tparam[opt] int id Bank number. If not given, unloads the entire bank.
function cls:bankswitch (adr, id)
  adr = floor(adr / 0x1000)
  if adr >= (self:hasChip "FDS" and 6 or 8) and adr <= 15 then
    _BANK[self][adr] = id
  end
end

--- Reads data from the NSF.
-- @tparam int i Starting address.
-- @tparam[opt=i] int j Ending address.
-- @treturn string The NSF contents. Inaccessible ranges are zero-padded.
function cls:readData (i, j)
  local readbank = function (self, mr, b, e)
    local bank = _BANK[self][mr]
    b = (b or 0) + 1
    e = (e or 0xFFF) + 1
    return bank and _DATA[self][bank + 1]:sub(b, e) or ("\x00"):rep(e - b + 1)
  end

  j = j or i
  local ir, jr = floor(i / 0x1000), floor(j / 0x1000)
  i, j = i % 0x1000, j % 0x1000
  if ir >= jr then
    return readbank(self, ir, i, j)
  end
  local out = {readbank(self, ir, i, nil)}
  for x = ir + 1, jr - 1 do
    insert(out, readbank(self, x, nil, nil))
  end
  insert(out, readbank(self, jr, nil, j))
  return table.concat(out)
end

--- Reads a number of bytes.
--
-- This function allows an NSF file to mimic part of the file handle interface.
-- @tparam int n Number of bytes to read, between 1 and 65536 (inclusive).
-- @treturn string The read contents.
function cls:read (n)
  Check(n >= 1 and n <= 0x10000 and n % 1 == 0, "Invalid NSF read count")
  local str
  if _ptr[self] + n > 0x10000 then
    str = self:readData(_ptr[self], 0xFFFF)
          .. self:readData(0, _ptr[self] + n - 0x10001)
  else
    str = self:readData(_ptr[self], _ptr[self] + n - 1)
  end
  self:seek("cur", n)
  return str
end

--- Moves the current read pointer.
--
-- This function allows an NSF file to mimic part of the file handle interface.
-- The read pointer warps as a 16-bit unsigned integer.
-- @tparam[opt="cur"] string whence Whether to move the pointer relative to the
-- zero address (`"set"`) or the current value (`"cur"`). `"end"` is not allowed.
-- @tparam[opt=0] int offset Skip amount.
-- @treturn int The new pointer address.
function cls:seek (whence, offset)
  offset = offset or 0
  if whence == "cur" or whence == nil then
    _ptr[self] = (_ptr[self] + offset) % 0x10000
    return _ptr[self]
  end
  if whence == "set" then
    _ptr[self] = offset % 0x10000
    return _ptr[self]
  end
  Check(false, "Invalid NSF seek option")
end

--- Obtains file position from an address.
-- @tparam[opt] int adr Address value, defaults to the NSF's current pointer.
-- @treturn[opt] int File position that the given address maps to, or `nil` if
-- it does not correspond to file data.
function cls:getPosition (adr)
  adr = adr or _ptr[self]
  local bank = _BANK[self][floor(adr / 0x1000)]
  if not bank then return nil end
  return 0x80 + bank * 0x1000 + adr % 0x1000 - self:getLOAD() % 0x1000
end

--- Returns the contents of the entire NSF file, including the header.
function cls:rawData ()
  return _RAW[self]
end

return require "mgcints.util.class" (cls)
