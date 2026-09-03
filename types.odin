package reflags

import "core:os"
import "core:strconv"
import "core:strings"

// ============================================================================
// ANSI Color Helpers - Simple string constants for styled output
// ============================================================================

color_reset :: "\x1b[0m"
color_bold :: "\x1b[1m"
color_dim :: "\x1b[2m"
color_underline :: "\x1b[4m"

// Foreground colors (SGR codes)
color_red :: "\x1b[31m"
color_green :: "\x1b[32m"
color_yellow :: "\x1b[33m"
color_blue :: "\x1b[34m"
color_magenta :: "\x1b[35m"
color_cyan :: "\x1b[36m"
color_white :: "\x1b[37m"
color_bright_red :: "\x1b[91m"
color_bright_green :: "\x1b[92m"
color_bright_yellow :: "\x1b[93m"
color_bright_blue :: "\x1b[94m"
color_bright_magenta :: "\x1b[95m"
color_bright_cyan :: "\x1b[96m"
color_bright_white :: "\x1b[97m"

// Background colors
color_bg_red :: "\x1b[41m"
color_bg_green :: "\x1b[42m"

// ============================================================================
// Type System for Arguments/Options
// ============================================================================

// Arg_Type describes the kind of value an Option or Argument holds.
Arg_Type :: enum {
	String,
	Int,
	Bool,
	Float,
	Path,
	Enum,
	Custom,
}

// Arg_Type_Info describes how a value is parsed and validated, based on
// its Arg_Type kind. Use the presets (string_type, int_type, ...) or
// construct one with enum_type / custom_type.
Arg_Type_Info :: struct {
	kind:         Arg_Type,
	enum_values:  []string, // For Enum type
	custom_parse: proc(_: string) -> (any, ^Re_Error), // For Custom type
}

// ============================================================================
// Option Definition
// ============================================================================

// Option defines a command-line option (flag or value option), used with
// `--name` and optionally `-s`.
Option :: struct {
	name:        string, // Long name (e.g., "verbose")
	short:       string, // Short name (e.g., "v"), empty if none
	description: string, // Help text
	notes:       [dynamic]string, // Extra note lines shown under this option in help
	type_info:   Arg_Type_Info,
	default_str: string, // Default value as string (empty if none)
	required:    bool,
	hidden:      bool, // Hide from help
	multiple:    bool, // Can be specified multiple times (accumulates)
}

// ============================================================================
// Argument Definition (Positional)
// ============================================================================

// Argument defines a positional argument, matched in declaration order.
//
// notes are extra lines shown under this argument in the help page.
Argument :: struct {
	name:        string, // Name for help display
	description: string, // Help text
	notes:       [dynamic]string, // Extra note lines shown under this argument
	type_info:   Arg_Type_Info,
	required:    bool,
	variadic:    bool, // Consumes all remaining args
	hidden:      bool,
}

// ============================================================================
// Command Definition
// ============================================================================

// Command_Handler is the signature for a command's handler. It is invoked
// with the Parsed_Args of the matched command; return nil on success or an
// ^Error (see make_error) on failure. A Help_Requested or Version_Requested
// error makes print_error print the help/version output instead.
Command_Handler :: proc(args: Parsed_Args) -> ^Error

// Command defines a command (or the root command of a CLI). It may carry
// options, positional arguments, nested subcommands, aliases, and a handler.
Command :: struct {
	name:        string,
	description: string,
	long_desc:   string, // Extended description (shown with --help)
	notes:       [dynamic]string, // Extra note lines shown in this command's help
	options:     [dynamic]Option,
	arguments:   [dynamic]Argument,
	subcommands: [dynamic]Command,
	handler:     Command_Handler,
	hidden:      bool,
	alias:       string, // Alternative name
}

// ============================================================================
// Parsed Arguments Result
// ============================================================================

// Parsed_Args is the result of a successful parse. `command` points at the
// matched command, `values` maps option/argument names to parsed string
// values (read them back with the get_* accessors), and `positionals` holds
// the raw positional arguments. Call destroy when finished.
Parsed_Args :: struct {
	command:     ^Command, // The matched command (or root)
	values:      map[string]string, // option/arg name -> string value
	positionals: []string, // Raw positional args
	raw_args:    []string, // All raw args after command
}

// Get a typed value from parsed args
// get_string returns the value of `name` as a string, or default_val if it
// was not provided.
get_string :: proc(
	args: Parsed_Args,
	name: string,
	default_val: string = "",
) -> string {
	if val, ok := args.values[name]; ok {
		return val
	}
	return default_val
}

// get_int returns the value of `name` parsed as an int, or default_val if
// it was not provided or cannot be parsed.
get_int :: proc(args: Parsed_Args, name: string, default_val: int = 0) -> int {
	if val, ok := args.values[name]; ok {
		if i, ok := strconv.parse_int(val, 10); ok {
			return int(i)
		}
	}
	return default_val
}

// get_bool returns the value of `name` parsed as a bool ("true"/"1" are
// true), or default_val if it was not provided.
get_bool :: proc(
	args: Parsed_Args,
	name: string,
	default_val: bool = false,
) -> bool {
	if val, ok := args.values[name]; ok {
		if b, ok := strconv.parse_bool(val); ok {
			return b
		}
		if val == "true" || val == "1" {
			return true
		}
	}
	return default_val
}

// get_float returns the value of `name` parsed as an f64, or default_val if
// it was not provided or cannot be parsed.
get_float :: proc(
	args: Parsed_Args,
	name: string,
	default_val: f64 = 0.0,
) -> f64 {
	if val, ok := args.values[name]; ok {
		if f, ok := strconv.parse_f64(val); ok {
			return f
		}
	}
	return default_val
}

// get_strings splits the value of `name` on commas and returns the pieces.
// Useful for `multiple` options and `variadic` arguments; returns nil if the
// name was not provided.
get_strings :: proc(args: Parsed_Args, name: string) -> []string {
	if val, ok := args.values[name]; ok {
		if val == "" {
			return nil
		}
		// Split comma-separated values for multiple options
		return strings.split(val, ",", context.allocator)
	}
	return nil
}

// get_enum returns the value of `name` and true if it was provided,
// otherwise ("", false).
get_enum :: proc(args: Parsed_Args, name: string) -> (string, bool) {
	if val, ok := args.values[name]; ok {
		return val, true
	}
	return "", false
}

// ============================================================================
// Cleanup
// ============================================================================

// destroy frees the maps and slices allocated inside a Parsed_Args. Use it
// (typically with defer) after you are done with the result of parse.
destroy :: proc(args: Parsed_Args) {
	delete(args.values)
	delete(args.positionals)
}

// ============================================================================
// Error Types
// ============================================================================

// Error_Reason enumerates the categories of errors the parser can produce.
// Help_Requested and Version_Requested are pseudo-errors used to trigger
// help/version output.
Error_Reason :: enum {
	None,
	Unknown_Command,
	Unknown_Option,
	Missing_Required_Option,
	Missing_Required_Argument,
	Invalid_Value,
	Extra_Arguments,
	Parse_Error,
	Help_Requested,
	Version_Requested,
}

// Error describes a parsing or validation failure (or a help/version
// request). See make_error for constructing one.
Re_Error :: struct {
	reason:  Error_Reason,
	message: string,
	command: ^Command, // Command context where error occurred
	option:  string, // Option name if applicable
}

Error :: union {
	Re_Error,
	os.Error,
}

// Parsing_Style selects the command-line syntax accepted by parse.
//
// `.Unix` (default) accepts `--flag`, `--flag=value`, `--flag value`, and
// bundled short flags (`-abc`).
//
// `.Odin` mirrors core:flags' Odin style: flags are introduced with a
// single dash (`-flag`), value options take an attached value
// (`-flag:value` or `-flag=value`), and underscores in flag names are
// treated as dashes (`-no_git` matches an option named `no-git`).
Parsing_Style :: enum {
	Odin,
	Unix,
}

// CLI is the top-level application descriptor: name, version, description,
// the root command, whether colored output is enabled, and which parsing
// style to use. Build one with make_cli / make_cli_no_color.
CLI :: struct {
	name:          string,
	version:       string,
	root_cmd:      ^Command,
	color_enabled: bool,
	style:         Parsing_Style,
}
