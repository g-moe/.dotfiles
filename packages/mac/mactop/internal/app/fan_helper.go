package app

import (
	"bufio"
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"os/user"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
)

const (
	fanHelperProtocolVersion = 2
	fanHelperLabel           = "com.mactop.fancontrol"
	fanHelperBinaryPath      = "/Library/PrivilegedHelperTools/com.mactop.fancontrol"
	fanHelperPlistPath       = "/Library/LaunchDaemons/com.mactop.fancontrol.plist"
	fanHelperSocketPath      = "/var/run/mactop-fancontrol.sock"
	fanHelperStatePath       = "/Library/Application Support/mactop/fan-control.json"
	fanHelperMaxRequestBytes = 1024
	fanHelperRequestTimeout  = 3 * time.Second
	fanHelperStopTimeout     = 5 * time.Second
	fanHelperStateVersion    = 1
	fanHelperMaxStateBytes   = 4096
)

var errFanHelperVersionMismatch = errors.New("fan helper update required")

var (
	fanHelperBuildOnce   sync.Once
	fanHelperBuildHash   string
	fanHelperBuildDigest string
)

func loadFanHelperBuildIdentity() {
	fanHelperBuildOnce.Do(func() {
		executable, err := os.Executable()
		if err != nil {
			return
		}
		contents, err := os.ReadFile(executable)
		if err != nil {
			return
		}
		sum := sha256.Sum256(contents)
		fanHelperBuildDigest = fmt.Sprintf("%x", sum[:])
		fanHelperBuildHash = fanHelperBuildDigest[:16]
	})
}

func fanHelperBuildVersion() string {
	loadFanHelperBuildIdentity()
	return fanHelperBuildHash
}

func fanHelperBuildSHA256() string {
	loadFanHelperBuildIdentity()
	return fanHelperBuildDigest
}

type fanHelperRequest struct {
	Protocol       int     `json:"protocol"`
	Command        string  `json:"command"`
	Mode           string  `json:"mode,omitempty"`
	ConstantRPM    int     `json:"constant_rpm,omitempty"`
	StartCelsius   float64 `json:"start_celsius,omitempty"`
	MaximumCelsius float64 `json:"maximum_celsius,omitempty"`
}

type fanHelperStatus struct {
	Protocol       int         `json:"protocol"`
	Version        string      `json:"version"`
	State          string      `json:"state"`
	Temperature    float64     `json:"temperature,omitempty"`
	Targets        map[int]int `json:"targets,omitempty"`
	Message        string      `json:"message,omitempty"`
	Mode           string      `json:"mode"`
	ConstantRPM    int         `json:"constant_rpm,omitempty"`
	StartCelsius   float64     `json:"start_celsius"`
	MaximumCelsius float64     `json:"maximum_celsius"`
	MinimumRPM     int         `json:"minimum_rpm,omitempty"`
	MaximumRPM     int         `json:"maximum_rpm,omitempty"`
	RPMRangeState  string      `json:"rpm_range_state"`
}

type fanPolicyRunSource uint8

const (
	fanPolicyRunSourceManual fanPolicyRunSource = iota
	fanPolicyRunSourceWakeResume
)

type fanPolicyRunSourceContextKey struct{}

type fanPolicyRunGenerationContextKey struct{}

func fanPolicySourceFromContext(ctx context.Context) fanPolicyRunSource {
	source, ok := ctx.Value(fanPolicyRunSourceContextKey{}).(fanPolicyRunSource)
	if !ok {
		return fanPolicyRunSourceManual
	}
	return source
}

func fanPolicyGenerationFromContext(ctx context.Context) uint64 {
	generation, _ := ctx.Value(fanPolicyRunGenerationContextKey{}).(uint64)
	return generation
}

type persistedFanPolicySettings struct {
	Version        int     `json:"version"`
	Mode           string  `json:"mode"`
	ConstantRPM    int     `json:"constant_rpm,omitempty"`
	StartCelsius   float64 `json:"start_celsius,omitempty"`
	MaximumCelsius float64 `json:"maximum_celsius,omitempty"`
}

type fanPolicyStore interface {
	Load() (fanPolicySettings, error)
	Save(fanPolicySettings) error
}

type fileFanPolicyStore struct {
	path     string
	ownerUID int
	ownerGID int
}

func (s fileFanPolicyStore) Load() (fanPolicySettings, error) {
	if err := validateOwnedDirectory(filepath.Dir(s.path), s.ownerUID); err != nil {
		return fanPolicySettings{}, err
	}
	info, err := os.Lstat(s.path)
	if err != nil {
		return fanPolicySettings{}, err
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || !info.Mode().IsRegular() || int(stat.Uid) != s.ownerUID || info.Mode().Perm() != 0600 {
		return fanPolicySettings{}, errors.New("fan control state file is not a root-owned 0600 regular file")
	}
	if info.Size() > fanHelperMaxStateBytes {
		return fanPolicySettings{}, errors.New("fan control state file is too large")
	}
	file, err := os.Open(s.path)
	if err != nil {
		return fanPolicySettings{}, err
	}
	defer file.Close()
	contents, err := io.ReadAll(io.LimitReader(file, fanHelperMaxStateBytes+1))
	if err != nil {
		return fanPolicySettings{}, err
	}
	if len(contents) > fanHelperMaxStateBytes {
		return fanPolicySettings{}, errors.New("fan control state file is too large")
	}
	var saved persistedFanPolicySettings
	decoder := json.NewDecoder(bytes.NewReader(contents))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&saved); err != nil {
		return fanPolicySettings{}, fmt.Errorf("invalid fan control state: %w", err)
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return fanPolicySettings{}, errors.New("fan control state must contain one JSON object")
	}
	if saved.Version != fanHelperStateVersion {
		return fanPolicySettings{}, fmt.Errorf("unsupported fan control state version %d", saved.Version)
	}
	settings := fanPolicySettings{
		Mode: saved.Mode, ConstantRPM: saved.ConstantRPM,
		StartCelsius: saved.StartCelsius, MaximumCelsius: saved.MaximumCelsius,
	}
	if err := settings.validate(); err != nil {
		return fanPolicySettings{}, fmt.Errorf("invalid saved fan settings: %w", err)
	}
	return settings, nil
}

func (s fileFanPolicyStore) Save(settings fanPolicySettings) error {
	if err := settings.validate(); err != nil {
		return err
	}
	if settings.Mode == fanModeDefault {
		if err := os.Remove(s.path); err != nil && !os.IsNotExist(err) {
			return err
		} else if err == nil {
			return syncDirectory(filepath.Dir(s.path))
		}
		return nil
	}
	if err := ensureOwnedDirectory(filepath.Dir(s.path), s.ownerUID, s.ownerGID); err != nil {
		return err
	}
	saved := persistedFanPolicySettings{
		Version: fanHelperStateVersion, Mode: settings.Mode,
		ConstantRPM: settings.ConstantRPM, StartCelsius: settings.StartCelsius,
		MaximumCelsius: settings.MaximumCelsius,
	}
	contents, err := json.Marshal(saved)
	if err != nil {
		return err
	}
	return writeOwnedFileAtomically(s.path, append(contents, '\n'), 0600, s.ownerUID, s.ownerGID)
}

type fanHelperInstaller interface {
	Executable() (string, error)
	ReadFile(string) ([]byte, os.FileMode, uint32, error)
	InstallFile(string, []byte, os.FileMode) error
	Launchctl(...string) error
	Sleep(time.Duration)
}

type systemFanHelperInstaller struct{}

func (systemFanHelperInstaller) Executable() (string, error) { return os.Executable() }
func (systemFanHelperInstaller) ReadFile(path string) ([]byte, os.FileMode, uint32, error) {
	source, err := os.Open(path)
	if err != nil {
		return nil, 0, 0, err
	}
	defer source.Close()
	info, err := source.Stat()
	if err != nil || !info.Mode().IsRegular() {
		return nil, 0, 0, errors.New("mactop executable is not a regular file")
	}
	fileStat, ok := info.Sys().(*syscall.Stat_t)
	if !ok {
		return nil, 0, 0, errors.New("could not read mactop executable ownership")
	}
	contents, err := io.ReadAll(source)
	return contents, info.Mode(), fileStat.Uid, err
}
func (systemFanHelperInstaller) InstallFile(path string, contents []byte, mode os.FileMode) error {
	return installRootOwnedFile(path, contents, mode)
}
func (systemFanHelperInstaller) Launchctl(arguments ...string) error {
	return runLaunchctl(arguments...)
}
func (systemFanHelperInstaller) Sleep(duration time.Duration) { time.Sleep(duration) }

type fanHelperService struct {
	commandMu         sync.Mutex
	mu                sync.Mutex
	state             fanHelperStatus
	cancel            context.CancelFunc
	done              chan struct{}
	shuttingDown      bool
	runPolicyFunc     func(context.Context, fanPolicySettings) error
	resetFunc         func() error
	readRangeFunc     func() (int, int, error)
	readForceTest     func() (int, error)
	stopTimeout       time.Duration
	store             fanPolicyStore
	settings          fanPolicySettings
	minimumRPM        int
	maximumRPM        int
	rpmRangeState     string
	requestMessage    string
	diagnostics       fanHelperDiagnostics
	sleeping          bool
	configuringManual bool
	resumePending     bool
	resumeRunning     bool
	resumeGeneration  uint64
}

func (s *fanHelperService) reset() fanHelperStatus {
	s.mu.Lock()
	s.invalidateWakeResumeLocked()
	s.requestMessage = ""
	active := s.cancel != nil
	s.mu.Unlock()
	if active {
		if status := s.disable(); status.State == "error" {
			return status
		}
		// The policy owner restores and verifies automatic mode before it exits.
		// Repeating the same reset here only adds another SMC propagation wait.
		s.mu.Lock()
		s.settings = defaultFanPolicySettings()
		s.state = newFanHelperStatus("off", 0, nil, "")
		s.mu.Unlock()
		return s.status()
	}
	s.setStatus("stopping", 0, nil, "")
	err := s.resetFunc()
	if err != nil {
		s.setStatus("error", 0, nil, err.Error())
	} else {
		s.mu.Lock()
		s.settings = defaultFanPolicySettings()
		s.state = newFanHelperStatus("off", 0, nil, "")
		s.mu.Unlock()
	}
	return s.status()
}

func (s *fanHelperService) shutdown() error {
	s.beginShutdown()
	s.commandMu.Lock()
	defer s.commandMu.Unlock()
	s.mu.Lock()
	active := s.cancel != nil
	done := s.done
	s.mu.Unlock()
	status := s.disable()
	if active && status.State == "off" {
		// A clean policy shutdown already restored and verified automatic mode.
		return nil
	}
	if active && done != nil {
		// A timed-out policy can still own the fan-control lock and write SMC
		// state. Join that exact writer before the fallback reset so it cannot
		// restore manual mode after automatic-mode readback.
		<-done
		status = s.status()
		if status.State == "off" {
			return nil
		}
	}
	if err := s.resetFunc(); err != nil {
		s.setStatus("error", 0, nil, err.Error())
		return err
	}
	s.setStatus("off", 0, nil, "")
	return nil
}

func (s *fanHelperService) beginShutdown() {
	s.mu.Lock()
	s.shuttingDown = true
	s.invalidateWakeResumeLocked()
	s.mu.Unlock()
}

func (s *fanHelperService) isShuttingDown() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.shuttingDown
}

func resetFansForHelper() error {
	lock, err := acquireFanControlLock(fanControlLockPath)
	if err != nil {
		return err
	}
	defer lock.Close()
	if err := initSocMetrics(); err != nil {
		return err
	}
	defer cleanupSocMetrics()
	return ResetFansToAuto()
}

func prepareFanHelperService(service *fanHelperService) error {
	status := service.reset()
	if status.State == "error" {
		return errors.New(status.Message)
	}
	lower, upper, err := service.readRangeFunc()
	service.setCommonRPMRange(lower, upper, err)
	saved, loadErr := service.store.Load()
	if os.IsNotExist(loadErr) {
		return nil
	}
	if loadErr != nil {
		service.setStatus("error", 0, nil, fmt.Sprintf("could not restore saved fan control: %v", loadErr))
		return nil
	}
	if saved.Mode == fanModeDefault {
		return nil
	}
	if validationErr := service.validateForCurrentHardware(saved); validationErr != nil {
		service.setStatus("error", 0, nil, fmt.Sprintf("could not restore saved fan control: %v", validationErr))
		return nil
	}
	service.mu.Lock()
	service.settings = saved
	service.mu.Unlock()
	service.enable()
	return nil
}

func newFanHelperService(store fanPolicyStore) *fanHelperService {
	service := &fanHelperService{state: newFanHelperStatus("off", 0, nil, "")}
	service.runPolicyFunc = service.runPolicy
	service.resetFunc = resetFansForHelper
	service.readRangeFunc = readCommonFanRPMRange
	service.readForceTest = readNativeFanForceTest
	service.stopTimeout = fanHelperStopTimeout
	service.store = store
	service.diagnostics = discardFanHelperDiagnostics{}
	service.settings = defaultFanPolicySettings()
	service.state = service.statusForSettings(service.state)
	return service
}

func (s *fanHelperService) validateForCurrentHardware(settings fanPolicySettings) error {
	if err := settings.validate(); err != nil {
		return err
	}
	if settings.Mode != fanModeConstant {
		return nil
	}
	s.mu.Lock()
	lower, upper, rangeState := s.minimumRPM, s.maximumRPM, s.rpmRangeState
	s.mu.Unlock()
	if rangeState != "available" {
		return errors.New("constant RPM is unavailable because the common hardware range could not be read")
	}
	if settings.ConstantRPM < lower || settings.ConstantRPM > upper {
		return fmt.Errorf("constant speed %d RPM is outside the common fan range %d-%d RPM", settings.ConstantRPM, lower, upper)
	}
	return nil
}

func (s *fanHelperService) statusForSettings(status fanHelperStatus) fanHelperStatus {
	status.Mode = s.settings.Mode
	status.ConstantRPM = s.settings.ConstantRPM
	status.StartCelsius = s.settings.StartCelsius
	status.MaximumCelsius = s.settings.MaximumCelsius
	status.MinimumRPM = s.minimumRPM
	status.MaximumRPM = s.maximumRPM
	status.RPMRangeState = s.rpmRangeState
	if status.Message == "" {
		status.Message = s.requestMessage
	}
	return status
}

func (s *fanHelperService) setCommonRPMRange(lower, upper int, err error) {
	s.mu.Lock()
	if err == nil {
		s.minimumRPM, s.maximumRPM = lower, upper
		s.rpmRangeState = "available"
	} else {
		s.minimumRPM, s.maximumRPM = 0, 0
		s.rpmRangeState = "unavailable"
	}
	s.mu.Unlock()
}

func (s *fanHelperService) updateCommonRPMRange(fans []FanInfo) {
	lower, upper, err := commonFanRPMRange(fans)
	s.setCommonRPMRange(lower, upper, err)
}

func readCommonFanRPMRange() (int, int, error) {
	lock, err := acquireFanControlLock(fanControlLockPath)
	if err != nil {
		return 0, 0, err
	}
	defer lock.Close()
	fans, err := readFanMetrics()
	if err != nil {
		return 0, 0, err
	}
	return commonFanRPMRange(fans)
}

func newFanHelperStatus(state string, temperature float64, targets map[int]int, message string) fanHelperStatus {
	return fanHelperStatus{
		Protocol:    fanHelperProtocolVersion,
		Version:     fanHelperBuildVersion(),
		State:       state,
		Temperature: temperature,
		Targets:     cloneFanTargets(targets),
		Message:     message,
	}
}

func (s *fanHelperService) status() fanHelperStatus {
	s.mu.Lock()
	defer s.mu.Unlock()
	status := s.state
	status.Targets = cloneFanTargets(status.Targets)
	return s.statusForSettings(status)
}

func cloneFanTargets(targets map[int]int) map[int]int {
	if targets == nil {
		return nil
	}
	result := make(map[int]int, len(targets))
	for id, rpm := range targets {
		result[id] = rpm
	}
	return result
}

func (s *fanHelperService) setStatus(state string, temperature float64, targets map[int]int, message string) {
	s.mu.Lock()
	s.state = newFanHelperStatus(state, temperature, targets, message)
	if state == "error" {
		s.requestMessage = ""
	}
	s.mu.Unlock()
}

func (s *fanHelperService) invalidateWakeResumeLocked() {
	s.resumeGeneration++
	s.resumePending = false
	s.resumeRunning = false
}

// statusWithMessage keeps the active helper configuration in error responses.
// It also keeps the message through status polls until a command succeeds.
func (s *fanHelperService) statusWithMessage(message string) fanHelperStatus {
	s.mu.Lock()
	s.requestMessage = message
	status := s.state
	status.Targets = cloneFanTargets(status.Targets)
	status = s.statusForSettings(status)
	s.mu.Unlock()
	return status
}

func (s *fanHelperService) enable() fanHelperStatus {
	status, _ := s.enableWithSource(fanPolicyRunSourceManual, 0)
	return status
}

func (s *fanHelperService) enableWithSource(source fanPolicyRunSource, generation uint64) (fanHelperStatus, bool) {
	s.mu.Lock()
	if s.shuttingDown {
		status := newFanHelperStatus("error", 0, nil, "fan helper is shutting down")
		s.mu.Unlock()
		return status, false
	}
	if source == fanPolicyRunSourceWakeResume &&
		(s.sleeping || !s.resumePending || !s.resumeRunning || s.resumeGeneration != generation) {
		status := s.statusForSettings(s.state)
		s.mu.Unlock()
		return status, false
	}
	if source == fanPolicyRunSourceManual && s.sleeping {
		status := s.statusForSettings(s.state)
		s.mu.Unlock()
		return status, false
	}
	if s.cancel != nil {
		status := s.state
		s.mu.Unlock()
		return status, false
	}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	s.cancel = cancel
	s.done = done
	s.state = newFanHelperStatus("starting", 0, nil, "")
	settings := s.settings
	s.mu.Unlock()

	go s.executePolicy(ctx, done, settings, source, generation)
	return s.status(), true
}

func (s *fanHelperService) executePolicy(ctx context.Context, done chan struct{}, settings fanPolicySettings, source fanPolicyRunSource, generation uint64) {
	defer close(done)
	defer func() {
		s.mu.Lock()
		s.cancel = nil
		s.done = nil
		s.mu.Unlock()
	}()
	policyContext := context.WithValue(ctx, fanPolicyRunSourceContextKey{}, source)
	if source == fanPolicyRunSourceWakeResume {
		policyContext = context.WithValue(policyContext, fanPolicyRunGenerationContextKey{}, generation)
	}
	if err := s.runPolicyFunc(policyContext, settings); err != nil {
		if ctx.Err() != nil && errors.Is(err, ctx.Err()) {
			return
		}
		s.setStatus("error", 0, nil, err.Error())
		if source == fanPolicyRunSourceWakeResume && s.finishWakeResume(generation) {
			s.logPolicyDiagnostic("wake_resume_failed", settings, 0, nil, nil, err)
		}
	}
}

func (s *fanHelperService) disable() fanHelperStatus {
	s.mu.Lock()
	cancel, done := s.cancel, s.done
	if cancel == nil {
		status := s.state
		if status.State != "error" {
			status = newFanHelperStatus("off", 0, nil, "")
			s.state = status
		}
		s.mu.Unlock()
		return status
	}
	s.state.State = "stopping"
	s.mu.Unlock()

	cancel()
	select {
	case <-done:
	case <-time.After(s.stopTimeout):
		s.setStatus("error", 0, nil, "timed out while restoring automatic fan control")
	}
	return s.status()
}

func (s *fanHelperService) runPolicy(ctx context.Context, settings fanPolicySettings) (err error) {
	lock, err := acquireFanControlLock(fanControlLockPath)
	if err != nil {
		if ctx.Err() != nil {
			return nil
		}
		return err
	}
	defer lock.Close()
	if ctx.Err() != nil {
		return nil
	}
	if err := initSocMetrics(); err != nil {
		if ctx.Err() != nil {
			return nil
		}
		return err
	}
	defer cleanupSocMetrics()
	if ctx.Err() != nil {
		return nil
	}

	controller := newFanPolicyControllerWithSettings(smcFanPolicyHardware{context: ctx}, settings)
	var lastFans []FanInfo
	var lastTemperature float64
	firstSample := true
	verified := false
	source := fanPolicySourceFromContext(ctx)
	resumeGeneration := fanPolicyGenerationFromContext(ctx)
	s.logPolicyDiagnostic("manual_policy_started", settings, 0, nil, nil, nil)
	defer func() {
		if recovered := recover(); recovered != nil {
			err = fmt.Errorf("fan policy panic: %v", recovered)
		}
		if err != nil {
			s.logPolicyDiagnostic("manual_policy_failed", settings, lastTemperature, lastFans, controller.lastRPM, err)
		} else if ctx.Err() != nil {
			s.logPolicyDiagnostic("manual_policy_stopped", settings, lastTemperature, lastFans, controller.lastRPM, nil)
		}
		closeErr := controller.Close()
		if closeErr != nil {
			err = errors.Join(err, fmt.Errorf("could not restore automatic fan control: %w", closeErr))
		}
		postResetFans, snapshotErr := readFanMetrics()
		if closeErr != nil || snapshotErr != nil {
			s.logPolicyDiagnostic("apple_default_restore_failed", settings, lastTemperature, postResetFans, controller.lastRPM, errors.Join(closeErr, snapshotErr))
		} else {
			s.logPolicyDiagnostic("apple_default_restored", settings, lastTemperature, postResetFans, controller.lastRPM, nil)
		}
		if err == nil {
			s.mu.Lock()
			if s.sleeping && s.resumePending {
				s.state = newFanHelperStatus("suspended", 0, nil, "Manual fan control is suspended for sleep.")
			} else {
				s.state = newFanHelperStatus("off", 0, nil, "")
			}
			s.mu.Unlock()
		}
	}()

	sysInfo := getSOCInfo()
	for {
		sample := normalizeSocMetricsPower(sampleSocMetrics(int(fanPolicySampleTime / time.Millisecond)))
		lastFans = sample.Fans
		s.updateCommonRPMRange(sample.Fans)
		if ctx.Err() != nil {
			return
		}
		temperature, targets, applyErr := controller.apply(ctx, sample, sysInfo)
		lastTemperature = temperature
		if applyErr != nil {
			if ctx.Err() != nil {
				return nil
			}
			return applyErr
		}
		if ctx.Err() != nil {
			return nil
		}
		if firstSample {
			s.setStatus("starting", temperature, targets, "")
			s.logPolicyDiagnostic("manual_policy_write_requested", settings, temperature, sample.Fans, targets, nil)
			firstSample = false
			// The next sample verifies the target and mode writes. Start it now;
			// the normal one-second cadence is only needed after verification.
			select {
			case <-ctx.Done():
				return
			default:
				continue
			}
		} else {
			s.setStatus("active", temperature, targets, "")
			if !verified {
				s.logPolicyDiagnostic("manual_policy_verified", settings, temperature, sample.Fans, targets, nil)
				if source == fanPolicyRunSourceWakeResume && s.finishWakeResume(resumeGeneration) {
					s.logPolicyDiagnostic("wake_resume_verified", settings, temperature, sample.Fans, targets, nil)
				}
				verified = true
			}
		}

		select {
		case <-ctx.Done():
			return
		case <-time.After(fanPolicyInterval):
		}
	}
}

func (s *fanHelperService) handlePowerEvent(event fanPowerEvent) {
	switch event {
	case fanPowerEventSleep:
		s.suspendForSleep()
	case fanPowerEventWake:
		s.scheduleWakeResume()
	}
}

func (s *fanHelperService) suspendForSleep() {
	s.mu.Lock()
	settings := s.settings
	if s.shuttingDown || (settings.Mode == fanModeDefault && !s.configuringManual) {
		s.mu.Unlock()
		return
	}
	wasResuming := s.resumeRunning
	pending := s.cancel != nil || s.resumePending || s.resumeRunning || s.configuringManual
	s.resumeGeneration++
	s.resumePending = pending
	s.resumeRunning = false
	s.sleeping = true
	cancel := s.cancel
	if pending {
		s.state = newFanHelperStatus("suspended", 0, nil, "Manual fan control is suspended for sleep.")
	}
	s.mu.Unlock()
	if !pending {
		return
	}
	if wasResuming {
		s.logPowerDiagnostic("wake_resume_cancelled", settings, "sleep", nil)
	} else {
		s.logPowerDiagnostic("policy_suspend_requested", settings, "sleep", nil)
	}
	if cancel != nil {
		cancel()
	}
}

func (s *fanHelperService) scheduleWakeResume() <-chan struct{} {
	s.mu.Lock()
	if s.shuttingDown || !s.sleeping {
		s.mu.Unlock()
		return nil
	}
	s.sleeping = false
	settings := s.settings
	if !s.resumePending || s.resumeRunning || settings.Mode == fanModeDefault {
		s.mu.Unlock()
		return nil
	}
	s.resumeRunning = true
	generation := s.resumeGeneration
	done := s.done
	s.mu.Unlock()

	s.logPowerDiagnostic("wake_resume_queued", settings, "", nil)
	resumeDone := make(chan struct{})
	go func() {
		defer close(resumeDone)
		if done != nil {
			<-done
		}
		if s.cancelWakeResumeAfterPolicyFailure(generation) {
			s.logPowerDiagnostic("wake_resume_cancelled", settings, "policy_cleanup_failed", nil)
			return
		}
		s.commandMu.Lock()
		defer s.commandMu.Unlock()
		if _, started := s.enableWithSource(fanPolicyRunSourceWakeResume, generation); started {
			s.logPolicyDiagnostic("wake_resume_started", settings, 0, nil, nil, nil)
		}
	}()
	return resumeDone
}

func (s *fanHelperService) cancelWakeResumeAfterPolicyFailure(generation uint64) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.sleeping || s.resumeGeneration != generation || !s.resumeRunning || s.state.State != "error" {
		return false
	}
	s.resumePending = false
	s.resumeRunning = false
	return true
}

func (s *fanHelperService) finishWakeResume(generation uint64) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.sleeping || s.resumeGeneration != generation || !s.resumeRunning {
		return false
	}
	s.resumePending = false
	s.resumeRunning = false
	return true
}

func (s *fanHelperService) logPowerDiagnostic(event string, settings fanPolicySettings, reason string, cause error) {
	diagnostic := fanHelperDiagnosticEvent{
		Event: event, Mode: settings.Mode, ConstantRPM: settings.ConstantRPM,
		StartCelsius: settings.StartCelsius, MaximumCelsius: settings.MaximumCelsius, Reason: reason,
	}
	if cause != nil {
		diagnostic.Error = cause.Error()
	}
	if err := s.diagnostics.Log(diagnostic); err != nil {
		fmt.Fprintf(os.Stderr, "Fan helper diagnostic logging failed: %v\n", err)
	}
}

func (s *fanHelperService) logPolicyDiagnostic(event string, settings fanPolicySettings, temperature float64, fans []FanInfo, targets map[int]int, cause error) {
	diagnostic := fanHelperDiagnosticEvent{
		Event: event, Mode: settings.Mode, ConstantRPM: settings.ConstantRPM,
		StartCelsius: settings.StartCelsius, MaximumCelsius: settings.MaximumCelsius,
		Temperature: temperature, Fans: diagnosticFans(fans), ExpectedTargets: cloneFanTargets(targets),
	}
	if forceTest, err := s.readForceTest(); err != nil {
		diagnostic.ForceTestError = err.Error()
	} else {
		diagnostic.ForceTest = &forceTest
	}
	if cause != nil {
		diagnostic.Error = cause.Error()
	}
	if err := s.diagnostics.Log(diagnostic); err != nil {
		fmt.Fprintf(os.Stderr, "Fan helper diagnostic logging failed: %v\n", err)
	}
}

func (s *fanHelperService) configure(settings fanPolicySettings) fanHelperStatus {
	if err := s.validateForCurrentHardware(settings); err != nil {
		return s.statusWithMessage(err.Error())
	}
	s.mu.Lock()
	resuming := s.resumePending || s.resumeRunning
	s.invalidateWakeResumeLocked()
	s.configuringManual = settings.Mode != fanModeDefault
	active := s.cancel != nil
	if s.sleeping && settings.Mode != fanModeDefault {
		s.resumePending = true
	}
	unchanged := active && !s.sleeping && !resuming && s.settings == settings
	s.mu.Unlock()
	defer func() {
		s.mu.Lock()
		s.configuringManual = false
		s.mu.Unlock()
	}()
	s.mu.Lock()
	s.requestMessage = ""
	s.mu.Unlock()
	if unchanged {
		if err := s.store.Save(settings); err != nil {
			return s.statusWithMessage(fmt.Sprintf("could not save fan control for restart: %v", err))
		}
		return s.status()
	}
	if active {
		// Remove A from durable state before stopping it. A cleanup or later save
		// failure then leaves reboot behavior at Apple Default, never at a policy
		// that the live helper did not accept.
		if err := s.store.Save(defaultFanPolicySettings()); err != nil {
			return s.statusWithMessage(fmt.Sprintf("could not clear saved fan control: %v", err))
		}
		if settings.Mode == fanModeDefault {
			return s.reset()
		}
		status := s.disable()
		if status.State == "error" {
			return status
		}
	}
	if err := s.store.Save(settings); err != nil {
		s.mu.Lock()
		s.settings = defaultFanPolicySettings()
		s.mu.Unlock()
		s.setStatus("error", 0, nil, fmt.Sprintf("could not save fan control for restart: %v", err))
		return s.status()
	}
	s.mu.Lock()
	s.settings = settings
	suspended := s.sleeping && settings.Mode != fanModeDefault
	if suspended {
		s.state = newFanHelperStatus("suspended", 0, nil, "Manual fan control is suspended for sleep.")
	}
	s.mu.Unlock()
	if settings.Mode == fanModeDefault {
		return s.reset()
	}
	if suspended {
		return s.status()
	}
	return s.enable()
}

func (s *fanHelperService) handle(request fanHelperRequest) fanHelperStatus {
	if request.Protocol != fanHelperProtocolVersion {
		return newFanHelperStatus("error", 0, nil, "fan helper protocol mismatch")
	}
	switch request.Command {
	case "status":
		return s.status()
	case "reset":
		return s.handleMutation(func() fanHelperStatus { return s.configure(defaultFanPolicySettings()) })
	case "configure":
		settings := fanPolicySettings{
			Mode: request.Mode, ConstantRPM: request.ConstantRPM,
			StartCelsius: request.StartCelsius, MaximumCelsius: request.MaximumCelsius,
		}
		return s.handleMutation(func() fanHelperStatus { return s.configure(settings) })
	default:
		return newFanHelperStatus("error", 0, nil, "unsupported fan helper command")
	}
}

func (s *fanHelperService) handleMutation(action func() fanHelperStatus) fanHelperStatus {
	s.commandMu.Lock()
	defer s.commandMu.Unlock()
	if s.isShuttingDown() {
		return newFanHelperStatus("error", 0, nil, "fan helper is shutting down")
	}
	return action()
}

func peerCanControlFans(connection *net.UnixConn, adminGID uint32) bool {
	raw, err := connection.SyscallConn()
	if err != nil {
		return false
	}
	allowed := false
	controlErr := raw.Control(func(fd uintptr) {
		credential, credentialErr := unix.GetsockoptXucred(int(fd), unix.SOL_LOCAL, unix.LOCAL_PEERCRED)
		if credentialErr != nil {
			return
		}
		if credential.Uid == 0 {
			allowed = true
			return
		}
		for index := 0; index < int(credential.Ngroups) && index < len(credential.Groups); index++ {
			if credential.Groups[index] == adminGID {
				allowed = true
				return
			}
		}
	})
	return controlErr == nil && allowed
}

func serveFanHelperConnection(connection *net.UnixConn, service *fanHelperService, adminGID uint32) {
	defer connection.Close()
	_ = connection.SetDeadline(time.Now().Add(fanHelperRequestTimeout))
	if !peerCanControlFans(connection, adminGID) {
		_ = json.NewEncoder(connection).Encode(newFanHelperStatus("error", 0, nil, "fan control requires an administrator account"))
		return
	}

	reader := bufio.NewReader(io.LimitReader(connection, fanHelperMaxRequestBytes+1))
	line, err := reader.ReadBytes('\n')
	if err != nil || len(line) > fanHelperMaxRequestBytes {
		_ = json.NewEncoder(connection).Encode(newFanHelperStatus("error", 0, nil, "invalid fan helper request"))
		return
	}
	request, err := decodeFanHelperRequest(line)
	if err != nil {
		_ = json.NewEncoder(connection).Encode(newFanHelperStatus("error", 0, nil, "invalid fan helper request"))
		return
	}
	if service.isShuttingDown() && request.Command != "status" {
		_ = json.NewEncoder(connection).Encode(newFanHelperStatus("error", 0, nil, "fan helper is shutting down"))
		return
	}
	_ = json.NewEncoder(connection).Encode(service.handle(request))
}

func decodeFanHelperRequest(line []byte) (fanHelperRequest, error) {
	var request fanHelperRequest
	decoder := json.NewDecoder(bytes.NewReader(line))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&request); err != nil {
		return fanHelperRequest{}, err
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return fanHelperRequest{}, errors.New("fan helper request must contain one JSON object")
	}
	return request, nil
}

func prepareFanHelperSocket(path string, adminGID int) (*net.UnixListener, error) {
	if info, err := os.Lstat(path); err == nil {
		stat, ok := info.Sys().(*syscall.Stat_t)
		if info.Mode()&os.ModeSocket == 0 || !ok || stat.Uid != 0 {
			return nil, fmt.Errorf("refusing to replace unsafe fan helper socket path %s", path)
		}
		if err := os.Remove(path); err != nil {
			return nil, err
		}
	} else if !os.IsNotExist(err) {
		return nil, err
	}
	listener, err := net.ListenUnix("unix", &net.UnixAddr{Name: path, Net: "unix"})
	if err != nil {
		return nil, err
	}
	if err := os.Chown(path, 0, adminGID); err != nil {
		listener.Close()
		return nil, err
	}
	if err := os.Chmod(path, 0660); err != nil {
		listener.Close()
		return nil, err
	}
	return listener, nil
}

func runFanHelper() error {
	if os.Geteuid() != 0 {
		return errors.New("the fan helper must run as root")
	}
	adminGroup, err := user.LookupGroup("admin")
	if err != nil {
		return err
	}
	adminGID, err := strconv.Atoi(adminGroup.Gid)
	if err != nil {
		return err
	}
	listener, err := prepareFanHelperSocket(fanHelperSocketPath, adminGID)
	if err != nil {
		return err
	}
	defer func() {
		listener.Close()
		_ = os.Remove(fanHelperSocketPath)
	}()

	service := newFanHelperService(fileFanPolicyStore{
		path: fanHelperStatePath, ownerUID: 0, ownerGID: 0,
	})
	diagnostics, diagnosticsErr := newFileFanHelperDiagnostics(fanHelperLogPath, 0, adminGID)
	if diagnosticsErr != nil {
		fmt.Fprintf(os.Stderr, "Fan helper diagnostic logging is unavailable: %v\n", diagnosticsErr)
	} else {
		service.diagnostics = diagnostics
	}
	powerEvents, powerEventsErr := startFanPowerNotifications()
	if powerEventsErr != nil {
		fmt.Fprintf(os.Stderr, "Fan helper sleep-resume handling is unavailable: %v\n", powerEventsErr)
	}
	if err := prepareFanHelperService(service); err != nil {
		return err
	}
	defer func() {
		if err := service.shutdown(); err != nil {
			fmt.Fprintf(os.Stderr, "Fan helper shutdown reset failed: %v\n", err)
		}
	}()
	if powerEventsErr == nil {
		defer stopFanPowerNotifications()
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM, syscall.SIGHUP)
	defer stop()
	go func() {
		<-ctx.Done()
		service.beginShutdown()
		listener.Close()
	}()
	if powerEventsErr == nil {
		go serveFanHelperPowerEvents(ctx, service, powerEvents)
	}
	for {
		connection, acceptErr := listener.AcceptUnix()
		if acceptErr != nil {
			if ctx.Err() != nil {
				return nil
			}
			return acceptErr
		}
		go serveFanHelperConnection(connection, service, uint32(adminGID))
	}
}

func serveFanHelperPowerEvents(ctx context.Context, service *fanHelperService, events <-chan fanPowerEvent) {
	for {
		select {
		case <-ctx.Done():
			return
		case event := <-events:
			service.handlePowerEvent(event)
		}
	}
}

func requestFanHelper(command string) (fanHelperStatus, error) {
	return requestFanHelperRequest(fanHelperRequest{Command: command})
}

func requestFanHelperAt(socketPath, command string) (fanHelperStatus, error) {
	return requestFanHelperRequestAt(socketPath, fanHelperRequest{Command: command})
}

func requestFanHelperRequest(request fanHelperRequest) (fanHelperStatus, error) {
	return requestFanHelperRequestAt(fanHelperSocketPath, request)
}

func requestFanHelperRequestAt(socketPath string, request fanHelperRequest) (fanHelperStatus, error) {
	return requestFanHelperRequestAtWithTimeout(socketPath, request, fanHelperRequestTimeout)
}

func requestFanHelperRequestAtWithTimeout(socketPath string, request fanHelperRequest, timeout time.Duration) (fanHelperStatus, error) {
	if timeout <= 0 {
		return fanHelperStatus{}, os.ErrDeadlineExceeded
	}
	deadline := time.Now().Add(timeout)
	connection, err := net.DialTimeout("unix", socketPath, time.Until(deadline))
	if err != nil {
		return fanHelperStatus{Protocol: fanHelperProtocolVersion, State: "unavailable"}, err
	}
	defer connection.Close()
	_ = connection.SetDeadline(deadline)
	request.Protocol = fanHelperProtocolVersion
	if err := json.NewEncoder(connection).Encode(request); err != nil {
		return fanHelperStatus{}, err
	}
	var status fanHelperStatus
	if err := json.NewDecoder(io.LimitReader(connection, fanHelperMaxRequestBytes*4)).Decode(&status); err != nil {
		return fanHelperStatus{}, err
	}
	if status.Protocol != fanHelperProtocolVersion {
		return fanHelperStatus{}, errors.New("fan helper protocol mismatch; reinstall the helper")
	}
	requiredVersion := fanHelperBuildVersion()
	if requiredVersion == "" {
		return status, errors.New("could not identify the mactop build")
	}
	if status.Version != requiredVersion {
		return status, fmt.Errorf("%w: installed %q, required %q", errFanHelperVersionMismatch, status.Version, requiredVersion)
	}
	return status, nil
}

func fanHelperPlist() string {
	return fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>%s</string>
<key>ProgramArguments</key><array><string>%s</string><string>--fan-helper</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><true/>
<key>ExitTimeOut</key><integer>30</integer>
<key>ProcessType</key><string>Interactive</string>
</dict></plist>
`, fanHelperLabel, fanHelperBinaryPath)
}

func installFanHelper() error {
	return installFanHelperWith(systemFanHelperInstaller{}, os.Geteuid() == 0)
}

func installFanHelperWith(installer fanHelperInstaller, hasRoot bool) error {
	if !hasRoot {
		return errors.New("fan helper installation requires root")
	}
	executable, err := installer.Executable()
	if err != nil {
		return err
	}
	binary, _, owner, err := installer.ReadFile(executable)
	if err != nil {
		return err
	}
	if owner != 0 {
		return errors.New("fan helper installer must execute a root-owned mactop copy")
	}
	if err := os.MkdirAll(filepath.Dir(fanHelperBinaryPath), 0755); err != nil {
		return err
	}
	if err := installer.InstallFile(fanHelperBinaryPath, binary, 0755); err != nil {
		return err
	}
	if err := installer.InstallFile(fanHelperPlistPath, []byte(fanHelperPlist()), 0644); err != nil {
		return err
	}

	// Bootout can fail when this is the first install. Bootstrap is the action
	// that must succeed. launchd can need a short time to retire the previous
	// service record after bootout, so retry only that bounded transition.
	_ = installer.Launchctl("bootout", "system/"+fanHelperLabel)
	var bootstrapErr error
	for attempt := 0; attempt < 20; attempt++ {
		bootstrapErr = installer.Launchctl("bootstrap", "system", fanHelperPlistPath)
		if bootstrapErr == nil {
			return nil
		}
		installer.Sleep(100 * time.Millisecond)
	}
	return bootstrapErr
}

// installRootOwnedFile writes in the protected destination directory and then
// renames the complete file into place. This avoids following a stale symlink
// or exposing a partial helper during an upgrade.
func installRootOwnedFile(path string, contents []byte, mode os.FileMode) (returnErr error) {
	return writeOwnedFileAtomically(path, contents, mode, 0, 0)
}

func ensureOwnedDirectory(path string, ownerUID, ownerGID int) error {
	if err := os.MkdirAll(path, 0755); err != nil {
		return err
	}
	if err := validateOwnedDirectory(path, ownerUID); err != nil {
		return err
	}
	if err := os.Chown(path, ownerUID, ownerGID); err != nil {
		return err
	}
	return os.Chmod(path, 0755)
}

func validateOwnedDirectory(path string, ownerUID int) error {
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	stat, ok := info.Sys().(*syscall.Stat_t)
	if !ok || !info.IsDir() || info.Mode()&os.ModeSymlink != 0 || int(stat.Uid) != ownerUID || info.Mode().Perm()&0022 != 0 {
		return errors.New("fan control state directory must be owner-controlled and not writable by group or other users")
	}
	return nil
}

func writeOwnedFileAtomically(path string, contents []byte, mode os.FileMode, ownerUID, ownerGID int) (returnErr error) {
	directory := filepath.Dir(path)
	temporary, err := os.CreateTemp(directory, ".mactop-install-*")
	if err != nil {
		return err
	}
	temporaryPath := temporary.Name()
	defer func() {
		_ = temporary.Close()
		_ = os.Remove(temporaryPath)
	}()
	if err := temporary.Chmod(mode); err != nil {
		return err
	}
	if err := temporary.Chown(ownerUID, ownerGID); err != nil {
		return err
	}
	if _, err := temporary.Write(contents); err != nil {
		return err
	}
	if err := temporary.Sync(); err != nil {
		return err
	}
	if err := temporary.Close(); err != nil {
		return err
	}
	if err := os.Rename(temporaryPath, path); err != nil {
		return err
	}
	return syncDirectory(directory)
}

func syncDirectory(path string) error {
	directoryFile, err := os.Open(path)
	if err != nil {
		return err
	}
	defer directoryFile.Close()
	return directoryFile.Sync()
}

func runLaunchctl(arguments ...string) error {
	output, err := exec.Command("/bin/launchctl", arguments...).CombinedOutput()
	if err != nil {
		message := strings.TrimSpace(string(output))
		if message == "" {
			message = err.Error()
		}
		return fmt.Errorf("launchctl %s failed: %s", strings.Join(arguments, " "), message)
	}
	return nil
}
