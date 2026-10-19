# Use a parent-bound Go core over JSONL

Each QML adapter owns one Go child process and communicates through bounded
JSONL over standard input and output. The native Waybar executable embeds the
same session library and emits Waybar JSONL directly; each configured bar
instance owns its monitoring process. A stateless command cannot own
the Event API cursor and recovery state. A daemon and control socket would add
client brokerage that no supported adapter needs.

The core may become a daemon only when a supported target needs simultaneous
independent rich clients, shared state or notifications across host processes,
a core that survives its host, or a host that cannot supervise a child.
