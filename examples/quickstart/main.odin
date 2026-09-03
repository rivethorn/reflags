package quickstart_example

import reflags "../.."
import "core:fmt"
import "core:os"

// ============================================================================
// Handlers
// ============================================================================

build_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	release := reflags.get_bool(args, "release")
	silent := reflags.get_bool(args, "silent")
	jobs := reflags.get_int(args, "jobs", 1)

	if !silent {
		mode := release ? "release" : "debug"
		reflags.success(
			fmt.tprintf("Building in %s mode (jobs: %d)", mode, jobs),
		)
	}
	return nil
}

run_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	release := reflags.get_bool(args, "release")
	silent := reflags.get_bool(args, "silent")
	app_args := reflags.get_strings(args, "args")

	if !silent {
		mode := release ? "release" : "debug"
		reflags.success(fmt.tprintf("Running in %s mode", mode))
		if len(app_args) > 0 {
			reflags.info_msg(os.stdout, fmt.tprintf("With args: %v", app_args))
		}
	}
	return nil
}

test_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	filter := reflags.get_string(args, "filter")
	watch := reflags.get_bool(args, "watch")

	if filter != "" {
		reflags.info_msg(
			os.stdout,
			fmt.tprintf("Running tests matching: %s", filter),
		)
	} else {
		reflags.info_msg(os.stdout, "Running all tests")
	}

	if watch {
		reflags.warning_msg(os.stdout, "Watch mode enabled")
	}

	reflags.success("All tests passed!")
	return nil
}

// ============================================================================
// CLI Definition
// ============================================================================

main :: proc() {
	// --- Build command ---
	build_cmd := reflags.command("build", "Compile the project")
	build_cmd.alias = "b"
	append(
		&build_cmd.notes,
		"Use '--' to pass extra flags through to the compiler",
	)
	append(
		&build_cmd.options,
		reflags.opt_flag("release", "", "Compile in release mode"),
	)
	append(
		&build_cmd.options,
		reflags.opt_flag("silent", "", "Silent terminal output"),
	)

	// Step-by-step builder for an int option with a note
	jobs_builder := reflags.option("jobs", "Number of parallel jobs")
	reflags.opt_type(&jobs_builder, reflags.int_type)
	reflags.opt_default(&jobs_builder, "1")
	reflags.opt_note(
		&jobs_builder,
		"Defaults to 1; set higher for faster builds",
	)
	append(&build_cmd.options, reflags.opt_build(jobs_builder))

	build_cmd.handler = build_handler

	// --- Run command ---
	run_cmd := reflags.command("run", "Build if needed, then run the project")
	run_cmd.alias = "r"
	append(
		&run_cmd.options,
		reflags.opt_flag("release", "", "Run the release build"),
	)
	append(
		&run_cmd.options,
		reflags.opt_flag("silent", "", "Silent terminal output"),
	)

	// Variadic argument with a note
	run_args := reflags.argument(
		"args",
		"Arguments passed through to the binary",
	)
	reflags.arg_optional(&run_args)
	reflags.arg_variadic(&run_args)
	reflags.arg_note(
		&run_args,
		"Introduce them with '--' so they are not parsed as options",
	)
	append(&run_cmd.arguments, reflags.arg_build(run_args))

	run_cmd.handler = run_handler

	// --- Test command ---
	test_cmd := reflags.command("test", "Run the test suite")
	test_cmd.alias = "t"
	append(
		&test_cmd.options,
		reflags.opt_flag("watch", "", "Re-run on file changes"),
	)

	// String option with attached value (Odin style: -filter:value)
	filter_builder := reflags.option(
		"filter",
		"Only run tests matching this filter",
	)
	reflags.opt_type(&filter_builder, reflags.string_type)
	append(&test_cmd.options, reflags.opt_build(filter_builder))

	test_cmd.handler = test_handler

	// --- Root command ---
	root := reflags.command("myapp", "A sample CLI application")
	root.long_desc = "A sample CLI application demonstrating reflags features.\nSupports build, run, and test subcommands with colored output and help."

	cmds := []reflags.Command{build_cmd, run_cmd, test_cmd}
	for sub in cmds {
		append(&root.subcommands, sub)
	}

	// The CLI outlives parse, so root must live on the heap.
	root_ptr := new(reflags.Command)
	root_ptr^ = root

	cli: reflags.CLI = reflags.make_cli("myapp", "1.0.0", root_ptr)
	cli.style = .Odin // single-dash flags, -flag:value, -- separator

	parsed := reflags.parse_or_exit(&cli, os.args[1:])
	defer reflags.destroy(parsed)

	// No subcommand given.
	if parsed.command.name == "myapp" {
		os.exit(1)
	}

	// Dispatch to the matched command's handler.
	handler := parsed.command.handler
	if handler != nil {
		if err := handler(parsed); err != nil {
			reflags.print_error(&cli, err)
			os.exit(1)
		}
	}
}
