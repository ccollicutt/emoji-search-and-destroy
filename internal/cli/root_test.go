package cli

import (
	"bytes"
	"strings"
	"testing"
)

func TestRootCommand(t *testing.T) {
	t.Run("help flag", func(t *testing.T) {
		// Create a new command instance to avoid state issues
		cmd := rootCmd
		cmd.SetArgs([]string{"--help"})
		buf := new(bytes.Buffer)
		cmd.SetOut(buf)
		cmd.SetErr(buf)

		err := cmd.Execute()
		if err != nil {
			t.Errorf("Help command should not error: %v", err)
		}

		output := buf.String()
		if !strings.Contains(output, "Emoji Search and Destroy CLI") {
			t.Errorf("Help output should contain app description")
		}
	})

	t.Run("flags exist", func(t *testing.T) {
		// Test that our flags are registered
		if rootCmd.Flags().Lookup("no-dry-run") == nil {
			t.Error("no-dry-run flag should exist")
		}
		if rootCmd.Flags().Lookup("help") == nil {
			t.Error("help flag should exist")
		}
		if rootCmd.Flags().Lookup("version") == nil {
			t.Error("version flag should exist")
		}
	})
}

func TestExecute(t *testing.T) {
	// Save original args
	oldArgs := rootCmd.Args

	// Test Execute function
	rootCmd.SetArgs([]string{"--help"})
	buf := new(bytes.Buffer)
	rootCmd.SetOut(buf)
	rootCmd.SetErr(buf)

	err := Execute()
	if err != nil {
		t.Errorf("Execute() error = %v, want nil for help", err)
	}

	// Restore
	rootCmd.Args = oldArgs
}
