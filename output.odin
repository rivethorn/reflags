package reflags

import "core:fmt"
import "core:os"
import "core:strings"

// ============================================================================
// Style Set
// ============================================================================

// style_set bundles the ANSI escape sequences used by the output
// procedures; it is empty (all-blank) when color is disabled so styled
// writes degrade to plain text.
style_set :: struct {
	reset:          string,
	bold:           string,
	dim:            string,
	underline:      string,

	// Foreground
	red:            string,
	green:          string,
	yellow:         string,
	blue:           string,
	magenta:        string,
	cyan:           string,
	white:          string,
	bright_red:     string,
	bright_green:   string,
	bright_yellow:  string,
	bright_blue:    string,
	bright_magenta: string,
	bright_cyan:    string,
	bright_white:   string,

	// Background
	bg_red:         string,
	bg_green:       string,
}

// make_style builds a style_set, populated with colors only when
// use_color is true.
make_style :: proc(use_color: bool) -> style_set {
	if use_color {
		return style_set {
			reset = color_reset,
			bold = color_bold,
			dim = color_dim,
			underline = color_underline,
			red = color_red,
			green = color_green,
			yellow = color_yellow,
			blue = color_blue,
			magenta = color_magenta,
			cyan = color_cyan,
			white = color_white,
			bright_red = color_bright_red,
			bright_green = color_bright_green,
			bright_yellow = color_bright_yellow,
			bright_blue = color_bright_blue,
			bright_magenta = color_bright_magenta,
			bright_cyan = color_bright_cyan,
			bright_white = color_bright_white,
			bg_red = color_bg_red,
			bg_green = color_bg_green,
		}
	}
	return style_set{}
}

// get_style returns the style_set matching the CLI's color_enabled flag.
get_style :: proc(cli: ^CLI) -> style_set {
	return make_style(cli.color_enabled)
}

// ============================================================================
// High-level Output Functions
// ============================================================================

// print_usage writes the compact usage form (usage line, description,
// options, arguments, subcommands) for cmd (or the root command) to out.
print_usage :: proc(cli: ^CLI, out: ^os.File, cmd: ^Command = nil) {
	s := get_style(cli)
	target := cmd
	if target == nil {
		target = cli.root_cmd
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	// Usage line
	write_usage_line(&builder, s, cli, target)

	// Description
	if len(target.description) > 0 {
		strings.write_byte(&builder, '\n')
		write_wrapped(&builder, target.description, 80, "  ")
	}

	// Options
	if len(target.options) > 0 {
		strings.write_byte(&builder, '\n')
		write_options(&builder, s, cli.style, target)
	}

	// Arguments
	if len(target.arguments) > 0 {
		strings.write_byte(&builder, '\n')
		write_arguments(&builder, s, target)
	}

	// Subcommands
	if len(target.subcommands) > 0 {
		strings.write_byte(&builder, '\n')
		write_subcommands(&builder, s, target)
	}

	fmt.fprint(out, strings.to_string(builder))
}

// print_help writes the full help page (header, usage, long description,
// options, arguments, subcommands, and the global hint on the root
// command) for cmd (or the root command) to out.
print_help :: proc(cli: ^CLI, out: ^os.File, cmd: ^Command = nil) {
	s := get_style(cli)
	target := cmd
	if target == nil {
		target = cli.root_cmd
	}

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	// Header
	write_header(&builder, s, cli, target)
	// strings.write_byte(&builder, '\n')

	// Long description
	if len(target.long_desc) > 0 {
		write_wrapped(&builder, target.long_desc, 80, "")
		strings.write_byte(&builder, '\n')
	} else if len(target.description) > 0 {
		write_wrapped(&builder, target.description, 80, "")
		strings.write_byte(&builder, '\n')
	}

	// Usage
	write_usage_line(&builder, s, cli, target)
	strings.write_byte(&builder, '\n')

	// Command notes
	if len(target.notes) > 0 {
		strings.write_byte(&builder, '\n')
		write_notes(&builder, s, target.notes, "  ")
	}

	// Options
	if len(target.options) > 0 {
		strings.write_byte(&builder, '\n')
		write_options(&builder, s, cli.style, target)
	}

	// Arguments
	if len(target.arguments) > 0 {
		strings.write_byte(&builder, '\n')
		write_arguments(&builder, s, target)
	}

	// Subcommands
	if len(target.subcommands) > 0 {
		strings.write_byte(&builder, '\n')
		write_subcommands(&builder, s, target)
	}

	// Global options hint
	if target == cli.root_cmd {
		strings.write_byte(&builder, '\n')
		write_global_hint(&builder, s, cli)
	}

	fmt.fprint(out, strings.to_string(builder))
}

// print_version writes the CLI name and version to out.
print_version :: proc(cli: ^CLI, out: ^os.File) {
	s := get_style(cli)
	fmt.fprintfln(out, "%s%s v%s%s", s.bold, s.bright_cyan, cli.version, s.reset)
}

// print_error prints err to stderr. Help_Requested reasons print the help
// page and Version_Requested reasons print the version instead; anything
// else prints a styled "<name> error:" message plus a usage hint.
print_error :: proc(cli: ^CLI, err: ^Re_Error) {
	s := get_style(cli)

	#partial switch err.reason {
	case .Help_Requested:
		print_help(cli, os.stderr, err.command)
		return
	case .Version_Requested:
		print_version(cli, os.stderr)
		return
	case:
		prefix := fmt.tprintf("%s%s%s error:%s", s.bold, s.bright_red, cli.name, s.reset)
		fmt.eprintfln("%s %s", prefix, err.message)

		// Show usage hint for errors, naming the actual command that was run.
		// In Odin style the flag is -help; in Unix style it's --help.
		if err.reason != .Help_Requested && err.reason != .Version_Requested {
			cmd_name := cli.name
			if err.command != nil {
				cmd_name = err.command.name
			}
			flag := "--help"
			if cli.style == .Odin {
				flag = "-help"
			}
			fmt.eprintfln("\n%sRun '%s %s' for usage.%s", s.dim, cmd_name, flag, s.reset)
		}
	}
}

// ============================================================================
// Section Writers
// ============================================================================

// write_header writes the styled app name/version (plus command name when
// printing a subcommand).
write_header :: proc(builder: ^strings.Builder, s: style_set, cli: ^CLI, cmd: ^Command) {
	strings.write_string(builder, s.bold)
	strings.write_string(builder, s.bright_cyan)
	strings.write_string(builder, cli.name)
	if len(cli.version) > 0 {
		strings.write_string(builder, " ")
		strings.write_string(builder, s.dim)
		strings.write_string(builder, "v")
		strings.write_string(builder, cli.version)
	}
	strings.write_string(builder, s.reset)

	if cmd != cli.root_cmd {
		strings.write_string(builder, " ")
		strings.write_string(builder, s.bold)
		strings.write_string(builder, s.green)
		strings.write_string(builder, cmd.name)
		strings.write_string(builder, s.reset)
	}
	strings.write_byte(builder, '\n')
}

// write_usage_line writes the "Usage: ..." line, including [OPTIONS],
// argument placeholders, and a <COMMAND> hint when subcommands exist.
write_usage_line :: proc(builder: ^strings.Builder, s: style_set, cli: ^CLI, cmd: ^Command) {
	strings.write_string(builder, s.bold)
	strings.write_string(builder, s.bright_green)
	strings.write_string(builder, "Usage:")
	strings.write_string(builder, s.reset)
	strings.write_string(builder, " ")
	strings.write_string(builder, cli.name)

	// Command path
	if cmd != cli.root_cmd {
		strings.write_string(builder, " ")
		strings.write_string(builder, s.bold)
		strings.write_string(builder, s.green)
		strings.write_string(builder, cmd.name)
		strings.write_string(builder, s.reset)
	}

	// Options placeholder
	if len(cmd.options) > 0 {
		strings.write_string(builder, " ")
		strings.write_string(builder, s.dim)
		strings.write_string(builder, "[OPTIONS]")
		strings.write_string(builder, s.reset)
	}

	// Arguments
	for i in 0 ..< len(cmd.arguments) {
		arg := &cmd.arguments[i]
		strings.write_string(builder, " ")
		if !arg.required {
			strings.write_string(builder, s.dim)
			strings.write_byte(builder, '[')
		}
		strings.write_string(builder, s.bold)
		strings.write_string(builder, s.blue)
		strings.write_byte(builder, '<')
		strings.write_string(builder, arg.name)
		strings.write_byte(builder, '>')
		strings.write_string(builder, s.reset)
		if arg.variadic {
			strings.write_string(builder, s.dim)
			strings.write_string(builder, "...")
			strings.write_string(builder, s.reset)
		}
		if !arg.required {
			strings.write_string(builder, s.dim)
			strings.write_byte(builder, ']')
			strings.write_string(builder, s.reset)
		}
	}

	// Subcommands hint
	if len(cmd.subcommands) > 0 {
		strings.write_string(builder, " ")
		strings.write_string(builder, s.dim)
		strings.write_string(builder, "<COMMAND>")
		strings.write_string(builder, s.reset)
	}
}

// write_options writes the "Options:" section (column-aligned, hidden
// options skipped) for a command. Flags are rendered in the given parsing
// style so the help matches how commands are actually entered.
write_options :: proc(
	builder: ^strings.Builder,
	s: style_set,
	style: Parsing_Style,
	cmd: ^Command,
) {
	strings.write_string(builder, s.bold)
	strings.write_string(builder, s.bright_yellow)
	strings.write_string(builder, "Options:")
	strings.write_string(builder, s.reset)
	strings.write_byte(builder, '\n')

	// Calculate max option width for alignment
	max_width := 0
	for i in 0 ..< len(cmd.options) {
		opt := &cmd.options[i]
		if opt.hidden {continue}
		w := option_display_width(style, opt)
		if w > max_width {max_width = w}
	}

	for i in 0 ..< len(cmd.options) {
		opt := &cmd.options[i]
		if opt.hidden {continue}

		strings.write_string(builder, "  ")
		write_option_line(builder, s, style, opt, max_width)
		strings.write_byte(builder, '\n')

		if len(opt.notes) > 0 {
			write_notes(builder, s, opt.notes, "      ")
		}
	}
}

// option_display_width computes the rendered width of an option's flag and
// value placeholder, used to align the Options: section.
option_display_width :: proc(style: Parsing_Style, opt: ^Option) -> int {
	w := 0
	if style == .Odin {
		// -name or -name:VALUE (no short flags in Odin style)
		w += 1 + len(opt.name)
		if opt.type_info.kind != .Bool {
			w += 1 + len(type_display_name(opt.type_info)) // :VALUE
		}
	} else {
		if len(opt.short) > 0 {
			w += 2 + len(opt.short) + 2 // -s,
		}
		w += 2 + len(opt.name) // --name
		if opt.type_info.kind != .Bool {
			w += 1 + len(type_display_name(opt.type_info)) // =VALUE
		}
	}
	return w
}

// write_option_line writes one option's full line (short/long names, value
// placeholder, description, default, required marker) padded to max_width,
// rendered in the given parsing style.
write_option_line :: proc(
	builder: ^strings.Builder,
	s: style_set,
	style: Parsing_Style,
	opt: ^Option,
	max_width: int,
) {
	if style == .Odin {
		// Odin style: single dash, no short flags, colon for values.
		strings.write_string(builder, s.bold)
		strings.write_string(builder, s.yellow)
		strings.write_byte(builder, '-')
		strings.write_string(builder, opt.name)
		strings.write_string(builder, s.reset)
		if opt.type_info.kind != .Bool {
			strings.write_string(builder, s.dim)
			strings.write_byte(builder, ':')
			strings.write_string(builder, type_display_name(opt.type_info))
			strings.write_string(builder, s.reset)
		}
	} else {
		// Unix style: short flags and --name=VALUE.
		if len(opt.short) > 0 {
			strings.write_string(builder, s.bold)
			strings.write_string(builder, s.yellow)
			strings.write_byte(builder, '-')
			strings.write_string(builder, opt.short)
			strings.write_string(builder, s.reset)
			strings.write_string(builder, ", ")
		}
		strings.write_string(builder, s.bold)
		strings.write_string(builder, s.yellow)
		strings.write_string(builder, "--")
		strings.write_string(builder, opt.name)
		strings.write_string(builder, s.reset)
		if opt.type_info.kind != .Bool {
			strings.write_string(builder, s.dim)
			strings.write_byte(builder, '=')
			strings.write_string(builder, type_display_name(opt.type_info))
			strings.write_string(builder, s.reset)
		}
	}

	// Padding
	current_width := option_display_width(style, opt)
	padding := max_width - current_width + 2
	strings.write_string(builder, strings.repeat(" ", padding, context.temp_allocator))

	// Description
	strings.write_string(builder, opt.description)

	// Default value hint
	if len(opt.default_str) > 0 && opt.type_info.kind != .Bool {
		strings.write_string(builder, " ")
		strings.write_string(builder, s.dim)
		strings.write_string(builder, fmt.tprintf("(default: %s)", opt.default_str))
		strings.write_string(builder, s.reset)
	}

	// Required hint
	if opt.required && len(opt.default_str) == 0 {
		strings.write_string(builder, " ")
		strings.write_string(builder, s.bold)
		strings.write_string(builder, s.red)
		strings.write_string(builder, "(required)")
		strings.write_string(builder, s.reset)
	}
}

// write_notes writes each note in `notes` on its own indented line, styled
// like a dim-context hint ("note: ..."). Used for command/option/argument
// notes appended via cmd_note/option_note/opt_note.
write_notes :: proc(
	builder: ^strings.Builder,
	s: style_set,
	notes: [dynamic]string,
	indent: string,
) {
	for note in notes {
		strings.write_string(builder, indent)
		strings.write_string(builder, s.dim)
		strings.write_string(builder, "note: ")
		strings.write_string(builder, s.reset)
		strings.write_string(builder, note)
		strings.write_byte(builder, '\n')
	}
}

// write_arguments writes the "Arguments:" section for a command.
write_arguments :: proc(builder: ^strings.Builder, s: style_set, cmd: ^Command) {
	strings.write_string(builder, s.bold)
	strings.write_string(builder, s.bright_blue)
	strings.write_string(builder, "Arguments:")
	strings.write_string(builder, s.reset)
	strings.write_byte(builder, '\n')

	for i in 0 ..< len(cmd.arguments) {
		arg := &cmd.arguments[i]
		if arg.hidden {continue}

		strings.write_string(builder, "  ")
		strings.write_string(builder, s.bold)
		strings.write_string(builder, s.blue)
		strings.write_string(builder, arg.name)
		strings.write_string(builder, s.reset)

		if arg.variadic {
			strings.write_string(builder, s.dim)
			strings.write_string(builder, "...")
			strings.write_string(builder, s.reset)
		}

		strings.write_string(builder, "  ")
		strings.write_string(builder, arg.description)

		if arg.required {
			strings.write_string(builder, " ")
			strings.write_string(builder, s.bold)
			strings.write_string(builder, s.red)
			strings.write_string(builder, "(required)")
			strings.write_string(builder, s.reset)
		}
		strings.write_byte(builder, '\n')

		if len(arg.notes) > 0 {
			write_notes(builder, s, arg.notes, "      ")
		}
	}
}

// write_subcommands writes the "Commands:" section for a command.
write_subcommands :: proc(builder: ^strings.Builder, s: style_set, cmd: ^Command) {
	strings.write_string(builder, s.bold)
	strings.write_string(builder, s.bright_magenta)
	strings.write_string(builder, "Commands:")
	strings.write_string(builder, s.reset)
	strings.write_byte(builder, '\n')

	max_name_len := 0
	for i in 0 ..< len(cmd.subcommands) {
		sub := &cmd.subcommands[i]
		if sub.hidden {continue}
		if len(sub.name) > max_name_len {max_name_len = len(sub.name)}
	}

	for i in 0 ..< len(cmd.subcommands) {
		sub := &cmd.subcommands[i]
		if sub.hidden {continue}

		strings.write_string(builder, "  ")
		strings.write_string(builder, s.bold)
		strings.write_string(builder, s.green)
		strings.write_string(builder, sub.name)
		strings.write_string(builder, s.reset)

		padding := max_name_len - len(sub.name) + 2
		strings.write_string(builder, strings.repeat(" ", padding, context.temp_allocator))
		strings.write_string(builder, sub.description)
		strings.write_byte(builder, '\n')
	}
}

// write_global_hint writes the "Run 'COMMAND --help' ..." hint used at the
// end of the root command's help output.
write_global_hint :: proc(builder: ^strings.Builder, s: style_set, cli: ^CLI) {
	strings.write_string(builder, s.dim)
	strings.write_string(builder, "Run '")
	strings.write_string(builder, s.bold)
	strings.write_string(builder, "COMMAND --help")
	strings.write_string(builder, s.reset)
	strings.write_string(builder, s.dim)
	strings.write_string(builder, "' for more information on a command.")
	strings.write_string(builder, s.reset)
	strings.write_byte(builder, '\n')
}

// ============================================================================
// Utility Functions
// ============================================================================

// type_display_name returns a short label for an Arg_Type_Info, e.g.
// "STRING", "INT", "{auto|always|never}" for enums.
type_display_name :: proc(t: Arg_Type_Info) -> string {
	switch t.kind {
	case .String:
		return "STRING"
	case .Int:
		return "INT"
	case .Float:
		return "FLOAT"
	case .Bool:
		return "BOOL"
	case .Path:
		return "PATH"
	case .Enum:
		return fmt.tprintf("%s%s%s", "{", strings.join(t.enum_values, "|", context.allocator), "}")
	case .Custom:
		return "VALUE"
	}
	return "VALUE"
}

// write_wrapped writes text to the builder, wrapping at width columns and
// indenting every line with indent.
write_wrapped :: proc(builder: ^strings.Builder, text: string, width: int, indent: string) {
	words := strings.split(text, " ", context.temp_allocator)
	line_width := len(indent)

	strings.write_string(builder, indent)

	for word in words {
		word_len := len(word)
		if line_width + word_len + 1 > width && line_width > len(indent) {
			strings.write_byte(builder, '\n')
			strings.write_string(builder, indent)
			line_width = len(indent)
		}
		if line_width > len(indent) {
			strings.write_byte(builder, ' ')
			line_width += 1
		}
		strings.write_string(builder, word)
		line_width += word_len
	}
	strings.write_byte(builder, '\n')
}

// ============================================================================
// Convenience functions for handlers
// ============================================================================

// Colored output helpers for handlers
// success writes msg to out in bold green.
success :: proc(msg: string) {
	s := make_style(true)
	fmt.printfln("%s%s%s%s", s.bold, s.green, msg, s.reset)
}

// warning_msg writes msg to out in bold yellow.
warning_msg :: proc(out: ^os.File, msg: string) {
	s := make_style(true)
	fmt.fprintfln(out, "%s%s%s%s", s.bold, s.yellow, msg, s.reset)
}

// info_msg writes msg to out in bold blue.
info_msg :: proc(out: ^os.File, msg: string) {
	s := make_style(true)
	fmt.fprintfln(out, "%s%s%s%s", s.bold, s.blue, msg, s.reset)
}

// error_output writes msg to out in bold red.
error_output :: proc(msg: string) {
	s := make_style(true)
	fmt.eprintfln("%s%s%s%s", s.bold, s.red, msg, s.reset)
}

// command_error prints "<prefix> error: <msg>" to out in bold red, the
// standard format for command-level errors. Use prefix like "mimir" (app
// errors) or "mimir install" (command errors).
command_error :: proc(prefix: string, msg: string) {
	s := make_style(true)
	fmt.eprintfln("%s%s%s error:%s %s", s.bold, s.bright_red, prefix, s.reset, msg)
}

// error_hint prints the "Run '<cmd> -help' for usage." line (Odin style).
error_hint :: proc(cmd: string) {
	s := make_style(true)
	fmt.eprintfln("\n%sRun '%s -help' for usage.%s", s.dim, cmd, s.reset)
}

// error_hint_unix prints the "Run '<cmd> --help' for usage." line (Unix style).
error_hint_unix :: proc(cmd: string) {
	s := make_style(true)
	fmt.eprintfln("\n%sRun '%s --help' for usage.%s", s.dim, cmd, s.reset)
}
