package cargo_example

import reflags "../.."
import "core:os"

main :: proc() {
	cli := CLI()
	defer reflags.destroy_cli(&cli)
	parsed, err := reflags.parse(&cli, os.args[1:])
	if err != nil {
		reflags.print_error(&cli, err)
		help_or_version := err.reason == .Help_Requested || err.reason == .Version_Requested
		free(err)
		if help_or_version {
			os.exit(0)
		}
		os.exit(1)
	}

	defer reflags.destroy(parsed)

	// Execute the command handler if present
	if parsed.command.handler != nil {
		handler_err := parsed.command.handler(parsed)
		if handler_err != nil {
			reflags.print_error(&cli, handler_err)
			free(handler_err)
			os.exit(1)
		}
	}
}
