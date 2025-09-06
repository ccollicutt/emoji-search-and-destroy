package emoji

import (
	"os"
	"path/filepath"
	"reflect"
	"sort"
	"strings"
	"testing"
)

func TestNewFileProcessor(t *testing.T) {
	processor := NewFileProcessor()
	if processor == nil {
		t.Fatal("NewFileProcessor() returned nil")
	}
	if processor.Detector == nil {
		t.Fatal("NewFileProcessor() did not initialize detector")
	}
}

func TestShouldSkipFile(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "test_skip_files")
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.RemoveAll(tempDir) }()

	tests := []struct {
		name     string
		filename string
		expected bool
	}{
		// Should skip - by extension
		{"executable", "file.exe", true},
		{"binary", "file.bin", true},
		{"shared object", "file.so", true},
		{"dll", "file.dll", true},
		{"jpeg image", "image.jpg", true},
		{"png image", "image.png", true},
		{"gif image", "image.gif", true},
		{"mp3 audio", "audio.mp3", true},
		{"mp4 video", "video.mp4", true},
		{"zip archive", "archive.zip", true},
		{"tar archive", "archive.tar", true},
		{"pdf document", "doc.pdf", true},
		{"socket file", "file.sock", true},

		// Should not skip
		{"text file", "file.txt", false},
		{"go file", "file.go", false},
		{"markdown", "file.md", false},
		{"json", "file.json", false},
		{"yaml", "file.yaml", false},
		{"no extension", "file", false},
		{"hidden file", ".gitignore", false},
		{"makefile", "Makefile", false},
		{"dockerfile", "Dockerfile", false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create the actual file
			filePath := filepath.Join(tempDir, tt.filename)
			_ = os.WriteFile(filePath, []byte("test content"), 0600)

			result := shouldSkipFile(filePath)
			if result != tt.expected {
				t.Errorf("shouldSkipFile(%q) = %v, want %v", filePath, result, tt.expected)
			}
		})
	}
}

func TestFileProcessor_ProcessFile(t *testing.T) {
	// Create temporary directory for test files
	tempDir, err := os.MkdirTemp("", "emoji_processor_test_")
	if err != nil {
		t.Fatal("Failed to create temp directory:", err)
	}
	defer func() { _ = os.RemoveAll(tempDir) }()

	processor := NewFileProcessor()

	tests := []struct {
		name             string
		filename         string
		content          string
		dryRun           bool
		expectedEmojis   []string
		expectedModified bool
		expectedContent  string // for non-dry-run tests
	}{
		{
			name:             "file with emojis - dry run",
			filename:         "test_emojis.txt",
			content:          "Hello 😊 world 🌍",
			dryRun:           true,
			expectedEmojis:   []string{"😊", "🌍"},
			expectedModified: true,
			expectedContent:  "Hello 😊 world 🌍", // unchanged in dry run
		},
		{
			name:             "file with emojis - actual removal",
			filename:         "test_emojis_remove.txt",
			content:          "Hello 😊 world 🌍",
			dryRun:           false,
			expectedEmojis:   []string{"😊", "🌍"},
			expectedModified: true,
			expectedContent:  "Hello  world ",
		},
		{
			name:             "file without emojis",
			filename:         "test_clean.txt",
			content:          "Hello world, no emojis here",
			dryRun:           false,
			expectedEmojis:   []string{},
			expectedModified: false,
			expectedContent:  "Hello world, no emojis here",
		},
		{
			name:             "empty file",
			filename:         "test_empty.txt",
			content:          "",
			dryRun:           false,
			expectedEmojis:   []string{},
			expectedModified: false,
			expectedContent:  "",
		},
		{
			name:             "file with only emojis",
			filename:         "test_only_emojis.txt",
			content:          "😊🌍🚀",
			dryRun:           false,
			expectedEmojis:   []string{"😊", "🌍", "🚀"},
			expectedModified: true,
			expectedContent:  "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create test file
			filePath := filepath.Join(tempDir, tt.filename)
			err := os.WriteFile(filePath, []byte(tt.content), 0600) // #nosec G306 -- test file
			if err != nil {
				t.Fatal("Failed to create test file:", err)
			}

			// Process the file
			result, err := processor.ProcessFile(filePath, tt.dryRun)
			if err != nil {
				t.Fatal("ProcessFile failed:", err)
			}

			// Check file path
			if result.FilePath != filePath {
				t.Errorf("Expected FilePath %q, got %q", filePath, result.FilePath)
			}

			// Check emojis found
			sort.Strings(result.EmojisFound)
			expectedEmojis := make([]string, len(tt.expectedEmojis))
			copy(expectedEmojis, tt.expectedEmojis)
			sort.Strings(expectedEmojis)

			// Handle nil vs empty slice comparison
			if len(result.EmojisFound) != 0 || len(expectedEmojis) != 0 {
				if !reflect.DeepEqual(result.EmojisFound, expectedEmojis) {
					t.Errorf("Expected emojis %v, got %v", expectedEmojis, result.EmojisFound)
				}
			}

			// Check modified flag
			if result.Modified != tt.expectedModified {
				t.Errorf("Expected Modified %v, got %v", tt.expectedModified, result.Modified)
			}

			// Check original size
			if result.OriginalSize != int64(len(tt.content)) {
				t.Errorf("Expected OriginalSize %d, got %d", len(tt.content), result.OriginalSize)
			}

			// Check file content after processing (for non-dry-run)
			if !tt.dryRun {
				actualContent, err := os.ReadFile(filePath) // #nosec G304 -- test file
				if err != nil {
					t.Fatal("Failed to read processed file:", err)
				}
				if string(actualContent) != tt.expectedContent {
					t.Errorf("Expected file content %q, got %q", tt.expectedContent, string(actualContent))
				}

				// Check new size
				if result.Modified && result.NewSize != int64(len(tt.expectedContent)) {
					t.Errorf("Expected NewSize %d, got %d", len(tt.expectedContent), result.NewSize)
				}
			}
		})
	}
}

func TestFileProcessor_ProcessDirectory(t *testing.T) {
	// Create temporary directory structure
	tempDir, err := os.MkdirTemp("", "emoji_processor_dir_test_")
	if err != nil {
		t.Fatal("Failed to create temp directory:", err)
	}
	defer func() { _ = os.RemoveAll(tempDir) }()

	// Create subdirectory
	subDir := filepath.Join(tempDir, "subdir")
	err = os.Mkdir(subDir, 0750) // #nosec G301 -- test directory
	if err != nil {
		t.Fatal("Failed to create subdirectory:", err)
	}

	// Create test files
	files := map[string]string{
		"emoji_file.txt":          "Hello 😊 world 🌍",
		"clean_file.txt":          "No emojis here",
		"empty_file.txt":          "",
		"subdir/nested_emoji.txt": "Nested 🚀 file",
		"subdir/nested_clean.txt": "Nested clean file",
		"binary_file.exe":         "fake binary content", // should be skipped
	}

	for relPath, content := range files {
		fullPath := filepath.Join(tempDir, relPath)
		err := os.WriteFile(fullPath, []byte(content), 0600) // #nosec G306 -- test file
		if err != nil {
			t.Fatal("Failed to create test file:", err)
		}
	}

	processor := NewFileProcessor()

	t.Run("dry run", func(t *testing.T) {
		results, err := processor.ProcessDirectory(tempDir, true)
		if err != nil {
			t.Fatal("ProcessDirectory failed:", err)
		}

		// Should find files with emojis (emoji_file.txt and nested_emoji.txt)
		// Should skip binary files and files without emojis
		expectedFileCount := 2
		if len(results) != expectedFileCount {
			t.Errorf("Expected %d results, got %d", expectedFileCount, len(results))
		}

		// Check that files with emojis are included
		foundFiles := make(map[string]bool)
		for _, result := range results {
			foundFiles[filepath.Base(result.FilePath)] = true
		}

		expectedFiles := []string{"emoji_file.txt", "nested_emoji.txt"}
		for _, expectedFile := range expectedFiles {
			if !foundFiles[expectedFile] {
				t.Errorf("Expected to find file %s in results", expectedFile)
			}
		}

		// Verify files are not modified in dry run
		originalContent, err := os.ReadFile(filepath.Join(tempDir, "emoji_file.txt")) // #nosec G304 -- test file
		if err != nil {
			t.Fatal("Failed to read file:", err)
		}
		if string(originalContent) != "Hello 😊 world 🌍" {
			t.Error("File was modified during dry run")
		}
	})

	t.Run("actual processing", func(t *testing.T) {
		results, err := processor.ProcessDirectory(tempDir, false)
		if err != nil {
			t.Fatal("ProcessDirectory failed:", err)
		}

		// Should find same files as dry run
		expectedFileCount := 2
		if len(results) != expectedFileCount {
			t.Errorf("Expected %d results, got %d", expectedFileCount, len(results))
		}

		// Verify files are actually modified
		processedContent, err := os.ReadFile(filepath.Join(tempDir, "emoji_file.txt")) // #nosec G304 -- test file
		if err != nil {
			t.Fatal("Failed to read processed file:", err)
		}
		expectedContent := "Hello  world "
		if string(processedContent) != expectedContent {
			t.Errorf("Expected processed content %q, got %q", expectedContent, string(processedContent))
		}

		// Verify clean files are unchanged
		cleanContent, err := os.ReadFile(filepath.Join(tempDir, "clean_file.txt")) // #nosec G304 -- test file
		if err != nil {
			t.Fatal("Failed to read clean file:", err)
		}
		if string(cleanContent) != "No emojis here" {
			t.Error("Clean file was unexpectedly modified")
		}
	})
}

func TestFileProcessor_ProcessDirectory_Errors(t *testing.T) {
	processor := NewFileProcessor()

	t.Run("non-existent directory", func(t *testing.T) {
		_, err := processor.ProcessDirectory("/non/existent/directory", false)
		if err == nil {
			t.Error("Expected error for non-existent directory")
		}
	})
}

func TestFileProcessor_ProcessFile_FilePermissions(t *testing.T) {
	// Create temporary directory
	tempDir, err := os.MkdirTemp("", "emoji_processor_perm_test_")
	if err != nil {
		t.Fatal("Failed to create temp directory:", err)
	}
	defer func() { _ = os.RemoveAll(tempDir) }()

	processor := NewFileProcessor()

	// Test file that gets processed has correct permissions
	filePath := filepath.Join(tempDir, "test_permissions.txt")
	content := "Hello 😊 world"
	err = os.WriteFile(filePath, []byte(content), 0600) // #nosec G306 -- test file
	if err != nil {
		t.Fatal("Failed to create test file:", err)
	}

	// Process file
	_, err = processor.ProcessFile(filePath, false)
	if err != nil {
		t.Fatal("ProcessFile failed:", err)
	}

	// Check that file has restrictive permissions (0600) after processing
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		t.Fatal("Failed to stat processed file:", err)
	}

	// The file should be readable/writable only by owner (0600)
	actualPerm := fileInfo.Mode().Perm()

	// Check that file has exactly 0600 permissions
	expectedPerm := os.FileMode(0600)
	if actualPerm != expectedPerm {
		t.Errorf("Expected file permissions %v, got %v", expectedPerm, actualPerm)
	}
}

func TestFileProcessor_ProcessFile_ReadError(t *testing.T) {
	processor := NewFileProcessor()

	// Try to process a non-existent file
	result, err := processor.ProcessFile("/non/existent/file.txt", false)
	if err == nil {
		t.Error("Expected error for non-existent file")
	}
	// The result should still have the filepath set even on error
	if result.FilePath != "/non/existent/file.txt" {
		t.Errorf("Result filepath = %v, want /non/existent/file.txt", result.FilePath)
	}
}

func TestFileProcessor_ProcessDirectory_WalkError(t *testing.T) {
	processor := NewFileProcessor()

	// Create a directory with a file, then remove read permissions
	tempDir, err := os.MkdirTemp("", "test_walk_error")
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.RemoveAll(tempDir) }()

	// Create a subdirectory
	subDir := filepath.Join(tempDir, "subdir")
	_ = os.Mkdir(subDir, 0750)

	// Create a file in subdirectory
	testFile := filepath.Join(subDir, "test.txt")
	_ = os.WriteFile(testFile, []byte("Test 😊"), 0600)

	// Remove read permissions from subdirectory to cause walk error
	_ = os.Chmod(subDir, 0000)
	defer func() { _ = os.Chmod(subDir, 0700) }() // #nosec G302 -- test cleanup

	// Process directory - should handle permission error gracefully
	results, err := processor.ProcessDirectory(tempDir, true)
	// The walk may succeed but skip the unreadable directory
	// or it may return an error depending on the OS
	if err == nil {
		// If no error, results should be empty or partial
		if len(results) > 1 {
			t.Errorf("Expected at most 1 result for partially accessible directory, got %d", len(results))
		}
	}
}

func TestShouldSkipFile_NonRegularFiles(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "test_skip_files")
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.RemoveAll(tempDir) }()

	// Test with a regular file (should not skip)
	regularFile := filepath.Join(tempDir, "regular.txt")
	_ = os.WriteFile(regularFile, []byte("test"), 0600)

	if shouldSkipFile(regularFile) {
		t.Error("Regular file should not be skipped")
	}

	// Test with non-existent file (should skip)
	nonExistentFile := filepath.Join(tempDir, "nonexistent.txt")
	if !shouldSkipFile(nonExistentFile) {
		t.Error("Non-existent file should be skipped")
	}

	// Test with directory (should skip)
	testDir := filepath.Join(tempDir, "testdir")
	_ = os.Mkdir(testDir, 0750)
	if !shouldSkipFile(testDir) {
		t.Error("Directory should be skipped")
	}
}

func TestProcessDirectory_SkipsVCSDirectories(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "test_vcs_skip")
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.RemoveAll(tempDir) }()

	processor := NewFileProcessor()

	// Create .git directory with files
	gitDir := filepath.Join(tempDir, ".git", "objects")
	_ = os.MkdirAll(gitDir, 0750)
	gitFile := filepath.Join(gitDir, "test_object")
	_ = os.WriteFile(gitFile, []byte("fake git object with emoji 😊"), 0600)

	// Create regular file with emoji
	regularFile := filepath.Join(tempDir, "regular.txt")
	_ = os.WriteFile(regularFile, []byte("regular file with emoji 🚀"), 0600)

	// Process directory
	results, err := processor.ProcessDirectory(tempDir, true)
	if err != nil {
		t.Fatal(err)
	}

	// Should only find the regular file, not the git object
	if len(results) != 1 {
		t.Errorf("Expected 1 result (regular file only), got %d", len(results))
	}

	if len(results) > 0 && !strings.Contains(results[0].FilePath, "regular.txt") {
		t.Errorf("Expected to find regular.txt, got %s", results[0].FilePath)
	}
}

func TestFileProcessor_WithExcludes(t *testing.T) {
	// Create temporary directory structure
	tempDir, err := os.MkdirTemp("", "emoji_exclude_test_")
	if err != nil {
		t.Fatal("Failed to create temp directory:", err)
	}
	defer func() { _ = os.RemoveAll(tempDir) }()

	// Create directory structure with files
	testFiles := map[string]string{
		"file1.txt":                  "emoji 😊 in file1",
		"file2.txt":                  "emoji 🚀 in file2",
		"skip.txt":                   "emoji 🌍 in skip",
		"node_modules/package.json":  "emoji 🎉 in node_modules",
		"vendor/lib.go":              "emoji 🔥 in vendor",
		"test.spec.js":               "emoji ⚡ in test",
		"config.json":                "emoji 💻 in config",
		"src/main.go":                "emoji 🎨 in src",
		"build/output.txt":           "emoji 🏗️ in build",
		"subdir/nested.txt":          "emoji 🔄 in nested",
		"subdir/excluded/secret.txt": "emoji 🔒 in secret",
	}

	// Create all files
	for relPath, content := range testFiles {
		fullPath := filepath.Join(tempDir, relPath)
		dir := filepath.Dir(fullPath)
		_ = os.MkdirAll(dir, 0750)
		_ = os.WriteFile(fullPath, []byte(content), 0600)
	}

	tests := []struct {
		name            string
		excludes        []string
		expectedFiles   []string
		unexpectedFiles []string
	}{
		{
			name:            "exclude specific file",
			excludes:        []string{"skip.txt"},
			expectedFiles:   []string{"file1.txt", "file2.txt", "main.go"},
			unexpectedFiles: []string{"skip.txt"},
		},
		{
			name:            "exclude directory",
			excludes:        []string{"node_modules"},
			expectedFiles:   []string{"file1.txt", "file2.txt"},
			unexpectedFiles: []string{"package.json"},
		},
		{
			name:            "exclude multiple directories",
			excludes:        []string{"node_modules", "vendor", "build"},
			expectedFiles:   []string{"file1.txt", "file2.txt", "main.go"},
			unexpectedFiles: []string{"package.json", "lib.go", "output.txt"},
		},
		{
			name:            "exclude with glob pattern",
			excludes:        []string{"*.spec.js"},
			expectedFiles:   []string{"file1.txt", "file2.txt"},
			unexpectedFiles: []string{"test.spec.js"},
		},
		{
			name:            "exclude nested directory",
			excludes:        []string{"excluded"},
			expectedFiles:   []string{"file1.txt", "nested.txt"},
			unexpectedFiles: []string{"secret.txt"},
		},
		{
			name:            "multiple exclusion patterns",
			excludes:        []string{"node_modules", "*.spec.js", "config.json", "vendor"},
			expectedFiles:   []string{"file1.txt", "file2.txt", "main.go"},
			unexpectedFiles: []string{"package.json", "test.spec.js", "config.json", "lib.go"},
		},
		{
			name:            "absolute path exclusion",
			excludes:        []string{filepath.Join(tempDir, "build")},
			expectedFiles:   []string{"file1.txt", "file2.txt"},
			unexpectedFiles: []string{"output.txt"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			processor := NewFileProcessorWithExcludes(tt.excludes)
			results, err := processor.ProcessDirectory(tempDir, true)
			if err != nil {
				t.Fatal("ProcessDirectory failed:", err)
			}

			// Create map of found files for easier checking
			foundFiles := make(map[string]bool)
			for _, result := range results {
				filename := filepath.Base(result.FilePath)
				foundFiles[filename] = true
			}

			// Check expected files are found
			for _, expectedFile := range tt.expectedFiles {
				if !foundFiles[expectedFile] {
					t.Errorf("Expected to find %s but it was not processed", expectedFile)
				}
			}

			// Check unexpected files are not found
			for _, unexpectedFile := range tt.unexpectedFiles {
				if foundFiles[unexpectedFile] {
					t.Errorf("Did not expect to find %s but it was processed", unexpectedFile)
				}
			}
		})
	}
}

func TestFileProcessor_IsExcluded(t *testing.T) {
	tests := []struct {
		name     string
		excludes []string
		path     string
		expected bool
	}{
		// Directory name matching
		{
			name:     "exact directory name",
			excludes: []string{"node_modules"},
			path:     "/project/node_modules/file.js",
			expected: true,
		},
		{
			name:     "directory not in path",
			excludes: []string{"node_modules"},
			path:     "/project/src/file.js",
			expected: false,
		},
		// File name matching
		{
			name:     "exact file name",
			excludes: []string{"config.json"},
			path:     "/project/config.json",
			expected: true,
		},
		{
			name:     "file name in subdirectory",
			excludes: []string{"config.json"},
			path:     "/project/src/config.json",
			expected: true,
		},
		// Glob patterns
		{
			name:     "glob pattern match",
			excludes: []string{"*.test.js"},
			path:     "/project/app.test.js",
			expected: true,
		},
		{
			name:     "glob pattern no match",
			excludes: []string{"*.test.js"},
			path:     "/project/app.js",
			expected: false,
		},
		// Absolute paths
		{
			name:     "absolute path exact match",
			excludes: []string{"/home/user/project/build"},
			path:     "/home/user/project/build",
			expected: true,
		},
		{
			name:     "absolute path subdirectory",
			excludes: []string{"/home/user/project/build"},
			path:     "/home/user/project/build/output.txt",
			expected: true,
		},
		// Multiple excludes
		{
			name:     "multiple excludes - first matches",
			excludes: []string{"node_modules", "vendor"},
			path:     "/project/node_modules/lib.js",
			expected: true,
		},
		{
			name:     "multiple excludes - second matches",
			excludes: []string{"node_modules", "vendor"},
			path:     "/project/vendor/lib.go",
			expected: true,
		},
		{
			name:     "multiple excludes - none match",
			excludes: []string{"node_modules", "vendor"},
			path:     "/project/src/main.go",
			expected: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			processor := NewFileProcessorWithExcludes(tt.excludes)
			result := processor.isExcluded(tt.path)
			if result != tt.expected {
				t.Errorf("isExcluded(%q) with excludes %v = %v, want %v",
					tt.path, tt.excludes, result, tt.expected)
			}
		})
	}
}
