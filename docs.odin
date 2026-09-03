/*
package reflags - a builder-style command-line argument parser for Odin.

reflags lets you define commands, options, and positional arguments
declaratively, then parse `os.args` against them. It supports nested
subcommands, typed option values (string, int, bool, float, path, enum,
custom), default values, required flags, variadic arguments, per-command
aliases, notes attached to commands/options/arguments, and colored,
auto-generated help/version output.

Two parsing styles are available via `Parsing_Style`:

	`.Unix`  -- `-s`, `--flag`, `--flag=value`, `--flag value`, bundled
				short flags (`-abc`).
	`.Odin`  -- `-flag`, `-flag:value`, `-flag=value`, underscores in flag
				names treated as dashes (`-no_git` matches `no-git`), and
				`--` as the end-of-options separator (everything after is
				positional).

Quick start (Odin style):

```odin
package main

import "core:os"
import "core:fmt"
import "pkgs:reflags"

build_cmd := reflags.command("build", "Compile the project into bin/")
build_cmd.alias = "b"  // optional alias
append(&build_cmd.options, reflags.opt_flag("release", "", "Compile in release mode"))
append(&build_cmd.options, reflags.opt_flag("silent", "", "Silent terminal output"))
append(&build_cmd.notes, "Use '--' to pass args through to the compiler")

run_cmd := reflags.command("run", "Build if needed, then run the project")
run_cmd.alias = "r"
append(&run_cmd.options, reflags.opt_flag("release", "", "Compile and run in release mode"))
run_cmd_args := reflags.argument("args", "Arguments passed through to the binary")
reflags.arg_optional(&run_cmd_args)
reflags.arg_variadic(&run_cmd_args)
append(&run_cmd.arguments, reflags.arg_build(run_cmd_args))

root := reflags.command("myapp", "A swiss-army knife for your project")
root.long_desc = "A swiss-army knife for your project.\\nBuild, run, and test with one tool."
cmds := []reflags.Command{ build_cmd, run_cmd }
for sub in cmds {
	append(&root.subcommands, sub)
}
root_ptr := new(reflags.Command)
root_ptr^ = root

cli: reflags.CLI = reflags.make_cli("myapp", "0.1.0", root_ptr)
cli.style = .Odin

parsed := reflags.parse_or_exit(&cli, os.args[1:])
defer reflags.destroy(parsed)

if parsed.command.name == "myapp" {
	os.exit(1)
}

match parsed.command.name {
case "build":
	release := reflags.get_bool(parsed, "release")
	silent  := reflags.get_bool(parsed, "silent")
	fmt.printfln("Building (release=%v, silent=%v)", release, silent)
case "run":
	release := reflags.get_bool(parsed, "release")
	silent  := reflags.get_bool(parsed, "silent")
	run_args := reflags.get_strings(parsed, "args")
	fmt.printfln("Running (release=%v, silent=%v, args=%v)", release, silent, run_args)
}
```

Error helpers for handlers:

```odin
reflags.command_error(os.to_stream(os.stderr), "myapp build", "Compilation failed: ...")
reflags.error_hint(os.to_stream(os.stderr), "build")
os.exit(1)
```

`command_error` prints `myapp <cmd> error: <msg>` in bold red; `error_hint`
prints the dim `Run '<cmd> -help' for usage.` follow-up (use `error_hint_unix`
for `--help` instead).

Options can also be built step by step with `option` + `opt_*` procedures
(`opt_short`, `opt_required`, `opt_hidden`, `opt_multiple`, `opt_default`,
`opt_type`, `opt_note`). Commands have `command_builder` + `cmd_*` for the
same style. Arguments use `argument` + `arg_*` (`arg_optional`, `arg_variadic`,
`arg_hidden`, `arg_type`, `arg_note`). Value types are described with
`Arg_Type_Info` presets (`string_type`, `int_type`, `bool_type`, `float_type`,
`path_type`) or constructed with `enum_type` / `custom_type`.

Notes (extra lines shown in help) can be attached to commands, options, and
arguments:

```odin
append(&my_cmd.notes, "Only works inside an Odin project directory")

opt_b := reflags.option("jobs", "Number of parallel jobs")
reflags.opt_note(&opt_b, "Defaults to the number of CPU cores")
append(&my_cmd.options, reflags.opt_build(opt_b))

arg_b := reflags.argument("path", "Path to the project")
reflags.arg_note(&arg_b, "Defaults to the current directory")
append(&my_cmd.arguments, reflags.arg_build(arg_b))
```

Command handlers receive a `Parsed_Args` and read values back with the
`get_*` accessors (`get_string`, `get_int`, `get_bool`, `get_float`,
`get_strings`, `get_enum`). Handlers may return an `^Error` (see `make_error`);
`Help_Requested` / `Version_Requested` reasons print help/version and exit 0.

See `examples/hello_world/` for a minimal example, or `examples/toolkit/` for a full multi-command CLI.
*/

package reflags
