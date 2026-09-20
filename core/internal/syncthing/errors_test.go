package syncthing

import (
	"errors"
	"testing"
)

func TestErrorFormattingAndUnwrap(t *testing.T) {
	cause := errors.New("network failed")
	tests := []struct {
		name string
		err  *Error
		want string
	}{
		{"message", &Error{Message: "request failed"}, "request failed"},
		{"operation", &Error{Op: "status"}, "status failed"},
		{"default", &Error{}, "Syncthing request failed"},
	}
	for _, test := range tests {
		if got := test.err.Error(); got != test.want {
			t.Errorf("%s error = %q, want %q", test.name, got, test.want)
		}
	}
	wrapped := &Error{Err: cause}
	if !errors.Is(wrapped, cause) {
		t.Fatal("Syncthing error did not expose its cause")
	}
}
