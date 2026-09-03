package reflags

// ============================================================================
// Type Info Builders
// ============================================================================

// Preset Arg_Type_Info values for the common primitive types; pass these
// to opt_type / arg_type.
string_type :: Arg_Type_Info{.String, nil, nil}
int_type :: Arg_Type_Info{.Int, nil, nil}
float_type :: Arg_Type_Info{.Float, nil, nil}
bool_type :: Arg_Type_Info{.Bool, nil, nil}
path_type :: Arg_Type_Info{.Path, nil, nil}

// enum_type creates an Enum Arg_Type_Info restricted to the given values.
// The values are copied to a stable heap allocation so they outlive the
// input slice (which may come from context.temp_allocator).
enum_type :: proc(values: []string) -> Arg_Type_Info {
	// Copy values to a stable heap allocation, since the original
	// slice literals may be allocated on context.temp_allocator
	// which can be reset between function calls.
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
// Option Definition
// ============================================================================

// Option_Builder is a step-by-step builder for an Option; start with
// `option`, chain opt_* procedures, finish with opt_build.
Option_Builder :: struct {
	opt: Option,
}

// option starts building an option with the given long name and description.
// The result defaults to a non-required, non-hidden String option.
option :: proc(name, description: string) -> Option_Builder {
	return Option_Builder {
		opt = Option {
			name = name,
			description = description,
			type_info = string_type,
			required = false,
			hidden = false,
			multiple = false,
		},
	}
}

// opt_short sets the short name (e.g. "v" for -v).
opt_short :: proc(b: ^Option_Builder, short: string) -> bool {
	b.opt.short = short
	return true
}

// opt_required marks the option as required.
opt_required :: proc(b: ^Option_Builder) -> bool {
	b.opt.required = true
	return true
}

// opt_hidden hides the option from help output.
opt_hidden :: proc(b: ^Option_Builder) -> bool {
	b.opt.hidden = true
	return true
}

// opt_multiple allows the option to be repeated; values are joined with
// commas (read them back with get_strings).
opt_multiple :: proc(b: ^Option_Builder) -> bool {
	b.opt.multiple = true
	return true
}

// opt_default sets the default value (as a string, applied when the option
// is absent).
opt_default :: proc(b: ^Option_Builder, val: string) -> bool {
	b.opt.default_str = val
	return true
}

// opt_type sets the value type of the option.
opt_type :: proc(b: ^Option_Builder, t: Arg_Type_Info) -> bool {
	b.opt.type_info = t
	return true
}

// Build into a final Option
// opt_note appends an extra note shown under this option-in-progress in help.
// May be called multiple times; each note appears on its own line.
opt_note :: proc(b: ^Option_Builder, note: string) -> bool {
	append(&b.opt.notes, note)
	return true
}

// opt_build finalizes the builder and returns the constructed Option.
opt_build :: proc(b: Option_Builder) -> Option {
	return b.opt
}

// Convenience builders for common option types
// opt_flag builds a boolean flag option in one call (short may be "").
opt_flag :: proc(name, short, description: string) -> Option {
	b := option(name, description)
	opt_type(&b, bool_type)
	opt_short(&b, short)
	return opt_build(b)
}

// opt_str builds a String option in one call (short may be "").
opt_str :: proc(name, short, description: string) -> Option {
	b := option(name, description)
	opt_type(&b, string_type)
	opt_short(&b, short)
	return opt_build(b)
}

// opt_str_req builds a required String option in one call (short may be "").
opt_str_req :: proc(name, short, description: string) -> Option {
	b := option(name, description)
	opt_type(&b, string_type)
	opt_short(&b, short)
	opt_required(&b)
	return opt_build(b)
}

// opt_int builds an Int option in one call (short may be "").
opt_int :: proc(name, short, description: string) -> Option {
	b := option(name, description)
	opt_type(&b, int_type)
	opt_short(&b, short)
	return opt_build(b)
}

// opt_int_req builds a required Int option in one call (short may be "").
opt_int_req :: proc(name, short, description: string) -> Option {
	b := option(name, description)
	opt_type(&b, int_type)
	opt_short(&b, short)
	opt_required(&b)
	return opt_build(b)
}

// opt_float builds a Float option in one call (short may be "").
opt_float :: proc(name, short, description: string) -> Option {
	b := option(name, description)
	opt_type(&b, float_type)
	opt_short(&b, short)
	return opt_build(b)
}

// opt_path builds a Path option in one call (short may be "").
opt_path :: proc(name, short, description: string) -> Option {
	b := option(name, description)
	opt_type(&b, path_type)
	opt_short(&b, short)
	return opt_build(b)
}

// opt_enum builds an Enum option in one call, restricted to the given
// values, with an optional default (short may be "").
opt_enum :: proc(
	name, short, description: string,
	values: []string,
	default_val: string = "",
) -> Option {
	b := option(name, description)
	opt_type(&b, enum_type(values))
	opt_short(&b, short)
	if len(default_val) > 0 {
		b.opt.default_str = default_val
	}
	return opt_build(b)
}

// opt_custom builds a Custom option in one call, parsed by parse_fn
// (short may be "").
opt_custom :: proc(
	name, short, description: string,
	parse_fn: proc(_: string) -> (any, ^Re_Error),
) -> Option {
	b := option(name, description)
	opt_type(&b, custom_type(parse_fn))
	opt_short(&b, short)
	return opt_build(b)
}

// ============================================================================
// Argument Definition
// ============================================================================

// Argument_Builder is a step-by-step builder for an Argument; start with
// `argument`, chain arg_* procedures, finish with arg_build.
Argument_Builder :: struct {
	arg: Argument,
}

// argument starts building a positional argument. Defaults to required,
// String type.
argument :: proc(name, description: string) -> Argument_Builder {
	return Argument_Builder {
		arg = Argument {
			name = name,
			description = description,
			type_info = string_type,
			required = true,
			variadic = false,
			hidden = false,
		},
	}
}

// arg_type sets the value type of the argument.
arg_type :: proc(b: ^Argument_Builder, t: Arg_Type_Info) -> bool {
	b.arg.type_info = t
	return true
}

// arg_string builds a required String positional argument in one call.
arg_string :: proc(name, description: string) -> Argument {
	return argument(name, description).arg
}

// arg_int builds a required Int positional argument in one call.
arg_int :: proc(name, description: string) -> Argument {
	a := argument(name, description)
	arg_type(&a, int_type)
	return a.arg
}

// arg_float builds a required Float positional argument in one call.
arg_float :: proc(name, description: string) -> Argument {
	a := argument(name, description)
	arg_type(&a, float_type)
	return a.arg
}

// arg_path builds a required Path positional argument in one call.
arg_path :: proc(name, description: string) -> Argument {
	a := argument(name, description)
	arg_type(&a, path_type)
	return a.arg
}

// arg_bool builds a required Bool positional argument in one call.
arg_bool :: proc(name, description: string) -> Argument {
	a := argument(name, description)
	arg_type(&a, bool_type)
	return a.arg
}

// arg_enum builds a required Enum positional argument in one call,
// restricted to the given values.
arg_enum :: proc(name, description: string, values: []string) -> Argument {
	a := argument(name, description)
	arg_type(&a, enum_type(values))
	return a.arg
}

// arg_optional marks the argument as not required.
arg_optional :: proc(b: ^Argument_Builder) -> bool {
	b.arg.required = false
	return true
}

// arg_variadic makes the argument consume all remaining positional
// arguments (implies not required).
arg_variadic :: proc(b: ^Argument_Builder) -> bool {
	b.arg.variadic = true
	b.arg.required = false
	return true
}

// arg_hidden hides the argument from usage output.
arg_hidden :: proc(b: ^Argument_Builder) -> bool {
	b.arg.hidden = true
	return true
}

// arg_note appends an extra note shown under this argument-in-progress in
// help. May be called multiple times; each note appears on its own line.
arg_note :: proc(b: ^Argument_Builder, note: string) -> bool {
	append(&b.arg.notes, note)
	return true
}

// arg_build finalizes the builder and returns the constructed Argument.
arg_build :: proc(b: Argument_Builder) -> Argument {
	return b.arg
}

// ============================================================================
// Command Definition
// ============================================================================

// Command_Builder is a step-by-step builder for a Command; start with
// `command_builder`, chain cmd_* procedures, finish with cmd_build.
Command_Builder :: struct {
	cmd: Command,
}

// Simple command creation - returns a Command directly
// command creates a Command with the given name and description.
// Populate it directly (options, arguments, subcommands, handler) or use
// command_builder for a chained style.
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

// command_builder starts building a command with the given name and
// description.
command_builder :: proc(name, description: string) -> Command_Builder {
	return Command_Builder {
		cmd = Command {
			name = name,
			description = description,
			long_desc = "",
			handler = nil,
			hidden = false,
		},
	}
}

// cmd_long_desc sets the extended description shown in --help output.
cmd_long_desc :: proc(b: ^Command_Builder, desc: string) -> bool {
	b.cmd.long_desc = desc
	return true
}

// cmd_note appends an extra note to a Command while it's being built.
// May be called multiple times; each note appears on its own line.
cmd_note :: proc(b: ^Command_Builder, note: string) -> bool {
	append(&b.cmd.notes, note)
	return true
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

// cmd_add_option appends an option to the command.
cmd_add_option :: proc(b: ^Command_Builder, o: Option) -> bool {
	append(&b.cmd.options, o)
	return true
}

// cmd_add_argument appends a positional argument to the command.
cmd_add_argument :: proc(b: ^Command_Builder, a: Argument) -> bool {
	append(&b.cmd.arguments, a)
	return true
}

// cmd_add_subcommand appends a subcommand to the command.
cmd_add_subcommand :: proc(b: ^Command_Builder, sub: Command) -> bool {
	append(&b.cmd.subcommands, sub)
	return true
}

// cmd_set_handler assigns the handler invoked when the command is matched.
cmd_set_handler :: proc(b: ^Command_Builder, h: Command_Handler) -> bool {
	b.cmd.handler = h
	return true
}

// cmd_hide hides the command from command listings.
cmd_hide :: proc(b: ^Command_Builder) -> bool {
	b.cmd.hidden = true
	return true
}

// cmd_set_aliases sets alternative names that match this command.
cmd_set_aliase :: proc(b: ^Command_Builder, alias: string) -> bool {
	b.cmd.alias = alias
	return true
}

// cmd_build finalizes the builder and returns the constructed Command.
cmd_build :: proc(b: Command_Builder) -> Command {
	return b.cmd
}

// ============================================================================
// CLI Builder
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

// Helper to add global options to any command
// add_global_options appends the standard --help and --version options to
// a command builder.
add_global_options :: proc(b: ^Command_Builder) -> bool {
	opts := global_options()
	for o in opts {
		append(&b.cmd.options, o)
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
