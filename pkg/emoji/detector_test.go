package emoji

import (
	"reflect"
	"sort"
	"testing"
)

func TestNewDetector(t *testing.T) {
	detector := NewDetector()
	if detector == nil {
		t.Fatal("NewDetector() returned nil")
	}
	if detector.emojiRegex == nil {
		t.Fatal("NewDetector() did not initialize regex")
	}
}

func TestDetector_FindEmojis(t *testing.T) {
	detector := NewDetector()

	tests := []struct {
		name     string
		input    string
		expected []string
	}{
		{
			name:     "no emojis",
			input:    "Hello world, this is plain text",
			expected: []string{}, // FindEmojis returns empty slice for no matches
		},
		{
			name:     "single emoji",
			input:    "Hello 😊 world",
			expected: []string{"😊"},
		},
		{
			name:     "multiple different emojis",
			input:    "Hello 😊 world 🌍 test 🚀",
			expected: []string{"😊", "🌍", "🚀"},
		},
		{
			name:     "duplicate emojis",
			input:    "Hello 😊 world 😊 again 😊",
			expected: []string{"😊"},
		},
		{
			name:     "emoji found by both regex and rune check",
			input:    "Test 😊😊 double",
			expected: []string{"😊"},
		},
		{
			name:     "mixed content with emojis",
			input:    "Code: function() { return 'test' 🎯 } // Comment 💯",
			expected: []string{"🎯", "💯"},
		},
		{
			name:     "various emoji categories",
			input:    "Faces 😊😢 Objects 🚀🎯 Symbols ✅⚡",
			expected: []string{"😊", "😢", "🚀", "🎯", "✅", "⚡"},
		},
		{
			name:     "empty string",
			input:    "",
			expected: []string{},
		},
		{
			name:     "only emojis",
			input:    "😊🌍🚀✨🎉💯",
			expected: []string{"😊", "🌍", "🚀", "✨", "🎉", "💯"},
		},
		{
			name:     "emoji at start and end",
			input:    "🎉 Party time! 🚀",
			expected: []string{"🎉", "🚀"},
		},
		{
			name:     "unicode chars that are not emojis",
			input:    "Café résumé naïve 中文 العربية русский",
			expected: []string{},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := detector.FindEmojis(tt.input)

			// Handle nil vs empty slice comparison
			if len(result) == 0 && len(tt.expected) == 0 {
				// Both are empty, this is correct
				return
			}

			// Sort both slices for comparison since order may vary
			sort.Strings(result)
			expected := make([]string, len(tt.expected))
			copy(expected, tt.expected)
			sort.Strings(expected)

			if !reflect.DeepEqual(result, expected) {
				t.Errorf("FindEmojis(%q) = %v, want %v", tt.input, result, expected)
			}
		})
	}
}

func TestDetector_RemoveEmojis(t *testing.T) {
	detector := NewDetector()

	tests := []struct {
		name     string
		input    string
		expected string
	}{
		{
			name:     "no emojis",
			input:    "Hello world, this is plain text",
			expected: "Hello world, this is plain text",
		},
		{
			name:     "single emoji",
			input:    "Hello 😊 world",
			expected: "Hello  world",
		},
		{
			name:     "multiple emojis",
			input:    "Hello 😊 world 🌍 test 🚀",
			expected: "Hello  world  test ",
		},
		{
			name:     "emoji at start",
			input:    "😊 Hello world",
			expected: " Hello world",
		},
		{
			name:     "emoji at end",
			input:    "Hello world 🚀",
			expected: "Hello world ",
		},
		{
			name:     "consecutive emojis",
			input:    "Hello 😊🌍🚀 world",
			expected: "Hello  world",
		},
		{
			name:     "only emojis",
			input:    "😊🌍🚀✨🎉💯",
			expected: "",
		},
		{
			name:     "empty string",
			input:    "",
			expected: "",
		},
		{
			name:     "mixed content",
			input:    "function test() { return 'hello 🚀'; } // Comment 💯",
			expected: "function test() { return 'hello '; } // Comment ",
		},
		{
			name:     "preserve unicode non-emojis",
			input:    "Café 😊 résumé 🚀 naïve",
			expected: "Café  résumé  naïve",
		},
		{
			name:     "preserve symbols and punctuation",
			input:    "Price: $100 😊 (discount available!) 🎉",
			expected: "Price: $100  (discount available!) ",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := detector.RemoveEmojis(tt.input)
			if result != tt.expected {
				t.Errorf("RemoveEmojis(%q) = %q, want %q", tt.input, result, tt.expected)
			}
		})
	}
}

func TestIsEmoji(t *testing.T) {
	tests := []struct {
		name     string
		input    rune
		expected bool
	}{
		// Emoji ranges
		{"smiley face", '😊', true},
		{"rocket", '🚀', true},
		{"globe", '🌍', true},
		{"checkmark", '✅', true},
		{"lightning", '⚡', true},
		{"target", '🎯', true},

		// Non-emoji characters
		{"letter a", 'a', false},
		{"number 1", '1', false},
		{"space", ' ', false},
		{"exclamation", '!', false},
		{"at symbol", '@', false},

		// Unicode non-emoji
		{"accented e", 'é', false},
		{"chinese char", '中', false},
		{"arabic char", 'ع', false},
		{"cyrillic char", 'р', false},

		// Edge cases
		{"null char", '\x00', false},
		{"tab", '\t', false},
		{"newline", '\n', false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isEmoji(tt.input)
			if result != tt.expected {
				t.Errorf("isEmoji(%c) = %v, want %v", tt.input, result, tt.expected)
			}
		})
	}
}

func TestDetector_EdgeCases(t *testing.T) {
	detector := NewDetector()

	t.Run("very long string with emojis", func(t *testing.T) {
		longString := ""
		for i := 0; i < 1000; i++ {
			longString += "text "
			if i%10 == 0 {
				longString += "😊 "
			}
		}

		emojis := detector.FindEmojis(longString)
		if len(emojis) != 1 || emojis[0] != "😊" {
			t.Errorf("Expected exactly one unique emoji '😊', got %v", emojis)
		}

		cleaned := detector.RemoveEmojis(longString)
		if detector.FindEmojis(cleaned) != nil && len(detector.FindEmojis(cleaned)) > 0 {
			t.Errorf("Cleaned string should not contain emojis")
		}
	})

	t.Run("string with only whitespace and emojis", func(t *testing.T) {
		input := "   😊   🚀   "
		emojis := detector.FindEmojis(input)
		expectedEmojis := []string{"😊", "🚀"}

		sort.Strings(emojis)
		sort.Strings(expectedEmojis)

		if !reflect.DeepEqual(emojis, expectedEmojis) {
			t.Errorf("Expected %v, got %v", expectedEmojis, emojis)
		}

		cleaned := detector.RemoveEmojis(input)
		expected := "         " // 3 spaces + 3 spaces + 3 spaces after emoji removal
		if cleaned != expected {
			t.Errorf("Expected %q, got %q", expected, cleaned)
		}
	})

	t.Run("multiline string with emojis", func(t *testing.T) {
		input := "Line 1 😊\nLine 2 🚀\nLine 3 plain text"
		emojis := detector.FindEmojis(input)
		expectedEmojis := []string{"😊", "🚀"}

		sort.Strings(emojis)
		sort.Strings(expectedEmojis)

		if !reflect.DeepEqual(emojis, expectedEmojis) {
			t.Errorf("Expected %v, got %v", expectedEmojis, emojis)
		}

		cleaned := detector.RemoveEmojis(input)
		expected := "Line 1 \nLine 2 \nLine 3 plain text"
		if cleaned != expected {
			t.Errorf("Expected %q, got %q", expected, cleaned)
		}
	})
}
