// Package nativebridge adapts one core session to a stdout-only native host.
package nativebridge

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"strconv"
	"time"
	"unicode/utf8"

	"github.com/omarchy-QOL/syncshell/core/internal/protocol"
)

const chunkBytes = 4 << 10
const chunkWindow = 8

type chunk struct {
	Transport int    `json:"transport"`
	Frame     uint64 `json:"frame"`
	Index     int    `json:"index"`
	Count     int    `json:"count"`
	Data      string `json:"data"`
	Ack       string `json:"ack,omitempty"`
}

type chunkWriter struct {
	ctx    context.Context
	output io.Writer
	acks   chan string
	frame  uint64
}

func (w *chunkWriter) Write(data []byte) (int, error) {
	if len(data) > protocol.MaxLineBytes || !utf8.Valid(data) ||
		!bytes.HasSuffix(data, []byte{'\n'}) || !json.Valid(bytes.TrimSpace(data)) {
		return 0, errors.New("invalid native output frame")
	}
	parts := splitFrame(data)
	w.frame++
	encoder := json.NewEncoder(w.output)
	encoder.SetEscapeHTML(false)
	for index, part := range parts {
		c := chunk{Transport: 1, Frame: w.frame, Index: index + 1,
			Count: len(parts), Data: part}
		if (index+1)%chunkWindow == 0 || index == len(parts)-1 {
			c.Ack = strconv.FormatUint(w.frame, 10) + ":" + strconv.Itoa(index+1)
		}
		if err := encoder.Encode(c); err != nil {
			return 0, err
		}
		if c.Ack != "" {
			if err := w.waitAck(c.Ack); err != nil {
				return 0, err
			}
		}
	}
	return len(data), nil
}

func splitFrame(data []byte) []string {
	parts := make([]string, 0, len(data)/chunkBytes+1)
	for len(data) > 0 {
		end := min(len(data), chunkBytes)
		for end < len(data) && !utf8.RuneStart(data[end]) {
			end--
		}
		parts = append(parts, string(data[:end]))
		data = data[end:]
	}
	return parts
}

func (w *chunkWriter) waitAck(expected string) error {
	timer := time.NewTimer(15 * time.Second)
	defer timer.Stop()
	select {
	case got := <-w.acks:
		if got != expected {
			return errors.New("native output acknowledgement is out of order")
		}
		return nil
	case <-w.ctx.Done():
		return w.ctx.Err()
	case <-timer.C:
		return errors.New("native output acknowledgement timed out")
	}
}
