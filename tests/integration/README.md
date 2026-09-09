# Disposable integration tools

These Go tools exercise the plugin against isolated Syncthing instances on
Linux. They use only the Go standard library. No review server, injected
browser API, or alternate desktop bridge is involved.

From the plugin root:

```sh
go -C core test -race ./...
go -C tests/integration test -race ./...
npm ci --prefix tests/webui
bash scripts/test-webui-integration.sh
```

The consumer check installs the imported bundle, verifies Modern and Omarchy
profiles, and exercises the production desktop bridge in a private D-Bus
session. It creates one disposable Syncthing instance and stops it on exit.
The Web repository owns the full frontend suite and paired synchronization
fixtures. `SYNCSHELL_CHROMIUM` selects an existing browser; otherwise
Playwright uses its installed browser.

A fixture can also be started explicitly from this directory:

```sh
bash ../../hosts/omarchy/scripts/syncthing-theme.sh prepare modern /tmp/gui
go run . -fixture-assets /tmp/gui/syncshell-modern -runtime /tmp/browser-test
```

The new runtime directory must not exist. The fixture disables discovery,
relays and upgrades and stops on SIGINT or SIGTERM. Never point test tools
at the owner's running configuration or synchronized files.

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
