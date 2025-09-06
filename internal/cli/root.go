// Package cli provides the command-line interface for the emoji-sad application.
package cli

import (
	"emoji-search-and-destroy/internal/cli/commands"
	"emoji-search-and-destroy/internal/version"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "emoji-sad [directory|-]",
	Short: "Find and remove emojis from all files in a directory or from a list of files",
	Long: `Emoji Search and Destroy CLI

This tool searches through all files in a directory and removes all emojis.
By default, it runs in dry-run mode to preview changes. Use --no-dry-run to actually modify files.

Use '-' as the directory to process content from stdin directly, or with --files-from-stdin to read file paths from stdin.

Examples:
  # Preview emoji removal from current directory (dry-run)
  emoji-sad .

  # Actually remove emojis from a specific directory
  emoji-sad --no-dry-run /path/to/project

  # Only list files containing emojis
  emoji-sad -l /path/to/project

  # Process content from stdin directly
  cat file.txt | emoji-sad -

  # Process file paths from stdin
  find . -name "*.txt" | emoji-sad - --files-from-stdin

  # Remove emojis from files listed in a file
  cat file_list.txt | emoji-sad - --files-from-stdin --no-dry-run

  # Exclude specific files or directories
  emoji-sad . --exclude node_modules --exclude "*.test.js"
  emoji-sad . --exclude /path/to/skip --exclude config.json

  # Output results in JSON format
  emoji-sad . --output json
  emoji-sad -l . -o json
  find . -name "*.txt" | emoji-sad -o json -`,
	Args: cobra.ExactArgs(1),
	RunE: commands.DestroyEmojis,
}

func init() {
	rootCmd.Flags().Bool("no-dry-run", false, "Actually modify files instead of previewing")
	rootCmd.Flags().BoolP("list-only", "l", false, "Only list files containing emojis, one per line")
	rootCmd.Flags().StringSlice("exclude", []string{}, "Exclude files or directories matching these patterns (can be used multiple times)")
	rootCmd.Flags().StringP("output", "o", "text", "Output format: text or json")
	rootCmd.Flags().Bool("files-from-stdin", false, "Read file paths from stdin instead of processing stdin content directly")
	rootCmd.Flags().BoolP("quiet", "q", false, "Suppress processing reports (only output cleaned content for stdin)")
	rootCmd.Flags().StringP("allow-file", "a", "", "File containing allowed emojis, one per line (default: .emoji-sad-allow if it exists)")
	rootCmd.Version = version.Version
}

// Execute runs the root command and returns any error encountered.
func Execute() error {
	return rootCmd.Execute()
}
