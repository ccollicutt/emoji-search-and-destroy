package emoji

import (
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

// FileProcessor handles processing files to remove emojis.
type FileProcessor struct {
	Detector *Detector // Made public so commands can access it
	excludes []string
}

// ProcessResult contains the results of processing a single file.
type ProcessResult struct {
	FilePath     string
	EmojisFound  []string
	OriginalSize int64
	NewSize      int64
	Modified     bool
}

// NewFileProcessor creates a new file processor with an emoji Detector.
func NewFileProcessor() *FileProcessor {
	return &FileProcessor{
		Detector: NewDetector(),
		excludes: []string{},
	}
}

// NewFileProcessorWithExcludes creates a new file processor with an emoji Detector and exclusion patterns.
func NewFileProcessorWithExcludes(excludes []string) *FileProcessor {
	return &FileProcessor{
		Detector: NewDetector(),
		excludes: excludes,
	}
}

// NewFileProcessorWithExcludesAndAllowed creates a new file processor with an emoji Detector, exclusion patterns, and allowed emojis.
func NewFileProcessorWithExcludesAndAllowed(excludes []string, allowed []string) *FileProcessor {
	return &FileProcessor{
		Detector: NewDetectorWithAllowed(allowed),
		excludes: excludes,
	}
}

// ProcessDirectory processes all files in a directory to find and optionally remove emojis.
func (fp *FileProcessor) ProcessDirectory(dirPath string, dryRun bool) ([]ProcessResult, error) {
	var results []ProcessResult

	err := filepath.WalkDir(dirPath, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		// Check if path should be excluded
		if fp.isExcluded(path) {
			if d.IsDir() {
				return fs.SkipDir
			}
			return nil
		}

		if d.IsDir() {
			return nil
		}

		// Skip files in .git directories and other version control directories
		if strings.Contains(path, "/.git/") || strings.Contains(path, "/.svn/") || strings.Contains(path, "/.hg/") {
			return nil
		}

		if shouldSkipFile(path) {
			return nil
		}

		result, err := fp.ProcessFile(path, dryRun)
		if err != nil {
			return fmt.Errorf("failed to process %s: %w", path, err)
		}

		if len(result.EmojisFound) > 0 {
			results = append(results, result)
		}

		return nil
	})

	return results, err
}

// ProcessFile processes a single file to find and optionally remove emojis.
func (fp *FileProcessor) ProcessFile(filePath string, dryRun bool) (ProcessResult, error) {
	content, err := os.ReadFile(filePath) // #nosec G304 -- filePath is user-provided directory path
	if err != nil {
		return ProcessResult{FilePath: filePath}, fmt.Errorf("failed to read file: %w", err)
	}

	originalText := string(content)
	emojis := fp.Detector.FindEmojis(originalText)

	result := ProcessResult{
		FilePath:     filePath,
		EmojisFound:  emojis,
		OriginalSize: int64(len(content)),
		Modified:     false,
	}

	if len(emojis) == 0 {
		return result, nil
	}

	cleanedText := fp.Detector.RemoveEmojis(originalText)
	result.NewSize = int64(len(cleanedText))
	result.Modified = true

	if !dryRun {
		if err := os.WriteFile(filePath, []byte(cleanedText), 0600); err != nil {
			return result, fmt.Errorf("failed to write cleaned file: %w", err)
		}
		// Explicitly set permissions to ensure they are correct regardless of umask
		if err := os.Chmod(filePath, 0600); err != nil {
			return result, fmt.Errorf("failed to set file permissions: %w", err)
		}
	}

	return result, nil
}

func shouldSkipFile(path string) bool {
	// Check file type first
	info, err := os.Stat(path)
	if err != nil {
		// If we can't stat the file, skip it to avoid errors
		return true
	}

	mode := info.Mode()

	// Skip non-regular files (sockets, devices, pipes, etc.)
	if !mode.IsRegular() {
		return true
	}

	// Check file extensions
	ext := filepath.Ext(path)
	skipExtensions := map[string]bool{
		".exe": true, ".bin": true, ".so": true, ".dll": true,
		".jpg": true, ".jpeg": true, ".png": true, ".gif": true, ".bmp": true,
		".mp3": true, ".mp4": true, ".avi": true, ".mov": true,
		".zip": true, ".tar": true, ".gz": true, ".7z": true,
		".pdf":  true,
		".sock": true, // Add socket extension explicitly too
	}

	return skipExtensions[ext]
}

// isExcluded checks if a path matches any of the exclusion patterns.
func (fp *FileProcessor) isExcluded(path string) bool {
	for _, exclude := range fp.excludes {
		// Check for exact match or if exclude is a directory/file name
		if matched := fp.matchExclude(path, exclude); matched {
			return true
		}
	}
	return false
}

// matchExclude checks if a path matches an exclusion pattern.
func (fp *FileProcessor) matchExclude(path, pattern string) bool {
	// Clean the path for consistent comparison
	path = filepath.Clean(path)
	pattern = filepath.Clean(pattern)

	// Check for exact path match
	if path == pattern {
		return true
	}

	// Check if pattern is an absolute path
	if filepath.IsAbs(pattern) {
		// For absolute paths, check if the path starts with the pattern
		if strings.HasPrefix(path, pattern+string(filepath.Separator)) || path == pattern {
			return true
		}
		return false
	}

	// For relative patterns, check multiple matching strategies
	// 1. Check if any path component matches the pattern (for directory names)
	pathParts := strings.Split(path, string(filepath.Separator))
	for _, part := range pathParts {
		if part == pattern {
			return true
		}
	}

	// 2. Check if the path ends with the pattern (for file names)
	if strings.HasSuffix(path, string(filepath.Separator)+pattern) || filepath.Base(path) == pattern {
		return true
	}

	// 3. Check for glob pattern matching
	if strings.Contains(pattern, "*") || strings.Contains(pattern, "?") {
		// Try matching against the full path
		if matched, err := filepath.Match(pattern, path); err == nil && matched {
			return true
		}
		// Try matching against just the filename
		if matched, err := filepath.Match(pattern, filepath.Base(path)); err == nil && matched {
			return true
		}
	}

	return false
}
