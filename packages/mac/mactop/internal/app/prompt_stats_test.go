package app

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestPromptStatsFormatMatchesLinuxPromptText(t *testing.T) {
	stats := promptStats{
		CPUPercent: 3.6,
		ExpiresAt:  time.Unix(1700000015, 0),
		GPUPercent: 2.3,
		Memory:     MemoryMetrics{Total: 200, Used: 68},
	}

	want := "1700000015\nCPU-4% | GPU-2% | MEM 34%\n"
	if got := stats.format(); got != want {
		t.Fatalf("format() = %q, want %q", got, want)
	}
}

func TestPromptStatsFormatHandlesMissingMemoryTotal(t *testing.T) {
	stats := promptStats{ExpiresAt: time.Unix(0, 0)}

	want := "0\nCPU-0% | GPU-0% | MEM 0%\n"
	if got := stats.format(); got != want {
		t.Fatalf("format() = %q, want %q", got, want)
	}
}

func TestWritePromptStatsReplacesFile(t *testing.T) {
	path := filepath.Join(t.TempDir(), promptStatsFileName)
	first := promptStats{CPUPercent: 1}
	second := promptStats{CPUPercent: 2}

	for _, stats := range []promptStats{first, second} {
		if err := writePromptStats(path, stats); err != nil {
			t.Fatalf("writePromptStats() error = %v", err)
		}
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("ReadFile() error = %v", err)
	}
	if got, want := string(data), second.format(); got != want {
		t.Fatalf("prompt stats file = %q, want %q", got, want)
	}
	if _, err := os.Stat(path + ".tmp"); !os.IsNotExist(err) {
		t.Fatalf("temp file was left behind: %v", err)
	}
}
