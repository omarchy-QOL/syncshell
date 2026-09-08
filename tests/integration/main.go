package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"
)

func main() {
	runtime := flag.String("runtime", "", "marked disposable runtime")
	folder := flag.String("folder", "port-verification", "test folder id")
	listen := flag.String("listen", "127.0.0.1:18421", "loopback review listener")
	script := flag.String("host-script", "../webui/review-host-actions.js", "browser review actions")
	assets := flag.String("fixture-assets", "", "start disposable Syncthing peers serving these assets")
	port := flag.Int("fixture-port", 18401, "primary fixture GUI port")
	launcher := flag.String("launcher-core", "", "test launcher acceptance with this core binary")
	flag.Parse()
	if *launcher != "" {
		ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
		defer stop()
		if err := runLauncher(ctx, *runtime, *launcher, *port); err != nil {
			log.Fatal(err)
		}
		return
	}
	if *assets != "" {
		ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
		defer stop()
		if err := runFixture(ctx, *runtime, *assets, *port); err != nil {
			log.Fatal(err)
		}
		return
	}
	s, err := newReview(*runtime, *folder, *listen)
	if err != nil {
		log.Fatal(err)
	}
	data, err := os.ReadFile(*script)
	if err != nil {
		log.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Join(*runtime, "evidence"), 0700); err != nil {
		log.Fatal(err)
	}
	server := &http.Server{Addr: *listen, Handler: s.handler(data), ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(server.ListenAndServe())
}
