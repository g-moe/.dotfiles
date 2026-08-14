package app

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
)

const (
	fanHelperLogPath     = "/Library/Logs/mactop/fan-control.log"
	fanHelperLogMaxBytes = 512 * 1024
)

// fanHelperDiagnostics records the few policy transitions that can change fan
// ownership. It does not log routine samples, so the file remains useful when
// an SMC readback fails hours or days after manual control starts.
type fanHelperDiagnostics interface {
	Log(fanHelperDiagnosticEvent) error
}

type fanHelperDiagnosticFan struct {
	ID         int `json:"id"`
	ActualRPM  int `json:"actual_rpm"`
	TargetRPM  int `json:"target_rpm"`
	MinimumRPM int `json:"minimum_rpm"`
	MaximumRPM int `json:"maximum_rpm"`
	Mode       int `json:"mode"`
}

type fanHelperDiagnosticEvent struct {
	Timestamp       time.Time                `json:"timestamp"`
	Event           string                   `json:"event"`
	Mode            string                   `json:"policy_mode"`
	ConstantRPM     int                      `json:"constant_rpm,omitempty"`
	StartCelsius    float64                  `json:"start_celsius,omitempty"`
	MaximumCelsius  float64                  `json:"maximum_celsius,omitempty"`
	Temperature     float64                  `json:"temperature_celsius,omitempty"`
	Fans            []fanHelperDiagnosticFan `json:"fans,omitempty"`
	ExpectedTargets map[int]int              `json:"expected_targets,omitempty"`
	ForceTest       *int                     `json:"force_test,omitempty"`
	ForceTestError  string                   `json:"force_test_error,omitempty"`
	Reason          string                   `json:"reason,omitempty"`
	Error           string                   `json:"error,omitempty"`
}

type discardFanHelperDiagnostics struct{}

func (discardFanHelperDiagnostics) Log(fanHelperDiagnosticEvent) error { return nil }

type fileFanHelperDiagnostics struct {
	mu       sync.Mutex
	path     string
	ownerUID int
	ownerGID int
	maxBytes int64
}

func newFileFanHelperDiagnostics(path string, ownerUID, ownerGID int) (*fileFanHelperDiagnostics, error) {
	logger := &fileFanHelperDiagnostics{
		path: path, ownerUID: ownerUID, ownerGID: ownerGID, maxBytes: fanHelperLogMaxBytes,
	}
	if err := ensureOwnedDirectory(filepath.Dir(path), ownerUID, ownerGID); err != nil {
		return nil, fmt.Errorf("prepare fan diagnostic log directory: %w", err)
	}
	return logger, nil
}

func (l *fileFanHelperDiagnostics) Log(event fanHelperDiagnosticEvent) error {
	l.mu.Lock()
	defer l.mu.Unlock()

	if event.Timestamp.IsZero() {
		event.Timestamp = time.Now().UTC()
	}
	contents, err := json.Marshal(event)
	if err != nil {
		return err
	}
	contents = append(contents, '\n')

	if err := ensureOwnedDirectory(filepath.Dir(l.path), l.ownerUID, l.ownerGID); err != nil {
		return err
	}
	if err := l.rotateIfNeeded(int64(len(contents))); err != nil {
		return err
	}
	file, err := l.open()
	if err != nil {
		return err
	}
	defer file.Close()
	if _, err := file.Write(contents); err != nil {
		return err
	}
	return file.Sync()
}

func (l *fileFanHelperDiagnostics) rotateIfNeeded(nextEventBytes int64) error {
	info, err := os.Lstat(l.path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return err
	}
	if err := l.validateFile(info); err != nil {
		return err
	}
	if info.Size()+nextEventBytes <= l.maxBytes {
		return nil
	}

	backupPath := l.path + ".1"
	if backup, backupErr := os.Lstat(backupPath); backupErr == nil {
		if err := l.validateFile(backup); err != nil {
			return fmt.Errorf("fan diagnostic log backup is unsafe: %w", err)
		}
		if err := os.Remove(backupPath); err != nil {
			return err
		}
	} else if !os.IsNotExist(backupErr) {
		return backupErr
	}
	return os.Rename(l.path, backupPath)
}

func (l *fileFanHelperDiagnostics) open() (*os.File, error) {
	fd, err := unix.Open(l.path, unix.O_WRONLY|unix.O_APPEND|unix.O_CREAT|unix.O_NOFOLLOW, 0640)
	if err != nil {
		return nil, err
	}
	file := os.NewFile(uintptr(fd), l.path)
	if err := file.Chown(l.ownerUID, l.ownerGID); err != nil {
		file.Close()
		return nil, err
	}
	if err := file.Chmod(0640); err != nil {
		file.Close()
		return nil, err
	}
	info, err := file.Stat()
	if err != nil {
		file.Close()
		return nil, err
	}
	if err := l.validateFile(info); err != nil {
		file.Close()
		return nil, err
	}
	return file, nil
}

func (l *fileFanHelperDiagnostics) validateFile(info os.FileInfo) error {
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || !info.Mode().IsRegular() || int(stat.Uid) != l.ownerUID ||
		int(stat.Gid) != l.ownerGID || info.Mode().Perm() != 0640 {
		return errors.New("fan diagnostic log must be a root-owned 0640 regular file")
	}
	return nil
}

func diagnosticFans(fans []FanInfo) []fanHelperDiagnosticFan {
	if len(fans) == 0 {
		return nil
	}
	result := make([]fanHelperDiagnosticFan, len(fans))
	for index, fan := range fans {
		result[index] = fanHelperDiagnosticFan{
			ID: fan.ID, ActualRPM: fan.ActualRPM, TargetRPM: fan.TargetRPM,
			MinimumRPM: fan.MinRPM, MaximumRPM: fan.MaxRPM, Mode: fan.Mode,
		}
	}
	return result
}
