package desktop

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestDesktopRequestBoundary(t *testing.T) {
	b := &Bridge{address: "127.0.0.1:12345", origin: "http://127.0.0.1:8384", token: strings.Repeat("a", 64)}
	for _, scenario := range []string{"origin", "host", "token", "get", "oversized", "unknown-field", "trailing", "preflight"} {
		t.Run(scenario, func(t *testing.T) {
			body := "{}"
			method := http.MethodPost
			if scenario == "oversized" {
				body = strings.Repeat("x", 17000)
			}
			if scenario == "unknown-field" {
				body = `{"command":"rm"}`
			}
			if scenario == "trailing" {
				body = "{} {}"
			}
			if scenario == "get" {
				method = http.MethodGet
			}
			if scenario == "preflight" {
				method = http.MethodOptions
			}
			r := httptest.NewRequest(method, "http://"+b.address+"/rename", strings.NewReader(body))
			r.Header.Set("Origin", b.origin)
			r.Header.Set("X-Syncshell-Token", b.token)
			if scenario == "origin" {
				r.Header.Set("Origin", "https://unrelated.example")
			}
			if scenario == "host" {
				r.Host = "attacker.example"
			}
			if scenario == "token" {
				r.Header.Del("X-Syncshell-Token")
			}
			w := httptest.NewRecorder()
			b.ServeHTTP(w, r)
			want := http.StatusForbidden
			if scenario == "oversized" || scenario == "unknown-field" || scenario == "trailing" {
				want = http.StatusBadRequest
			}
			if scenario == "preflight" {
				want = http.StatusNoContent
			}
			if w.Code != want {
				t.Fatalf("status %d, want %d", w.Code, want)
			}
		})
	}
}
