package main

import (
	"encoding/xml"
	"strings"
	"testing"
)

func TestFixtureConfigIsolatesGeneratedDefaults(t *testing.T) {
	data := []byte(`<configuration version="37"><folder id="default" path="/unwanted"/><device id="self"/><gui tls="false"><address>127.0.0.1:8384</address><apikey>fixture-key</apikey><theme>default</theme></gui><options><listenAddress>default</listenAddress><globalAnnounceEnabled>true</globalAnnounceEnabled><localAnnounceEnabled>true</localAnnounceEnabled><relaysEnabled>true</relaysEnabled><natEnabled>true</natEnabled><urAccepted>0</urAccepted><unrelated>retain</unrelated></options></configuration>`)
	result, err := fixtureConfig(data, "127.0.0.1:18401", "tcp://127.0.0.1:18411", "syncshell-modern")
	if err != nil {
		t.Fatal(err)
	}
	var config struct {
		Folders []struct{} `xml:"folder"`
		Device  struct {
			ID string `xml:"id,attr"`
		} `xml:"device"`
		GUI struct {
			Address string `xml:"address"`
			Key     string `xml:"apikey"`
			Theme   string `xml:"theme"`
		} `xml:"gui"`
		Options struct {
			Unrelated string `xml:"unrelated"`
		} `xml:"options"`
	}
	if err := xml.Unmarshal(result, &config); err != nil {
		t.Fatal(err)
	}
	if len(config.Folders) != 0 || config.Device.ID != "self" || config.GUI.Address != "127.0.0.1:18401" || config.GUI.Key != "fixture-key" || config.GUI.Theme != "syncshell-modern" || config.Options.Unrelated != "retain" {
		t.Fatal("fixture changed unrelated configuration or retained the generated folder")
	}
	if strings.Contains(string(result), ">true<") || !strings.Contains(string(result), "<urAccepted>-1</urAccepted>") {
		t.Fatal("fixture retained external discovery or reporting")
	}
}
