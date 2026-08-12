// Package messages provides the fixed U.S. English text catalog.
package messages

import (
	"embed"
	"encoding/json"
)

//go:embed messages.json
var messageFS embed.FS

var messages = loadUSCatalog()

func loadUSCatalog() map[string]string {
	data, err := messageFS.ReadFile("messages.json")
	if err != nil {
		panic("load U.S. English messages: " + err.Error())
	}
	var catalog map[string]string
	if err := json.Unmarshal(data, &catalog); err != nil {
		panic("decode U.S. English messages: " + err.Error())
	}
	return catalog
}

// Text returns the U.S. English string for id, or id when it is unknown.
// Keeping this small lookup API avoids coupling UI code to the catalog format.
func Text(id string) string {
	if message, ok := messages[id]; ok {
		return message
	}
	return id
}
