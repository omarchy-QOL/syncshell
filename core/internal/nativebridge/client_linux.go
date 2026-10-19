package nativebridge

import (
	"bufio"
	"encoding/json"
	"errors"
	"net"
	"os"
	"path/filepath"
	"syscall"
	"time"
)

// Control forwards only an operation and generation path, never action data.
func Control(args []string) error {
	if len(args) < 2 || len(args) > 3 {
		return errors.New("expected native-control directory ping|stop|request|ack [token]")
	}
	directory, op := args[0], args[1]
	if !generationName.MatchString(filepath.Base(directory)) {
		return errors.New("invalid native generation")
	}
	if err := privateDirectory(filepath.Dir(directory)); err != nil {
		return err
	}
	if err := privateDirectory(directory); err != nil {
		return err
	}
	socket := filepath.Join(directory, "inlet.sock")
	info, err := os.Lstat(socket)
	if err != nil || info.Mode()&os.ModeSocket == 0 || info.Mode().Perm() != 0o600 ||
		info.Sys().(*syscall.Stat_t).Uid != uint32(os.Geteuid()) {
		return errors.New("native socket ownership is invalid")
	}
	m := message{Op: op}
	if op == "ack" && len(args) == 3 {
		m.Ack = args[2]
	} else if len(args) != 2 || (op != "ping" && op != "stop" && op != "request") {
		return errors.New("invalid native operation")
	}
	conn, err := net.DialTimeout("unix", socket, 2*time.Second)
	if err != nil {
		return errors.New("native worker is unavailable")
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(5 * time.Second))
	if json.NewEncoder(conn).Encode(m) != nil {
		return errors.New("native delivery is uncertain; do not replay")
	}
	answer, err := bufio.NewReader(conn).ReadString('\n')
	if err != nil || answer != "ok\n" {
		return errors.New("native delivery is uncertain; do not replay")
	}
	return nil
}
