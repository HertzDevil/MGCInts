# MGCInts

MGCInts (**M**ML **G**eneric **C**ompiler **Int**erface**s**) is a Lua framework for creating binary music compilers with a uniform Music Macro Language syntax. It also contains a frontend to compile its own MML files directly.

MGCInts is licensed under Mozilla Public License Version 2.0.

### Caution

MGCInts is in very early development stage. There might be backward-incompatible changes to the API even if the MML engines are usable in limited contexts. See `STATUS.md` for details.

Also, the compiler does not back up your files right now, nor support non-destructive data insertion. Your music data might corrupt other tracks or even other parts of your output file.

### Features

- One frontend, multiple target music drivers
- Single syntax scheme for almost all MML commands
- Simple, system-agnostic construction of MML grammar definitions
- Utility for rudimentary music stream decompilation
- 100% vanilla Lua ~~(with optional dependencies requiring C compiler)~~

### Prerequisites

- [Lua](https://www.lua.org/) 5.1 or above (required; should be accessible as `lua` at the command prompt)
- [argparse](https://github.com/mpeterv/argparse) (required (future versions should allow limited use of the frontend without argparse installed))

### Installation

- Download the entire folder or clone the repository;
- Add the `bin` directory to `$PATH`;
- Add the `src` directory to `$LUA_PATH`;
- Add the root directory to `$MGCINTS_PATH`.

As this framework becomes more complete, automatic installation will be available via LuaRocks.

### Synopsis

To insert a single song:

```
$ mgcfront my_engine my_song.mml output.bin
```

Alternatively, on Linux systems MML files may be directly "executed":

```
$ cat my_song.mml
#!/usr/bin/env mgcfront my_engine
/* ... */
$ chmod u+x my_song.mml
$ ./my_song.mml         # no output specified, uses "my_song.bin" as default
```

### Directory

Below is the structure of this repository:

- `README.md`: This file
- `STATUS.md`: Project status and supported engines
- `CONTRIB.md`: Guidelines for submitting sound engines
- `CHANGES.md`: Change log
- `COPYING`: The software license (MPL-2.0)
- `bin/`: System-dependent launchers
- `doc/`: LDoc-generated guide and manual
- `include/`: Tentative MML grammar definitions
- `mml/`: Example MML songs
- `src/mgcints/`: The framework source scripts
  - `default/`: Default definitions
  - `engine/`: Complete MML grammar definitions
  - `mml/`: MML processing module
  - `music/`: Music data representation module
  - `util/`: Helper classes
- `src/mgcfront.lua`: The frontend script

### Contributing

- **Source code**: Create a fork and pull request on Github for this repository. It must contain also at least one test script.
- **Sound engine**: Unavailable right now.
