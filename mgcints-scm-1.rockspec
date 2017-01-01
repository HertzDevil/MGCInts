local SRCDIR = {folder = "mgcints",
  "init",
  {folder = "default",
    "directives", "engine", "errors",
    "init", "lexers", "macros", "symbols",
  },
  {folder = "engine",
    "cv1", "mm3", "silius",
  },
  {folder = "mml",
    "init", "macrotable", "parser", "ppcontext",
    {folder = "command", "init", "paramcmd", "builder"},
    {folder = "feature", "init", "mute"},
  },
  {folder = "music",
    "init", "channel", "compiler", "engine", "linker", "song", "state", "stream",
    {folder = "chunk", "init", "multi", "num", "pointer", "str"},
  },
  {folder = "util",
    "class", "exception", "misc", "streamdec", "streamdumper",
    "stringfuncs", "stringview", "svtrace", "trie", "warning",
  },
}

local module_recurse = function (dir)
  local m = {}
  local function f (dir, prefix, lp)
    prefix = prefix .. dir.folder
    lp = lp .. dir.folder
    for i = 1, #dir do
      local v = dir[i]
      if v == "init" then
        m[lp] = "src/" .. prefix .. "/init.lua"
      elseif v.folder then
        f(v, prefix .. "/", lp .. ".")
      else
        m[lp .. "." .. v] = "src/" .. prefix .. "/" .. v .. ".lua"
      end
    end
  end
  f(dir, "", "")
  return m
end

package = "mgcints"
version = "scm-1"
description = {
  summary = "Music Macro Language Generic Compiler Interfaces for pure Lua",
  detailed = [[MGCInts is a Lua framework for creating binary music compilers
  with a uniform Music Macro Language syntax. It also contains a frontend to
  compile its own MML files directly.]],
  license = "MPL-2.0",
  homepage = "http://github.com/HertzDevil/MGCInts",
  maintainer = "HertzDevil <nicetas (dot) c (at) gmail (dot) com>",
}
dependencies = {
  "lua >= 5.1, < 5.4",
  "argparse",
}
source = {
  url = "git+https://github.com/HertzDevil/MGCInts",
  tag = "",
}
build = {
  type = "builtin",
  modules = module_recurse(SRCDIR),
  copy_directories = {"doc", "etc", "include", "mml", "test"},
  install = {
    bin = {mgcfront = "src/mgcfront.lua"},
  }
}
