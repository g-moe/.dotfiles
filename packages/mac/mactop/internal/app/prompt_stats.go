// prompt_stats.go - Shares the menu bar's latest CPU, GPU, and memory use with the shell prompt
package app

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"time"
)

const (
	promptStatsFileName = "prompt-stats"

	// The prompt hides the stats after this many missed samples, so a stopped
	// menu bar does not leave old numbers on screen.
	promptStatsMissedSamples = 3
)

// promptStats is one menu bar sample in the shape the prompt shows.
type promptStats struct {
	CPUPercent    int
	ExpiresAt     time.Time
	GPUPercent    int
	MemoryPercent int
}

type newPromptStatsParams struct {
	CPUPercent     float64
	GPUPercent     float64
	Memory         MemoryMetrics
	Now            time.Time
	UpdateInterval time.Duration
}

// newPromptStats rounds one sample into whole percentages that expire after
// promptStatsMissedSamples update intervals.
//
// @example
// newPromptStats(newPromptStatsParams{CPUPercent: 3.6, GPUPercent: 2.3, Memory: MemoryMetrics{Total: 100, Used: 33}, Now: now, UpdateInterval: 5000 * time.Millisecond})
// // promptStats{CPUPercent: 4, GPUPercent: 2, MemoryPercent: 33, ExpiresAt: now.Add(15 * time.Second)}
func newPromptStats(params newPromptStatsParams) promptStats {
	memoryPercent := 0.0
	if params.Memory.Total > 0 {
		memoryPercent = float64(params.Memory.Used) / float64(params.Memory.Total) * 100
	}

	return promptStats{
		CPUPercent:    int(math.Round(params.CPUPercent)),
		ExpiresAt:     params.Now.Add(params.UpdateInterval * promptStatsMissedSamples),
		GPUPercent:    int(math.Round(params.GPUPercent)),
		MemoryPercent: int(math.Round(memoryPercent)),
	}
}

// formatPromptStats renders the prompt file: the expiry as Unix seconds on the
// first line, then the same text the Linux prompt shows.
//
// @example
// formatPromptStats(promptStats{CPUPercent: 4, GPUPercent: 2, MemoryPercent: 33, ExpiresAt: time.Unix(1700000015, 0)})
// // "1700000015\nCPU-4% | GPU-2% | MEM 33%\n"
func formatPromptStats(stats promptStats) string {
	return fmt.Sprintf(
		"%d\nCPU-%d%% | GPU-%d%% | MEM %d%%\n",
		stats.ExpiresAt.Unix(),
		stats.CPUPercent,
		stats.GPUPercent,
		stats.MemoryPercent,
	)
}

// writePromptStats replaces the prompt file in one rename so the prompt never
// reads a half-written file.
func writePromptStats(path string, stats promptStats) error {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return fmt.Errorf("create prompt stats directory: %w", err)
	}

	tempFile, err := os.CreateTemp(filepath.Dir(path), promptStatsFileName+".*")
	if err != nil {
		return fmt.Errorf("create prompt stats temp file: %w", err)
	}
	tempPath := tempFile.Name()
	defer os.Remove(tempPath)

	if _, err := tempFile.WriteString(formatPromptStats(stats)); err != nil {
		tempFile.Close()
		return fmt.Errorf("write prompt stats: %w", err)
	}
	if err := tempFile.Close(); err != nil {
		return fmt.Errorf("close prompt stats: %w", err)
	}
	if err := os.Chmod(tempPath, 0644); err != nil {
		return fmt.Errorf("set prompt stats permissions: %w", err)
	}
	if err := os.Rename(tempPath, path); err != nil {
		return fmt.Errorf("replace prompt stats: %w", err)
	}
	return nil
}

// publishPromptStats writes the menu bar's current sample for the shell prompt.
// A failed write is logged and never stops the menu bar.
func publishPromptStats(cpuPercent float64, gpuMetrics GPUMetrics) {
	stats := newPromptStats(newPromptStatsParams{
		CPUPercent:     cpuPercent,
		GPUPercent:     gpuMetrics.ActivePercent,
		Memory:         getMemoryMetrics(),
		Now:            time.Now(),
		UpdateInterval: time.Duration(updateInterval) * time.Millisecond,
	})

	if err := writePromptStats(mactopStatePath(promptStatsFileName), stats); err != nil {
		stderrLogger.Printf("Error writing prompt stats: %v\n", err)
	}
}
