package commands

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/spf13/cobra"
)

func TestDestroyEmojis(t *testing.T) {
	tests := []struct {
		name        string
		setupFunc   func() (string, func())
		args        []string
		noDryRun    bool
		wantErr     bool
		wantOutput  string
		checkFile   bool
		fileContent string
	}{
		{
			name: "non-existent directory",
			setupFunc: func() (string, func()) {
				return "/non/existent/directory", func() {}
			},
			args:    []string{},
			wantErr: true,
		},
		{
			name: "empty directory",
			setupFunc: func() (string, func()) {
				dir, _ := os.MkdirTemp("", "test_empty")
				return dir, func() { _ = os.RemoveAll(dir) }
			},
			args:       []string{},
			wantErr:    false,
			wantOutput: "No emojis found",
		},
		{
			name: "directory with clean files",
			setupFunc: func() (string, func()) {
				dir, _ := os.MkdirTemp("", "test_clean")
				_ = os.WriteFile(filepath.Join(dir, "clean.txt"), []byte("No emojis here"), 0600)
				return dir, func() { _ = os.RemoveAll(dir) }
			},
			args:       []string{},
			wantErr:    false,
			wantOutput: "No emojis found",
		},
		{
			name: "dry run with emojis",
			setupFunc: func() (string, func()) {
				dir, _ := os.MkdirTemp("", "test_dryrun")
				testFile := filepath.Join(dir, "test.txt")
				_ = os.WriteFile(testFile, []byte("Hello 😊 World"), 0600)
				return dir, func() { _ = os.RemoveAll(dir) }
			},
			args:        []string{},
			noDryRun:    false,
			wantErr:     false,
			wantOutput:  "DRY RUN:",
			checkFile:   true,
			fileContent: "Hello 😊 World",
		},
		{
			name: "actual removal with no-dry-run",
			setupFunc: func() (string, func()) {
				dir, _ := os.MkdirTemp("", "test_removal")
				testFile := filepath.Join(dir, "test.txt")
				_ = os.WriteFile(testFile, []byte("Hello 😊 World"), 0600)
				return dir, func() { _ = os.RemoveAll(dir) }
			},
			args:        []string{},
			noDryRun:    true,
			wantErr:     false,
			wantOutput:  "Removed",
			checkFile:   true,
			fileContent: "Hello  World",
		},
		{
			name: "multiple files with emojis",
			setupFunc: func() (string, func()) {
				dir, _ := os.MkdirTemp("", "test_multiple")
				_ = os.WriteFile(filepath.Join(dir, "file1.txt"), []byte("Test 🚀"), 0600)
				_ = os.WriteFile(filepath.Join(dir, "file2.txt"), []byte("Another ✨"), 0600)
				return dir, func() { _ = os.RemoveAll(dir) }
			},
			args:       []string{},
			noDryRun:   false,
			wantErr:    false,
			wantOutput: "Found emojis in 2 file(s)",
		},
		{
			name: "nested directories",
			setupFunc: func() (string, func()) {
				dir, _ := os.MkdirTemp("", "test_nested")
				subdir := filepath.Join(dir, "subdir")
				_ = os.MkdirAll(subdir, 0750)
				_ = os.WriteFile(filepath.Join(subdir, "nested.txt"), []byte("Nested 🎈"), 0600)
				return dir, func() { _ = os.RemoveAll(dir) }
			},
			args:       []string{},
			noDryRun:   false,
			wantErr:    false,
			wantOutput: "🎈",
		},
		{
			name: "binary files are skipped",
			setupFunc: func() (string, func()) {
				dir, _ := os.MkdirTemp("", "test_binary")
				// Create a binary file
				binaryContent := []byte{0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE}
				_ = os.WriteFile(filepath.Join(dir, "binary.bin"), binaryContent, 0600)
				// Also add a text file with emoji
				_ = os.WriteFile(filepath.Join(dir, "text.txt"), []byte("Text 🔥"), 0600)
				return dir, func() { _ = os.RemoveAll(dir) }
			},
			args:       []string{},
			noDryRun:   false,
			wantErr:    false,
			wantOutput: "text.txt",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Setup test directory
			dir, cleanup := tt.setupFunc()
			defer cleanup()

			// Create command
			cmd := &cobra.Command{}
			cmd.Flags().Bool("no-dry-run", tt.noDryRun, "")
			cmd.Flags().BoolP("list-only", "l", false, "")
			cmd.Flags().StringSlice("exclude", []string{}, "")
			cmd.Flags().StringP("output", "o", "text", "")
			cmd.Flags().Bool("files-from-stdin", false, "")
			cmd.Flags().BoolP("quiet", "q", false, "")
			cmd.Flags().StringP("allow-file", "a", "", "")

			// Capture output
			oldStdout := os.Stdout
			r, w, _ := os.Pipe()
			os.Stdout = w

			// Run function
			err := DestroyEmojis(cmd, []string{dir})

			// Restore stdout
			_ = w.Close()
			os.Stdout = oldStdout

			// Read output
			buf := make([]byte, 4096)
			n, _ := r.Read(buf)
			output := string(buf[:n])

			// Check error
			if (err != nil) != tt.wantErr {
				t.Errorf("DestroyEmojis() error = %v, wantErr %v", err, tt.wantErr)
			}

			// Check output
			if tt.wantOutput != "" && !strings.Contains(output, tt.wantOutput) {
				t.Errorf("DestroyEmojis() output = %v, want to contain %v", output, tt.wantOutput)
			}

			// Check file content if needed
			if tt.checkFile {
				testFile := filepath.Join(dir, "test.txt")
				content, _ := os.ReadFile(testFile) // #nosec G304 -- testFile is controlled in test
				if string(content) != tt.fileContent {
					t.Errorf("File content = %v, want %v", string(content), tt.fileContent)
				}
			}
		})
	}
}

func TestDestroyEmojisEdgeCases(t *testing.T) {
	t.Run("flag retrieval error simulation", func(t *testing.T) {
		// This test ensures our error handling for flag retrieval works
		// In practice, this is hard to trigger, but we test the code path exists
		cmd := &cobra.Command{}
		// Don't set the flag, causing potential issues

		dir, _ := os.MkdirTemp("", "test_flag_error")
		defer func() { _ = os.RemoveAll(dir) }()

		// The function should handle missing flags gracefully
		err := DestroyEmojis(cmd, []string{dir})
		// We expect it to work with default values
		if err != nil && !strings.Contains(err.Error(), "no-dry-run flag") {
			t.Errorf("Expected flag error or success, got: %v", err)
		}
	})
}
