package app

import (
	"errors"
	"math"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestFanCurveTargetRPM(t *testing.T) {
	curve := fixedFanCurve()
	tests := []struct {
		name        string
		temperature float64
		want        int
	}{
		{name: "below lower limit", temperature: 20, want: 1700},
		{name: "at lower limit", temperature: 38, want: 1700},
		{name: "midpoint", temperature: 61.5, want: 3100},
		{name: "at upper limit", temperature: 85, want: 4500},
		{name: "above upper limit", temperature: 100, want: 4500},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := curve.targetRPM(test.temperature, 1700, 4500)
			if err != nil {
				t.Fatal(err)
			}
			if got != test.want {
				t.Fatalf("targetRPM() = %d, want %d", got, test.want)
			}
		})
	}
}

func TestFanCurveRejectsInvalidInput(t *testing.T) {
	tests := []struct {
		name        string
		temperature float64
		minRPM      int
		maxRPM      int
	}{
		{name: "NaN temperature", temperature: math.NaN(), minRPM: 1000, maxRPM: 2000},
		{name: "infinite temperature", temperature: math.Inf(1), minRPM: 1000, maxRPM: 2000},
		{name: "implausible temperature", temperature: 126, minRPM: 1000, maxRPM: 2000},
		{name: "zero minimum", temperature: 50, minRPM: 0, maxRPM: 2000},
		{name: "reversed range", temperature: 50, minRPM: 2000, maxRPM: 1000},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if _, err := fixedFanCurve().targetRPM(test.temperature, test.minRPM, test.maxRPM); err == nil {
				t.Fatal("targetRPM() returned no error")
			}
		})
	}
}

func TestPerformanceCoreAverage(t *testing.T) {
	sensors := []TempSensor{
		{Key: "Te01", Name: "CPU E-Core 01", Value: 30},
		{Key: "Tp01", Name: "CPU P-Core 01", Value: 40},
		{Key: "Tp02", Name: "CPU P-Core 02", Value: 50},
		{Key: "Tg01", Name: "GPU", Value: 70},
	}
	got, err := performanceCoreAverage(sensors, SystemInfo{ECoreCount: 1, PCoreCount: 2})
	if err != nil {
		t.Fatal(err)
	}
	if got != 45 {
		t.Fatalf("performanceCoreAverage() = %.1f, want 45.0", got)
	}
}

func TestPerformanceCoreAverageRejectsGenericSensors(t *testing.T) {
	sensors := []TempSensor{
		{Key: "TC00", Name: "CPU Core", Value: 20},
		{Key: "TC01", Name: "CPU Core", Value: 30},
		{Key: "TC02", Name: "CPU Core", Value: 50},
		{Key: "TC03", Name: "CPU Core", Value: 60},
	}
	if _, err := performanceCoreAverage(sensors, SystemInfo{ECoreCount: 2, PCoreCount: 2}); err == nil {
		t.Fatal("generic sensors returned no error")
	}
}

func TestPerformanceCoreAverageRejectsMissingOrInvalidSensors(t *testing.T) {
	if _, err := performanceCoreAverage([]TempSensor{{Key: "Tg0", Name: "GPU", Value: 40}}, SystemInfo{}); err == nil {
		t.Fatal("missing P-core sensors returned no error")
	}
	if _, err := performanceCoreAverage([]TempSensor{{Key: "Tp0", Name: "CPU P-Core", Value: math.NaN()}}, SystemInfo{}); err == nil {
		t.Fatal("invalid P-core sensor returned no error")
	}
}

func TestFanPolicySettingsValidation(t *testing.T) {
	valid := []fanPolicySettings{
		{Mode: fanModeDefault},
		{Mode: fanModeConstant, ConstantRPM: 2000},
		{Mode: fanModeCurve, StartCelsius: 20, MaximumCelsius: 25},
		{Mode: fanModeCurve, StartCelsius: 38, MaximumCelsius: 85},
	}
	for _, settings := range valid {
		if err := settings.validate(); err != nil {
			t.Errorf("valid settings %+v: %v", settings, err)
		}
	}

	invalid := []fanPolicySettings{
		{Mode: "custom"},
		{Mode: fanModeDefault, ConstantRPM: 2000},
		{Mode: fanModeConstant, ConstantRPM: 0},
		{Mode: fanModeConstant, ConstantRPM: 20001},
		{Mode: fanModeConstant, ConstantRPM: 2000, StartCelsius: 38},
		{Mode: fanModeCurve, ConstantRPM: 2000, StartCelsius: 38, MaximumCelsius: 85},
		{Mode: fanModeCurve, StartCelsius: math.NaN(), MaximumCelsius: 85},
		{Mode: fanModeCurve, StartCelsius: 38, MaximumCelsius: math.Inf(1)},
		{Mode: fanModeCurve, StartCelsius: 38.5, MaximumCelsius: 85},
		{Mode: fanModeCurve, StartCelsius: 19, MaximumCelsius: 85},
		{Mode: fanModeCurve, StartCelsius: 38, MaximumCelsius: 101},
		{Mode: fanModeCurve, StartCelsius: 80, MaximumCelsius: 84},
		{Mode: fanModeCurve, StartCelsius: 85, MaximumCelsius: 38},
	}
	for _, settings := range invalid {
		if err := settings.validate(); err == nil {
			t.Errorf("invalid settings %+v returned no error", settings)
		}
	}
}

func TestConstantFanSpeedUsesCommonRangeWithoutTemperature(t *testing.T) {
	sample := SocMetrics{Fans: []FanInfo{
		{ID: 0, MinRPM: 1200, MaxRPM: 5000},
		{ID: 1, MinRPM: 1500, MaxRPM: 4500},
	}}
	settings := fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2300}
	temperature, targets, err := evaluateFanSettings(sample, SystemInfo{}, settings)
	if err != nil {
		t.Fatal(err)
	}
	if temperature != 0 || !reflect.DeepEqual(targets, map[int]int{0: 2300, 1: 2300}) {
		t.Fatalf("temperature = %.1f, targets = %v", temperature, targets)
	}

	settings.ConstantRPM = 1400
	if _, _, err := evaluateFanSettings(sample, SystemInfo{}, settings); err == nil || !strings.Contains(err.Error(), "1500-4500") {
		t.Fatalf("out-of-range error = %v", err)
	}
}

func TestM1MacMiniConstantFanBaseline(t *testing.T) {
	sample := SocMetrics{Fans: []FanInfo{{ID: 0, MinRPM: 1700, MaxRPM: 4499}}}
	for _, rpm := range []int{2500, 4499} {
		_, targets, err := evaluateFanSettings(sample, SystemInfo{}, fanPolicySettings{
			Mode: fanModeConstant, ConstantRPM: rpm,
		})
		if err != nil {
			t.Fatalf("M1 Mac mini Constant %d: %v", rpm, err)
		}
		if !reflect.DeepEqual(targets, map[int]int{0: rpm}) {
			t.Fatalf("M1 Mac mini Constant %d targets = %v", rpm, targets)
		}
	}
	_, _, err := evaluateFanSettings(sample, SystemInfo{}, fanPolicySettings{
		Mode: fanModeConstant, ConstantRPM: 4500,
	})
	if err == nil || !strings.Contains(err.Error(), "1700-4499") {
		t.Fatalf("M1 Mac mini accepted 4500 RPM: %v", err)
	}
}

func TestM4MacMiniDiscoveredFanRange(t *testing.T) {
	for _, key := range []string{"TfC0", "Tp00"} {
		if group := sensorGroupName(key); group != "CPU P-Core" {
			t.Fatalf("M4 Mac mini sensor %s group = %q, want CPU P-Core", key, group)
		}
	}
	sample := SocMetrics{
		Fans: []FanInfo{{ID: 0, MinRPM: 1000, MaxRPM: 4900}},
		TempSensors: []TempSensor{
			{Key: "TfC0", Name: "CPU P-Core", Value: 50},
			{Key: "Tp00", Name: "CPU P-Core", Value: 52},
		},
	}
	settings := fanPolicySettings{Mode: fanModeCurve, StartCelsius: 38, MaximumCelsius: 85}
	temperature, targets, err := evaluateFanSettings(sample, SystemInfo{}, settings)
	if err != nil {
		t.Fatal(err)
	}
	want := 1000 + int(math.Round((51.0-38.0)/(85.0-38.0)*3900.0))
	if temperature != 51 || !reflect.DeepEqual(targets, map[int]int{0: want}) {
		t.Fatalf("M4 Mac mini temperature = %.1f, targets = %v, want 51.0 and fan 0=%d", temperature, targets, want)
	}
	for _, rpm := range []int{1000, 2950, 4900} {
		_, constantTargets, constantErr := evaluateFanSettings(sample, SystemInfo{}, fanPolicySettings{
			Mode: fanModeConstant, ConstantRPM: rpm,
		})
		if constantErr != nil || constantTargets[0] != rpm {
			t.Fatalf("M4 Mac mini Constant %d targets = %v, error = %v", rpm, constantTargets, constantErr)
		}
	}
}

func TestConstantFanSpeedRejectsFansWithoutCommonRange(t *testing.T) {
	sample := SocMetrics{Fans: []FanInfo{
		{ID: 0, MinRPM: 1000, MaxRPM: 1800},
		{ID: 1, MinRPM: 2000, MaxRPM: 3000},
	}}
	settings := fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2100}
	if _, _, err := evaluateFanSettings(sample, SystemInfo{}, settings); err == nil || !strings.Contains(err.Error(), "common") {
		t.Fatalf("no-intersection error = %v", err)
	}
}

func TestCustomFanCurveUsesRequestedTemperatures(t *testing.T) {
	settings := fanPolicySettings{Mode: fanModeCurve, StartCelsius: 45, MaximumCelsius: 75}
	for _, test := range []struct {
		temperature float64
		want        int
	}{
		{temperature: 40, want: 1000},
		{temperature: 45, want: 1000},
		{temperature: 60, want: 2000},
		{temperature: 75, want: 3000},
		{temperature: 80, want: 3000},
	} {
		sample := SocMetrics{
			Fans:        []FanInfo{{ID: 0, MinRPM: 1000, MaxRPM: 3000}},
			TempSensors: []TempSensor{{Key: "Tp0", Name: "CPU P-Core", Value: test.temperature}},
		}
		_, targets, err := evaluateFanSettings(sample, SystemInfo{}, settings)
		if err != nil {
			t.Fatal(err)
		}
		if targets[0] != test.want {
			t.Errorf("temperature %.1f target = %d, want %d", test.temperature, targets[0], test.want)
		}
	}
}

func TestConstantFanPolicyWritesTargetBeforeMode(t *testing.T) {
	hardware := &fakeFanHardware{}
	controller := newFanPolicyControllerWithSettings(hardware, fanPolicySettings{
		Mode: fanModeConstant, ConstantRPM: 2200,
	})
	sample := SocMetrics{Fans: []FanInfo{{ID: 0, MinRPM: 1000, MaxRPM: 3000}}}
	if _, targets, err := controller.apply(sample, SystemInfo{}); err != nil {
		t.Fatal(err)
	} else if targets[0] != 2200 {
		t.Fatalf("target = %d, want 2200", targets[0])
	}
	if !reflect.DeepEqual(hardware.calls, []string{"target", "mode", "target"}) {
		t.Fatalf("calls = %v, want target, mode, then confirmed target", hardware.calls)
	}
}

func TestConstantFanPolicyRequiresExactTargetReadback(t *testing.T) {
	hardware := &fakeFanHardware{}
	controller := newFanPolicyControllerWithSettings(hardware, fanPolicySettings{
		Mode: fanModeConstant, ConstantRPM: 2200,
	})
	controller.lastRPM[0] = 2200
	sample := SocMetrics{Fans: []FanInfo{{
		ID: 0, MinRPM: 1000, MaxRPM: 3000, Mode: 1, TargetRPM: 2199,
	}}}
	if _, _, err := controller.apply(sample, SystemInfo{}); err == nil {
		t.Fatal("inexact constant target readback returned no error")
	}
	if !reflect.DeepEqual(hardware.calls, []string{"reset"}) {
		t.Fatalf("calls = %v, want reset", hardware.calls)
	}
}

func TestFanPolicyClassifiesLostManualOwnership(t *testing.T) {
	controller := newFanPolicyControllerWithSettings(&fakeFanHardware{}, fanPolicySettings{
		Mode: fanModeConstant, ConstantRPM: 2200,
	})
	controller.lastRPM[0] = 2200
	err := controller.verifyLastWrite([]FanInfo{{ID: 0, Mode: 3, TargetRPM: 0}})
	if !errors.Is(err, errFanManualOwnershipLost) {
		t.Fatalf("manual ownership error = %v", err)
	}
	if err.Error() != "fan 0 did not enter manual mode" {
		t.Fatalf("manual ownership text = %q", err)
	}
}

func TestFanPolicyApplyClassifiesModeThreeOwnershipLossAndRestoresAuto(t *testing.T) {
	hardware := &fakeFanHardware{}
	controller := newFanPolicyControllerWithSettings(hardware, fanPolicySettings{
		Mode: fanModeConstant, ConstantRPM: 2200,
	})
	controller.lastRPM[0] = 2200

	_, _, err := controller.apply(SocMetrics{Fans: []FanInfo{{
		ID: 0, MinRPM: 1000, MaxRPM: 3000, Mode: 3, TargetRPM: 0,
	}}}, SystemInfo{})
	if !errors.Is(err, errFanManualOwnershipLost) {
		t.Fatalf("mode-3 apply error = %v", err)
	}
	if !reflect.DeepEqual(hardware.calls, []string{"reset"}) {
		t.Fatalf("mode-3 calls = %v, want automatic reset", hardware.calls)
	}
}

type fakeFanHardware struct {
	calls      []string
	failTarget bool
	failMode   bool
	failReset  bool
}

func (f *fakeFanHardware) SetTarget(fanID, rpm int) error {
	f.calls = append(f.calls, "target")
	if f.failTarget {
		return errors.New("target failed")
	}
	return nil
}

func (f *fakeFanHardware) SetMode(fanID, mode int) error {
	f.calls = append(f.calls, "mode")
	if f.failMode {
		return errors.New("mode failed")
	}
	return nil
}

func (f *fakeFanHardware) ResetToAuto() error {
	f.calls = append(f.calls, "reset")
	if f.failReset {
		return errors.New("reset failed")
	}
	return nil
}

func validPolicySample(mode, target int) SocMetrics {
	return SocMetrics{
		Fans:        []FanInfo{{ID: 0, MinRPM: 1000, MaxRPM: 3000, Mode: mode, TargetRPM: target}},
		TempSensors: []TempSensor{{Key: "Tp0", Name: "CPU P-Core", Value: 61.5}},
	}
}

func TestFanPolicyWritesTargetBeforeModeAndSuppressesNoOpWrites(t *testing.T) {
	hardware := &fakeFanHardware{}
	controller := newFanPolicyController(hardware)
	_, targets, err := controller.apply(validPolicySample(0, 1000), SystemInfo{})
	if err != nil {
		t.Fatal(err)
	}
	if targets[0] != 2000 {
		t.Fatalf("target = %d, want 2000", targets[0])
	}
	if !reflect.DeepEqual(hardware.calls, []string{"target", "mode", "target"}) {
		t.Fatalf("calls = %v, want target, mode, then confirmed target", hardware.calls)
	}

	_, _, err = controller.apply(validPolicySample(1, 2000), SystemInfo{})
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(hardware.calls, []string{"target", "mode", "target"}) {
		t.Fatalf("unchanged target caused extra writes: %v", hardware.calls)
	}
	if err := controller.Close(); err != nil {
		t.Fatal(err)
	}
	if err := controller.Close(); err != nil {
		t.Fatal(err)
	}
	if got := strings.Count(strings.Join(hardware.calls, ","), "reset"); got != 1 {
		t.Fatalf("reset count = %d, want 1", got)
	}
}

func TestFanPolicySetsAllTargetsBeforeAnyManualMode(t *testing.T) {
	hardware := &fakeFanHardware{}
	controller := newFanPolicyController(hardware)
	sample := SocMetrics{
		Fans: []FanInfo{
			{ID: 0, MinRPM: 1000, MaxRPM: 3000, Mode: 0, TargetRPM: 1000},
			{ID: 1, MinRPM: 1500, MaxRPM: 3500, Mode: 0, TargetRPM: 1500},
		},
		TempSensors: []TempSensor{{Key: "Tp0", Name: "CPU P-Core", Value: 61.5}},
	}
	if _, _, err := controller.apply(sample, SystemInfo{}); err != nil {
		t.Fatal(err)
	}
	want := []string{"target", "target", "mode", "mode", "target", "target"}
	if !reflect.DeepEqual(hardware.calls, want) {
		t.Fatalf("calls = %v, want %v", hardware.calls, want)
	}
}

func TestFanPolicyDeadbandKeepsLastWrittenTarget(t *testing.T) {
	hardware := &fakeFanHardware{}
	controller := newFanPolicyController(hardware)
	controller.lastRPM[0] = 2000

	// Each calculated target stays within 25 RPM of the actual 2000 RPM write.
	// The controller must not move its readback baseline when it skips a write.
	for _, temperature := range []float64{61.7, 61.9, 62.0} {
		sample := SocMetrics{
			Fans:        []FanInfo{{ID: 0, MinRPM: 1000, MaxRPM: 3000, Mode: 1, TargetRPM: 2000}},
			TempSensors: []TempSensor{{Key: "Tp0", Name: "CPU P-Core", Value: temperature}},
		}
		if _, _, err := controller.apply(sample, SystemInfo{}); err != nil {
			t.Fatalf("temperature %.1f: %v", temperature, err)
		}
	}
	if controller.lastRPM[0] != 2000 {
		t.Fatalf("last written target = %d, want 2000", controller.lastRPM[0])
	}
	if len(hardware.calls) != 0 {
		t.Fatalf("unexpected calls: %v", hardware.calls)
	}
}

func TestFanPolicyFailureResetsOnce(t *testing.T) {
	for _, test := range []struct {
		name     string
		hardware *fakeFanHardware
		sample   SocMetrics
	}{
		{name: "target write", hardware: &fakeFanHardware{failTarget: true}, sample: validPolicySample(0, 1000)},
		{name: "mode write", hardware: &fakeFanHardware{failMode: true}, sample: validPolicySample(0, 1000)},
		{name: "readback", hardware: &fakeFanHardware{}, sample: validPolicySample(0, 1000)},
	} {
		t.Run(test.name, func(t *testing.T) {
			controller := newFanPolicyController(test.hardware)
			if test.name == "readback" {
				controller.lastRPM[0] = 2000
			}
			if _, _, err := controller.apply(test.sample, SystemInfo{}); err == nil {
				t.Fatal("apply() returned no error")
			}
			_ = controller.Close()
			if got := strings.Count(strings.Join(test.hardware.calls, ","), "reset"); got != 1 {
				t.Fatalf("reset count = %d, want 1; calls: %v", got, test.hardware.calls)
			}
		})
	}
}

func TestFanPolicyFailsClosedWhenManagedFanDisappears(t *testing.T) {
	hardware := &fakeFanHardware{}
	controller := newFanPolicyController(hardware)
	controller.lastRPM[0] = 2000
	sample := SocMetrics{
		Fans:        []FanInfo{{ID: 1, MinRPM: 1000, MaxRPM: 3000, Mode: 0, TargetRPM: 1000}},
		TempSensors: []TempSensor{{Key: "Tp0", Name: "CPU P-Core", Value: 50}},
	}
	if _, _, err := controller.apply(sample, SystemInfo{}); err == nil {
		t.Fatal("apply() returned no error")
	}
	if !reflect.DeepEqual(hardware.calls, []string{"reset"}) {
		t.Fatalf("calls = %v, want reset", hardware.calls)
	}
}

func TestFanPolicyReportsWriteAndResetFailures(t *testing.T) {
	hardware := &fakeFanHardware{failTarget: true, failReset: true}
	controller := newFanPolicyController(hardware)
	_, _, err := controller.apply(validPolicySample(0, 1000), SystemInfo{})
	if err == nil {
		t.Fatal("apply() returned no error")
	}
	for _, message := range []string{"target failed", "could not restore automatic fan control", "reset failed"} {
		if !strings.Contains(err.Error(), message) {
			t.Errorf("error %q does not contain %q", err, message)
		}
	}
}

func TestValidateFans(t *testing.T) {
	tests := [][]FanInfo{
		nil,
		{{ID: -1, MinRPM: 1000, MaxRPM: 2000}},
		{{ID: 0, MinRPM: 0, MaxRPM: 2000}},
		{{ID: 0, MinRPM: 2000, MaxRPM: 1000}},
		{{ID: 0, MinRPM: 1000, MaxRPM: 2000}, {ID: 0, MinRPM: 1000, MaxRPM: 2000}},
	}
	for i, fans := range tests {
		if err := validateFans(fans); err == nil {
			t.Errorf("case %d returned no error", i)
		}
	}
}

func TestAcquireFanControlLockIsExclusive(t *testing.T) {
	path := filepath.Join(t.TempDir(), "fan-policy.lock")
	first, err := acquireFanControlLock(path)
	if err != nil {
		t.Fatal(err)
	}
	defer first.Close()

	if second, err := acquireFanControlLock(path); err == nil {
		second.Close()
		t.Fatal("second lock succeeded")
	}
	if err := first.Close(); err != nil {
		t.Fatal(err)
	}
	third, err := acquireFanControlLock(path)
	if err != nil {
		t.Fatalf("lock after release failed: %v", err)
	}
	third.Close()
}

func TestPrepareFanResetRejectsActiveController(t *testing.T) {
	path := filepath.Join(t.TempDir(), "fan-control.lock")
	active, err := acquireFanControlLock(path)
	if err != nil {
		t.Fatal(err)
	}
	defer active.Close()

	if resetLock, err := prepareFanReset(path, true); err == nil {
		resetLock.Close()
		t.Fatal("fan reset acquired an active controller lock")
	}
}

func TestPrepareFanResetRequiresRootBeforeLock(t *testing.T) {
	missingDirPath := filepath.Join(t.TempDir(), "missing", "fan-control.lock")
	if _, err := prepareFanReset(missingDirPath, false); err == nil || !strings.Contains(err.Error(), "requires root") {
		t.Fatalf("prepareFanReset() error = %v, want root error", err)
	}
}

func TestFanResetClearsSavedPolicyBeforeHardwareReset(t *testing.T) {
	store := &fakeFanPolicyStore{
		hasState: true,
		settings: fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2500},
	}
	resetCalled := false
	if err := resetFansAndClearPolicy(store, func() error {
		if store.hasState {
			t.Fatal("hardware reset ran before saved policy was cleared")
		}
		resetCalled = true
		return nil
	}); err != nil {
		t.Fatal(err)
	}
	if !resetCalled || store.hasState {
		t.Fatalf("resetCalled = %t, saved state = %+v", resetCalled, store)
	}

	store.hasState = true
	store.saveErr = errors.New("read-only filesystem")
	resetCalled = false
	if err := resetFansAndClearPolicy(store, func() error {
		resetCalled = true
		return nil
	}); err == nil || resetCalled {
		t.Fatalf("persistence failure = %v, resetCalled = %t", err, resetCalled)
	}
}

func TestFanModeHasLegacyConflict(t *testing.T) {
	tests := []struct {
		name string
		args []string
		want bool
	}{
		{name: "no fan mode", args: []string{"--dump-ioreport"}, want: false},
		{name: "policy only", args: []string{"--fan-policy"}, want: false},
		{name: "policy and dump", args: []string{"--fan-policy", "--dump-ioreport"}, want: true},
		{name: "dry run and short dump", args: []string{"-d", "--fan-policy-dry-run"}, want: true},
		{name: "reset and test", args: []string{"--fan-reset", "--test", "value"}, want: true},
		{name: "equals reset and test", args: []string{"--fan-reset=true", "--test", "value"}, want: true},
		{name: "single dash policy and testapp", args: []string{"-fan-policy=true", "-a"}, want: true},
		{name: "equals false is inactive", args: []string{"--fan-policy-dry-run=false", "-d"}, want: false},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if got := fanModeHasLegacyConflict(test.args); got != test.want {
				t.Fatalf("fanModeHasLegacyConflict() = %t, want %t", got, test.want)
			}
		})
	}
}
