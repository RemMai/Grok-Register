package email

import "testing"

func TestExtractCodeGrok(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		{"Your verification code is MM0-SF3", "MM0SF3"},
		{">ABC-DEF<", "ABCDEF"},
		{"Subject: Your code 123456 for login", "123456"},
		{"background 177010 should skip and use 654321", "654321"},
	}
	for _, tc := range cases {
		if got := extractCode(tc.in); got != tc.want {
			t.Fatalf("extractCode(%q)=%q want %q", tc.in, got, tc.want)
		}
	}
}
