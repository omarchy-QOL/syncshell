# Caelestia adapter

Syncshell supports Caelestia Shell commit
`1d0e5a588c61f1d905eba5fe8446ec222d37f50c` on Arch Linux with its pinned
Quickshell and CLI revisions. The status entry and popout use one shell-owned
native core. The adapter extends Caelestia's compiled bar configuration so the
entry remains a normal configurable status item.

## Install and update

Install or update from the repository root:

```bash
./install.sh --shell caelestia
```

The installer clones the pinned Caelestia source, applies the adapter, and
rebuilds its compiled configuration. It requires Caelestia's upstream build
dependencies. Syncshell's core remains a prebuilt, checksummed artifact.

## Remove

Rebuild and install the unmodified pinned Caelestia checkout. Syncthing
configuration, service state, and folder contents are not changed.
