// prompt_stats.go - Shares the menu bar's CPU, GPU, and memory use with the Zsh prompt
package app

import (
	"fmt"
	"os"
	"time"
)

const (
	promptStatsFileName = "prompt-stats"

	// The prompt hides the stats this many update intervals after the last
	// write, so a stopped menu bar does not leave old numbers on screen.
	promptStatsLifetimeIntervals = 3
)

type promptStats struct {
	CPUPercent float64
	ExpiresAt  time.Time
	GPUPercent float64
	Memory     MemoryMetrics
}

// format renders the expiry as Unix seconds, then the same text the Linux
// prompt shows.
//
// @example
// promptStats{CPUPercent: 3.6, ExpiresAt: time.Unix(1700000015, 0), GPUPercent: 2.3, Memory: MemoryMetrics{Total: 100, Used: 33}}.format()
// // "1700000015\nCPU-4% | GPU-2% | MEM 33%\n"
func (s promptStats) format() string {
	memoryPercent := 0.0
	if s.Memory.Total > 0 {
		memoryPercent = float64(s.Memory.Used) / float64(s.Memory.Total) * 100
	}
	return fmt.Sprintf("%d\nCPU-%.0f%% | GPU-%.0f%% | MEM %.0f%%\n",
		s.ExpiresAt.Unix(), s.CPUPercent, s.GPUPercent, memoryPercent)
}

// writePromptStats replaces the file with one rename so the prompt never reads
// a half-written file.
func writePromptStats(path string, stats promptStats) error {
	tempPath := path + ".tmp"
	if err := os.WriteFile(tempPath, []byte(stats.format()), 0644); err != nil {
		return err
	}
	return os.Rename(tempPath, path)
}

// publishPromptStats writes the menu bar's current sample for the prompt.
// A failed write is logged and never stops the menu bar.
func publishPromptStats(cpuPercent float64, gpuMetrics GPUMetrics) {
	interval := time.Duration(updateInterval) * time.Millisecond
	stats := promptStats{
		CPUPercent: cpuPercent,
		ExpiresAt:  time.Now().Add(interval * promptStatsLifetimeIntervals),
		GPUPercent: gpuMetrics.ActivePercent,
		Memory:     getMemoryMetrics(),
	}

	if err := writePromptStats(mactopStatePath(promptStatsFileName), stats); err != nil {
		stderrLogger.Printf("Error writing prompt stats: %v\n", err)
	}
}
