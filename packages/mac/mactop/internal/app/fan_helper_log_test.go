package app

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestFanHelperDiagnosticsRecordsRawFanReadback(t *testing.T) {
	path := filepath.Join(t.TempDir(), "logs", "fan-control.log")
	logger, err := newFileFanHelperDiagnostics(path, os.Getuid(), os.Getgid())
	if err != nil {
		t.Fatal(err)
	}
	forceTest := 1
	event := fanHelperDiagnosticEvent{
		Timestamp: time.Date(2026, time.August, 13, 18, 20, 0, 0, time.UTC),
		Event:     "manual_policy_failed", Mode: fanModeConstant, ConstantRPM: 3000,
		Fans: []fanHelperDiagnosticFan{{
			ID: 0, ActualRPM: 2987, TargetRPM: 3000, MinimumRPM: 1350, MaximumRPM: 5777, Mode: 3,
		}},
		ExpectedTargets: map[int]int{0: 3000}, ForceTest: &forceTest,
		Reason: "manual_policy_still_verified", Error: "fan 0 did not enter manual mode",
	}
	if err := logger.Log(event); err != nil {
		t.Fatal(err)
	}

	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0640 {
		t.Fatalf("log mode = %v, want 0640", info.Mode().Perm())
	}
	contents, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var got fanHelperDiagnosticEvent
	if err := json.Unmarshal(contents, &got); err != nil {
		t.Fatal(err)
	}
	if got.Event != event.Event || got.ForceTest == nil || *got.ForceTest != 1 ||
		len(got.Fans) != 1 || got.Fans[0].Mode != 3 || got.ExpectedTargets[0] != 3000 ||
		got.Reason != event.Reason || !strings.Contains(got.Error, "manual mode") {
		t.Fatalf("diagnostic event = %+v", got)
	}
}

func TestFanHelperDiagnosticsRotatesLogFiles(t *testing.T) {
	path := filepath.Join(t.TempDir(), "logs", "fan-control.log")
	logger, err := newFileFanHelperDiagnostics(path, os.Getuid(), os.Getgid())
	if err != nil {
		t.Fatal(err)
	}
	logger.maxBytes = 1
	if err := logger.Log(fanHelperDiagnosticEvent{Event: "first"}); err != nil {
		t.Fatal(err)
	}
	if err := logger.Log(fanHelperDiagnosticEvent{Event: "second"}); err != nil {
		t.Fatal(err)
	}
	backup, err := os.ReadFile(path + ".1")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(backup), `"event":"first"`) {
		t.Fatalf("backup = %s", backup)
	}
}

func TestFanHelperDiagnosticsRejectsUnsafeLogFiles(t *testing.T) {
	path := filepath.Join(t.TempDir(), "logs", "fan-control.log")
	logger, err := newFileFanHelperDiagnostics(path, os.Getuid(), os.Getgid())
	if err != nil {
		t.Fatal(err)
	}
	if err := logger.Log(fanHelperDiagnosticEvent{Event: "first"}); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(path, 0600); err != nil {
		t.Fatal(err)
	}
	if err := logger.Log(fanHelperDiagnosticEvent{Event: "second"}); err == nil || !strings.Contains(err.Error(), "root-owned") {
		t.Fatalf("unsafe log error = %v", err)
	}
}
