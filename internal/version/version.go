// Package version provides version information for the emoji-sad CLI.
package version

var (
	// Version is the current version of the emoji-sad CLI.
	// This can be overridden at build time using -ldflags.
	Version = "0.1.5"

	// Name is the application name.
	Name = "emoji-sad"

	// Description is the application description.
	Description = "Emoji Search and Destroy - CLI tool to find and remove emojis from text files"
)
