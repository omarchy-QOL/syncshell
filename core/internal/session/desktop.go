package session

import (
	"context"

	"github.com/omarchy-QOL/syncshell/core/internal/desktop"
)

// EnableDesktop is explicit host authority and never required for monitoring.
func (s *Session) EnableDesktop() func() {
	s.desktopEnabled = true
	return func() {
		if s.desktop != nil {
			s.desktop.Close()
		}
	}
}

func (s *Session) openWebUI(ctx context.Context) ActionResult {
	if !s.desktopEnabled {
		return rejected("desktop_unavailable", "Desktop integration is unavailable; open the Syncthing address in your browser")
	}
	if s.desktop == nil {
		var err error
		s.desktop, err = desktop.New(s.client)
		if err != nil {
			return rejected("desktop_unavailable", err.Error())
		}
	}
	if err := s.desktop.Open(ctx); err != nil {
		return rejected("desktop_open", err.Error())
	}
	return ActionResult{OK: true}
}
