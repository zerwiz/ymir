# Fix: ymir_plan printf em-dash broke quoting

The `ymir_plan` tool's bash printf used an em-dash in the format string, which broke quoting when passed through the run() helper. Replaced with a plain hyphen.
