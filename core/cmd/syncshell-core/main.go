package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/protocol"
	"github.com/omarchy-QOL/syncshell/core/internal/session"
	"github.com/omarchy-QOL/syncshell/core/internal/systemduser"
)

var buildVersion = "0.1.8"

type options struct {
	session.Config
	DesktopAuthorized bool
}

func main() {
	if err := run(context.Background(), os.Args[1:], os.Stdin, os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "syncshell-core:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, args []string, stdin io.Reader, stdout io.Writer) error {
	if len(args) == 0 {
		return errors.New("expected probe, status, or stream")
	}
	command := args[0]
	if command != "probe" && command != "status" && command != "stream" {
		return errors.New("expected probe, status, or stream")
	}
	flags := flag.NewFlagSet(command, flag.ContinueOnError)
	flags.SetOutput(io.Discard)
	options, outputJSON, err := parseOptions(flags, args[1:])
	if err != nil {
		return err
	}
	if command != "stream" && !outputJSON {
		return errors.New("probe and status require --json")
	}

	coreSession, err := session.New(ctx, options.Config)
	if err != nil {
		return err
	}
	switch command {
	case "stream":
		if options.DesktopAuthorized {
			closeDesktop := coreSession.EnableDesktop()
			defer closeDesktop()
		}
		return protocol.Stream{Session: coreSession, Input: stdin, Output: stdout,
			Build: protocol.Build{Version: buildVersion}}.Run(ctx)
	case "probe", "status":
		published, refreshErr := coreSession.Refresh(ctx)
		encoder := json.NewEncoder(stdout)
		encoder.SetEscapeHTML(false)
		if command == "probe" {
			err = encoder.Encode(struct {
				Revision   uint64             `json:"revision"`
				Connection session.Connection `json:"connection"`
				Identity   session.Identity   `json:"identity"`
				Lifecycle  systemduser.State  `json:"lifecycle"`
			}{published.Revision, published.State.Connection,
				published.State.Identity, published.State.Lifecycle})
		} else {
			err = encoder.Encode(published)
		}
		if err != nil {
			return err
		}
		return refreshErr
	}
	return nil
}

func parseOptions(flags *flag.FlagSet, args []string) (options, bool, error) {
	var config options
	var outputJSON bool
	var lifecycleKind string
	var probeSeconds int
	flags.StringVar(&config.Discovery.ConfigPath, "config", "", "Syncthing config.xml path")
	flags.StringVar(&config.Discovery.Endpoint, "endpoint", "", "explicit Syncthing endpoint")
	flags.StringVar(&config.Discovery.CredentialFile, "credential-file", "", "private API credential file")
	flags.StringVar(&config.Discovery.TLSCertificate, "tls-certificate", "", "pinned TLS certificate")
	flags.StringVar(&config.Discovery.ExpectedDeviceID, "expected-device-id", "", "expected Syncthing device ID")
	flags.BoolVar(&config.Discovery.InsecureTLS, "insecure-tls", false, "allow unverified TLS for this target")
	flags.BoolVar(&config.DesktopAuthorized, "desktop-authorized", false,
		"authorize the desktop bridge")
	flags.StringVar(&lifecycleKind, "lifecycle-kind", "", "authorized lifecycle kind")
	flags.BoolVar(&config.Lifecycle.Authorized, "lifecycle-authorized", false, "authorize the exact lifecycle binding")
	flags.StringVar(&config.Lifecycle.Unit, "lifecycle-unit", "", "exact systemd user unit")
	flags.StringVar(&config.Lifecycle.ConfigPath, "lifecycle-config", "", "config path bound to the unit")
	flags.IntVar(&probeSeconds, "probe-interval-seconds", 15, "lifecycle probe interval")
	flags.StringVar(&config.DesiredServiceState, "desired-service-state", "enabled", "persistent lifecycle intent")
	flags.BoolVar(&outputJSON, "json", false, "write JSON output")
	if err := flags.Parse(args); err != nil {
		return options{}, false, errors.New("invalid command arguments")
	}
	if flags.NArg() != 0 {
		return options{}, false, errors.New("unexpected command arguments")
	}
	if lifecycleKind != "" && lifecycleKind != "systemd-user" {
		return options{}, false, errors.New("unsupported lifecycle kind")
	}
	if config.Lifecycle.Authorized && (lifecycleKind != "systemd-user" || config.Lifecycle.Unit == "") {
		return options{}, false, errors.New("authorized lifecycle binding is incomplete")
	}
	if !config.Lifecycle.Authorized &&
		(lifecycleKind != "" || config.Lifecycle.Unit != "" || config.Lifecycle.ConfigPath != "") {
		return options{}, false, errors.New("lifecycle binding requires explicit authority")
	}
	if probeSeconds < 1 || probeSeconds > 3600 {
		return options{}, false, errors.New("probe interval must be between 1 and 3600 seconds")
	}
	if config.DesiredServiceState != "enabled" && config.DesiredServiceState != "disabled" {
		return options{}, false, errors.New("desired service state must be enabled or disabled")
	}
	if strings.ContainsAny(config.Lifecycle.Unit, "\r\n\x00") {
		return options{}, false, errors.New("lifecycle unit is invalid")
	}
	config.ProbeInterval = time.Duration(probeSeconds) * time.Second
	return config, outputJSON, nil
}
