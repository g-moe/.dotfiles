package app

import (
	"context"
	"errors"
	"reflect"
	"testing"
	"time"
)

type fakeFanModeHardware struct {
	modes             map[int]int
	forceTest         int
	forceTestMissing  bool
	modeFailures      int
	modeWrites        []int
	forceTestWrites   []bool
	reclaimOnForceOff bool
}

func (f *fakeFanModeHardware) ReadMode(fanID int) (int, error) {
	mode, ok := f.modes[fanID]
	if !ok {
		return 0, errors.New("mode missing")
	}
	return mode, nil
}

func (f *fakeFanModeHardware) WriteMode(fanID, mode int) error {
	f.modeWrites = append(f.modeWrites, mode)
	if f.modeFailures > 0 {
		f.modeFailures--
		return errors.New("mode write rejected")
	}
	f.modes[fanID] = mode
	return nil
}

func (f *fakeFanModeHardware) ReadForceTest() (int, error) {
	if f.forceTestMissing {
		return 0, errFanForceTestUnavailable
	}
	return f.forceTest, nil
}

func (f *fakeFanModeHardware) WriteForceTest(enabled bool) error {
	f.forceTestWrites = append(f.forceTestWrites, enabled)
	if enabled {
		f.forceTest = 1
		return nil
	}
	f.forceTest = 0
	if f.reclaimOnForceOff {
		for fanID := range f.modes {
			f.modes[fanID] = 3
		}
	}
	return nil
}

func TestSetFanModeUsesDirectWriteWhenHardwareAcceptsIt(t *testing.T) {
	hardware := &fakeFanModeHardware{modes: map[int]int{0: 0}}
	if err := setFanModeWithHardware(hardware, 0, 1, func(time.Duration) error {
		t.Fatal("direct mode write slept")
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(hardware.modeWrites, []int{1}) || len(hardware.forceTestWrites) != 0 {
		t.Fatalf("mode writes = %v, force-test writes = %v", hardware.modeWrites, hardware.forceTestWrites)
	}
}

func TestFansHaveManualModeDistinguishesSystemControl(t *testing.T) {
	if fansHaveManualMode([]FanInfo{{Mode: 0}, {Mode: 3}}) {
		t.Fatal("automatic and system-control modes were reported as manual")
	}
	if !fansHaveManualMode([]FanInfo{{Mode: 3}, {Mode: 1}}) {
		t.Fatal("manual mode was not detected")
	}
}

func TestSetFanModeFallsBackToForceTestUnlock(t *testing.T) {
	hardware := &fakeFanModeHardware{modes: map[int]int{0: 3}, modeFailures: 3}
	var sleeps []time.Duration
	if err := setFanModeWithHardware(hardware, 0, 1, func(delay time.Duration) error {
		sleeps = append(sleeps, delay)
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(hardware.modeWrites, []int{1, 1, 1, 1}) {
		t.Fatalf("mode writes = %v", hardware.modeWrites)
	}
	if !reflect.DeepEqual(hardware.forceTestWrites, []bool{true}) {
		t.Fatalf("force-test writes = %v", hardware.forceTestWrites)
	}
	wantSleeps := []time.Duration{fanUnlockSettleTime, fanUnlockRetryTime, fanUnlockRetryTime}
	if !reflect.DeepEqual(sleeps, wantSleeps) {
		t.Fatalf("sleeps = %v, want %v", sleeps, wantSleeps)
	}
}

func TestSetFanModeClearsForceTestAfterUnlockTimeout(t *testing.T) {
	hardware := &fakeFanModeHardware{modes: map[int]int{0: 3}, modeFailures: fanUnlockAttempts + 1}
	err := setFanModeWithHardware(hardware, 0, 1, func(time.Duration) error { return nil })
	if err == nil {
		t.Fatal("unlock timeout returned no error")
	}
	if !reflect.DeepEqual(hardware.forceTestWrites, []bool{true, false}) || hardware.forceTest != 0 {
		t.Fatalf("force-test writes = %v, state = %d", hardware.forceTestWrites, hardware.forceTest)
	}
}

func TestSetFanModeClearsForceTestWhenPolicyIsCanceled(t *testing.T) {
	hardware := &fakeFanModeHardware{modes: map[int]int{0: 3}, modeFailures: 1}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	err := setFanModeWithHardware(hardware, 0, 1, waitForFanControlContext(ctx))
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("cancellation error = %v", err)
	}
	if !reflect.DeepEqual(hardware.forceTestWrites, []bool{true, false}) || hardware.forceTest != 0 {
		t.Fatalf("force-test writes = %v, state = %d", hardware.forceTestWrites, hardware.forceTest)
	}
}

func TestResetFansAcceptsAppleSiliconSystemMode(t *testing.T) {
	hardware := &fakeFanModeHardware{modes: map[int]int{0: 3, 1: 3}}
	fans := []FanInfo{{ID: 0}, {ID: 1}}
	if err := resetFansToAutoWithHardware(hardware, fans, func(time.Duration) error {
		t.Fatal("system mode reset slept")
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if len(hardware.modeWrites) != 0 || len(hardware.forceTestWrites) != 0 {
		t.Fatalf("mode writes = %v, force-test writes = %v", hardware.modeWrites, hardware.forceTestWrites)
	}
}

func TestResetFansClearsForceTestAndVerifiesNoManualModes(t *testing.T) {
	hardware := &fakeFanModeHardware{
		modes: map[int]int{0: 1, 1: 1}, forceTest: 1, modeFailures: 2, reclaimOnForceOff: true,
	}
	fans := []FanInfo{{ID: 0}, {ID: 1}}
	if err := resetFansToAutoWithHardware(hardware, fans, func(time.Duration) error { return nil }); err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(hardware.modeWrites, []int{0, 0}) {
		t.Fatalf("mode writes = %v", hardware.modeWrites)
	}
	if !reflect.DeepEqual(hardware.forceTestWrites, []bool{false}) {
		t.Fatalf("force-test writes = %v", hardware.forceTestWrites)
	}
	if hardware.modes[0] != 3 || hardware.modes[1] != 3 {
		t.Fatalf("modes = %v", hardware.modes)
	}
}

func TestResetFansWorksWithoutForceTestKey(t *testing.T) {
	hardware := &fakeFanModeHardware{modes: map[int]int{0: 1}, forceTestMissing: true}
	if err := resetFansToAutoWithHardware(hardware, []FanInfo{{ID: 0}}, func(time.Duration) error { return nil }); err != nil {
		t.Fatal(err)
	}
	if hardware.modes[0] != 0 || len(hardware.forceTestWrites) != 0 {
		t.Fatalf("mode = %d, force-test writes = %v", hardware.modes[0], hardware.forceTestWrites)
	}
}
