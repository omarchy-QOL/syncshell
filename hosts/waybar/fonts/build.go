// Build the fixed three-glyph font without a runtime font-tool dependency.
package main

import (
	"bytes"
	_ "embed"
	"encoding/binary"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"slices"
	"unicode/utf16"
)

//go:embed glyphs.json
var source []byte

const family = "Syncshell Icons"
const filename = "SyncshellIcons.ttf"
const em = 1024
const ascent = 896
const descent = -128

type glyph struct {
	Codepoint int       `json:"codepoint"`
	Name      string    `json:"name"`
	Contours  [][]point `json:"contours"`
}

// Each point stores x, y and the TrueType on-curve flag.
type point [3]int
type data struct{ bytes.Buffer }

func (d *data) words(values ...int) {
	for _, value := range values {
		d.Write(binary.BigEndian.AppendUint16(nil, uint16(value)))
	}
}

func (d *data) longs(values ...uint32) {
	for _, value := range values {
		d.Write(binary.BigEndian.AppendUint32(nil, value))
	}
}

func bounds(g glyph) [4]int {
	b := [4]int{em, ascent, 0, descent}
	for _, contour := range g.Contours {
		for _, p := range contour {
			b = [4]int{min(b[0], p[0]), min(b[1], p[1]), max(b[2], p[0]), max(b[3], p[1])}
		}
	}
	return b
}

func buildFont() ([]byte, error) {
	var glyphs []glyph
	if err := json.Unmarshal(source, &glyphs); err != nil {
		return nil, err
	}
	if len(glyphs) != 3 {
		return nil, fmt.Errorf("expected the three agreed status glyphs")
	}
	var outlines, locations, metrics data
	locations.longs(0) // .notdef is intentionally empty
	metrics.words(em, 0)
	maxPoints, maxContours := 0, 0
	box := [4]int{0, 0, 0, 0}
	for i, g := range glyphs {
		if g.Codepoint != 0xE000+i || len(g.Contours) == 0 {
			return nil, fmt.Errorf("invalid glyph %q", g.Name)
		}
		b := bounds(g)
		if b[0] < 0 || b[1] < descent || b[2] > em || b[3] > ascent {
			return nil, fmt.Errorf("glyph %q exceeds its cell", g.Name)
		}
		box = [4]int{min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3])}
		locations.longs(uint32(outlines.Len()))
		metrics.words(em, b[0])
		outlines.words(len(g.Contours), b[0], b[1], b[2], b[3])
		var points []point
		for _, contour := range g.Contours {
			if len(contour) < 3 {
				return nil, fmt.Errorf("invalid contour in %q", g.Name)
			}
			points = append(points, contour...)
			outlines.words(len(points) - 1)
		}
		if len(points) > 65535 {
			return nil, fmt.Errorf("too many points in %q", g.Name)
		}
		maxPoints, maxContours = max(maxPoints, len(points)), max(maxContours, len(g.Contours))
		outlines.words(0) // no bytecode hints
		for _, p := range points {
			if p[2] != 0 && p[2] != 1 {
				return nil, fmt.Errorf("invalid on-curve flag in %q", g.Name)
			}
			outlines.WriteByte(byte(p[2]))
		}
		for axis := range 2 {
			previous := 0
			for _, p := range points {
				outlines.words(p[axis] - previous)
				previous = p[axis]
			}
		}
		if outlines.Len()%2 != 0 {
			outlines.WriteByte(0)
		}
	}
	locations.longs(uint32(outlines.Len()))

	// Fixed OpenType metadata; timestamps and table order are deterministic.
	var head, hhea, maxp, os2, post, cmap data
	head.longs(0x10000, 0x10000, 0, 0x5F0F3CF5)
	head.words(3, em)
	head.longs(0, 2082844800, 0, 2082844800)
	head.words(box[0], box[1], box[2], box[3], 0, 8, 2, 1, 0)
	hhea.longs(0x10000)
	hhea.words(ascent, descent, 0, em, 0, 0, em, 1, 0, 0, 0, 0, 0, 0, 0, 4)
	maxp.longs(0x10000)
	maxp.words(4, maxPoints, maxContours, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0)
	os2.words(4, em, 400, 5, 0, 665, 665, 0, 143, 665, 665, 0, 491, 51, 265, 0)
	os2.Write(make([]byte, 10)) // PANOSE: no text-face classification
	os2.longs(0, 1<<28, 0, 0)   // Unicode private-use area
	os2.WriteString("SSHL")
	os2.words(0xC0, 0xE000, 0xE002, ascent, descent, 0, ascent, -descent)
	os2.longs(0, 0)
	os2.words(512, 768, 0, 0, 1)
	post.longs(0x30000, 0)
	post.words(-75, 50)
	post.longs(1, 0, 0, 0, 0)
	cmap.words(0, 2, 0, 3)
	cmap.longs(20)
	cmap.words(3, 1)
	cmap.longs(20)
	// Format 4: U+E000..E002 map to glyphs 1..3, followed by the sentinel.
	cmap.words(4, 32, 0, 4, 4, 1, 0, 0xE002, 0xFFFF, 0, 0xE000, 0xFFFF, 0x2001, 1, 0, 0)
	return assemble(map[string][]byte{
		"head": head.Bytes(), "hhea": hhea.Bytes(), "maxp": maxp.Bytes(),
		"OS/2": os2.Bytes(), "post": post.Bytes(), "cmap": cmap.Bytes(),
		"glyf": outlines.Bytes(), "loca": locations.Bytes(), "hmtx": metrics.Bytes(),
		"name": names(),
	}), nil
}

func names() []byte {
	values := map[int]string{
		0: "Based on Syncthing icons, copyright Syncthing contributors",
		1: family, 2: "Regular", 3: "SyncshellIcons-Regular-1.000",
		4: family + " Regular", 5: "Version 1.000", 6: "SyncshellIcons-Regular",
		13: "Mozilla Public License 2.0; see assets/LICENSE.md",
		14: "https://mozilla.org/MPL/2.0/",
	}
	var ids []int
	for id := range values {
		ids = append(ids, id)
	}
	slices.Sort(ids)
	var header, strings data
	header.words(0, len(ids), 6+12*len(ids))
	for _, id := range ids {
		encoded := utf16.Encode([]rune(values[id]))
		header.words(3, 1, 0x409, id, 2*len(encoded), strings.Len())
		for _, c := range encoded {
			strings.words(int(c))
		}
	}
	header.Write(strings.Bytes())
	return header.Bytes()
}

func checksum(b []byte) uint32 {
	var sum uint32
	for i := 0; i < len(b); i += 4 {
		var word [4]byte
		copy(word[:], b[i:min(i+4, len(b))])
		sum += binary.BigEndian.Uint32(word[:])
	}
	return sum
}

func assemble(tables map[string][]byte) []byte {
	var keys []string
	for key := range tables {
		keys = append(keys, key)
	}
	slices.Sort(keys)
	n, power, selector := len(keys), 1, 0
	for power*2 <= n {
		power, selector = power*2, selector+1
	}
	var header, body data
	header.longs(0x10000)
	header.words(n, power*16, selector, n*16-power*16)
	headOffset := 0
	for _, key := range keys {
		table := tables[key]
		offset := 12 + n*16 + body.Len()
		header.WriteString(key)
		header.longs(checksum(table), uint32(offset), uint32(len(table)))
		if key == "head" {
			headOffset = offset
		}
		body.Write(table)
		for body.Len()%4 != 0 {
			body.WriteByte(0)
		}
	}
	header.Write(body.Bytes())
	result := header.Bytes()
	binary.BigEndian.PutUint32(result[headOffset+8:], 0xB1B0AFBA-checksum(result))
	return result
}

func main() {
	check := flag.Bool("check", false, "verify the bundled font without writing")
	flag.Parse()
	font, err := buildFont()
	if err != nil {
		log.Fatal(err)
	}
	if *check {
		current, err := os.ReadFile(filename)
		if err != nil || !bytes.Equal(current, font) {
			log.Fatal("bundled font differs; run go run . to regenerate")
		}
		fmt.Println("bundled icon font matches its outline source")
		return
	}
	if err := os.WriteFile(filename, font, 0o644); err != nil {
		log.Fatal(err)
	}
	fmt.Printf("built %s: %d bytes\n", filename, len(font))
}
