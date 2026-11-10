package app

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestNewPromptStatsRoundsAndExpires(t *testing.T) {
	now := time.Unix(1700000000, 0)

	got := newPromptStats(newPromptStatsParams{
		CPUPercent:     3.6,
		GPUPercent:     2.3,
		Memory:         MemoryMetrics{Total: 200, Used: 67},
		Now:            now,
		UpdateInterval: 5000 * time.Millisecond,
	})
	want := promptStats{
		CPUPercent:    4,
		ExpiresAt:     now.Add(15 * time.Second),
		GPUPercent:    2,
		MemoryPercent: 34,
	}
	if got != want {
		t.Fatalf("newPromptStats() = %+v, want %+v", got, want)
	}
}

func TestNewPromptStatsHandlesMissingMemoryTotal(t *testing.T) {
	got := newPromptStats(newPromptStatsParams{Memory: MemoryMetrics{Used: 10}})
	if got.MemoryPercent != 0 {
		t.Fatalf("MemoryPercent = %d, want 0", got.MemoryPercent)
	}
}

func TestFormatPromptStatsMatchesLinuxPromptText(t *testing.T) {
	got := formatPromptStats(promptStats{
		CPUPercent:    4,
		ExpiresAt:     time.Unix(1700000015, 0),
		GPUPercent:    2,
		MemoryPercent: 33,
	})
	want := "1700000015\nCPU-4% | GPU-2% | MEM 33%\n"
	if got != want {
		t.Fatalf("formatPromptStats() = %q, want %q", got, want)
	}
}

func TestWritePromptStatsReplacesFileAndCreatesDirectory(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state", promptStatsFileName)
	first := promptStats{CPUPercent: 1, ExpiresAt: time.Unix(1, 0)}
	second := promptStats{CPUPercent: 2, ExpiresAt: time.Unix(2, 0)}

	if err := writePromptStats(path, first); err != nil {
		t.Fatalf("first writePromptStats() error = %v", err)
	}
	if err := writePromptStats(path, second); err != nil {
		t.Fatalf("second writePromptStats() error = %v", err)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("ReadFile() error = %v", err)
	}
	if got, want := string(data), formatPromptStats(second); got != want {
		t.Fatalf("prompt stats file = %q, want %q", got, want)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatalf("Stat() error = %v", err)
	}
	if got := info.Mode().Perm(); got != 0644 {
		t.Fatalf("prompt stats permissions = %o, want 644", got)
	}

	entries, err := os.ReadDir(filepath.Dir(path))
	if err != nil {
		t.Fatalf("ReadDir() error = %v", err)
	}
	if len(entries) != 1 {
		t.Fatalf("state directory has %d entries, want only the prompt stats file", len(entries))
	}
}
