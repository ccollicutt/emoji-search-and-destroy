// Package commands contains the CLI command implementations.
package commands

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"emoji-search-and-destroy/pkg/emoji"

	"github.com/spf13/cobra"
)

// DestroyEmojis is the main command handler that processes a directory to find and remove emojis.
func DestroyEmojis(cmd *cobra.Command, args []string) error {
	config, err := parseFlags(cmd)
	if err != nil {
		return err
	}

	results, err := processInput(args[0], config)
	if err != nil {
		return err
	}

	// Check if we're processing stdin content directly (not file paths)
	isStdinContent := args[0] == "-" && !config.filesFromStdin
	return outputResults(results, config, isStdinContent)
}

// commandConfig holds the parsed command flags
type commandConfig struct {
	dryRun         bool
	listOnly       bool
	exclude        []string
	output         string
	filesFromStdin bool
	quiet          bool
	allowFile      string
	allowedEmojis  []string
}

// parseFlags extracts and validates command flags
func parseFlags(cmd *cobra.Command) (*commandConfig, error) {
	noDryRun, err := cmd.Flags().GetBool("no-dry-run")
	if err != nil {
		return nil, fmt.Errorf("failed to get no-dry-run flag: %w", err)
	}

	listOnly, err := cmd.Flags().GetBool("list-only")
	if err != nil {
		return nil, fmt.Errorf("failed to get list-only flag: %w", err)
	}

	exclude, err := cmd.Flags().GetStringSlice("exclude")
	if err != nil {
		return nil, fmt.Errorf("failed to get exclude flag: %w", err)
	}

	output, err := cmd.Flags().GetString("output")
	if err != nil {
		return nil, fmt.Errorf("failed to get output flag: %w", err)
	}

	filesFromStdin, err := cmd.Flags().GetBool("files-from-stdin")
	if err != nil {
		return nil, fmt.Errorf("failed to get files-from-stdin flag: %w", err)
	}

	quiet, err := cmd.Flags().GetBool("quiet")
	if err != nil {
		return nil, fmt.Errorf("failed to get quiet flag: %w", err)
	}

	allowFile, err := cmd.Flags().GetString("allow-file")
	if err != nil {
		return nil, fmt.Errorf("failed to get allow-file flag: %w", err)
	}

	// Validate output format
	if output != "text" && output != "json" {
		return nil, fmt.Errorf("invalid output format: %s (must be 'text' or 'json')", output)
	}

	// Load allowed emojis
	var allowedEmojis []string
	if allowFile != "" {
		allowedEmojis, err = loadAllowFile(allowFile)
		if err != nil {
			return nil, fmt.Errorf("failed to load allow file: %w", err)
		}
	} else {
		// Check for default .emoji-sad-allow file
		if _, err := os.Stat(".emoji-sad-allow"); err == nil {
			allowedEmojis, err = loadAllowFile(".emoji-sad-allow")
			if err != nil {
				return nil, fmt.Errorf("failed to load default allow file: %w", err)
			}
		}
	}

	return &commandConfig{
		dryRun:         !noDryRun,
		listOnly:       listOnly,
		exclude:        exclude,
		output:         output,
		filesFromStdin: filesFromStdin,
		quiet:          quiet,
		allowFile:      allowFile,
		allowedEmojis:  allowedEmojis,
	}, nil
}

// loadAllowFile loads allowed emojis from a file, one per line
func loadAllowFile(filepath string) ([]string, error) {
	// Validate filepath to prevent directory traversal
	if filepath == "" {
		return nil, fmt.Errorf("filepath cannot be empty")
	}

	// #nosec G304 - This is an intentional file read for allow file functionality
	file, err := os.Open(filepath)
	if err != nil {
		return nil, err
	}
	defer func() {
		_ = file.Close() // Ignore close error in defer
	}()

	var allowed []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		emoji := strings.TrimSpace(scanner.Text())
		if emoji != "" && !strings.HasPrefix(emoji, "#") { // Skip empty lines and comments
			allowed = append(allowed, emoji)
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return allowed, nil
}

// processInput processes either stdin or directory input
func processInput(dirPath string, config *commandConfig) ([]emoji.ProcessResult, error) {
	processor := emoji.NewFileProcessorWithExcludesAndAllowed(config.exclude, config.allowedEmojis)

	if dirPath == "-" {
		if config.listOnly && !config.filesFromStdin {
			return nil, fmt.Errorf("--list-only cannot be used with stdin content processing (use --files-from-stdin for file lists)")
		}
		if config.filesFromStdin {
			return processFilePathsFromStdin(processor, config.dryRun)
		}
		return processContentFromStdin(processor, config.dryRun)
	}

	if _, err := os.Stat(dirPath); os.IsNotExist(err) {
		return nil, fmt.Errorf("directory does not exist: %s", dirPath)
	}

	return processor.ProcessDirectory(dirPath, config.dryRun)
}

// JSONOutput represents the JSON output structure
type JSONOutput struct {
	Summary JSONSummary    `json:"summary"`
	Files   []JSONFileInfo `json:"files"`
}

// JSONSummary represents summary information in JSON output
type JSONSummary struct {
	TotalFiles  int    `json:"total_files"`
	TotalEmojis int    `json:"total_emojis"`
	DryRun      bool   `json:"dry_run"`
	Mode        string `json:"mode"` // "list", "process"
}

// JSONFileInfo represents file information in JSON output
type JSONFileInfo struct {
	FilePath     string   `json:"file_path"`
	EmojisFound  []string `json:"emojis_found"`
	OriginalSize int64    `json:"original_size"`
	NewSize      int64    `json:"new_size,omitempty"`
	Modified     bool     `json:"modified"`
}

// outputResults handles the output formatting based on results and config
func outputResults(results []emoji.ProcessResult, config *commandConfig, isStdinContent bool) error {
	if config.output == "json" {
		return outputJSON(results, config)
	}

	// For stdin content processing, we already output the cleaned content to stdout
	// So we only need to output the report to stderr (or skip if quiet or no emojis)
	if isStdinContent {
		if config.quiet || len(results) == 0 {
			return nil // No report needed for stdin with quiet mode or no emojis
		}
		return outputDetailedResults(results, config.dryRun, true) // true = output to stderr
	}

	// Text output (original behavior for directories and file lists)
	if config.quiet && !config.listOnly {
		return nil // In quiet mode, suppress all output except list-only
	}

	if len(results) == 0 {
		if !config.listOnly {
			fmt.Println("No emojis found in any files.")
		}
		return nil
	}

	if config.listOnly {
		return outputFileList(results)
	}

	return outputDetailedResults(results, config.dryRun, false) // false = output to stdout
}

// outputFileList outputs just the file paths (for --list-only)
func outputFileList(results []emoji.ProcessResult) error {
	for _, result := range results {
		fmt.Println(result.FilePath)
	}
	return nil
}

// outputDetailedResults outputs detailed results with emoji counts and size changes
func outputDetailedResults(results []emoji.ProcessResult, dryRun bool, toStderr bool) error {
	out := os.Stdout
	if toStderr {
		out = os.Stderr
	}

	if dryRun {
		_, _ = fmt.Fprintf(out, "DRY RUN: Found emojis in %d file(s):\n\n", len(results))
	} else {
		_, _ = fmt.Fprintf(out, "Processed %d file(s) and removed emojis:\n\n", len(results))
	}

	totalEmojis := 0
	for _, result := range results {
		_, _ = fmt.Fprintf(out, "File: %s\n", result.FilePath)
		_, _ = fmt.Fprintf(out, "  Emojis found: %v\n", result.EmojisFound)
		totalEmojis += len(result.EmojisFound)

		if result.Modified {
			if dryRun {
				_, _ = fmt.Fprintf(out, "  Would reduce size: %d → %d bytes\n", result.OriginalSize, result.NewSize)
			} else {
				_, _ = fmt.Fprintf(out, "  Size changed: %d → %d bytes\n", result.OriginalSize, result.NewSize)
			}
		}
		_, _ = fmt.Fprintln(out)
	}

	if dryRun {
		_, _ = fmt.Fprintf(out, "Total: Would remove %d emoji(s) from %d file(s)\n", totalEmojis, len(results))
		_, _ = fmt.Fprintln(out, "Run with --no-dry-run to actually remove emojis.")
	} else {
		_, _ = fmt.Fprintf(out, "Total: Removed %d emoji(s) from %d file(s)\n", totalEmojis, len(results))
	}

	return nil
}

// processFilePathsFromStdin reads file paths from stdin and processes each file
func processFilePathsFromStdin(processor *emoji.FileProcessor, dryRun bool) ([]emoji.ProcessResult, error) {
	var results []emoji.ProcessResult
	scanner := bufio.NewScanner(os.Stdin)

	for scanner.Scan() {
		filePath := strings.TrimSpace(scanner.Text())
		if filePath == "" {
			continue
		}

		// Check if file exists
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			fmt.Fprintf(os.Stderr, "Warning: file does not exist: %s\n", filePath)
			continue
		}

		result, err := processor.ProcessFile(filePath, dryRun)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Warning: failed to process %s: %v\n", filePath, err)
			continue
		}

		// Only include files that actually had emojis
		if len(result.EmojisFound) > 0 {
			results = append(results, result)
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading from stdin: %w", err)
	}

	return results, nil
}

// processContentFromStdin reads content from stdin and processes it directly
func processContentFromStdin(processor *emoji.FileProcessor, dryRun bool) ([]emoji.ProcessResult, error) {
	// Read all content from stdin
	scanner := bufio.NewScanner(os.Stdin)
	var content strings.Builder

	for scanner.Scan() {
		content.WriteString(scanner.Text())
		content.WriteString("\n")
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading from stdin: %w", err)
	}

	contentStr := content.String()
	if contentStr == "" {
		return []emoji.ProcessResult{}, nil
	}

	// Remove trailing newline that we added
	contentStr = strings.TrimSuffix(contentStr, "\n")

	// Use the processor's detector which has allowed emojis configured
	emojis := processor.Detector.FindEmojis(contentStr)

	result := emoji.ProcessResult{
		FilePath:     "<stdin>",
		EmojisFound:  emojis,
		OriginalSize: int64(len(contentStr)),
		Modified:     len(emojis) > 0,
	}

	if len(emojis) == 0 {
		return []emoji.ProcessResult{}, nil
	}

	// Process the content (remove emojis)
	cleanedContent := processor.Detector.RemoveEmojis(contentStr)
	result.NewSize = int64(len(cleanedContent))

	if !dryRun {
		// Output the cleaned content to stdout
		fmt.Print(cleanedContent)
	}

	return []emoji.ProcessResult{result}, nil
}

// outputJSON outputs results in JSON format
func outputJSON(results []emoji.ProcessResult, config *commandConfig) error {
	var mode string
	if config.listOnly {
		mode = "list"
	} else {
		mode = "process"
	}

	// Calculate total emojis
	totalEmojis := 0
	for _, result := range results {
		totalEmojis += len(result.EmojisFound)
	}

	// Build JSON output
	output := JSONOutput{
		Summary: JSONSummary{
			TotalFiles:  len(results),
			TotalEmojis: totalEmojis,
			DryRun:      config.dryRun,
			Mode:        mode,
		},
		Files: make([]JSONFileInfo, 0, len(results)),
	}

	// Convert results to JSON format
	for _, result := range results {
		fileInfo := JSONFileInfo{
			FilePath:     result.FilePath,
			EmojisFound:  result.EmojisFound,
			OriginalSize: result.OriginalSize,
			Modified:     result.Modified,
		}

		// Only include new size if file was modified
		if result.Modified {
			fileInfo.NewSize = result.NewSize
		}

		output.Files = append(output.Files, fileInfo)
	}

	// Marshal and output JSON
	jsonBytes, err := json.MarshalIndent(output, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal JSON output: %w", err)
	}

	fmt.Println(string(jsonBytes))
	return nil
}
