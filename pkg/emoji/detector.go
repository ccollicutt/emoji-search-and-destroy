// Package emoji provides functionality for detecting and removing emojis from text.
package emoji

import (
	"regexp"
)

// Detector provides methods for finding and removing emojis from text.
type Detector struct {
	emojiRegex    *regexp.Regexp
	allowedEmojis map[string]bool
}

// NewDetector creates a new emoji detector with predefined emoji patterns.
func NewDetector() *Detector {
	emojiPattern := `[\x{1F600}-\x{1F64F}]|[\x{1F300}-\x{1F5FF}]|[\x{1F680}-\x{1F6FF}]|[\x{1F1E0}-\x{1F1FF}]|[\x{2600}-\x{26FF}]|[\x{2700}-\x{27BF}]|[\x{1F900}-\x{1F9FF}]|[\x{1F018}-\x{1F0FF}]|[\x{1F90A}-\x{1F93A}]|[\x{1F940}-\x{1F94C}]|[\x{1F947}-\x{1F978}]|[\x{1F980}-\x{1F991}]|[\x{1F993}-\x{1F9A2}]|[\x{1F9A5}-\x{1F9AA}]|[\x{1F9AE}-\x{1F9CA}]|[\x{1F9CD}-\x{1F9FF}]|[\x{1FA70}-\x{1FA73}]|[\x{1FA78}-\x{1FA7A}]|[\x{1FA80}-\x{1FA82}]|[\x{1FA90}-\x{1FA95}]`
	return &Detector{
		emojiRegex:    regexp.MustCompile(emojiPattern),
		allowedEmojis: make(map[string]bool),
	}
}

// NewDetectorWithAllowed creates a new emoji detector with allowed emojis that won't be removed.
func NewDetectorWithAllowed(allowed []string) *Detector {
	detector := NewDetector()
	for _, emoji := range allowed {
		detector.allowedEmojis[emoji] = true
	}
	return detector
}

// FindEmojis returns a slice of unique emojis found in the given text (excluding allowed emojis).
func (d *Detector) FindEmojis(text string) []string {
	var emojis []string
	seen := make(map[string]bool)

	matches := d.emojiRegex.FindAllString(text, -1)
	for _, match := range matches {
		// Skip allowed emojis
		if d.allowedEmojis[match] {
			continue
		}
		if !seen[match] {
			emojis = append(emojis, match)
			seen[match] = true
		}
	}

	for _, r := range text {
		if isEmoji(r) {
			emoji := string(r)
			// Skip allowed emojis
			if d.allowedEmojis[emoji] {
				continue
			}
			if !seen[emoji] {
				emojis = append(emojis, emoji)
				seen[emoji] = true
			}
		}
	}

	return emojis
}

// RemoveEmojis removes all emojis from the given text (except allowed ones) and returns the cleaned text.
func (d *Detector) RemoveEmojis(text string) string {
	// If we have allowed emojis, we need to be more selective
	if len(d.allowedEmojis) > 0 {
		// Process character by character to preserve allowed emojis
		var cleaned []rune
		textRunes := []rune(text)

		for i := 0; i < len(textRunes); i++ {
			r := textRunes[i]
			emoji := string(r)

			// Check if this rune is an emoji
			if isEmoji(r) || d.emojiRegex.MatchString(emoji) {
				// Keep it if it's allowed
				if d.allowedEmojis[emoji] {
					cleaned = append(cleaned, r)
				}
				// Otherwise skip it (remove it)
			} else {
				// Not an emoji, keep it
				cleaned = append(cleaned, r)
			}
		}
		return string(cleaned)
	}

	// No allowed emojis, use the faster method
	result := d.emojiRegex.ReplaceAllString(text, "")

	var cleaned []rune
	for _, r := range result {
		if !isEmoji(r) {
			cleaned = append(cleaned, r)
		}
	}

	return string(cleaned)
}

func isEmoji(r rune) bool {
	if r >= 0x1F600 && r <= 0x1F64F {
		return true
	}
	if r >= 0x1F300 && r <= 0x1F5FF {
		return true
	}
	if r >= 0x1F680 && r <= 0x1F6FF {
		return true
	}
	if r >= 0x1F1E0 && r <= 0x1F1FF {
		return true
	}
	if r >= 0x2600 && r <= 0x26FF {
		return true
	}
	if r >= 0x2700 && r <= 0x27BF {
		return true
	}
	if r >= 0x1F900 && r <= 0x1F9FF {
		return true
	}
	return false
}
