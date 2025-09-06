// Package main provides the entry point for the emoji-sad CLI application.
package main

import (
	"os"

	"emoji-search-and-destroy/internal/cli"
)

func main() {
	if err := cli.Execute(); err != nil {
		os.Exit(1)
	}
}
