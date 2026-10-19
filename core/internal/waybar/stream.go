package waybar

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/session"
	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

// Run owns one session; presentation timers never perform network requests.
func Run(ctx context.Context, configPath string, output io.Writer) error {
	ctx, cancel := context.WithCancel(ctx)
	updates := make(chan session.Snapshot, 1)
	go observe(ctx, configPath, updates)
	defer func() {
		cancel()
		// Wait for the session's event cursor to stop.
		for range updates {
		}
	}()
	ticker := time.NewTicker(dotInterval)
	defer ticker.Stop()
	return stream(ctx, updates, ticker.C, output)
}

func stream(ctx context.Context, updates <-chan session.Snapshot, ticks <-chan time.Time, output io.Writer) error {
	var presenter Presenter
	state := session.Snapshot{Connection: session.Connection{Phase: "discovering"}}
	encoder := json.NewEncoder(output)
	previous := ""
	write := func(now time.Time) error {
		value := presenter.Render(state, now)
		// Text contains the full tooltip; class membership can also change alone.
		encoded, err := json.Marshal(value)
		if err != nil {
			return err
		}
		if string(encoded) == previous {
			return nil
		}
		if err := encoder.Encode(value); err != nil {
			return err
		}
		previous = string(encoded)
		return nil
	}
	if err := write(time.Now()); err != nil {
		return err
	}
	for {
		select {
		case <-ctx.Done():
			return nil
		case next, ok := <-updates:
			if !ok {
				return nil
			}
			state = next
			if err := write(time.Now()); err != nil {
				return err
			}
		case <-ticks:
			if err := write(time.Now()); err != nil {
				return err
			}
		}
	}
}

func observe(ctx context.Context, path string, output chan<- session.Snapshot) {
	defer close(output)
	emit := func(s session.Snapshot) {
		select {
		case output <- s:
		case <-ctx.Done():
		}
	}
	delay := time.Second
	for ctx.Err() == nil {
		config, err := loadConfig(path)
		code := "waybar-config"
		var core *session.Session
		if err == nil {
			code = "config"
			core, err = session.New(ctx, config)
		}
		if err != nil {
			var failure *syncthing.Error
			if errors.As(err, &failure) {
				code = string(failure.Code)
			}
			emit(session.Snapshot{Connection: session.Connection{Phase: "error", Error: &session.Error{Code: code}}})
			timer := time.NewTimer(delay)
			select {
			case <-ctx.Done():
				timer.Stop()
				return
			case <-timer.C:
			}
			delay = min(delay*2, 8*time.Second)
			continue
		}
		emit(session.Snapshot{Connection: session.Connection{Phase: "loading"}})
		for next := range core.Updates(ctx) {
			emit(next.State)
		}
		return
	}
}
