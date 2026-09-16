# Waybar adapter

Syncshell supports Waybar 0.15.0 with Quickshell 0.3.1 on Arch Linux and
Hyprland. The native custom module reads one JSON status stream and provides
popup, refresh, and Web UI click actions. A single Quickshell bridge owns the
bundled core across every Waybar output.

## Install, update, and remove

Install or update from the repository root:

```bash
./install.sh --shell waybar
```

Run a newer bundle's installer to update. Remove the adapter with
`~/.local/share/syncshell/waybar/remove.sh`. Managed JSONC and CSS fragments
are marked explicitly; unrelated Waybar configuration, Syncthing settings,
and synchronized data remain in place.

See [Arch shell adapters](../../docs/arch-adapters.md) for ownership,
placement, and exact support details.
