# Development

## Branches

Preact is the release frontend. `dev` integrates release work before promotion
of the verified candidate to `main`. The cleaned comparison snapshots are:

- `dev-preact-webUI-upgrade`: Preact release snapshot
- `dev-svelte-webUI-upgrade`: Svelte alternative
- `dev-native-webUI-upgrade`: updated AngularJS alternative

Each branch contains one frontend and prepares its own Modern and adaptive
Omarchy profiles. Alternative branches are comparison snapshots, not parallel
products. Tags, releases and marketplace publication remain separate actions.

The following branches are read-only historical source and evidence:

- `dev-syncshell-cross-distro` at `1062b17`
- `dev-syncshell-cross-distro-ui` at `5af5056`

Their QML-first core is not an implementation base for 0.1.8.

## Architecture

The target ownership and protocol are recorded in:

- [Syncshell glossary](CONTEXT.md)
- [ownership map](docs/ownership.md)
- [adapter protocol v1](docs/adapter-protocol-v1.md)
- [Omarchy service contract](docs/omarchy-service-contract.md)
- [Omarchy interaction contract](docs/omarchy-interaction-contract-0.1.7.md)

The production entry points delegate to the Omarchy host, which starts one
bundled native core. Do not introduce a mixed QML and Go domain runtime.

## Baseline checks

Run the baseline checks from the repository root:

```bash
git diff --check
jq empty manifest.json
(cd webui && sha256sum --quiet --check SHA256SUMS)
omarchy plugin validate .
(
  qml_imports=$(mktemp -d)
  trap 'find "$qml_imports" -depth -delete' EXIT
  mkdir "$qml_imports/qs"
  ln -s /usr/share/omarchy/shell/{Commons,Ui} "$qml_imports/qs/"
  /usr/lib/qt6/bin/qmllint -I "$qml_imports" Panel.qml Service.qml \
    shared/*.qml hosts/omarchy/*.qml hosts/omarchy/controllers/*.qml \
    hosts/omarchy/ui/*.qml hosts/standalone/*.qml tests/*.qml
)
for script in hosts/omarchy/scripts/*.sh packaging/bundled/*.sh \
  tests/*.sh tests/live/*.sh; do
  bash -n "$script" || exit 1
done
mise exec aqua:koalaman/shellcheck@0.11.0 -- \
  shellcheck -x -P SCRIPTDIR \
    hosts/omarchy/scripts/*.sh packaging/bundled/*.sh \
    tests/*.sh tests/live/copy-*.sh
qml6 --apptype core -f tests/run.qml
bash tests/scripts.test.sh
node --test tests/webui/*.test.*
bash tests/busy-button.test.sh
bash tests/rescan-core-loss.test.sh
bash tests/install-recovery.test.sh
bash tests/refresh-recovery.test.sh
bash tests/settings-migration.test.sh
bash tests/architecture.test.sh
bash tests/native-core-architecture.test.sh
bash tests/omarchy-service-contract.test.sh
```

## Isolated runtime tests

QML scenarios live beside their shell runners in `tests/`. The shared test
helper stages only each scenario's dependencies in a temporary shell root;
Omarchy scenarios also link the installed `Commons` and `Ui` there. Run the
shell wrappers so Quickshell resolves imports within that temporary root.

Never use the owner's normal Syncthing configuration, database, API key, or
synchronized data. Test instances use temporary configuration, database, GUI,
and folder paths with discovery, relays, NAT traversal, and upgrades disabled.

Interactive release evidence comes from the repo-owned `syncshell-vm-setup`
Omarchy profile on `optiplex-sff`. Verify the source commit and snapshot before
copying code, keep the guest inhibitor active, pull evidence, and fully stop the
guest afterward.

## Native core development

For byte-identical reproduction, use the compiler recorded by
`go version -m bin/x86_64/syncshell-core` (currently Go 1.27.0). The module's
minimum Go version is a source-compatibility floor, not the bundle's compiler.

Build and verify the exact production artifact before running the native
checks:

```bash
packaging/bundled/build.sh
git add bin/x86_64/syncshell-core
packaging/bundled/verify.sh
go -C core test ./...
go -C core test -race ./...
go -C core vet ./...
go -C core test -run='^$' -fuzz=FuzzEventJSON -fuzztime=1s \
  ./internal/syncthing
tests/core-process.test.sh
tests/standalone-service.test.sh
tests/native-core-architecture.test.sh
tests/native-core-live.test.sh
```

The live test creates one temporary Syncthing home and Unix GUI socket. It
disables discovery, relays, NAT traversal, telemetry, and upgrades, then removes
the complete temporary tree.

To inspect the shell-neutral harness manually, reproduce the bundled core and
provide an isolated Syncthing configuration:

```bash
packaging/bundled/build.sh
SYNCSHELL_PLUGIN_ROOT="$PWD" \
SYNCSHELL_CONFIG_PATH=/path/to/isolated/config.xml \
  bash tests/standalone.sh
```

Never point the harness at the owner's normal Syncthing configuration. The
standalone surface is a maintained contract test, not a supported 0.1.8 host.

The interactive VM parity gate runs `tests/native-core-parity-vm.test.sh`
against the explicitly supplied bundled core path. It creates two isolated
loopback-only Syncthing nodes and records only credential-free results under
the VM artifact directory.

`packaging/bundled/SHA256SUMS` is the sole tracked checksum list for the
bundled artifact.

## Plugin updates

The supported update sequence is a normal Omarchy plugin update followed by
a shell restart. Test the current panel and service together after that
restart, including settings, bar placement, and Syncthing data preservation.

The interval before restart has no cross-version usability guarantee. Do not
retain old helpers, aliases, fallback runtimes, or version bridges for it.
The service-contract fixture describes the current host interface; its
members may evolve together with the panel.

## Automated acceptance and runtime archives

The test workflow runs on main/dev pushes and pull requests. It checks the
core, the Go review tools, browser API contracts, generated frontend assets,
and browser workflows against a disposable Syncthing pair. Real launcher
acceptance creates an isolated account on the CI host and checks system,
manual, managed-user and custom-config scenarios through the core protocol.
See tests/integration/README.md for the same local commands. Graphical QML
acceptance is a separate host check; a protocol test is not a popup screenshot.

The workflow exports a runtime archive using packaging/bundled/archive.sh.
.gitattributes omits test/build source and demonstration media from that
archive while retaining the core executable, QML, icons and built Web UI.
Normal Omarchy installation still performs a Git clone and receives tracked
source and tests. export-ignore does not change clone or pull behavior, and
this project does not delete files from installed checkouts or silently
configure sparse checkout. The archive is a separate distribution artifact.
