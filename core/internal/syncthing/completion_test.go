package syncthing

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestFolderCompletionUsesExactPair(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/rest/db/completion" ||
			r.URL.Query().Get("folder") != "folder &+?" || r.URL.Query().Get("device") != "REMOTE" ||
			r.Header.Get("X-API-Key") != testAPIKey {
			t.Error("completion query did not preserve the authenticated folder-device pair")
		}
		writeJSON(w, `{"remoteState":"notSharing","completion":0}`)
	}))
	defer server.Close()
	result, err := testClient(t, server.URL, "", false).FolderCompletion(context.Background(), "folder &+?", "REMOTE")
	if err != nil || result.RemoteState != "notSharing" {
		t.Fatalf("completion = %#v, %v", result, err)
	}
}
