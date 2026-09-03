package reflags

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

// ============================================================================
// Parsing Context
// ============================================================================

// Parse_Ctx holds the internal state of a parse in progress. Most callers
// should just use parse / parse_or_exit.
Parse_Ctx :: struct {
	cli:              ^CLI,
	current_cmd:      ^Command,
	args:             []string,
	values:           map[string]string,
	positionals:      [dynamic]string,
	seen_options:     map[string]bool,
	seen_positionals: int,
	strict:           bool,
	style:            Parsing_Style,
}

// ============================================================================
// Main Entry Point
// ============================================================================

// parse parses args (typically os.args[1:]) against the CLI's command
// tree. It matches commands/subcommands (including aliases), parses options
// and positional arguments, and validates required fields / applies
// defaults. Returns the parsed result or an ^Error. Call destroy on the
// result when done.
parse :: proc(
	cli: ^CLI,
	args: []string,
	strict: bool = true,
) -> (
	Parsed_Args,
	^Re_Error,
) {
	ctx := Parse_Ctx {
		cli          = cli,
		current_cmd  = cli.root_cmd,
		args         = args,
		values       = make(map[string]string),
		positionals  = make([dynamic]string),
		seen_options = make(map[string]bool),
		strict       = strict,
		style        = cli.style,
	}

	// Parse command hierarchy
	if err := parse_commands(&ctx); err != nil {
		delete(ctx.values)
		delete(ctx.positionals)
		delete(ctx.seen_options)
		return Parsed_Args{}, err
	}

	// Parse options and arguments for the final command
	if err := parse_options_and_args(&ctx); err != nil {
		delete(ctx.values)
		delete(ctx.positionals)
		delete(ctx.seen_options)
		return Parsed_Args{}, err
	}

	// Validate required options/args
	if err := validate_parsed(&ctx); err != nil {
		delete(ctx.values)
		delete(ctx.positionals)
		delete(ctx.seen_options)
		return Parsed_Args{}, err
	}

	parsed: Parsed_Args
	parsed.command = ctx.current_cmd
	parsed.values = ctx.values
	parsed.positionals = ctx.positionals[:]

	return parsed, nil
}

// parse_or_exit is a convenience wrapper around parse: on error it prints
// the error (help/version reasons exit 0, everything else exits 1). The
// caller must still call destroy on the result.
parse_or_exit :: proc(cli: ^CLI, args: []string) -> Parsed_Args {
	parsed, err := parse(cli, args, true)
	if err != nil {
		print_error(cli, err)
		if err.reason == .Help_Requested || err.reason == .Version_Requested {
			os.exit(0)
		}
		os.exit(1)
	}
	return parsed
}

// ============================================================================
// Command Parsing
// ============================================================================

// parse_commands walks the command tree, consuming subcommand names from
// the front of the args. Stops at the first flag or unmatched positional.
parse_commands :: proc(ctx: ^Parse_Ctx) -> ^Re_Error {
	for len(ctx.args) > 0 {
		arg := ctx.args[0]

		// Check for help/version flags early
		if arg == "--help" || arg == "-h" || arg == "-help" {
			return make_error(.Help_Requested, "", ctx.current_cmd)
		}
		if arg == "--version" || arg == "-V" || arg == "-version" {
			return make_error(.Version_Requested, "", ctx.current_cmd)
		}

		// Stop at first non-flag (positional or subcommand)
		if !strings.has_prefix(arg, "-") {
			// Try to match as subcommand
			if matched := try_match_subcommand(ctx, arg); matched {
				ctx.args = ctx.args[1:]
				continue
			}
			// Not a subcommand, stop command parsing
			break
		}

		// It's a flag but we're still in command parsing phase
		// This means it's a global option - stop command parsing
		break
	}
	return nil
}

// try_match_subcommand advances ctx.current_cmd to the subcommand named
// `name` (matching aliases too) and reports whether it matched.
try_match_subcommand :: proc(ctx: ^Parse_Ctx, name: string) -> bool {
	for i in 0 ..< len(ctx.current_cmd.subcommands) {
		cmd := &ctx.current_cmd.subcommands[i]
		if cmd.name == name {
			ctx.current_cmd = cmd
			return true
		}
		// Check aliases
		if cmd.alias == name {
			ctx.current_cmd = cmd
			return true
		}
	}
	return false
}

// ============================================================================
// Option and Argument Parsing
// ============================================================================

// parse_options_and_args parses long/short options and positional
// arguments for the current command.
parse_options_and_args :: proc(ctx: ^Parse_Ctx) -> ^Re_Error {
	if ctx.style == .Odin {
		return parse_options_and_args_odin(ctx)
	}

	cmd := ctx.current_cmd

	// Build option lookup maps
	long_options := make(map[string]^Option)
	short_options := make(map[string]^Option)
	defer delete(long_options)
	defer delete(short_options)

	for i in 0 ..< len(cmd.options) {
		opt := &cmd.options[i]
		long_options[opt.name] = opt
		if len(opt.short) > 0 {
			short_options[opt.short] = opt
		}
	}

	// Parse arguments
	arg_index := 0
	i := 0
	only_positionals := false
	for i < len(ctx.args) {
		arg := ctx.args[i]

		// `--` ends option parsing; everything after is positional.
		if !only_positionals && arg == "--" {
			only_positionals = true
			i += 1
			continue
		}

		if only_positionals {
			if err := parse_positional(ctx, arg, cmd, &arg_index); err != nil {
				return err
			}
			arg_index += 1
		} else if strings.has_prefix(arg, "--") {
			// Long option: --name or --name=value
			if err := parse_long_option(ctx, arg, long_options); err != nil {
				return err
			}
		} else if strings.has_prefix(arg, "-") && len(arg) > 1 {
			// Short option(s): -v, -abc, -o value, -o=value
			if err := parse_short_options(ctx, arg, short_options, &i);
			   err != nil {
				return err
			}
		} else {
			// Positional argument
			if err := parse_positional(ctx, arg, cmd, &arg_index); err != nil {
				return err
			}
			arg_index += 1
		}
		i += 1
	}

	return nil
}

// parse_long_option handles a single `--name`, `--name=value` argument.
parse_long_option :: proc(
	ctx: ^Parse_Ctx,
	arg: string,
	options: map[string]^Option,
) -> ^Re_Error {
	name_value := arg[2:] // strip --

	name: string
	value: string
	has_value: bool

	if eq_idx := strings.index_byte(name_value, '='); eq_idx != -1 {
		name = name_value[:eq_idx]
		value = name_value[eq_idx + 1:]
		has_value = true
	} else {
		name = name_value
		has_value = false
	}

	opt_ptr, ok := options[name]
	if !ok {
		return make_error(
			.Unknown_Option,
			fmt.tprintf("Unknown option: --%s", name),
			ctx.current_cmd,
			name,
		)
	}
	opt := opt_ptr^

	if opt.type_info.kind == .Bool {
		if has_value {
			return make_error(
				.Invalid_Value,
				fmt.tprintf("Boolean option --%s does not take a value", name),
				ctx.current_cmd,
				name,
			)
		}
		ctx.values[name] = "true"
		ctx.seen_options[name] = true
	} else {
		if !has_value {
			// Need to consume next arg as value
			return make_error(
				.Missing_Required_Option,
				fmt.tprintf("Option --%s requires a value", name),
				ctx.current_cmd,
				name,
			)
		}
		parsed_val, err := parse_value(value, opt.type_info)
		if err != nil {
			return err
		}
		if opt.multiple {
			existing := ctx.values[name]
			if existing != "" {
				// Join existing and new with comma separator
				ctx.values[name] = strings.concatenate(
					{existing, ",", parsed_val},
				)
			} else {
				ctx.values[name] = parsed_val
			}
		} else {
			ctx.values[name] = parsed_val
		}
		ctx.seen_options[name] = true
	}

	return nil
}

// parse_short_options handles a `-...` cluster: bundled flags (-abc),
// attached values (-o=value, -ovalue), and separated values (-o value).
parse_short_options :: proc(
	ctx: ^Parse_Ctx,
	arg: string,
	options: map[string]^Option,
	index_ptr: ^int,
) -> ^Re_Error {
	// Handle bundled short options: -abc, -o value, -o=value
	shorts := arg[1:] // strip -

	for j := 0; j < len(shorts); j += 1 {
		short := shorts[j:j + 1]

		opt_ptr, ok := options[short]
		if !ok {
			return make_error(
				.Unknown_Option,
				fmt.tprintf("Unknown option: -%s", short),
				ctx.current_cmd,
				short,
			)
		}
		opt := opt_ptr^

		if opt.type_info.kind == .Bool {
			ctx.values[opt.name] = "true"
			ctx.seen_options[opt.name] = true
		} else {
			// Option takes a value
			// Check if value is attached: -o=value or -ovalue
			if j + 1 < len(shorts) {
				// -ovalue (rest of string is value)
				// Check if there's an = sign
				if shorts[j + 1] == '=' {
					value := shorts[j + 2:]
					parsed_val, err := parse_value(value, opt.type_info)
					if err != nil {
						return err
					}
					if opt.multiple {
						existing := ctx.values[opt.name]
						if existing != "" {
							ctx.values[opt.name] = strings.concatenate(
								{existing, ",", parsed_val},
							)
						} else {
							ctx.values[opt.name] = parsed_val
						}
					} else {
						ctx.values[opt.name] = parsed_val
					}
					ctx.seen_options[opt.name] = true
					break
				}
				// Otherwise, rest is value
				value := shorts[j + 1:]
				parsed_val, err := parse_value(value, opt.type_info)
				if err != nil {
					return err
				}
				if opt.multiple {
					existing := ctx.values[opt.name]
					if existing != "" {
						ctx.values[opt.name] = strings.concatenate(
							{existing, ",", parsed_val},
						)
					} else {
						ctx.values[opt.name] = parsed_val
					}
				} else {
					ctx.values[opt.name] = parsed_val
				}
				ctx.seen_options[opt.name] = true
				break
			} else if index_ptr^ + 1 < len(ctx.args) {
				// -o value (next arg is value)
				index_ptr^ += 1
				value := ctx.args[index_ptr^]
				if strings.has_prefix(value, "-") {
					return make_error(
						.Missing_Required_Option,
						fmt.tprintf("Option -%s requires a value", short),
						ctx.current_cmd,
						opt.name,
					)
				}
				parsed_val, err := parse_value(value, opt.type_info)
				if err != nil {
					return err
				}
				if opt.multiple {
					existing := ctx.values[opt.name]
					if existing != "" {
						ctx.values[opt.name] = strings.concatenate(
							{existing, ",", parsed_val},
						)
					} else {
						ctx.values[opt.name] = parsed_val
					}
				} else {
					ctx.values[opt.name] = parsed_val
				}
				ctx.seen_options[opt.name] = true
			} else {
				return make_error(
					.Missing_Required_Option,
					fmt.tprintf("Option -%s requires a value", short),
					ctx.current_cmd,
					opt.name,
				)
			}
		}
	}

	return nil
}

// parse_positional matches one positional argument against the command's
// argument definitions, handling variadic trailing arguments.
parse_positional :: proc(
	ctx: ^Parse_Ctx,
	arg: string,
	cmd: ^Command,
	arg_index: ^int,
) -> ^Re_Error {
	// Find the argument definition for this position
	arg_def_index := -1
	for i in 0 ..< len(cmd.arguments) {
		a := &cmd.arguments[i]
		if a.variadic {
			arg_def_index = i
			break
		}
		if arg_index^ == i {

			arg_def_index = i
			arg_def_index = i
			break
		}
	}

	if arg_def_index == -1 {
		// No more argument definitions - check if last arg is variadic
		if len(cmd.arguments) > 0 &&
		   cmd.arguments[len(cmd.arguments) - 1].variadic {
			arg_def_index = len(cmd.arguments) - 1
		} else {
			return make_error(
				.Extra_Arguments,
				fmt.tprintf("Unexpected argument: %s", arg),
				cmd,
			)
		}
	}

	arg_def := &cmd.arguments[arg_def_index]

	parsed_val, err := parse_value(arg, arg_def.type_info)
	if err != nil {
		return err
	}

	if arg_def.variadic {
		// Accumulate into comma-separated string
		key := arg_def.name
		existing := ctx.values[key]
		if existing != "" {
			ctx.values[key] = strings.concatenate({existing, ",", parsed_val})
		} else {
			ctx.values[key] = parsed_val
		}
	} else {
		ctx.values[arg_def.name] = parsed_val
	}

	append(&ctx.positionals, arg)
	ctx.seen_positionals += 1

	return nil
}

// ============================================================================
// Value Parsing
// ============================================================================

// parse_value converts a raw string to the type described by type_info,
// returning it as a normalized string or an Invalid_Value / Parse_Error.
parse_value :: proc(
	value: string,
	type_info: Arg_Type_Info,
) -> (
	string,
	^Re_Error,
) {
	switch type_info.kind {
	case .String:
		return value, nil
	case .Int:
		i, ok := strconv.parse_int(value, 10)
		if !ok {
			return "", make_error(
				.Invalid_Value,
				fmt.tprintf("Invalid integer: %s", value),
			)
		}
		return fmt.tprintf("%d", i), nil
	case .Float:
		f, ok := strconv.parse_f64(value)
		if !ok {
			return "", make_error(
				.Invalid_Value,
				fmt.tprintf("Invalid float: %s", value),
			)
		}
		return fmt.tprintf("%g", f), nil
	case .Bool:
		b, ok := strconv.parse_bool(value)
		if !ok {
			return "", make_error(
				.Invalid_Value,
				fmt.tprintf("Invalid boolean: %s", value),
			)
		}
		if b {
			return "true", nil
		}
		return "false", nil
	case .Path:
		return value, nil
	case .Enum:
		found := false
		for ev in type_info.enum_values {
			if ev == value {
				found = true
				break
			}
		}
		if !found {
			return "", make_error(
				.Invalid_Value,
				fmt.tprintf(
					"Invalid value '%s'. Valid values: %s",
					value,
					strings.join(
						type_info.enum_values,
						"|",
						context.temp_allocator,
					),
				),
			)
		}
		return value, nil
	case .Custom:
		if type_info.custom_parse != nil {
			val, err := type_info.custom_parse(value)
			if err != nil {
				return "", err
			}
			// Convert any to string for storage
			switch v in val {
			case string:
				return v, nil
			case int:
				return fmt.tprintf("%d", v), nil
			case bool:
				if v {return "true", nil}; return "false", nil
			case f64:
				return fmt.tprintf("%g", v), nil
			}
			return "", make_error(
				.Parse_Error,
				"Unhandled custom parse result type",
			)
		}
		return "", make_error(.Parse_Error, "Custom parser not provided")
	}
	return "", make_error(
		.Parse_Error,
		fmt.tprintf("Unknown type kind: %v", type_info.kind),
	)
}

// ============================================================================
// Validation
// ============================================================================

// validate_parsed checks that required options/arguments were provided and
// applies defaults for absent options that have one.
validate_parsed :: proc(ctx: ^Parse_Ctx) -> ^Re_Error {
	cmd := ctx.current_cmd

	// Check required options and apply defaults
	for i in 0 ..< len(cmd.options) {
		opt := &cmd.options[i]
		if !ctx.seen_options[opt.name] {
			if opt.required && len(opt.default_str) == 0 {
				return make_error(
					.Missing_Required_Option,
					fmt.tprintf("Required option --%s not provided", opt.name),
					cmd,
					opt.name,
				)
			}
			// Apply default value if present
			if len(opt.default_str) > 0 {
				val, err := parse_value(opt.default_str, opt.type_info)
				if err != nil {
					return make_error(
						.Invalid_Value,
						fmt.tprintf(
							"Invalid default value for --%s: %s",
							opt.name,
							err.message,
						),
						cmd,
						opt.name,
					)
				}
				ctx.values[opt.name] = val
			}
		}
	}

	// Check required arguments
	required_args := 0
	for i in 0 ..< len(cmd.arguments) {
		if cmd.arguments[i].required {
			required_args += 1
		}
	}

	if ctx.seen_positionals < required_args {
		// Find which required arg is missing
		for i in 0 ..< len(cmd.arguments) {
			if cmd.arguments[i].required && i >= ctx.seen_positionals {
				return make_error(
					.Missing_Required_Argument,
					fmt.tprintf(
						"Missing required argument: %s",
						cmd.arguments[i].name,
					),
					cmd,
				)
			}
		}
	}

	return nil
}

// ============================================================================
// Error Creation Helper
// ============================================================================

// make_error allocates an Error with the given reason, message, and
// optional command/option context.
make_error :: proc(
	reason: Error_Reason,
	message: string,
	cmd: ^Command = nil,
	opt: string = "",
) -> ^Re_Error {
	err := new(Re_Error)
	err.reason = reason
	err.message = message
	err.command = cmd
	err.option = opt
	return err
}
// ============================================================================
// Odin-Style Parsing (like core:flags)
// ============================================================================

// parse_options_and_args_odin parses options and positionals using the
// Odin-style syntax: `-flag` sets a bool, `-flag:value` / `-flag=value`
// attach a value (value options require an attached value), underscores in
// flag names are treated as dashes, and everything not starting with `-`
// (or following `--`) is a positional argument.
parse_options_and_args_odin :: proc(ctx: ^Parse_Ctx) -> ^Re_Error {
	cmd := ctx.current_cmd

	// Odin style has no short flags; only the long name is recognized.
	long_options := make(map[string]^Option)
	defer delete(long_options)

	for i in 0 ..< len(cmd.options) {
		opt := &cmd.options[i]
		long_options[opt.name] = opt
	}

	arg_index := 0
	only_positionals := false
	i := 0
	for i < len(ctx.args) {
		arg := ctx.args[i]

		// `--` ends option parsing; everything after is positional.
		if !only_positionals && arg == "--" {
			only_positionals = true
			i += 1
			continue
		}

		if only_positionals || len(arg) < 2 || arg[0] != '-' {
			if err := parse_positional(ctx, arg, cmd, &arg_index); err != nil {
				return err
			}
			arg_index += 1
			i += 1
			continue
		}

		// Odin-style flag: -flag, -flag:value
		body := arg[1:]
		name := body
		value := ""
		has_value := false
		if colon_idx := strings.index_byte(body, ':'); colon_idx != -1 {
			name, value, has_value =
				body[:colon_idx], body[colon_idx + 1:], true
		}

		// Underscores in flag names are treated as dashes (like core:flags).
		if strings.index_byte(name, '_') != -1 {
			name, _ = strings.replace_all(
				name,
				"_",
				"-",
				context.temp_allocator,
			)
		}

		// Only the long (real) name matches; `-r` would look up an option
		// literally named "r", which does not exist.
		opt_ptr, ok := long_options[name]
		if !ok {
			return make_error(
				.Unknown_Option,
				fmt.tprintf("Unknown option: -%s", name),
				ctx.current_cmd,
				name,
			)
		}
		opt := opt_ptr^

		if opt.type_info.kind == .Bool {
			if has_value {
				return make_error(
					.Invalid_Value,
					fmt.tprintf(
						"Boolean option -%s does not take a value",
						name,
					),
					ctx.current_cmd,
					name,
				)
			}
			ctx.values[opt.name] = "true"
			ctx.seen_options[opt.name] = true
		} else {
			if !has_value {
				return make_error(
					.Missing_Required_Option,
					fmt.tprintf(
						"Option -%s requires a value (-%s:value)",
						name,
						name,
						name,
					),
					ctx.current_cmd,
					name,
				)
			}
			parsed_val, err := parse_value(value, opt.type_info)
			if err != nil {
				return err
			}
			if opt.multiple {
				existing := ctx.values[opt.name]
				if existing != "" {
					ctx.values[opt.name] = strings.concatenate(
						{existing, ",", parsed_val},
					)
				} else {
					ctx.values[opt.name] = parsed_val
				}
			} else {
				ctx.values[opt.name] = parsed_val
			}
			ctx.seen_options[opt.name] = true
		}

		i += 1
	}

	return nil
}
