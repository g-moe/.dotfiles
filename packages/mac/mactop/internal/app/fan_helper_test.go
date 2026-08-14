package app

import (
	"context"
	"encoding/json"
	"errors"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

type fakeFanHelperInstaller struct {
	owner      uint32
	files      map[string][]byte
	launches   [][]string
	bootstraps int
}

type fakeFanPolicyStore struct {
	settings fanPolicySettings
	hasState bool
	loadErr  error
	saveErr  error
	saveFunc func(fanPolicySettings) error
	saves    []fanPolicySettings
}

type recordedFanHelperDiagnostics struct {
	events chan fanHelperDiagnosticEvent
}

func (d *recordedFanHelperDiagnostics) Log(event fanHelperDiagnosticEvent) error {
	d.events <- event
	return nil
}

func (s *fakeFanPolicyStore) Load() (fanPolicySettings, error) {
	if s.loadErr != nil {
		return fanPolicySettings{}, s.loadErr
	}
	if !s.hasState {
		return fanPolicySettings{}, os.ErrNotExist
	}
	return s.settings, nil
}

func (s *fakeFanPolicyStore) Save(settings fanPolicySettings) error {
	if s.saveFunc != nil {
		if err := s.saveFunc(settings); err != nil {
			return err
		}
	}
	if s.saveErr != nil {
		return s.saveErr
	}
	s.saves = append(s.saves, settings)
	s.settings = settings
	s.hasState = settings.Mode != fanModeDefault
	return nil
}

func newTestFanHelperService() (*fanHelperService, *fakeFanPolicyStore) {
	store := &fakeFanPolicyStore{}
	return newFanHelperService(store), store
}

func configureFanHelperDiagnosticRecording(service *fanHelperService) *recordedFanHelperDiagnostics {
	diagnostics := &recordedFanHelperDiagnostics{events: make(chan fanHelperDiagnosticEvent, 32)}
	service.diagnostics = diagnostics
	service.readForceTest = func() (int, error) { return 1, nil }
	return diagnostics
}

func (f *fakeFanHelperInstaller) Executable() (string, error) { return "/tmp/mactop-staged", nil }
func (f *fakeFanHelperInstaller) ReadFile(string) ([]byte, os.FileMode, uint32, error) {
	return []byte("mactop binary"), 0755, f.owner, nil
}
func (f *fakeFanHelperInstaller) InstallFile(path string, contents []byte, _ os.FileMode) error {
	if f.files == nil {
		f.files = make(map[string][]byte)
	}
	f.files[path] = append([]byte(nil), contents...)
	return nil
}
func (f *fakeFanHelperInstaller) Launchctl(arguments ...string) error {
	f.launches = append(f.launches, append([]string(nil), arguments...))
	if len(arguments) > 0 && arguments[0] == "bootstrap" {
		f.bootstraps++
		if f.bootstraps < 3 {
			return errors.New("launchd still retiring old service")
		}
	}
	return nil
}
func (*fakeFanHelperInstaller) Sleep(time.Duration) {}

func TestFanHelperRejectsUnknownProtocolAndCommands(t *testing.T) {
	service, _ := newTestFanHelperService()

	wrongProtocol := service.handle(fanHelperRequest{Protocol: fanHelperProtocolVersion + 1, Command: "status"})
	if wrongProtocol.State != "error" || !strings.Contains(wrongProtocol.Message, "protocol") {
		t.Fatalf("wrong protocol response = %+v", wrongProtocol)
	}

	unknown := service.handle(fanHelperRequest{Protocol: fanHelperProtocolVersion, Command: "set-rpm"})
	if unknown.State != "error" || !strings.Contains(unknown.Message, "unsupported") {
		t.Fatalf("unknown command response = %+v", unknown)
	}
	legacy := service.handle(fanHelperRequest{Protocol: fanHelperProtocolVersion, Command: "enable"})
	if legacy.State != "error" || !strings.Contains(legacy.Message, "unsupported") {
		t.Fatalf("legacy command response = %+v", legacy)
	}
}

func TestFanHelperInstallerRequiresRootOwnedStagingAndRetriesBootstrap(t *testing.T) {
	unprivileged := &fakeFanHelperInstaller{owner: 501}
	if err := installFanHelperWith(unprivileged, true); err == nil || !strings.Contains(err.Error(), "root-owned") {
		t.Fatalf("unprivileged staging error = %v", err)
	}

	installer := &fakeFanHelperInstaller{owner: 0}
	if err := installFanHelperWith(installer, true); err != nil {
		t.Fatal(err)
	}
	if installer.bootstraps != 3 {
		t.Fatalf("bootstrap attempts = %d, want 3", installer.bootstraps)
	}
	if string(installer.files[fanHelperBinaryPath]) != "mactop binary" {
		t.Fatalf("installed helper = %q", installer.files[fanHelperBinaryPath])
	}
	if !strings.Contains(string(installer.files[fanHelperPlistPath]), fanHelperBinaryPath) {
		t.Fatal("installed plist does not name fixed helper path")
	}
	if !strings.Contains(string(installer.files[fanHelperPlistPath]), "<key>ExitTimeOut</key><integer>30</integer>") {
		t.Fatal("installed plist does not allow policy cleanup to finish")
	}
	if err := installFanHelperWith(installer, false); err == nil || !strings.Contains(err.Error(), "requires root") {
		t.Fatalf("non-root install error = %v", err)
	}
}

func TestFileFanPolicyStoreRoundTripsAndClearsSettings(t *testing.T) {
	path := filepath.Join(t.TempDir(), "state", "fan-control.json")
	store := fileFanPolicyStore{path: path, ownerUID: os.Getuid(), ownerGID: os.Getgid()}
	want := fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2500}
	if err := store.Save(want); err != nil {
		t.Fatal(err)
	}
	info, err := os.Lstat(path)
	if err != nil {
		t.Fatal(err)
	}
	if !info.Mode().IsRegular() || info.Mode().Perm() != 0600 {
		t.Fatalf("state mode = %v, want regular 0600", info.Mode())
	}
	got, err := store.Load()
	if err != nil {
		t.Fatal(err)
	}
	if got != want {
		t.Fatalf("loaded settings = %+v, want %+v", got, want)
	}
	if err := store.Save(defaultFanPolicySettings()); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Lstat(path); !os.IsNotExist(err) {
		t.Fatalf("default mode did not remove state file: %v", err)
	}
}

func TestFileFanPolicyStoreRejectsUnsafeOrMalformedState(t *testing.T) {
	path := filepath.Join(t.TempDir(), "fan-control.json")
	store := fileFanPolicyStore{path: path, ownerUID: os.Getuid(), ownerGID: os.Getgid()}
	if err := os.WriteFile(path, []byte(`{"version":1,"mode":"constant","constant_rpm":2500}`), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(path, 0644); err != nil {
		t.Fatal(err)
	}
	if _, err := store.Load(); err == nil || !strings.Contains(err.Error(), "0600") {
		t.Fatalf("unsafe state error = %v", err)
	}
	for _, contents := range []string{
		`{"version":1,"mode":"constant","constant_rpm":2500,"path":"/tmp/x"}`,
		`{"version":99,"mode":"constant","constant_rpm":2500}`,
		`{"version":1,"mode":"curve","start_celsius":40,"maximum_celsius":42}`,
		`not-json`,
	} {
		if err := os.WriteFile(path, []byte(contents), 0600); err != nil {
			t.Fatal(err)
		}
		if _, err := store.Load(); err == nil {
			t.Errorf("unsafe saved state %q was accepted", contents)
		}
	}
}

func TestFanHelperRestoresSavedConstantModeAfterStartupReset(t *testing.T) {
	store := &fakeFanPolicyStore{
		hasState: true,
		settings: fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2500},
	}
	service := newFanHelperService(store)
	service.readRangeFunc = func() (int, int, error) { return 1700, 4499, nil }
	events := make(chan string, 3)
	service.resetFunc = func() error {
		events <- "automatic"
		return nil
	}
	service.runPolicyFunc = func(ctx context.Context, settings fanPolicySettings) error {
		events <- "start-" + settings.Mode
		service.setStatus("active", 0, map[int]int{0: settings.ConstantRPM}, "")
		<-ctx.Done()
		service.setStatus("off", 0, nil, "")
		return nil
	}
	if err := prepareFanHelperService(service); err != nil {
		t.Fatal(err)
	}
	waitForHelperState(t, service, "active")
	for _, want := range []string{"automatic", "start-constant"} {
		if got := <-events; got != want {
			t.Fatalf("startup event = %q, want %q", got, want)
		}
	}
	status := service.status()
	if status.Mode != fanModeConstant || status.ConstantRPM != 2500 || status.Targets[0] != 2500 {
		t.Fatalf("restored status = %+v", status)
	}
	if err := service.shutdown(); err != nil {
		t.Fatal(err)
	}
	if !store.hasState || store.settings.ConstantRPM != 2500 {
		t.Fatalf("shutdown cleared desired settings: %+v", store)
	}
}

func TestFanHelperStartupRejectsInvalidSavedSettingsWithoutExiting(t *testing.T) {
	store := &fakeFanPolicyStore{loadErr: errors.New("invalid saved data")}
	service := newFanHelperService(store)
	service.resetFunc = func() error { return nil }
	service.readRangeFunc = func() (int, int, error) { return 1700, 4500, nil }
	var starts atomic.Int32
	service.runPolicyFunc = func(context.Context, fanPolicySettings) error {
		starts.Add(1)
		return nil
	}
	if err := prepareFanHelperService(service); err != nil {
		t.Fatal(err)
	}
	status := service.status()
	if status.State != "error" || status.Mode != fanModeDefault || !strings.Contains(status.Message, "saved") || starts.Load() != 0 {
		t.Fatalf("invalid startup status = %+v, starts = %d", status, starts.Load())
	}
}

func TestFanHelperStartupIgnoresSavedDefaultMode(t *testing.T) {
	store := &fakeFanPolicyStore{hasState: true, settings: defaultFanPolicySettings()}
	service := newFanHelperService(store)
	service.resetFunc = func() error { return nil }
	service.readRangeFunc = func() (int, int, error) { return 1700, 4500, nil }
	var starts atomic.Int32
	service.runPolicyFunc = func(context.Context, fanPolicySettings) error {
		starts.Add(1)
		return nil
	}
	if err := prepareFanHelperService(service); err != nil {
		t.Fatal(err)
	}
	if status := service.status(); status.State != "off" || status.Mode != fanModeDefault || starts.Load() != 0 {
		t.Fatalf("saved default status = %+v, starts = %d", status, starts.Load())
	}
}

func TestFanHelperStartupRejectsSavedConstantOutsideCurrentRange(t *testing.T) {
	store := &fakeFanPolicyStore{
		hasState: true,
		settings: fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 4500},
	}
	service := newFanHelperService(store)
	service.resetFunc = func() error { return nil }
	service.readRangeFunc = func() (int, int, error) { return 1700, 4000, nil }
	var starts atomic.Int32
	service.runPolicyFunc = func(context.Context, fanPolicySettings) error {
		starts.Add(1)
		return nil
	}
	if err := prepareFanHelperService(service); err != nil {
		t.Fatal(err)
	}
	status := service.status()
	if status.State != "error" || status.Mode != fanModeDefault ||
		!strings.Contains(status.Message, "1700-4000") || starts.Load() != 0 {
		t.Fatalf("out-of-range startup status = %+v, starts = %d", status, starts.Load())
	}
}

func TestFanHelperRejectsArbitraryFields(t *testing.T) {
	for _, input := range []string{
		`{"protocol":2,"command":"configure","rpm":4000}`,
		`{"protocol":2,"command":"configure","key":"F0Tg"}`,
		`{"protocol":2,"command":"configure","path":"/tmp/program"}`,
		`{"protocol":2,"command":"configure","fan_id":0}`,
	} {
		if _, err := decodeFanHelperRequest([]byte(input)); err == nil {
			t.Fatalf("decodeFanHelperRequest(%s) succeeded", input)
		}
	}
}

func TestFanHelperConfiguresAllModesAndReportsSourceOfTruth(t *testing.T) {
	service, store := newTestFanHelperService()
	service.setCommonRPMRange(1000, 5000, nil)
	started := make(chan fanPolicySettings, 2)
	service.runPolicyFunc = func(ctx context.Context, settings fanPolicySettings) error {
		started <- settings
		service.setStatus("active", 0, map[int]int{0: settings.ConstantRPM}, "")
		<-ctx.Done()
		service.setStatus("off", 0, nil, "")
		return nil
	}
	service.resetFunc = func() error { return nil }

	constant := fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeConstant, ConstantRPM: 2200,
	}
	service.handle(constant)
	waitForHelperState(t, service, "active")
	if got := <-started; got.Mode != fanModeConstant || got.ConstantRPM != 2200 {
		t.Fatalf("constant settings = %+v", got)
	}
	if status := service.status(); status.Mode != fanModeConstant || status.ConstantRPM != 2200 {
		t.Fatalf("constant status = %+v", status)
	}
	if !store.hasState || store.settings != (fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200}) {
		t.Fatalf("saved constant settings = %+v", store)
	}

	curve := fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeCurve,
		StartCelsius: 45, MaximumCelsius: 80,
	}
	service.handle(curve)
	waitForHelperState(t, service, "active")
	if got := <-started; got.Mode != fanModeCurve || got.StartCelsius != 45 || got.MaximumCelsius != 80 {
		t.Fatalf("curve settings = %+v", got)
	}
	if status := service.status(); status.Mode != fanModeCurve || status.StartCelsius != 45 || status.MaximumCelsius != 80 {
		t.Fatalf("curve status = %+v", status)
	}
	if !store.hasState || store.settings != (fanPolicySettings{Mode: fanModeCurve, StartCelsius: 45, MaximumCelsius: 80}) {
		t.Fatalf("saved curve settings = %+v", store)
	}

	status := service.handle(fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeDefault,
	})
	if status.State != "off" || status.Mode != fanModeDefault {
		t.Fatalf("default status = %+v", status)
	}
	if store.hasState {
		t.Fatalf("Apple Default kept saved manual settings: %+v", store)
	}
}

func TestFanHelperDoesNotStartUnpersistedSettings(t *testing.T) {
	service, store := newTestFanHelperService()
	service.setCommonRPMRange(1700, 4500, nil)
	store.saveErr = errors.New("disk full")
	var starts atomic.Int32
	service.runPolicyFunc = func(context.Context, fanPolicySettings) error {
		starts.Add(1)
		return nil
	}
	status := service.handle(fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure",
		Mode: fanModeConstant, ConstantRPM: 2500,
	})
	if status.State != "error" || status.Mode != fanModeDefault ||
		!strings.Contains(status.Message, "save") || starts.Load() != 0 {
		t.Fatalf("save failure status = %+v, starts = %d", status, starts.Load())
	}
}

func TestFanHelperPersistenceFailureKeepsActivePolicyAndDurableTruth(t *testing.T) {
	for _, next := range []fanPolicySettings{
		{Mode: fanModeConstant, ConstantRPM: 3000},
		defaultFanPolicySettings(),
	} {
		t.Run(next.Mode, func(t *testing.T) {
			service, store := newTestFanHelperService()
			service.setCommonRPMRange(1700, 4500, nil)
			service.resetFunc = func() error { return nil }
			service.runPolicyFunc = func(ctx context.Context, settings fanPolicySettings) error {
				service.setStatus("active", 0, map[int]int{0: settings.ConstantRPM}, "")
				<-ctx.Done()
				service.setStatus("off", 0, nil, "")
				return nil
			}
			original := fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2500}
			service.configure(original)
			waitForHelperState(t, service, "active")
			store.saveErr = errors.New("read-only filesystem")

			status := service.configure(next)
			if status.State != "active" || status.Mode != fanModeConstant ||
				status.ConstantRPM != 2500 || !strings.Contains(status.Message, "save") {
				t.Fatalf("failed transition status = %+v", status)
			}
			if store.settings != original || !store.hasState {
				t.Fatalf("failed transition changed durable policy: %+v", store)
			}

			store.saveErr = nil
			if err := service.shutdown(); err != nil {
				t.Fatal(err)
			}
			restarted := newFanHelperService(store)
			restarted.resetFunc = func() error { return nil }
			restarted.readRangeFunc = func() (int, int, error) { return 1700, 4500, nil }
			restarted.runPolicyFunc = func(ctx context.Context, settings fanPolicySettings) error {
				restarted.setStatus("active", 0, map[int]int{0: settings.ConstantRPM}, "")
				<-ctx.Done()
				return nil
			}
			if err := prepareFanHelperService(restarted); err != nil {
				t.Fatal(err)
			}
			waitForHelperState(t, restarted, "active")
			if restored := restarted.status(); restored.Mode != fanModeConstant || restored.ConstantRPM != 2500 {
				t.Fatalf("restart did not restore durable truth: %+v", restored)
			}
			if err := restarted.shutdown(); err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestFanHelperCleanupFailureLeavesRebootAtAppleDefault(t *testing.T) {
	for _, next := range []fanPolicySettings{
		{Mode: fanModeConstant, ConstantRPM: 3000},
		defaultFanPolicySettings(),
	} {
		t.Run(next.Mode, func(t *testing.T) {
			service, store := newTestFanHelperService()
			service.setCommonRPMRange(1700, 4500, nil)
			service.resetFunc = func() error { return nil }
			service.runPolicyFunc = func(ctx context.Context, settings fanPolicySettings) error {
				service.setStatus("active", 0, map[int]int{0: settings.ConstantRPM}, "")
				<-ctx.Done()
				return errors.New("automatic mode readback failed")
			}
			service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2500})
			waitForHelperState(t, service, "active")

			status := service.configure(next)
			if status.State != "error" || status.Mode != fanModeConstant ||
				!strings.Contains(status.Message, "readback") || store.hasState {
				t.Fatalf("cleanup failure status = %+v, store = %+v", status, store)
			}

			restarted := newFanHelperService(store)
			restarted.resetFunc = func() error { return nil }
			restarted.readRangeFunc = func() (int, int, error) { return 1700, 4500, nil }
			if err := prepareFanHelperService(restarted); err != nil {
				t.Fatal(err)
			}
			if restored := restarted.status(); restored.State != "off" || restored.Mode != fanModeDefault {
				t.Fatalf("cleanup failure reboot state = %+v", restored)
			}
		})
	}
}

func TestFanHelperNewPolicySaveFailureFallsBackToDurableDefault(t *testing.T) {
	service, store := newTestFanHelperService()
	service.setCommonRPMRange(1700, 4500, nil)
	service.resetFunc = func() error { return nil }
	service.runPolicyFunc = func(ctx context.Context, settings fanPolicySettings) error {
		service.setStatus("active", 0, map[int]int{0: settings.ConstantRPM}, "")
		<-ctx.Done()
		service.setStatus("off", 0, nil, "")
		return nil
	}
	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2500})
	waitForHelperState(t, service, "active")
	store.saveFunc = func(settings fanPolicySettings) error {
		if settings.Mode == fanModeConstant && settings.ConstantRPM == 3000 {
			return errors.New("disk full")
		}
		return nil
	}

	status := service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 3000})
	if status.State != "error" || status.Mode != fanModeDefault ||
		!strings.Contains(status.Message, "save") || store.hasState {
		t.Fatalf("new policy save failure = %+v, store = %+v", status, store)
	}

	restarted := newFanHelperService(store)
	restarted.resetFunc = func() error { return nil }
	restarted.readRangeFunc = func() (int, int, error) { return 1700, 4500, nil }
	if err := prepareFanHelperService(restarted); err != nil {
		t.Fatal(err)
	}
	if restored := restarted.status(); restored.State != "off" || restored.Mode != fanModeDefault {
		t.Fatalf("save failure reboot state = %+v", restored)
	}
}

func TestFanHelperRejectsInvalidConfigurations(t *testing.T) {
	service, _ := newTestFanHelperService()
	for _, request := range []fanHelperRequest{
		{Protocol: fanHelperProtocolVersion, Command: "configure", Mode: "manual"},
		{Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeConstant},
		{Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeConstant, ConstantRPM: 2000, StartCelsius: 38},
		{Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeCurve, ConstantRPM: 2000, StartCelsius: 38, MaximumCelsius: 85},
		{Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeCurve, StartCelsius: 38.5, MaximumCelsius: 85},
		{Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeCurve, StartCelsius: 50, MaximumCelsius: 53},
	} {
		if status := service.handle(request); status.State != "off" || status.Message == "" || status.Mode != fanModeDefault {
			t.Errorf("request %+v returned %+v", request, status)
		}
	}
}

func TestFanHelperInvalidConfigureKeepsActiveSourceOfTruth(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.setCommonRPMRange(1700, 4500, nil)
	service.resetFunc = func() error { return nil }
	service.runPolicyFunc = func(ctx context.Context, settings fanPolicySettings) error {
		service.setStatus("active", 0, map[int]int{0: settings.ConstantRPM}, "")
		<-ctx.Done()
		service.setStatus("off", 0, nil, "")
		return nil
	}
	service.handle(fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeConstant, ConstantRPM: 2200,
	})
	waitForHelperState(t, service, "active")
	status := service.handle(fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeConstant, ConstantRPM: 1600,
	})
	if status.State != "active" || status.Mode != fanModeConstant || status.ConstantRPM != 2200 || status.Message == "" {
		t.Fatalf("invalid configure status = %+v", status)
	}
	if polled := service.status(); polled.Message != status.Message {
		t.Fatalf("poll lost configure error: got %q, want %q", polled.Message, status.Message)
	}
	status = service.handle(fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeConstant, ConstantRPM: 2200,
	})
	if status.Message != "" {
		t.Fatalf("successful configure kept old error %q", status.Message)
	}
	service.reset()
}

func TestFanHelperReportsCommonConstantRPMRange(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.updateCommonRPMRange([]FanInfo{
		{ID: 0, MinRPM: 1200, MaxRPM: 5000},
		{ID: 1, MinRPM: 1500, MaxRPM: 4500},
	})
	status := service.status()
	if status.MinimumRPM != 1500 || status.MaximumRPM != 4500 || status.RPMRangeState != "available" {
		t.Fatalf("range = %d-%d, want 1500-4500", status.MinimumRPM, status.MaximumRPM)
	}

	service.updateCommonRPMRange([]FanInfo{
		{ID: 0, MinRPM: 1000, MaxRPM: 1800},
		{ID: 1, MinRPM: 2000, MaxRPM: 3000},
	})
	status = service.status()
	if status.MinimumRPM != 0 || status.MaximumRPM != 0 || status.RPMRangeState != "unavailable" {
		t.Fatalf("range without intersection = %d-%d, want unavailable", status.MinimumRPM, status.MaximumRPM)
	}
}

func TestFanHelperChangesManualModesOnlyAfterPriorOwnerStops(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.setCommonRPMRange(1000, 5000, nil)
	service.resetFunc = func() error { return nil }
	events := make(chan string, 8)
	service.runPolicyFunc = func(ctx context.Context, settings fanPolicySettings) error {
		events <- "start-" + settings.Mode
		service.setStatus("active", 0, nil, "")
		<-ctx.Done()
		events <- "auto-" + settings.Mode
		service.setStatus("off", 0, nil, "")
		return nil
	}
	service.handle(fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeConstant, ConstantRPM: 2200,
	})
	waitForHelperState(t, service, "active")
	service.handle(fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeCurve,
		StartCelsius: 38, MaximumCelsius: 85,
	})
	waitForHelperState(t, service, "active")
	want := []string{"start-constant", "auto-constant", "start-curve"}
	for _, expected := range want {
		if got := <-events; got != expected {
			t.Fatalf("event = %q, want %q", got, expected)
		}
	}
	service.reset()
}

func TestFanHelperConfigureAndResetAreIdempotent(t *testing.T) {
	service, _ := newTestFanHelperService()
	var resets atomic.Int32
	service.resetFunc = func() error {
		resets.Add(1)
		return nil
	}
	var starts atomic.Int32
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		starts.Add(1)
		service.setStatus("active", 42, map[int]int{0: 1938}, "")
		<-ctx.Done()
		service.setStatus("off", 0, nil, "")
		return nil
	}

	request := fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeCurve,
		StartCelsius: 38, MaximumCelsius: 85,
	}
	service.handle(request)
	service.handle(request)
	waitForHelperState(t, service, "active")
	if starts.Load() != 1 {
		t.Fatalf("policy starts = %d, want 1", starts.Load())
	}

	if status := service.handle(fanHelperRequest{Protocol: fanHelperProtocolVersion, Command: "reset"}); status.State != "off" {
		t.Fatalf("reset status = %+v", status)
	}
	if resets.Load() != 0 {
		t.Fatalf("active reset repeated verified policy cleanup %d times", resets.Load())
	}
	if status := service.handle(fanHelperRequest{Protocol: fanHelperProtocolVersion, Command: "reset"}); status.State != "off" {
		t.Fatalf("second reset status = %+v", status)
	}
	if resets.Load() != 1 {
		t.Fatalf("inactive reset calls = %d, want 1", resets.Load())
	}
}

func TestFanHelperReportsPolicyCleanupFailure(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		service.setStatus("active", 40, map[int]int{0: 1800}, "")
		<-ctx.Done()
		return errors.New("automatic mode readback failed")
	}
	service.enable()
	waitForHelperState(t, service, "active")
	status := service.disable()
	if status.State != "error" || !strings.Contains(status.Message, "readback") {
		t.Fatalf("cleanup failure status = %+v", status)
	}
}

func TestFanHelperStartupRestoresAutomaticMode(t *testing.T) {
	service, _ := newTestFanHelperService()
	var resets atomic.Int32
	service.readRangeFunc = func() (int, int, error) { return 1500, 4500, nil }
	service.resetFunc = func() error {
		resets.Add(1)
		return nil
	}
	if err := prepareFanHelperService(service); err != nil {
		t.Fatal(err)
	}
	if resets.Load() != 1 || service.status().State != "off" ||
		service.status().MinimumRPM != 1500 || service.status().MaximumRPM != 4500 {
		t.Fatalf("resets = %d, status = %+v", resets.Load(), service.status())
	}

	service.resetFunc = func() error { return errors.New("mode readback failed") }
	if err := prepareFanHelperService(service); err == nil || !strings.Contains(err.Error(), "readback") {
		t.Fatalf("startup failure = %v", err)
	}
}

func TestFanHelperShutdownRetriesResetAfterPolicyError(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.setStatus("error", 0, nil, "earlier reset readback failed")
	var resets atomic.Int32
	service.resetFunc = func() error {
		resets.Add(1)
		return nil
	}
	if err := service.shutdown(); err != nil {
		t.Fatal(err)
	}
	if resets.Load() != 1 || service.status().State != "off" {
		t.Fatalf("resets = %d, status = %+v", resets.Load(), service.status())
	}

	service.resetFunc = func() error { return errors.New("still manual") }
	if err := service.shutdown(); err == nil || service.status().State != "error" {
		t.Fatalf("shutdown error = %v, status = %+v", err, service.status())
	}
}

func TestFanHelperCleanActiveShutdownDoesNotResetTwice(t *testing.T) {
	service, _ := newTestFanHelperService()
	var cleanups atomic.Int32
	var fallbackResets atomic.Int32
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		service.setStatus("active", 0, map[int]int{0: 2000}, "")
		<-ctx.Done()
		cleanups.Add(1)
		service.setStatus("off", 0, nil, "")
		return nil
	}
	service.resetFunc = func() error {
		fallbackResets.Add(1)
		return nil
	}
	service.enable()
	waitForHelperState(t, service, "active")
	if err := service.shutdown(); err != nil {
		t.Fatal(err)
	}
	if cleanups.Load() != 1 || fallbackResets.Load() != 0 {
		t.Fatalf("cleanups = %d, fallback resets = %d", cleanups.Load(), fallbackResets.Load())
	}
}

func TestFanHelperShutdownJoinsTimedOutPolicyBeforeFallbackReset(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.stopTimeout = 10 * time.Millisecond
	releasePolicy := make(chan struct{})
	policyDone := make(chan struct{})
	resetStarted := make(chan struct{})
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		service.setStatus("active", 0, map[int]int{0: 2500}, "")
		<-ctx.Done()
		<-releasePolicy
		close(policyDone)
		return errors.New("automatic mode readback failed")
	}
	service.resetFunc = func() error {
		select {
		case <-policyDone:
		default:
			t.Error("fallback reset raced the active policy writer")
		}
		close(resetStarted)
		return nil
	}
	service.enable()
	waitForHelperState(t, service, "active")

	shutdownDone := make(chan error, 1)
	go func() { shutdownDone <- service.shutdown() }()
	select {
	case <-resetStarted:
		t.Fatal("fallback reset started before the policy writer stopped")
	case <-time.After(30 * time.Millisecond):
	}
	close(releasePolicy)
	select {
	case err := <-shutdownDone:
		if err != nil {
			t.Fatal(err)
		}
	case <-time.After(time.Second):
		t.Fatal("shutdown did not finish after policy writer stopped")
	}
	if status := service.status(); status.State != "off" {
		t.Fatalf("shutdown status = %+v", status)
	}
}

func TestFanHelperShutdownSerializesCommandsAndRejectsLateConfigure(t *testing.T) {
	service, _ := newTestFanHelperService()
	resetStarted := make(chan struct{})
	releaseReset := make(chan struct{})
	service.resetFunc = func() error {
		close(resetStarted)
		<-releaseReset
		return nil
	}
	shutdownDone := make(chan error, 1)
	go func() { shutdownDone <- service.shutdown() }()
	<-resetStarted

	configureDone := make(chan fanHelperStatus, 1)
	go func() {
		configureDone <- service.handle(fanHelperRequest{
			Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeConstant, ConstantRPM: 2000,
		})
	}()
	select {
	case <-configureDone:
		t.Fatal("configure completed while shutdown held the command lock")
	case <-time.After(20 * time.Millisecond):
	}
	close(releaseReset)
	if err := <-shutdownDone; err != nil {
		t.Fatal(err)
	}
	status := <-configureDone
	if status.State != "error" || !strings.Contains(status.Message, "shutting down") {
		t.Fatalf("late enable status = %+v", status)
	}
}

func TestFanHelperShutdownRejectsQueuedReset(t *testing.T) {
	service, _ := newTestFanHelperService()
	resetStarted := make(chan struct{})
	releaseReset := make(chan struct{})
	var resetCalls atomic.Int32
	service.resetFunc = func() error {
		if resetCalls.Add(1) == 1 {
			close(resetStarted)
			<-releaseReset
		}
		return nil
	}
	shutdownDone := make(chan error, 1)
	go func() { shutdownDone <- service.shutdown() }()
	<-resetStarted

	resetDone := make(chan fanHelperStatus, 1)
	go func() {
		resetDone <- service.handle(fanHelperRequest{Protocol: fanHelperProtocolVersion, Command: "reset"})
	}()
	select {
	case <-resetDone:
		t.Fatal("reset completed while shutdown held the command lock")
	case <-time.After(20 * time.Millisecond):
	}
	close(releaseReset)
	if err := <-shutdownDone; err != nil {
		t.Fatal(err)
	}
	status := <-resetDone
	if status.State != "error" || !strings.Contains(status.Message, "shutting down") {
		t.Fatalf("queued reset status = %+v", status)
	}
	if resetCalls.Load() != 1 {
		t.Fatalf("reset calls = %d, want shutdown reset only", resetCalls.Load())
	}
}

func TestAuthorizedFanHelperInstallCommandVerifiesCopiedBytes(t *testing.T) {
	command := authorizedFanHelperInstallCommand("/tmp/mactop path", strings.Repeat("a", 64))
	for _, required := range []string{
		"mktemp /var/tmp/mactop-fan-helper-install.XXXXXX",
		"install -o root -g wheel -m 0755 '/tmp/mactop path'",
		"shasum -a 256 \"$staged\"",
		strings.Repeat("a", 64),
		"\"$staged\" --install-fan-helper",
	} {
		if !strings.Contains(command, required) {
			t.Fatalf("authorization command is missing %q: %s", required, command)
		}
	}
}

func TestFanHelperClientUsesTypedProtocol(t *testing.T) {
	directory, err := os.MkdirTemp("/tmp", "mactop-helper-test-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(directory) })
	path := filepath.Join(directory, "helper.sock")
	listener, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()

	requests := make(chan fanHelperRequest, 1)
	go func() {
		connection, acceptErr := listener.Accept()
		if acceptErr != nil {
			return
		}
		defer connection.Close()
		var request fanHelperRequest
		_ = json.NewDecoder(connection).Decode(&request)
		requests <- request
		_ = json.NewEncoder(connection).Encode(fanHelperStatus{
			Protocol: fanHelperProtocolVersion,
			Version:  fanHelperBuildVersion(),
			State:    "active",
			Targets:  map[int]int{0: 2000},
		})
	}()

	status, err := requestFanHelperAt(path, "status")
	if err != nil {
		t.Fatal(err)
	}
	request := <-requests
	if request.Protocol != fanHelperProtocolVersion || request.Command != "status" {
		t.Fatalf("request = %+v", request)
	}
	if status.State != "active" || status.Targets[0] != 2000 {
		t.Fatalf("status = %+v", status)
	}
}

func TestFanHelperClientRejectsStaleBuild(t *testing.T) {
	path, closeServer := startFanHelperTestServer(t, fanHelperStatus{
		Protocol: fanHelperProtocolVersion,
		Version:  "old",
		State:    "off",
	})
	defer closeServer()
	if _, err := requestFanHelperAt(path, "status"); !errors.Is(err, errFanHelperVersionMismatch) {
		t.Fatalf("version error = %v", err)
	}
}

func TestFanHelperClientHonorsRequestTimeout(t *testing.T) {
	directory, err := os.MkdirTemp("/tmp", "mactop-timeout-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(directory) })
	path := filepath.Join(directory, "slow-helper.sock")
	listener, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	go func() {
		connection, acceptErr := listener.Accept()
		if acceptErr != nil {
			return
		}
		defer connection.Close()
		time.Sleep(200 * time.Millisecond)
	}()
	started := time.Now()
	_, err = requestFanHelperRequestAtWithTimeout(
		path, fanHelperRequest{Command: "status"}, 25*time.Millisecond,
	)
	if err == nil {
		t.Fatal("slow helper request did not time out")
	}
	if elapsed := time.Since(started); elapsed > 150*time.Millisecond {
		t.Fatalf("request timeout took %v, want less than 150ms", elapsed)
	}
}

func TestFanHelperReadinessHonorsTotalDeadline(t *testing.T) {
	directory, err := os.MkdirTemp("/tmp", "mactop-readiness-")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = os.RemoveAll(directory) })
	path := filepath.Join(directory, "helper.sock")
	listener, err := net.Listen("unix", path)
	if err != nil {
		t.Fatal(err)
	}
	defer listener.Close()
	go func() {
		connection, acceptErr := listener.Accept()
		if acceptErr != nil {
			return
		}
		defer connection.Close()
		time.Sleep(200 * time.Millisecond)
	}()
	started := time.Now()
	_, err = waitForFanHelperReadinessAt(path, 50*time.Millisecond)
	if err == nil {
		t.Fatal("readiness check accepted an unresponsive helper")
	}
	if elapsed := time.Since(started); elapsed > 150*time.Millisecond {
		t.Fatalf("readiness deadline took %v, want less than 150ms", elapsed)
	}
}

func TestFanHelperBuildVersionMatchesFullDigest(t *testing.T) {
	digest := fanHelperBuildSHA256()
	version := fanHelperBuildVersion()
	if len(digest) != 64 || len(version) != 16 || !strings.HasPrefix(digest, version) {
		t.Fatalf("build identity version=%q digest=%q", version, digest)
	}
}

func startFanHelperTestServer(t *testing.T, response fanHelperStatus) (string, func()) {
	t.Helper()
	directory, err := os.MkdirTemp("/tmp", "mactop-helper-version-test-")
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(directory, "helper.sock")
	listener, err := net.Listen("unix", path)
	if err != nil {
		_ = os.RemoveAll(directory)
		t.Fatal(err)
	}
	go func() {
		connection, acceptErr := listener.Accept()
		if acceptErr != nil {
			return
		}
		defer connection.Close()
		var request fanHelperRequest
		_ = json.NewDecoder(connection).Decode(&request)
		_ = json.NewEncoder(connection).Encode(response)
	}()
	return path, func() {
		_ = listener.Close()
		_ = os.RemoveAll(directory)
	}
}

func TestFanSettingsDisplayUsesHelperAsSourceOfTruth(t *testing.T) {
	state, detail, message := fanSettingsDisplay(fanHelperStatus{
		State:       "active",
		Temperature: 45.25,
		Targets:     map[int]int{1: 2200, 0: 2100},
	}, nil)
	if state != fanSettingsActive || detail != "CPU P-core 45.2 °C • Fan 0: 2100 RPM • Fan 1: 2200 RPM" || message != "" {
		t.Fatalf("display = %d, %q, %q", state, detail, message)
	}

	state, _, message = fanSettingsDisplay(fanHelperStatus{}, &os.PathError{Op: "dial", Path: fanHelperSocketPath, Err: os.ErrNotExist})
	if state != fanSettingsUnavailable || !strings.Contains(message, "not installed") {
		t.Fatalf("unavailable display = %d, %q", state, message)
	}
}

func TestPrepareFanHelperSocketRefusesExistingFiles(t *testing.T) {
	path := filepath.Join(t.TempDir(), "helper.sock")
	if err := os.WriteFile(path, []byte("do not replace"), 0600); err != nil {
		t.Fatal(err)
	}
	if _, err := prepareFanHelperSocket(path, 0); err == nil || !strings.Contains(err.Error(), "unsafe") {
		t.Fatalf("prepareFanHelperSocket error = %v", err)
	}
}

func waitForHelperState(t *testing.T, service *fanHelperService, state string) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		if service.status().State == state {
			return
		}
		time.Sleep(time.Millisecond)
	}
	t.Fatalf("helper state = %q, want %q", service.status().State, state)
}
