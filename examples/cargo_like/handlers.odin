package cargo_example

import reflags "../.."
import "core:fmt"
import "core:os"

// ============================================================================
// Handler Implementations
// ============================================================================

build_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	release := reflags.get_bool(args, "release")
	verbose := reflags.get_bool(args, "verbose")
	pkg := reflags.get_string(args, "package")
	target := reflags.get_string(args, "target")
	jobs := reflags.get_int(args, "jobs")
	features := reflags.get_string(args, "features")
	all_features := reflags.get_bool(args, "all-features")
	no_default_features := reflags.get_bool(args, "no-default-features")

	if verbose {
		reflags.info_msg(os.stdout, "Building...")
	}

	if release {
		fmt.printf(
			"  %sCompiling%s %s v0.1.0 (%s)\n",
			reflags.color_bold,
			reflags.color_reset,
			"myapp",
			"release",
		)
	} else {
		fmt.printf(
			"  %sCompiling%s %s v0.1.0 (%s)\n",
			reflags.color_bold,
			reflags.color_reset,
			"myapp",
			"debug",
		)
	}

	if pkg != "" {
		fmt.printf("  Package: %s\n", pkg)
	}
	if target != "" {
		fmt.printf("  Target: %s\n", target)
	}
	if jobs > 0 {
		fmt.printf("  Jobs: %d\n", jobs)
	}
	if features != "" {
		fmt.printf("  Features: %s\n", features)
	}
	if all_features {
		fmt.println("  All features enabled")
	}
	if no_default_features {
		fmt.println("  Default features disabled")
	}

	reflags.success("Build completed successfully!")
	return nil
}

run_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	verbose := reflags.get_bool(args, "verbose")
	bin_name := reflags.get_string(args, "bin")
	example_name := reflags.get_string(args, "example")
	passed_args := reflags.get_strings(args, "args")

	if verbose {
		reflags.info_msg(os.stdout, "Building and running...")
	}

	target := "myapp"
	if bin_name != "" {
		target = bin_name
	} else if example_name != "" {
		target = example_name
	}

	fmt.printf(
		"  %sRunning%s %s\n",
		reflags.color_bold,
		reflags.color_reset,
		target,
	)

	if len(passed_args) > 0 {
		fmt.printf("  Args: %v\n", passed_args)
	}

	fmt.println(os.stdout, "Hello from the binary!")
	return nil
}

test_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	verbose := reflags.get_bool(args, "verbose")
	no_run := reflags.get_bool(args, "no-run")
	test_filter := reflags.get_string(args, "test")
	passed_args := reflags.get_strings(args, "args")

	if verbose {
		reflags.info_msg(os.stdout, "Testing...")
	}

	if no_run {
		fmt.println(os.to_stream(os.stdout), "  Compiling tests only...")
	} else {
		fmt.println(os.to_stream(os.stdout), "  Running tests...")
		if test_filter != "" {
			fmt.printf("  Filter: %s\n", test_filter)
		}
		fmt.printf(
			"  %stest%s tests::it_works ... %sok%s\n",
			reflags.color_bold,
			reflags.color_reset,
			reflags.color_green,
			reflags.color_reset,
		)
	}

	if len(passed_args) > 0 {
		fmt.printf("  Passed args: %v\n", passed_args)
	}

	reflags.success("All tests passed!")
	return nil
}

check_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	verbose := reflags.get_bool(args, "verbose")

	if verbose {
		reflags.info_msg(os.stdout, "Checking...")
	}

	fmt.println(os.to_stream(os.stdout), "  Checking myapp v0.1.0")
	reflags.success("Check completed successfully!")
	return nil
}

clean_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	verbose := reflags.get_bool(args, "verbose")

	if verbose {
		reflags.info_msg(os.stdout, "Cleaning...")
	}

	fmt.println(os.to_stream(os.stdout), "  Removing target directory")
	reflags.success("Clean completed!")
	return nil
}

doc_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	verbose := reflags.get_bool(args, "verbose")

	if verbose {
		reflags.info_msg(os.stdout, "Building documentation...")
	}

	fmt.println("  Documenting myapp v0.1.0")
	fmt.println("  Generating docs...")
	reflags.success("Documentation built successfully!")
	return nil
}

new_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	path := reflags.get_string(args, "path")
	name := reflags.get_string(args, "name")
	vcs := reflags.get_string(args, "vcs")
	edition := reflags.get_string(args, "edition")
	is_bin := reflags.get_bool(args, "bin")

	if path == "" {
		path = "."
	}
	if name == "" {
		name = "my_project"
	}

	proj_type := "library"
	if is_bin {
		proj_type = "binary"
	}

	fmt.printf(
		"  %sCreating%s %s project\n",
		reflags.color_bold,
		reflags.color_reset,
		proj_type,
	)
	fmt.printf("  Name: %s\n", name)
	fmt.printf("  Path: %s\n", path)
	fmt.printf("  VCS: %s\n", vcs)
	fmt.printf("  Edition: %s\n", edition)

	reflags.success(fmt.tprintf("Created %s project", proj_type))
	return nil
}

init_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	name := reflags.get_string(args, "name")
	vcs := reflags.get_string(args, "vcs")
	edition := reflags.get_string(args, "edition")
	is_bin := reflags.get_bool(args, "bin")

	if name == "" {
		name = "my_project"
	}

	proj_type := "library"
	if is_bin {
		proj_type = "binary"
	}

	fmt.printf(
		"  %sInitializing%s %s project\n",
		reflags.color_bold,
		reflags.color_reset,
		proj_type,
	)
	fmt.printf("  Name: %s\n", name)
	fmt.printf("  VCS: %s\n", vcs)
	fmt.printf("  Edition: %s\n", edition)

	reflags.success("Initialized project!")
	return nil
}

add_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	dep := reflags.get_string(args, "dependency")
	features := reflags.get_string(args, "features")
	optional := reflags.get_bool(args, "optional")
	rename := reflags.get_string(args, "rename")
	dev := reflags.get_bool(args, "dev")
	build := reflags.get_bool(args, "build")
	target := reflags.get_string(args, "target")

	fmt.printf(
		"  %sAdding%s dependency: %s\n",
		reflags.color_bold,
		reflags.color_reset,
		dep,
	)

	if features != "" {
		fmt.printf("  Features: %s\n", features)
	}
	if optional {
		fmt.println("  Optional: true")
	}
	if rename != "" {
		fmt.printf("  Renamed to: %s\n", rename)
	}
	if dev {
		fmt.println("  Type: dev-dependency")
	} else if build {
		fmt.println("  Type: build-dependency")
	} else {
		fmt.println("  Type: dependency")
	}
	if target != "" {
		fmt.printf("  Target: %s\n", target)
	}

	reflags.success(fmt.tprintf("Added dependency %s", dep))
	return nil
}

remove_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	dep := reflags.get_string(args, "dependency")
	dev := reflags.get_bool(args, "dev")
	build := reflags.get_bool(args, "build")
	target := reflags.get_string(args, "target")

	dep_type := "dependency"
	if dev {dep_type = "dev-dependency"} else if build {dep_type = "build-dependency"}

	fmt.printf(
		"  %sRemoving%s %s: %s\n",
		reflags.color_bold,
		reflags.color_reset,
		dep_type,
		dep,
	)

	if target != "" {
		fmt.printf("  Target: %s\n", target)
	}

	reflags.success(fmt.tprintf("Removed %s", dep))
	return nil
}

update_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	packages := reflags.get_strings(args, "packages")

	reflags.info_msg(os.stdout, "Updating dependencies...")

	if len(packages) > 0 {
		fmt.printf("  Packages: %v\n", packages)
	} else {
		fmt.println("  Updating all packages")
	}

	reflags.success("Dependencies updated!")
	return nil
}

metadata_handler :: proc(args: reflags.Parsed_Args) -> ^reflags.Error {
	format_version := reflags.get_int(args, "format-version")

	fmt.println("{")
	fmt.printf("  \"format_version\": %d,\n", format_version)
	fmt.println("  \"packages\": [")
	fmt.println("    {")
	fmt.println("      \"name\": \"myapp\",")
	fmt.println("      \"version\": \"0.1.0\",")
	fmt.println("      \"description\": \"\",")
	fmt.println("      \"dependencies\": []")
	fmt.println("    }")
	fmt.println("  ],")
	fmt.println("  \"resolve\": {}")
	fmt.println("}")

	return nil
}

// ============================================================================
// Helpers
// ============================================================================

cond_str :: proc(cond: bool, true_val, false_val: string) -> string {
	if cond {return true_val}
	return false_val
}
