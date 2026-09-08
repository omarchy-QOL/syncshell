package main

import (
	"context"
	"testing"
	"time"
)

func TestCoreWaitRetainsSnapshotBeforeActionResult(t *testing.T) {
	s := &coreStream{frames: make(chan coreFrame, 2)}
	ready := coreFrame{Type: "snapshot"}
	ready.State.Connection.Online = true
	ready.State.Lifecycle.Classification = "managed"
	ready.State.Folders = append(ready.State.Folders, struct{ ID string }{"folder"})
	s.frames <- ready
	s.frames <- coreFrame{Type: "result", ID: "start", OK: true}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if _, err := s.await(ctx, func(f coreFrame) bool { return f.Type == "result" }); err != nil {
		t.Fatal(err)
	}
	// An unchanged idle snapshot need not be emitted again after the result.
	if err := s.online(ctx, "managed"); err != nil {
		t.Fatal(err)
	}
}
