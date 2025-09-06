package version

import (
	"testing"
)

func TestVersion(t *testing.T) {
	// Test that Version is not empty
	if Version == "" {
		t.Error("Version should not be empty")
	}

	// Test that Version follows semantic versioning pattern (x.y.z)
	if len(Version) < 5 { // Minimum: "0.0.1"
		t.Errorf("Version should follow semantic versioning format, got: %s", Version)
	}

	// Test that other constants are set
	if Name == "" {
		t.Error("Name should not be empty")
	}

	if Description == "" {
		t.Error("Description should not be empty")
	}
}
