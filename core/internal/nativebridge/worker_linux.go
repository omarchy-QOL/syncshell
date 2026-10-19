package nativebridge

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/omarchy-QOL/syncshell/core/internal/protocol"
	"golang.org/x/sys/unix"
)

type message struct {
	Op  string `json:"op"`
	Ack string `json:"ack,omitempty"`
}

// Run keeps the existing ordered dispatcher and owns only its transport.
func Run(ctx context.Context, base string, stream protocol.Stream) error {
	if err := os.Mkdir(base, 0o700); err != nil && !os.IsExist(err) {
		return errors.New("cannot create native runtime directory")
	}
	if err := privateDirectory(base); err != nil {
		return err
	}
	lock, err := openPrivateFile(filepath.Join(base, "worker.lock"), unix.O_RDWR|unix.O_CREAT)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err := unix.Flock(int(lock.Fd()), unix.LOCK_EX|unix.LOCK_NB); err != nil {
		return errors.New("native worker is already running")
	}
	if err := cleanGenerations(base); err != nil {
		return err
	}
	directory, err := os.MkdirTemp(base, "generation-")
	if err != nil {
		return err
	}
	defer cleanGenerations(base)
	if err := createSlot(directory); err != nil {
		return err
	}
	listener, err := net.ListenUnix("unix", &net.UnixAddr{Name: filepath.Join(directory, "inlet.sock"), Net: "unix"})
	if err != nil {
		return errors.New("cannot create native request socket")
	}
	defer listener.Close()
	if err := os.Chmod(filepath.Join(directory, "inlet.sock"), 0o600); err != nil {
		return err
	}
	ctx, stop := signal.NotifyContext(ctx, syscall.SIGTERM, syscall.SIGINT, syscall.SIGHUP)
	defer stop()
	return serve(ctx, stop, directory, listener, stream)
}

func createSlot(directory string) error {
	f, err := openPrivateFile(filepath.Join(directory, "request-slot.json"), unix.O_WRONLY|unix.O_CREAT|unix.O_EXCL)
	if err == nil {
		err = f.Close()
	}
	return err
}

func serve(ctx context.Context, stop context.CancelFunc, directory string, listener *net.UnixListener, stream protocol.Stream) error {
	reader, writer := io.Pipe()
	defer reader.Close()
	defer writer.Close()
	acks := make(chan string, 1)
	var touched atomic.Int64
	touched.Store(time.Now().UnixNano())
	var workers sync.WaitGroup
	workers.Add(2)
	go func() {
		defer workers.Done()
		watchOwner(ctx, stop, &touched)
		listener.Close()
		reader.Close()
		writer.Close()
	}()
	go func() {
		defer workers.Done()
		acceptRequests(ctx, stop, directory, listener, writer, acks, &touched)
	}()
	defer func() { stop(); workers.Wait() }()
	if err := json.NewEncoder(stream.Output).Encode(map[string]any{
		"transport": 1, "type": "ready", "directory": directory,
	}); err != nil {
		return err
	}
	stream.Input = reader
	stream.Output = &chunkWriter{ctx: ctx, output: stream.Output, acks: acks}
	return stream.Run(ctx)
}

func watchOwner(ctx context.Context, stop context.CancelFunc, touched *atomic.Int64) {
	parent := os.Getppid()
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if os.Getppid() != parent || parent == 1 || time.Since(time.Unix(0, touched.Load())) > 20*time.Second {
				stop()
				return
			}
		}
	}
}

func acceptRequests(ctx context.Context, stop context.CancelFunc, directory string, listener *net.UnixListener,
	writer io.Writer, acks chan<- string, touched *atomic.Int64) {
	var workers sync.WaitGroup
	defer workers.Wait()
	slots := make(chan struct{}, 4)
	var requestMu sync.Mutex
	for {
		conn, err := listener.AcceptUnix()
		if err != nil {
			return
		}
		select {
		case slots <- struct{}{}:
		default:
			conn.Close()
			continue
		}
		workers.Add(1)
		go func() {
			defer workers.Done()
			defer func() { <-slots }()
			defer conn.Close()
			conn.SetDeadline(time.Now().Add(5 * time.Second))
			decoder := json.NewDecoder(io.LimitReader(conn, protocol.MaxLineBytes+1024))
			decoder.DisallowUnknownFields()
			var m message
			if decoder.Decode(&m) != nil {
				return
			}
			switch m.Op {
			case "ping":
				touched.Store(time.Now().UnixNano())
			case "stop":
				stop()
			case "ack":
				select {
				case acks <- m.Ack:
				case <-ctx.Done():
					return
				}
			case "request":
				requestMu.Lock()
				defer requestMu.Unlock()
				data, err := consumeRequest(directory, "request-slot.json")
				if err != nil || !json.Valid(data) || bytes.ContainsAny(data, "\r\n") {
					return
				}
				if createSlot(directory) != nil {
					return
				}
				if _, err := writer.Write(append(data, '\n')); err != nil {
					return
				}
			default:
				return
			}
			io.WriteString(conn, "ok\n")
		}()
	}
}
