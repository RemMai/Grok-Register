package config

import "testing"

func TestNormalizeMailAPIBase(t *testing.T) {
	cases := map[string]string{
		"https://x.workers.dev/":                      "https://x.workers.dev",
		"https://x.workers.dev/admin":                 "https://x.workers.dev",
		"https://x.workers.dev/admin/new_address":     "https://x.workers.dev",
		"https://x.workers.dev/api/mails":             "https://x.workers.dev",
		"https://x.workers.dev/api":                   "https://x.workers.dev",
		"  https://x.workers.dev/api/new_address  ": "https://x.workers.dev",
	}
	for in, want := range cases {
		if got := NormalizeMailAPIBase(in); got != want {
			t.Fatalf("NormalizeMailAPIBase(%q)=%q want %q", in, got, want)
		}
	}
}

func TestNormalizeEmailMode(t *testing.T) {
	cases := map[string]EmailMode{
		"cloudflare":             EmailCloudflare,
		"cf":                     EmailCloudflare,
		"cloudflare_temp_email":  EmailCloudflare,
		"vmail":                  EmailCloudflare,
		"tempmail":               EmailTempmail,
		"testmail":               EmailTestmail,
		"custom":                 EmailCustom,
	}
	for in, want := range cases {
		if got := NormalizeEmailMode(in); got != want {
			t.Fatalf("NormalizeEmailMode(%q)=%q want %q", in, got, want)
		}
	}
}

func TestNormalizeCloudflareAuthMode(t *testing.T) {
	cases := map[string]string{
		"":            "x-admin-auth",
		"admin":       "x-admin-auth",
		"none":        "none",
		"bearer":      "bearer",
		"x-api-key":   "x-api-key",
		"query-key":   "query-key",
	}
	for in, want := range cases {
		if got := NormalizeCloudflareAuthMode(in); got != want {
			t.Fatalf("NormalizeCloudflareAuthMode(%q)=%q want %q", in, got, want)
		}
	}
}
