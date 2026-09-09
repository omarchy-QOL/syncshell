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

For a browser suite on a fresh pair, prepare the branch's Modern profile,
then start the fixture process. It exits and stops both daemons on SIGINT or
SIGTERM. The new runtime directory must not already exist.

```sh
bash ../../hosts/omarchy/scripts/syncthing-theme.sh prepare modern /tmp/gui
go run . -fixture-assets /tmp/gui/syncshell-modern -runtime /tmp/browser-test
```

The full frontend suite now lives in `syncshell-webui`. This checkout keeps
consumer checks for installing an imported release, Omarchy palette refresh,
and the production desktop bridge. Run `bash scripts/test-webui-integration.sh`
from the plugin root. `SYNCSHELL_CHROMIUM` selects an existing browser;
otherwise Playwright uses its installed browser.

The launcher acceptance command needs root and a running systemd/logind host:

```sh
go build -o /tmp/syncshell-test .
sudo /tmp/syncshell-test -launcher-core /absolute/syncshell-core \
  -fixture-port 18601 -runtime /var/tmp/launcher-test
```

It creates one new system account and tests real system/manual launchers,
the unrelated inactive user unit, rescan through the panel's core protocol,
automatic outage recovery, authorized user-service control and explicit
custom-config selection. The account and its systemd units are removed at
the end; result files remain in the selected test directory. No owner's
configuration is used. This covers the launcher behavior, not rendered QML
popup appearance; graphical acceptance remains a separate host check.

The graphical host check uses plugin-acceptance.mjs with an exported plugin
copy. It loads the real Omarchy service at the normal per-user plugin path,
delivers theme colors through the shell's applyTheme IPC contract, verifies
live browser refresh, and rescans after removing the frontend files. It uses
a disposable account and leaves the owner's desktop untouched.

A persistent developer review can pass -theme-helper with its branch's
syncthing-theme.sh. This keeps the isolated review palette aligned with the
owner's desktop theme; it is test infrastructure, not a production watcher.
