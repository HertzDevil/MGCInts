-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

--- Universal definitions for almost all MML engines.
-- @module Default

local DEFAULT = {}

local require = require

--- Assertion functions for various predefined exception types.
--
-- These throw exceptions created from @{util.Exception.typed} whose name is the
-- field name with "Check" replaced with "Error".
-- @field ParamCheck Reading errors thrown by lexer functions.
-- @field ArgumentCheck Invalid function inputs.
-- @field RuntimeCheck Runtime errors in general.
-- @field SyntaxCheck Syntax errors in the input MML. Specialization of
-- `RuntimeCheck`.
-- @field CommandCheck Errors thrown by MML commands. Specialization of
-- `RuntimeCheck`.
-- @table Errors
DEFAULT.Errors = require "mgcints.default.errors"

--- MML macro names for the default command definitions.
--
-- These fields should not be changed during run-time.
-- @field RAW_INSERT The macro for raw byte insertion, default `"`"`;
-- @field SINGLECOMMENT The macro for single-line comments, default `";"`;
-- @field MULTICOMMENT_BEGIN The macro for starting multi-line comments, default
-- `"/*"`;
-- @field MULTICOMMENT_END The macro for finishing multi-line comments, default
-- `"*/"`;
-- @field CHANNELSELECT The macro for selecting active channels, default `"!"`;
-- @field DIRECTIVE_PREFIX The symbol that all preprocessor directives begin
-- with, default `"#"`;
-- @field MACRODEFINE The macro for defining MML substitution macros, default
-- `"$$"`;
-- @field MACROINVOKE The macro for invoking MML substitution macros, default
-- `"$"`;
-- @field PATTERNDEFINE The macro for defining pattern channels, default `"$<"`;
-- @field PATTERNINVOKE The macro for invoking pattern channels, default `"$>"`
-- (this command has a null action and must be overridden manually).
-- @table Symbols
DEFAULT.Symbols = require "mgcints.default.symbols"

--- A table containing default lexer functions for @{MML.CmdBuilder}.
-- @table Lexers
-- @see Default.Lexers
DEFAULT.Lexers = require "mgcints.default.lexers"

--- Constructor for default preprocessor directives.
--
-- Returns a new @{MML.MacroTable} with the following preprocessor directives:
--
-- - Preprocessor numeric constant definition (`#define`, `#undef`);
-- - Conditional compiling directives (`#if`, `#ifdef`, `#ifndef`, `#else`,
-- `#endif`);
-- - The channel remapping directive (`#remap n c`), which maps the `n`-th
-- channel to the character `c`.
-- @function Directives
DEFAULT.Directives = require "mgcints.default.directives"

--- Constructor for default MML commands.
--
-- Returns a new @{MML.MacroTable} with the following MML commands:
--
-- - Raw byte insertion;
-- - Single-line and multi-line comments;
-- - Channel selector;
-- - Substitution macro definition and invocation.
-- @function Macros
DEFAULT.Macros = require "mgcints.default.macros"

--- Constructor for the default MML engine.
--
-- Returns a blank engine definition with the following default components: (see
-- @{Music.Engine:__init} for the meaning of those fields)
--
-- - `song`: A blank subclass of @{Music.Song};
-- - `channel`: A blank subclass of @{Music.Channel};
-- - `parser`: An @{MML.Parser} object using the default tables.
-- @function Engine
-- @tparam[opt=1] int chcount Channel count.
-- @tparam[opt] string Engine name.
DEFAULT.Engine = require "mgcints.default.engine"

return DEFAULT
