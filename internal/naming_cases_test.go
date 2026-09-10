package internal

import "testing"

func TestMixedCase(t *testing.T) {
	for _, tt := range []struct{ input, camel, pascal string }{
		{"", "", ""}, {"http_server", "httpServer", "HttpServer"},
		{"HTTPServer", "hTTPServer", "HTTPServer"}, {"UpperFirst", "upperFirst", "UpperFirst"},
		{"__leading_name", "__leadingName", "__LeadingName"},
		{"trailing_name_", "trailingName_", "TrailingName_"},
		{"value__name", "value_Name", "Value_Name"},
		{"value___name", "value__Name", "Value__Name"}, {"___", "___", "___"},
		{"class", "class_", "Class"}, {"Class", "class_", "Class"},
		{"version2_value", "version2Value", "Version2Value"},
	} {
		t.Run(tt.input, func(t *testing.T) {
			if got := toCamelCase(tt.input); got != tt.camel {
				t.Errorf("camel = %q, want %q", got, tt.camel)
			}
			if got := toPascalCase(tt.input); got != tt.pascal {
				t.Errorf("pascal = %q, want %q", got, tt.pascal)
			}
		})
	}
}

func TestSnakeCase(t *testing.T) {
	for _, tt := range []struct{ input, lower, upper string }{
		{"", "", ""}, {"HTTPServer", "http_server", "HTTP_SERVER"},
		{"version2Value", "version2_value", "VERSION2_VALUE"},
		{"already_snake", "already_snake", "ALREADY_SNAKE"},
		{"a.b-c", "a_b_c", "A_B_C"}, {"class", "class_", "CLASS"},
	} {
		if got := toSnakeCase(tt.input, false); got != tt.lower {
			t.Errorf("%q lower = %q, want %q", tt.input, got, tt.lower)
		}
		if got := toSnakeCase(tt.input, true); got != tt.upper {
			t.Errorf("%q upper = %q, want %q", tt.input, got, tt.upper)
		}
	}
}
