package syncthing

import (
	"context"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestClientConfigurationAndFileRequests(t *testing.T) {
	ctx := context.Background()
	tests := []struct {
		name     string
		method   string
		target   string
		body     string
		response string
		call     func(context.Context, *Client) error
	}{
		{
			name: "folder", method: http.MethodGet,
			target: "/rest/config/folders/folder%2Fone", response: `{"id":"folder/one"}`,
			call: func(ctx context.Context, client *Client) error {
				folder, err := client.Folder(ctx, "folder/one")
				if err == nil && folder.ID != "folder/one" {
					t.Errorf("unexpected folder: %#v", folder)
				}
				return err
			},
		},
		{
			name: "patch folder", method: http.MethodPatch,
			target: "/rest/config/folders/folder%20one", body: `{"paused":true}`,
			call: func(ctx context.Context, client *Client) error {
				return client.PatchFolder(ctx, "folder one", map[string]bool{"paused": true})
			},
		},
		{
			name: "delete folder", method: http.MethodDelete,
			target: "/rest/config/folders/folder%20one",
			call: func(ctx context.Context, client *Client) error {
				return client.DeleteFolder(ctx, "folder one")
			},
		},
		{
			name: "default folder", method: http.MethodGet,
			target: "/rest/config/defaults/folder", response: `{"type":"sendreceive"}`,
			call: func(ctx context.Context, client *Client) error {
				config, err := client.DefaultFolder(ctx)
				if err == nil && config["type"] != "sendreceive" {
					t.Errorf("unexpected default folder: %#v", config)
				}
				return err
			},
		},
		{
			name: "add folder", method: http.MethodPost,
			target: "/rest/config/folders", body: `{"id":"new"}`,
			call: func(ctx context.Context, client *Client) error {
				return client.AddFolder(ctx, FolderConfig{"id": "new"})
			},
		},
		{
			name: "pending folders", method: http.MethodGet,
			target:   "/rest/cluster/pending/folders",
			response: `{"offered":{"offeredBy":{"device":{"label":"Offer"}}}}`,
			call: func(ctx context.Context, client *Client) error {
				folders, err := client.PendingFolders(ctx)
				if err == nil && folders["offered"].OfferedBy["device"].Label != "Offer" {
					t.Errorf("unexpected pending folders: %#v", folders)
				}
				return err
			},
		},
		{
			name: "gui config", method: http.MethodGet,
			target: "/rest/config/gui", response: `{"theme":"syncshell-modern"}`,
			call: func(ctx context.Context, client *Client) error {
				config, err := client.GUIConfig(ctx)
				if err == nil && config.Theme != "syncshell-modern" {
					t.Errorf("unexpected GUI config: %#v", config)
				}
				return err
			},
		},
		{
			name: "set gui theme", method: http.MethodPatch,
			target: "/rest/config/gui", body: `{"theme":"syncshell-modern"}`,
			call: func(ctx context.Context, client *Client) error {
				return client.SetGUITheme(ctx, "syncshell-modern")
			},
		},
		{
			name: "system paths", method: http.MethodGet,
			target: "/rest/system/paths", response: `{"guiAssets":"/tmp/gui"}`,
			call: func(ctx context.Context, client *Client) error {
				paths, err := client.SystemPaths(ctx)
				if err == nil && paths.GUIAssets != "/tmp/gui" {
					t.Errorf("unexpected system paths: %#v", paths)
				}
				return err
			},
		},
		{
			name: "folder errors", method: http.MethodGet,
			target:   "/rest/folder/errors?folder=folder+one&page=1&perpage=100",
			response: `{"errors":[{"path":"blocked","error":"denied"}]}`,
			call: func(ctx context.Context, client *Client) error {
				errors, err := client.FolderErrors(ctx, "folder one")
				if err == nil && (len(errors.Errors) != 1 || errors.Errors[0].Path != "blocked") {
					t.Errorf("unexpected folder errors: %#v", errors)
				}
				return err
			},
		},
		{
			name: "random string", method: http.MethodGet,
			target: "/rest/svc/random/string?length=12", response: `{"random":"strong-id"}`,
			call: func(ctx context.Context, client *Client) error {
				value, err := client.RandomString(ctx, 12)
				if err == nil && value != "strong-id" {
					t.Errorf("unexpected random string: %q", value)
				}
				return err
			},
		},
		{
			name: "file info", method: http.MethodGet,
			target:   "/rest/db/file?folder=folder+one&file=dir%2Ffile.txt",
			response: `{"local":{"name":"dir/file.txt"}}`,
			call: func(ctx context.Context, client *Client) error {
				info, err := client.FileInfo(ctx, "folder one", "dir/file.txt")
				if err == nil && (info.Local == nil || info.Local.Name != "dir/file.txt") {
					t.Errorf("unexpected file info: %#v", info)
				}
				return err
			},
		},
		{
			name: "rescan subdirectory", method: http.MethodPost,
			target: "/rest/db/scan?folder=folder+one&sub=dir%2Fchild",
			call: func(ctx context.Context, client *Client) error {
				return client.RescanSubdirectory(ctx, "folder one", "dir/child")
			},
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			server := httptest.NewServer(http.HandlerFunc(func(
				writer http.ResponseWriter,
				request *http.Request,
			) {
				if request.Method != test.method {
					t.Errorf("method = %s, want %s", request.Method, test.method)
				}
				if request.RequestURI != test.target {
					t.Errorf("target = %s, want %s", request.RequestURI, test.target)
				}
				if request.Header.Get("X-API-Key") != testAPIKey {
					t.Error("request omitted API key")
				}
				contents, err := io.ReadAll(request.Body)
				if err != nil {
					t.Errorf("read request: %v", err)
				}
				if string(contents) != test.body {
					t.Errorf("body = %q, want %q", contents, test.body)
				}
				if test.body != "" && request.Header.Get("Content-Type") != "application/json" {
					t.Error("JSON request omitted content type")
				}
				if test.response != "" {
					writeJSON(writer, test.response)
					return
				}
				writer.WriteHeader(http.StatusNoContent)
			}))
			defer server.Close()

			if err := test.call(ctx, testClient(t, server.URL, "", false)); err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestFolderErrorsAcceptsUnsupportedEndpoint(t *testing.T) {
	server := httptest.NewServer(http.NotFoundHandler())
	defer server.Close()

	errors, err := testClient(t, server.URL, "", false).
		FolderErrors(context.Background(), "folder")
	if err != nil || len(errors.Errors) != 0 {
		t.Fatalf("unexpected unsupported response: %#v %v", errors, err)
	}
}

func TestJSONRequestRejectsUnsupportedValues(t *testing.T) {
	client := &Client{}
	err := client.PatchFolder(context.Background(), "folder", make(chan int))
	assertErrorCode(t, err, ErrorSchema)
}
