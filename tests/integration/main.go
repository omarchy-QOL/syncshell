package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	runtime := flag.String("runtime", "", "new disposable runtime directory")
	assets := flag.String("fixture-assets", "", "start disposable Syncthing with these GUI assets")
	port := flag.Int("fixture-port", 18401, "fixture GUI port")
	launcher := flag.String("launcher-core", "", "test launcher acceptance with this core binary")
	plugin := flag.String("plugin-source", "", "test an exported plugin with real Omarchy QML")
	qmlFile := flag.String("plugin-qml", "../plugin-acceptance.qml", "QML acceptance fixture")
	omarchy := flag.String("omarchy-path", "/usr/share/omarchy", "installed Omarchy sources")
	flag.Parse()
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	var err error
	switch {
	case *plugin != "":
		err = runPlugin(ctx, *runtime, *plugin, *qmlFile, *omarchy, *port)
	case *launcher != "":
		err = runLauncher(ctx, *runtime, *launcher, *port)
	case *assets != "":
		err = runFixture(ctx, *runtime, *assets, *port)
	default:
		log.Fatal("select fixture-assets, launcher-core or plugin-source")
	}
	if err != nil {
		log.Fatal(err)
	}
}
