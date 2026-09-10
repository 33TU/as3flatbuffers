package internal

import (
	"strings"
)

func toSnakeCase(s string, upper bool) string {
	if s == "" {
		return ""
	}

	var b strings.Builder
	b.Grow(len(s) + len(s)/2)

	for i := 0; i < len(s); i++ {
		c := s[i]

		if c == '-' || c == '.' {
			c = '_'
		}

		if i > 0 && c != '_' {
			prev := s[i-1]
			nextLower := i+1 < len(s) && isLower(s[i+1])

			if (isLower(prev) || isDigit(prev)) && isUpper(c) {
				b.WriteByte('_')
			} else if isUpper(prev) && isUpper(c) && nextLower {
				b.WriteByte('_')
			}
		}

		if upper {
			c = toUpper(c)
		} else {
			c = toLower(c)
		}
		b.WriteByte(c)
	}

	return escapeReserved(b.String())
}

func toCamelCase(s string) string {
	return toMixedCase(s, false)
}

func toPascalCase(s string) string {
	return toMixedCase(s, true)
}

func toMixedCase(s string, upperFirst bool) string {
	if s == "" {
		return ""
	}

	var b strings.Builder
	b.Grow(len(s))

	upperNext := upperFirst
	started := false
	underscoreRun := 0

	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '_' {
			underscoreRun++
			if started {
				upperNext = true
			}
			continue
		}

		if !started && underscoreRun > 0 {
			b.WriteString(strings.Repeat("_", underscoreRun))
		} else if underscoreRun > 1 {
			b.WriteString(strings.Repeat("_", underscoreRun-1))
		}
		underscoreRun = 0

		if upperNext {
			c = toUpper(c)
			upperNext = false
		} else if !started && !upperFirst {
			c = toLower(c)
		}

		b.WriteByte(c)
		started = true
	}

	if underscoreRun > 0 {
		b.WriteString(strings.Repeat("_", underscoreRun))
	}

	return escapeReserved(b.String())
}

func isLower(c byte) bool {
	return c >= 'a' && c <= 'z'
}

func isUpper(c byte) bool {
	return c >= 'A' && c <= 'Z'
}

func isDigit(c byte) bool {
	return c >= '0' && c <= '9'
}

func toLower(c byte) byte {
	if isUpper(c) {
		return c + ('a' - 'A')
	}
	return c
}

func toUpper(c byte) byte {
	if isLower(c) {
		return c - ('a' - 'A')
	}
	return c
}

func escapeReserved(name string) string {
	if IsAS3ReservedWord(name) {
		return name + "_"
	}
	return name
}
