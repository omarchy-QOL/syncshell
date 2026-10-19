//go:build !linux

package nativebridge

import (
	"context"
	"errors"

	"github.com/omarchy-QOL/syncshell/core/internal/protocol"
)

func Run(context.Context, string, protocol.Stream) error {
	return errors.New("native plugin transport requires Linux")
}

func Control([]string) error {
	return errors.New("native plugin transport requires Linux")
}

func SaveCleanup(string, []string) error {
	return errors.New("native plugin cleanup requires Linux")
}
