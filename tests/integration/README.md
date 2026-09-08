# Disposable integration tools

These Go tools are development infrastructure, never a production service.
Run on Linux. The review server uses Syncthing's index for discovery and
rechecks; local filesystem operations are limited to explicit open/rename
actions. The x/sys dependency supplies atomic no-replace rename semantics.

```sh
go test -race ./...
go run . -runtime /absolute/marked/runtime -listen 127.0.0.1:18421 \
  -host-script ../webui/review-host-actions.js
```

The runtime must contain `.syncshell-port-fixture`, `home/config.xml` and
`files/`. The configuration must identify that files directory as the selected
test folder and use a loopback GUI address. Its credentials stay on the host.
The default folder ID is `port-verification`; use `-folder` to select another
marked fixture. Do not point the tool at a user's active synchronization root.

The browser test capability is injected into the served page. Syncthing serves
the actual frontend and REST operations. The review server requires its exact
Host and Origin and a fresh per-process token for filesystem actions.
Renaming refuses stale index metadata, symlinks and existing destinations.
File-manager actions use the session's FileManager1 interface.

The real browser action check is `../webui/live-conflict-actions.mjs`. It
creates tiny disposable conflicts, verifies reveal/rename/refusal behavior,
and removes its files afterward. Unit tests can run without a desktop or
Syncthing process.
