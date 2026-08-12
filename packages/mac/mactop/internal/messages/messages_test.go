package messages

import (
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"
)

var (
	messageKeyRE = regexp.MustCompile(`^\s*"([A-Za-z0-9_][A-Za-z0-9_]*)"\s*:`)
	goKeyRE      = regexp.MustCompile(`messages\.Text\("([^"]+)"\)`)
	objcKeyRE    = regexp.MustCompile(`messageText\(@"([^"]+)"\)`)
)

func TestOnlyUSMessageCatalogExists(t *testing.T) {
	var catalogs []string
	err := filepath.WalkDir("..", func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if !entry.IsDir() && (strings.HasSuffix(entry.Name(), ".json") || strings.HasSuffix(entry.Name(), ".toml")) {
			catalogs = append(catalogs, path)
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(catalogs) != 1 || filepath.Base(catalogs[0]) != "messages.json" {
		t.Fatalf("message catalogs = %v, want only messages.json", catalogs)
	}
}

func TestUSCatalogIsValidAndHasNoDuplicateKeys(t *testing.T) {
	data, err := messageFS.ReadFile("messages.json")
	if err != nil {
		t.Fatal(err)
	}
	var catalog map[string]string
	if err := json.Unmarshal(data, &catalog); err != nil {
		t.Fatal(err)
	}
	if len(catalog) == 0 {
		t.Fatal("U.S. English catalog is empty")
	}
	seen := make(map[string]bool, len(catalog))
	for line := range strings.SplitSeq(string(data), "\n") {
		match := messageKeyRE.FindStringSubmatch(line)
		if len(match) != 2 {
			continue
		}
		if seen[match[1]] {
			t.Fatalf("U.S. English catalog declares %q more than once", match[1])
		}
		seen[match[1]] = true
	}
	if len(seen) != len(catalog) {
		t.Fatalf("validated %d message keys, catalog contains %d", len(seen), len(catalog))
	}
}

func TestLiteralMessageKeysExist(t *testing.T) {
	used := make(map[string]string)
	err := filepath.WalkDir("../app", func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() || strings.HasSuffix(path, "_test.go") {
			return nil
		}
		if !strings.HasSuffix(path, ".go") && !strings.HasSuffix(path, ".m") {
			return nil
		}
		data, readErr := os.ReadFile(path)
		if readErr != nil {
			return readErr
		}
		for _, matcher := range []*regexp.Regexp{goKeyRE, objcKeyRE} {
			for _, match := range matcher.FindAllStringSubmatch(string(data), -1) {
				used[match[1]] = path
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	var missing []string
	for key, path := range used {
		if _, ok := messages[key]; !ok {
			missing = append(missing, key+" ("+path+")")
		}
	}
	sort.Strings(missing)
	if len(missing) > 0 {
		t.Fatalf("U.S. English catalog is missing literal message keys: %s", strings.Join(missing, ", "))
	}
}

func TestUnknownMessageReturnsID(t *testing.T) {
	const id = "Missing_Test_Message"
	if got := Text(id); got != id {
		t.Fatalf("Text(%q) = %q", id, got)
	}
}
