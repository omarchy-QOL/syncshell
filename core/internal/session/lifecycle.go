package session

import (
	"context"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/systemduser"
)

func (s *Session) lifecycleAction(ctx context.Context, name string) ActionResult {
	published, _ := s.Refresh(ctx)
	state := published.State.Lifecycle
	if !state.Authorized || !state.TargetMatch {
		return rejected("lifecycle_forbidden", "lifecycle binding does not apply to this target")
	}
	if name == "start" && !state.CanStart && !state.CanControl {
		return rejected("lifecycle_forbidden", "user service cannot be started for this target")
	}
	if name != "start" && !state.CanControl {
		return rejected("lifecycle_forbidden", "user service cannot be controlled for this target")
	}
	return s.waitForLifecycle(ctx, name)
}

func (s *Session) waitForLifecycle(ctx context.Context, name string) ActionResult {
	deadline := time.Now().Add(10 * time.Second)
	for {
		published, _ := s.Refresh(ctx)
		if lifecycleReached(name, published) {
			return ActionResult{OK: true, Revision: published.Revision}
		}
		if time.Now().After(deadline) {
			return rejected("lifecycle_timeout", "user service did not reach the requested state")
		}
		_ = s.lifecycle.Apply(ctx, s.binding.Unit, systemduser.Action(name))
		if !waitContext(ctx, 200*time.Millisecond) {
			return rejected("canceled", "lifecycle action was canceled")
		}
	}
}

func lifecycleReached(name string, published PublishedSnapshot) bool {
	state := published.State.Lifecycle
	switch name {
	case "start":
		return state.ActiveState == "active"
	case "stop":
		return !state.Active
	case "enable":
		return state.UnitFileState == "enabled"
	case "disable":
		return state.UnitFileState == "disabled"
	default:
		return false
	}
}
