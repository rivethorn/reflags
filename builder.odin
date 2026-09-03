package reflags

// ============================================================================
// Type Info Presets
// ============================================================================

// Preset Arg_Type_Info values for the common primitive types.
string_type :: Arg_Type_Info{.String, nil, nil}
int_type :: Arg_Type_Info{.Int, nil, nil}
float_type :: Arg_Type_Info{.Float, nil, nil}
bool_type :: Arg_Type_Info{.Bool, nil, nil}
path_type :: Arg_Type_Info{.Path, nil, nil}

// enum_type creates an Enum Arg_Type_Info restricted to the given values.
// The values are copied to a stable heap allocation so they outlive the
// input slice (which may come from context.temp_allocator).
enum_type :: proc(values: []string) -> Arg_Type_Info {
	result := make([dynamic]string)
	for v in values {
		append(&result, v)
	}
	return Arg_Type_Info{.Enum, result[:], nil}
}


// custom_type creates a Custom Arg_Type_Info that delegates parsing to the
// supplied procedure.
custom_type :: proc(
	parse_fn: proc(_: string) -> (any, ^Re_Error),
) -> Arg_Type_Info {
	return Arg_Type_Info{.Custom, nil, parse_fn}
}

// ============================================================================
// Option Factories - thin helpers over the Option struct
// ============================================================================

// opt_flag builds a boolean flag option in one call (short may be "").
opt_flag :: proc(name, short, description: string) -> Option {
	return Option{name = name, short = short, description = description, type_info = bool_type}
}

// opt_str builds a String option in one call (short may be "").
opt_str :: proc(name, short, description: string) -> Option {
	return Option{name = name, short = short, description = description, type_info = string_type}
}

// opt_str_req builds a required String option in one call (short may be "").
opt_str_req :: proc(name, short, description: string) -> Option {
	return Option{name = name, short = short, description = description, type_info = string_type, required = true}
}

// opt_int builds an Int option in one call (short may be "").
opt_int :: proc(name, short, description: string) -> Option {
	return Option{name = name, short = short, description = description, type_info = int_type}
}

// opt_int_req builds a required Int option in one call (short may be "").
opt_int_req :: proc(name, short, description: string) -> Option {
	return Option{name = name, short = short, description = description, type_info = int_type, required = true}
}

// opt_float builds a Float option in one call (short may be "").
opt_float :: proc(name, short, description: string) -> Option {
	return Option{name = name, short = short, description = description, type_info = float_type}
}

// opt_path builds a Path option in one call (short may be "").
opt_path :: proc(name, short, description: string) -> Option {
	return Option{name = name, short = short, description = description, type_info = path_type}
}

// opt_enum builds an Enum option in one call, restricted to the given
// values, with an optional default (short may be "").
opt_enum :: proc(
	name, short, description: string,
	values: []string,
	default_val: string = "",
) -> Option {
	return Option{name = name, short = short, description = description, type_info = enum_type(values), default_str = default_val}
}

// opt_custom builds a Custom option in one call, parsed by parse_fn
// (short may be "").
opt_custom :: proc(
	name, short, description: string,
	parse_fn: proc(_: string) -> (any, ^Re_Error),
) -> Option {
	return Option{name = name, short = short, description = description, type_info = custom_type(parse_fn)}
}

// ============================================================================
// Argument Factories - thin helpers over the Argument struct
// ============================================================================

// arg_string builds a required String positional argument in one call.
arg_string :: proc(name, description: string) -> Argument {
	return Argument{name = name, description = description, type_info = string_type, required = true}
}

// arg_int builds a required Int positional argument in one call.
arg_int :: proc(name, description: string) -> Argument {
	return Argument{name = name, description = description, type_info = int_type, required = true}
}

// arg_float builds a required Float positional argument in one call.
arg_float :: proc(name, description: string) -> Argument {
	return Argument{name = name, description = description, type_info = float_type, required = true}
}

// arg_path builds a required Path positional argument in one call.
arg_path :: proc(name, description: string) -> Argument {
	return Argument{name = name, description = description, type_info = path_type, required = true}
}

// arg_bool builds a required Bool positional argument in one call.
arg_bool :: proc(name, description: string) -> Argument {
	return Argument{name = name, description = description, type_info = bool_type, required = true}
}

// arg_enum builds a required Enum positional argument in one call,
// restricted to the given values.
arg_enum :: proc(name, description: string, values: []string) -> Argument {
	return Argument{name = name, description = description, type_info = enum_type(values), required = true}
}

// ============================================================================
// Command Helper
// ============================================================================

// command creates a Command with the given name and description.
// Populate it directly (options, arguments, subcommands, handler).
command :: proc(name: string, description: Maybe(string)) -> Command {
	desc, ok := description.?
	return Command {
		name = name,
		description = ok ? desc : "",
		long_desc = "",
		handler = nil,
		hidden = false,
	}
}

// option_note appends an extra note to an already-built Option.
// Convenient when constructing an Option with opt_flag/opt_str/etc. and
// you still want to attach notes before adding it to a command.
option_note :: proc(opt: ^Option, note: string) {
	append(&opt.notes, note)
}

// command_note appends an extra note to an already-built Command.
// Convenient when constructing a Command with `command` directly.
command_note :: proc(c: ^Command, note: string) {
	append(&c.notes, note)
}

// ============================================================================
// CLI Helpers
// ============================================================================

// make_cli creates a CLI descriptor with color output enabled.
make_cli :: proc(name, version: string, root: ^Command) -> CLI {
	return CLI {
		name = name,
		version = version,
		root_cmd = root,
		color_enabled = true,
	}
}

// make_cli_no_color creates a CLI descriptor with color output disabled.
make_cli_no_color :: proc(name, version: string, root: ^Command) -> CLI {
	return CLI {
		name = name,
		version = version,
		root_cmd = root,
		color_enabled = false,
	}
}

// ============================================================================
// Common Global Options
// ============================================================================

// help_option returns the standard --help/-h boolean flag.
help_option :: proc() -> Option {
	return Option {
		name = "help",
		short = "h",
		description = "Print help information",
		type_info = bool_type,
	}
}

// version_option returns the standard --version/-V boolean flag.
version_option :: proc() -> Option {
	return Option {
		name = "version",
		short = "V",
		description = "Print version information",
		type_info = bool_type,
	}
}

// global_options returns a dynamic array with the standard --help and
// --version options.
global_options :: proc() -> [dynamic]Option {
	result: [dynamic]Option
	append(&result, help_option())
	append(&result, version_option())
	return result
}

// add_global_options appends the standard --help and --version options to
// a command.
add_global_options :: proc(c: ^Command) -> bool {
	opts := global_options()
	for o in opts {
		append(&c.options, o)
	}
	return true
}

// ============================================================================
// Common Option Groups
// ============================================================================

verbose_option :: Option {
	name        = "verbose",
	short       = "v",
	description = "Use verbose output",
	type_info   = bool_type,
}

quiet_option :: Option {
	name        = "quiet",
	short       = "q",
	description = "No output printed to stdout",
	type_info   = bool_type,
}

// color_option returns a --color option accepting auto|always|never,
// defaulting to auto.
color_option :: proc() -> Option {
	return Option {
		name = "color",
		description = "Coloring: auto, always, never",
		type_info = enum_type({"auto", "always", "never"}),
		default_str = "auto",
	}
}

// build_options returns a dynamic array with the common --verbose,
// --quiet, and --color options.
build_options :: proc() -> [dynamic]Option {
	result: [dynamic]Option
	append(&result, verbose_option)
	append(&result, quiet_option)
	append(&result, color_option())
	return result
}
