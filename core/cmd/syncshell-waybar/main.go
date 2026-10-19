package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/waybar"
	"golang.org/x/sys/unix"
)

var buildVersion = "dev"

func main() {
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer cancel()
	signal.Ignore(syscall.SIGPIPE)
	go watchOwner(ctx, cancel, os.Getppid(), int(os.Stdout.Fd()))
	if err := run(ctx, os.Args[1:], os.Stdout); err != nil && !errors.Is(err, syscall.EPIPE) {
		fmt.Fprintln(os.Stderr, "syncshell-waybar:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, args []string, output io.Writer) error {
	if len(args) == 1 && args[0] == "--version" {
		_, err := fmt.Fprintln(output, buildVersion)
		return err
	}
	if len(args) == 0 || (len(args) == 1 && (args[0] == "--help" || args[0] == "-h")) {
		_, err := fmt.Fprintln(output, "usage: syncshell-waybar status [--config /absolute/path/waybar.json]")
		return err
	}
	if args[0] != "status" {
		return errors.New("expected status, --version or --help")
	}
	flags := flag.NewFlagSet("status", flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	path := flags.String("config", "", "nonsecret Waybar target configuration")
	if err := flags.Parse(args[1:]); err != nil || flags.NArg() != 0 {
		return errors.New("invalid status arguments; see --help")
	}
	return waybar.Run(ctx, *path, output)
}

// Idle output is coalesced, so notice a closed pipe without another write.
func watchOwner(ctx context.Context, cancel context.CancelFunc, parent, fd int) {
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			fds := []unix.PollFd{{Fd: int32(fd)}}
			_, _ = unix.Poll(fds, 0)
			if os.Getppid() != parent || fds[0].Revents&(unix.POLLERR|unix.POLLHUP|unix.POLLNVAL) != 0 {
				cancel()
				return
			}
		}
	}
}
