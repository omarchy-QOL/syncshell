package session

import (
	"context"
	"strings"
	"testing"

	"github.com/omarchy-QOL/syncshell/core/internal/syncthing"
)

func TestAddDeviceRejectsInvalidSelfAndDuplicateWithoutWriting(t *testing.T) {
	localID := strings.TrimSuffix(strings.Repeat("AAAAAAA-", 8), "-")
	remoteID := strings.TrimSuffix(strings.Repeat("BBBBBBB-", 8), "-")
	for _, tc := range []struct{ name, id, code string }{
		{"invalid", "not-a-device-id", "device_id_invalid"},
		{"self", localID, "device_self"},
		{"duplicate", remoteID, "device_exists"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			api := &actionAPI{devices: []syncthing.Device{{DeviceID: remoteID}}}
			session := newActionSession(t, api)
			if _, err := session.Refresh(context.Background()); err != nil {
				t.Fatal(err)
			}
			snapshot := session.Current().State
			snapshot.Identity.DeviceID = localID
			session.publish(snapshot)
			result := session.Act(context.Background(), "device.add", ActionArguments{DeviceID: tc.id, DeviceName: "kept name"})
			if result.OK || result.Error == nil || result.Error.Code != tc.code || result.Error.Message == "" {
				t.Fatalf("unexpected rejection: %#v", result)
			}
			api.mu.Lock()
			defer api.mu.Unlock()
			if api.lastDeviceAdd != nil {
				t.Fatalf("rejected device was written: %#v", api.lastDeviceAdd)
			}
		})
	}
}
