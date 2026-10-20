package hello_world_example

import reflags "../.."
import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
	// Define a root command with one string option and one bool flag.
	root := reflags.command("greet", "Say hello")
	append(&root.options, reflags.opt_str("name", "n", "Who to greet"))
	append(&root.options, reflags.opt_flag("shout", "s", "Shout the greeting"))

	// The CLI must outlive parse, so root lives on the heap.
	root_ptr := new(reflags.Command)
	root_ptr^ = root

	cli: reflags.CLI = reflags.make_cli("greet", "1.0.0", root_ptr)
	defer reflags.destroy_cli(&cli)

	// Parse arguments; prints help/version/errors and exits on its own.
	parsed := reflags.parse_or_exit(&cli, os.args[1:])
	defer reflags.destroy(parsed)

	// Read values back with the get_* accessors.
	name := reflags.get_string(parsed, "name")
	shout := reflags.get_bool(parsed, "shout")

	greeting := fmt.tprintf("Hello, %s!", name)
	if shout {
		greeting = strings.to_upper(greeting, context.temp_allocator)
	}
	fmt.println(greeting)
}
