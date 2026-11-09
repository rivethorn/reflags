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

main :: proc() {
	// Define a root command with one string option and one bool flag.
	root := reflags.command("greet", "Say hello")
	append(&root.options, reflags.opt_str("name", "n", "Who to greet"))
	append(&root.options, reflags.opt_flag("shout", "s", "Shout the greeting"))

	// The CLI must outlive parse, so root lives on the heap.
	root_ptr := new_clone(root)

	cli: reflags.CLI = reflags.make_cli("greet", "1.0.0", root_ptr)
	defer reflags.destroy_cli(&cli)

	// Parse arguments; prints help/version/errors and exits on its own.
	parsed := reflags.parse_or_exit(&cli, os.args[1:])
	defer reflags.destroy(parsed)

	// Read values back with the get_* accessors.
	name := reflags.get_string(parsed, "name")
	shout := reflags.get_bool(parsed, "shout")

	greeting := "Hello There!"

	if name != "" {
		greeting = fmt.tprintf("Hello, %s!", name)
	}

	if shout {
		greeting = strings.to_upper(greeting, context.temp_allocator)
	}
	fmt.println(greeting)
}
```

Error helpers for handlers (they print to stderr and exit code comes from
returning the error up to the parser):

```odin
return reflags.command_fail("myapp build", "Compilation failed: ...")
```

`command_fail` prints `myapp build error: ...` in bold red and returns an
Error carrying the exit code for the parser (1 unless overridden).️

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
`get_strings`, `get_enum`). Handlers may return an `^Error` (see `make_error`
and `command_fail`); `Help_Requested` / `Version_Requested` reasons print
help/version and exit 0.

For teardown: `destroy_cli` frees the command tree that `make_cli` keeps
alive (notes, options, arguments, subcommands, and the heap-allocated
root command). `destroy(parsed)` frees the parsed maps plus every value
string the parser built itself. Values that only borrow from the raw
arguments are not allocated at all.

See `examples/hello_world/` for a minimal example, or `examples/toolkit/` for a full multi-command CLI.
*/

package reflags
