package nativebridge

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"io"
	"strings"
	"testing"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/protocol"
)

func TestChunkRoundTripAtFrameLimit(t *testing.T) {
	for _, text := range []string{strings.Repeat("a", protocol.MaxLineBytes-3),
		strings.Repeat("界\\\"", 700000)} {
		data, err := json.Marshal(text)
		if err != nil {
			t.Fatal(err)
		}
		data = append(data, '\n')
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		reader, output := io.Pipe()
		writer := &chunkWriter{ctx: ctx, output: output, acks: make(chan string, 1)}
		done := make(chan error, 1)
		go func() { _, err := writer.Write(data); done <- err; output.Close() }()
		scanner := bufio.NewScanner(reader)
		var joined bytes.Buffer
		index := 0
		for scanner.Scan() {
			if len(scanner.Bytes()) >= 64<<10 {
				t.Fatal("exceeded host line bound")
			}
			var part chunk
			if err := json.Unmarshal(scanner.Bytes(), &part); err != nil {
				t.Fatal(err)
			}
			index++
			if part.Index != index || part.Transport != 1 || part.Frame != 1 {
				t.Fatalf("invalid chunk sequence: %#v", part)
			}
			joined.WriteString(part.Data)
			if part.Ack != "" {
				writer.acks <- part.Ack
			}
		}
		if err := scanner.Err(); err != nil {
			t.Fatal(err)
		}
		if err := <-done; err != nil {
			t.Fatal(err)
		}
		if !bytes.Equal(data, joined.Bytes()) {
			t.Fatal("fragmented UTF-8 frame changed")
		}
	}
}

func TestWriterWaitsForConsumerAndRejectsWrongAck(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	reader, output := io.Pipe()
	defer reader.Close()
	writer := &chunkWriter{ctx: ctx, output: output, acks: make(chan string, 1)}
	done := make(chan error, 1)
	go func() { _, err := writer.Write([]byte("{}\n")); done <- err; output.Close() }()
	if _, err := bufio.NewReader(reader).ReadString('\n'); err != nil {
		t.Fatal(err)
	}
	select {
	case <-done:
		t.Fatal("writer did not wait for acknowledgement")
	default:
	}
	writer.acks <- "1:2"
	if err := <-done; err == nil {
		t.Fatal("accepted mismatched acknowledgement")
	}
}
