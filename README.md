# MGCInts

MGCInts (**M**ML **G**eneric **C**ompiler **Int**erface**s**) is a Lua framework for creating binary music compilers with a uniform Music Macro Language syntax. It also contains a frontend to compile its own MML files directly.

MGCInts is licensed under Mozilla Public License Version 2.0.

### Caution

MGCInts is in very early development stage. Backward-incompatible changes to the API might occur even if the MML engines remain usable in limited contexts.

Also, the compiler does not back up the output files right now, nor support non-destructive data insertion. Your music data might corrupt other tracks or even other parts of your output file; however, the ones listed in `STATUS.md` will guarantee that the written data only affects existing music data.

### Features

- One frontend, multiple target music drivers
- Single syntax scheme for almost all MML commands
- Simple, system-agnostic construction of MML grammar definitions
- Utility for rudimentary music stream decompilation
- 100% vanilla Lua ~~(with optional dependencies requiring C compiler)~~

### Prerequisites

- [Lua](https://www.lua.org/) 5.1 or above (required; should be accessible as `lua` at the command prompt)
- [argparse](https://github.com/mpeterv/argparse) (required for all command line options)

### Installation

- Download the entire folder or clone the repository;
- Add the `bin` directory to `$PATH`;
- Add the root directory to `$MGCINTS_PATH`.

This framework will be later accessible remotely from LuaRocks.

### Synopsis

To insert a single song:

```
$ mgcfront my_engine my_song.mml output.bin
```

On a Linux LuaRocks system user installation, MML files may be directly "executed":

```
$ cat my_song.mml
#!/usr/local/bin/mgcfront my_engine
/* ... */
$ chmod u+x my_song.mml
$ ./my_song.mml output.bin
```

### Directory

Below is the structure of this repository:

- `README.md`: This file
- `STATUS.md`: Project status and supported engines
- `FAQ.md`: Frequently asked questions
- `CONTRIB.md`: Guidelines for submitting sound engines
- `CHANGES.md`: Change log
- `COPYING`: The software license (MPL-2.0)
- `mgcints-scm-1.rockspec`: LuaRocks specification
- `bin/`: System-dependent launchers
- `doc/`: LDoc-generated guide and manual
- `etc/`: Miscellaneous files
- `include/`: Common MML files for sound drivers
- `mml/`: Example MML songs
- `src/mgcints/`: The framework source scripts
  - `default/`: Default object definitions
  - `engine/`: MML grammar definitions
  - `mml/`: MML processing module
  - `music/`: Music data representation module
  - `util/`: Helper classes
- `src/mgcfront.lua`: The frontend script

### Contributing

- **Source code**: Create a fork and pull request on Github for this repository. It must contain also at least one test script.
- **Sound engine**: Unavailable right now.
