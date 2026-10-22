package session

import (
	"context"
	"sync"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

// Optional peer metadata must not hold up the local folder snapshot indefinitely.
func (s *Session) loadRemoteSharing(ctx context.Context, folders []Folder,
	devices []syncthing.Device, connections syncthing.Connections, localID string,
) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	connected := make(map[string]bool, len(devices))
	for _, device := range devices {
		connected[device.DeviceID] = !device.Paused && connections.Connections[device.DeviceID].Connected
	}
	type pair struct {
		folderID string
		member   *FolderDevice
	}
	jobs := make(chan pair)
	var workers sync.WaitGroup
	for i := 0; i < 4; i++ {
		workers.Add(1)
		go func() {
			defer workers.Done()
			for job := range jobs {
				completion, err := s.client.FolderCompletion(ctx, job.folderID, job.member.ID)
				if err != nil {
					continue
				}
				switch completion.RemoteState {
				case "valid", "paused", "notSharing":
					job.member.RemoteState = completion.RemoteState
				}
			}
		}()
	}
enqueue:
	for _, folder := range folders {
		if folder.Paused {
			continue
		}
		for i := range folder.Devices {
			member := &folder.Devices[i]
			if member.ID == localID || !connected[member.ID] {
				continue
			}
			select {
			case jobs <- pair{folder.ID, member}:
			case <-ctx.Done():
				break enqueue
			}
		}
	}
	close(jobs)
	workers.Wait()
}
