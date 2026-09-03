#+feature dynamic-literals
package cargo_example

import reflags "../.."

// ============================================================================
// Shared Options
// ============================================================================

add_common_opts :: proc(c: ^reflags.Command) {
	append(
		&c.options,
		reflags.Option {
			name = "verbose",
			short = "v",
			description = "Use verbose output",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "quiet",
			short = "q",
			description = "No output printed to stdout",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "color",
			description = "Coloring: auto, always, never",
			type_info = reflags.enum_type([]string{"auto", "always", "never"}),
			default_str = "auto",
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "config",
			short = "c",
			description = "Path to config file",
			type_info = reflags.path_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "manifest-path",
			description = "Path to Cargo.toml",
			type_info = reflags.path_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "frozen",
			description = "Require Cargo.lock and cache are up to date",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "locked",
			description = "Require Cargo.lock is up to date",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "offline",
			description = "Run without accessing the network",
			type_info = reflags.bool_type,
		},
	)
}

add_build_opts :: proc(c: ^reflags.Command) {
	append(
		&c.options,
		reflags.Option {
			name = "package",
			short = "p",
			description = "Package to build",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "bin",
			description = "Build only the specified binary",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "example",
			description = "Build only the specified example",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "target",
			description = "Build for the target triple",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "target-dir",
			description = "Directory for all generated artifacts",
			type_info = reflags.path_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "release",
			short = "r",
			description = "Build in release mode",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "features",
			description = "Space-separated list of features to enable",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "all-features",
			description = "Enable all available features",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "no-default-features",
			description = "Do not enable the default feature",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "jobs",
			short = "j",
			description = "Number of parallel jobs",
			type_info = reflags.int_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "keep-going",
			description = "Do not abort on first error",
			type_info = reflags.bool_type,
		},
	)
}

add_test_opts :: proc(c: ^reflags.Command) {
	append(
		&c.options,
		reflags.Option {
			name = "test",
			description = "Test only the specified test",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "no-run",
			description = "Compile but don't run tests",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "doc",
			description = "Build documentation",
			type_info = reflags.bool_type,
		},
	)
}

add_project_opts :: proc(c: ^reflags.Command) {
	append(
		&c.options,
		reflags.Option {
			name = "name",
			description = "Set the package name",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "vcs",
			description = "Initialize a new VCS repository (git, hg, pijul, fossil, none)",
			type_info = reflags.enum_type(
				[]string{"git", "hg", "pijul", "fossil", "none"},
			),
			default_str = "git",
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "edition",
			description = "Edition to set for the crate",
			type_info = reflags.enum_type(
				[]string{"2015", "2018", "2021", "2024"},
			),
			default_str = "2024",
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "bin",
			description = "Create a binary (application) project",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "lib",
			description = "Create a library project",
			type_info = reflags.bool_type,
		},
	)
}

add_dep_opts :: proc(c: ^reflags.Command) {
	append(
		&c.options,
		reflags.Option {
			name = "features",
			description = "Features to enable for the dependency",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "optional",
			description = "Dependency is optional",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "rename",
			description = "Rename the dependency",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "dev",
			description = "Add as a development dependency",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "build",
			description = "Add as a build dependency",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "target",
			description = "Target platform for the dependency",
			type_info = reflags.string_type,
		},
	)
}

add_remove_opts :: proc(c: ^reflags.Command) {
	append(
		&c.options,
		reflags.Option {
			name = "dev",
			description = "Remove from dev-dependencies",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "build",
			description = "Remove from build-dependencies",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "target",
			description = "Target platform for the dependency",
			type_info = reflags.string_type,
		},
	)
}

// ============================================================================
// Command Definitions
// ============================================================================

build_cmd :: proc() -> reflags.Command {
	c := reflags.command("build", "Compile the current package")
	c.long_desc = "Compile the current package and all of its dependencies.\n\nIf the package has multiple targets (binaries, examples, tests, etc.),\nthey will all be built by default. Use --bin, --example, --test, or\n--bench to build only a specific target."
	add_common_opts(&c)
	add_build_opts(&c)
	c.handler = build_handler
	return c
}

run_cmd :: proc() -> reflags.Command {
	c := reflags.command("run", "Build and execute the binary")
	c.long_desc = "Run a binary or example of the package. All arguments following\nthe two dashes (-- are passed to the binary."
	add_common_opts(&c)
	add_build_opts(&c)
	append(
		&c.arguments,
		reflags.Argument {
			name = "args",
			description = "Arguments to pass to the binary",
			type_info = reflags.string_type,
			required = false,
			variadic = true,
		},
	)
	c.handler = run_handler
	return c
}

test_cmd :: proc() -> reflags.Command {
	c := reflags.command("test", "Run tests")
	c.long_desc = "Run the tests of the package. By default, runs all tests.\n\nArguments after -- are passed to the test binary."
	add_common_opts(&c)
	add_build_opts(&c)
	add_test_opts(&c)
	append(
		&c.arguments,
		reflags.Argument {
			name = "args",
			description = "Arguments to pass to the test binary",
			type_info = reflags.string_type,
			required = false,
			variadic = true,
		},
	)
	c.handler = test_handler
	return c
}

check_cmd :: proc() -> reflags.Command {
	c := reflags.command("check", "Check the package for errors")
	c.long_desc = "Check the package for errors without building.\nThis is faster than a full build and is useful during development."
	add_common_opts(&c)
	add_build_opts(&c)
	c.handler = check_handler
	return c
}

clean_cmd :: proc() -> reflags.Command {
	c := reflags.command("clean", "Remove the target directory")
	c.long_desc = "Remove the target directory, cleaning all build artifacts."
	add_common_opts(&c)
	append(
		&c.options,
		reflags.Option {
			name = "target-dir",
			description = "Directory for all generated artifacts",
			type_info = reflags.path_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "package",
			short = "p",
			description = "Package to clean",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "target",
			description = "Build for the target triple",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "release",
			short = "r",
			description = "Clean release artifacts",
			type_info = reflags.bool_type,
		},
	)
	c.handler = clean_handler
	return c
}

doc_cmd :: proc() -> reflags.Command {
	c := reflags.command("doc", "Build documentation")
	c.long_desc = "Build the documentation for the package and all dependencies."
	add_common_opts(&c)
	add_build_opts(&c)
	append(
		&c.options,
		reflags.Option {
			name = "doc",
			description = "Build documentation",
			type_info = reflags.bool_type,
		},
	)
	c.handler = doc_handler
	return c
}

new_cmd :: proc() -> reflags.Command {
	c := reflags.command("new", "Create a new project")
	c.long_desc = "Create a new project at <path>.\n\nIf <path> is not specified, the project will be created in the\ncurrent directory."
	append(
		&c.options,
		reflags.Option {
			name = "verbose",
			short = "v",
			description = "Use verbose output",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "quiet",
			short = "q",
			description = "No output printed to stdout",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "color",
			description = "Coloring: auto, always, never",
			type_info = reflags.enum_type([]string{"auto", "always", "never"}),
			default_str = "auto",
		},
	)
	add_project_opts(&c)
	append(
		&c.arguments,
		reflags.Argument {
			name = "path",
			description = "Path to create the project",
			type_info = reflags.path_type,
			required = false,
		},
	)
	c.handler = new_handler
	return c
}

init_cmd :: proc() -> reflags.Command {
	c := reflags.command(
		"init",
		"Create a new project in an existing directory",
	)
	c.long_desc = "Create a new project in the current directory.\nThis is useful for initializing a project in an existing directory."
	append(
		&c.options,
		reflags.Option {
			name = "verbose",
			short = "v",
			description = "Use verbose output",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "quiet",
			short = "q",
			description = "No output printed to stdout",
			type_info = reflags.bool_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "color",
			description = "Coloring: auto, always, never",
			type_info = reflags.enum_type([]string{"auto", "always", "never"}),
			default_str = "auto",
		},
	)
	add_project_opts(&c)
	c.handler = init_handler
	return c
}

add_cmd :: proc() -> reflags.Command {
	c := reflags.command("add", "Add a dependency to the project")
	c.long_desc = "Add a dependency to the project. The dependency will be added\nto Cargo.toml and downloaded."
	add_common_opts(&c)
	add_dep_opts(&c)
	append(
		&c.arguments,
		reflags.Argument {
			name = "dependency",
			description = "Dependency to add (e.g., serde@1.0)",
			type_info = reflags.string_type,
			required = true,
		},
	)
	c.handler = add_handler
	return c
}

remove_cmd :: proc() -> reflags.Command {
	c := reflags.command("remove", "Remove a dependency from the project")
	c.alias = "rm"
	c.long_desc = "Remove a dependency from the project."
	add_common_opts(&c)
	add_remove_opts(&c)
	append(
		&c.arguments,
		reflags.Argument {
			name = "dependency",
			description = "Dependency to remove",
			type_info = reflags.string_type,
			required = true,
		},
	)
	c.handler = remove_handler
	return c
}

update_cmd :: proc() -> reflags.Command {
	c := reflags.command("update", "Update dependencies")
	c.long_desc = "Update dependencies in Cargo.lock to their latest versions."
	add_common_opts(&c)
	append(
		&c.options,
		reflags.Option {
			name = "package",
			short = "p",
			description = "Package to update",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.options,
		reflags.Option {
			name = "target",
			description = "Build for the target triple",
			type_info = reflags.string_type,
		},
	)
	append(
		&c.arguments,
		reflags.Argument {
			name = "packages",
			description = "Packages to update",
			type_info = reflags.string_type,
			required = false,
			variadic = true,
		},
	)
	c.handler = update_handler
	return c
}

metadata_cmd :: proc() -> reflags.Command {
	c := reflags.command("metadata", "Output metadata about the package")
	c.long_desc = "Output metadata about the package and its dependencies in JSON format."
	add_common_opts(&c)
	append(
		&c.options,
		reflags.Option {
			name = "format-version",
			description = "Metadata format version",
			type_info = reflags.int_type,
			default_str = "1",
		},
	)
	c.handler = metadata_handler
	return c
}

// ============================================================================
// CLI Application
// ============================================================================

CLI :: proc() -> reflags.CLI {
	c := reflags.command("cargo", "The Rust package manager")
	c.long_desc = "Cargo is the Rust package manager. It downloads your package's\ndependencies, compiles your packages, makes distributable packages,\nand uploads them to crates.io, the Rust community's package registry."
	add_common_opts(&c)

	cmds := []reflags.Command {
		build_cmd(),
		run_cmd(),
		test_cmd(),
		check_cmd(),
		clean_cmd(),
		doc_cmd(),
		new_cmd(),
		init_cmd(),
		add_cmd(),
		remove_cmd(),
		update_cmd(),
		metadata_cmd(),
	}
	for cmd in cmds {
		append(&c.subcommands, cmd)
	}

	root := new(reflags.Command)
	root^ = c

	return reflags.CLI {
		name = "cargo",
		version = "1.80.0",
		root_cmd = root,
		color_enabled = true,
	}
}
