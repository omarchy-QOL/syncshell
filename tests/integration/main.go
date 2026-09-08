package main

import (
	"flag"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"
)

func main() {
	runtime := flag.String("runtime", "", "marked disposable runtime")
	folder := flag.String("folder", "port-verification", "test folder id")
	listen := flag.String("listen", "127.0.0.1:18421", "loopback review listener")
	script := flag.String("host-script", "../webui/review-host-actions.js", "browser review actions")
	flag.Parse()
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
