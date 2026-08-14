package app

import (
	"context"
	"errors"
	"fmt"
	"math"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"
)

const (
	fanPolicyLowCelsius  = 38.0
	fanPolicyHighCelsius = 85.0
	fanPolicySampleTime  = 500 * time.Millisecond
	fanPolicyInterval    = time.Second
	fanPolicyRPMDeadband = 25
	fanControlLockPath   = "/var/run/mactop-fan-control.lock"
)

var errFanManualOwnershipLost = errors.New("manual fan ownership was lost")

type fanManualOwnershipLostError struct {
	fanID int
}

func (e fanManualOwnershipLostError) Error() string {
	return fmt.Sprintf("fan %d did not enter manual mode", e.fanID)
}

func (fanManualOwnershipLostError) Is(target error) bool {
	return target == errFanManualOwnershipLost
}

const (
	fanModeDefault  = "default"
	fanModeConstant = "constant"
	fanModeCurve    = "curve"
)

type fanPolicySettings struct {
	Mode           string
	ConstantRPM    int
	StartCelsius   float64
	MaximumCelsius float64
}

func defaultFanPolicySettings() fanPolicySettings {
	return fanPolicySettings{Mode: fanModeDefault}
}

func fixedCurveSettings() fanPolicySettings {
	return fanPolicySettings{
		Mode: fanModeCurve, StartCelsius: fanPolicyLowCelsius,
		MaximumCelsius: fanPolicyHighCelsius,
	}
}

func (s fanPolicySettings) validate() error {
	switch s.Mode {
	case fanModeDefault:
		if s.ConstantRPM != 0 || s.StartCelsius != 0 || s.MaximumCelsius != 0 {
			return errors.New("Apple Default does not accept manual fan settings")
		}
		return nil
	case fanModeConstant:
		if s.StartCelsius != 0 || s.MaximumCelsius != 0 {
			return errors.New("Constant RPM does not accept curve temperatures")
		}
		if s.ConstantRPM <= 0 || s.ConstantRPM > 20000 {
			return fmt.Errorf("constant fan speed %d RPM is invalid", s.ConstantRPM)
		}
		return nil
	case fanModeCurve:
		if s.ConstantRPM != 0 {
			return errors.New("Curve does not accept a constant RPM")
		}
		if math.IsNaN(s.StartCelsius) || math.IsNaN(s.MaximumCelsius) ||
			math.IsInf(s.StartCelsius, 0) || math.IsInf(s.MaximumCelsius, 0) ||
			math.Trunc(s.StartCelsius) != s.StartCelsius ||
			math.Trunc(s.MaximumCelsius) != s.MaximumCelsius ||
			s.StartCelsius < 20 || s.MaximumCelsius > 100 ||
			s.MaximumCelsius-s.StartCelsius < 5 {
			return fmt.Errorf("curve temperatures %.1f-%.1f C are invalid", s.StartCelsius, s.MaximumCelsius)
		}
		return nil
	default:
		return fmt.Errorf("fan control mode %q is invalid", s.Mode)
	}
}

// fanCurve maps configured CPU P-core temperature limits to each fan's own
// hardware RPM range. The pure calculation keeps every boundary testable
// without changing fan state.
type fanCurve struct {
	lowCelsius  float64
	highCelsius float64
}

func fixedFanCurve() fanCurve {
	return fanCurve{lowCelsius: fanPolicyLowCelsius, highCelsius: fanPolicyHighCelsius}
}

func curveFromSettings(settings fanPolicySettings) fanCurve {
	return fanCurve{lowCelsius: settings.StartCelsius, highCelsius: settings.MaximumCelsius}
}

func fanTargetTolerance(mode string) int {
	if mode == fanModeConstant {
		return 0
	}
	return fanPolicyRPMDeadband
}

func (c fanCurve) targetRPM(celsius float64, minRPM, maxRPM int) (int, error) {
	if math.IsNaN(celsius) || math.IsInf(celsius, 0) || celsius < 0 || celsius > 125 {
		return 0, fmt.Errorf("invalid CPU P-core temperature %.1f C", celsius)
	}
	if c.lowCelsius >= c.highCelsius {
		return 0, errors.New("fan policy temperature limits are invalid")
	}
	if minRPM <= 0 || maxRPM < minRPM {
		return 0, fmt.Errorf("invalid fan RPM range %d-%d", minRPM, maxRPM)
	}
	if celsius <= c.lowCelsius {
		return minRPM, nil
	}
	if celsius >= c.highCelsius {
		return maxRPM, nil
	}

	fraction := (celsius - c.lowCelsius) / (c.highCelsius - c.lowCelsius)
	return minRPM + int(math.Round(fraction*float64(maxRPM-minRPM))), nil
}

// performanceCoreAverage returns the same CPU P-core sensor group that mactop
// shows in its thermal views. It does not fall back to a broader CPU reading:
// losing the configured sensor must stop manual fan control, not mask a fault.
func performanceCoreAverage(sensors []TempSensor, _ SystemInfo) (float64, error) {
	var sum float64
	var count int
	for _, sensor := range sensors {
		if !strings.HasPrefix(sensor.Name, "CPU P-Core") {
			continue
		}
		if math.IsNaN(sensor.Value) || math.IsInf(sensor.Value, 0) || sensor.Value < 0 || sensor.Value > 125 {
			return 0, fmt.Errorf("invalid CPU P-core sensor %q value %.1f C", sensor.Key, sensor.Value)
		}
		sum += sensor.Value
		count++
	}
	if count == 0 {
		return 0, errors.New("no CPU P-core temperature sensors were found")
	}
	return sum / float64(count), nil
}

type fanPolicyHardware interface {
	SetTarget(fanID, rpm int) error
	SetMode(fanID, mode int) error
	ResetToAuto() error
}

type smcFanPolicyHardware struct {
	context context.Context
}

func (smcFanPolicyHardware) SetTarget(fanID, rpm int) error { return SetFanTarget(fanID, rpm) }
func (h smcFanPolicyHardware) SetMode(fanID, mode int) error {
	if h.context == nil {
		return SetFanMode(fanID, mode)
	}
	return setFanModeWithHardware(nativeFanModeHardware{}, fanID, mode, waitForFanControlContext(h.context))
}
func (smcFanPolicyHardware) ResetToAuto() error { return ResetFansToAuto() }

// fanPolicyController is the single owner of policy SMC writes. Close is safe
// to call after an earlier failure, so all exit paths can request cleanup.
type fanPolicyController struct {
	hardware  fanPolicyHardware
	settings  fanPolicySettings
	lastRPM   map[int]int
	closeOnce sync.Once
	closeErr  error
}

func newFanPolicyController(hardware fanPolicyHardware) *fanPolicyController {
	return newFanPolicyControllerWithSettings(hardware, fixedCurveSettings())
}

func newFanPolicyControllerWithSettings(hardware fanPolicyHardware, settings fanPolicySettings) *fanPolicyController {
	return &fanPolicyController{
		hardware: hardware,
		settings: settings,
		lastRPM:  make(map[int]int),
	}
}

func (c *fanPolicyController) Close() error {
	c.closeOnce.Do(func() { c.closeErr = c.hardware.ResetToAuto() })
	return c.closeErr
}

func (c *fanPolicyController) fail(cause error) error {
	if resetErr := c.Close(); resetErr != nil {
		return errors.Join(cause, fmt.Errorf("could not restore automatic fan control: %w", resetErr))
	}
	return cause
}

func validateFans(fans []FanInfo) error {
	if len(fans) == 0 {
		return errors.New("no fans were found")
	}
	seen := make(map[int]bool, len(fans))
	for _, fan := range fans {
		if fan.ID < 0 || fan.ID > 7 || seen[fan.ID] {
			return fmt.Errorf("invalid or duplicate fan ID %d", fan.ID)
		}
		seen[fan.ID] = true
		if fan.MinRPM <= 0 || fan.MaxRPM < fan.MinRPM {
			return fmt.Errorf("fan %d has invalid RPM range %d-%d", fan.ID, fan.MinRPM, fan.MaxRPM)
		}
	}
	return nil
}

func commonFanRPMRange(fans []FanInfo) (int, int, error) {
	if err := validateFans(fans); err != nil {
		return 0, 0, err
	}
	lower, upper := fans[0].MinRPM, fans[0].MaxRPM
	for _, fan := range fans[1:] {
		if fan.MinRPM > lower {
			lower = fan.MinRPM
		}
		if fan.MaxRPM < upper {
			upper = fan.MaxRPM
		}
	}
	if lower > upper {
		return 0, 0, errors.New("fans do not have a common constant RPM range")
	}
	return lower, upper, nil
}

func evaluateFanPolicy(sample SocMetrics, sysInfo SystemInfo, curve fanCurve) (float64, map[int]int, error) {
	return evaluateFanSettings(sample, sysInfo, fanPolicySettings{
		Mode: fanModeCurve, StartCelsius: curve.lowCelsius, MaximumCelsius: curve.highCelsius,
	})
}

func evaluateFanSettings(sample SocMetrics, sysInfo SystemInfo, settings fanPolicySettings) (float64, map[int]int, error) {
	if err := settings.validate(); err != nil {
		return 0, nil, err
	}
	if settings.Mode == fanModeDefault {
		return 0, nil, errors.New("default mode does not use manual fan targets")
	}
	if err := validateFans(sample.Fans); err != nil {
		return 0, nil, err
	}
	if settings.Mode == fanModeConstant {
		lower, upper, err := commonFanRPMRange(sample.Fans)
		if err != nil {
			return 0, nil, err
		}
		if settings.ConstantRPM < lower || settings.ConstantRPM > upper {
			return 0, nil, fmt.Errorf("constant speed %d RPM is outside the common fan range %d-%d RPM", settings.ConstantRPM, lower, upper)
		}
	}
	var temperature float64
	if settings.Mode == fanModeCurve {
		var err error
		temperature, err = performanceCoreAverage(sample.TempSensors, sysInfo)
		if err != nil {
			return 0, nil, err
		}
	}
	curve := curveFromSettings(settings)
	targets := make(map[int]int, len(sample.Fans))
	for _, fan := range sample.Fans {
		target := settings.ConstantRPM
		if settings.Mode == fanModeCurve {
			var targetErr error
			target, targetErr = curve.targetRPM(temperature, fan.MinRPM, fan.MaxRPM)
			if targetErr != nil {
				return 0, nil, fmt.Errorf("fan %d: %w", fan.ID, targetErr)
			}
		}
		targets[fan.ID] = target
	}
	return temperature, targets, nil
}

func (c *fanPolicyController) verifyLastWrite(fans []FanInfo) error {
	seen := make(map[int]bool, len(fans))
	for _, fan := range fans {
		seen[fan.ID] = true
		expected, ok := c.lastRPM[fan.ID]
		if !ok {
			continue
		}
		if fan.Mode != 1 {
			return fanManualOwnershipLostError{fanID: fan.ID}
		}
		if absInt(fan.TargetRPM-expected) > fanTargetTolerance(c.settings.Mode) {
			return fmt.Errorf("fan %d target readback is %d RPM, expected %d RPM", fan.ID, fan.TargetRPM, expected)
		}
	}
	for fanID := range c.lastRPM {
		if !seen[fanID] {
			return fmt.Errorf("managed fan %d disappeared from the SMC sample", fanID)
		}
	}
	return nil
}

func (c *fanPolicyController) apply(sample SocMetrics, sysInfo SystemInfo) (float64, map[int]int, error) {
	if err := c.verifyLastWrite(sample.Fans); err != nil {
		return 0, nil, c.fail(err)
	}
	temperature, targets, err := evaluateFanSettings(sample, sysInfo, c.settings)
	if err != nil {
		return 0, nil, c.fail(err)
	}

	// Write all targets before any fan enters manual mode. A mode write can
	// therefore never expose an old target left by another application.
	writtenTargets := make(map[int]int, len(sample.Fans))
	for _, fan := range sample.Fans {
		target := targets[fan.ID]
		if previous, ok := c.lastRPM[fan.ID]; ok &&
			absInt(previous-target) <= fanTargetTolerance(c.settings.Mode) {
			continue
		}
		if err := c.hardware.SetTarget(fan.ID, target); err != nil {
			return 0, nil, c.fail(err)
		}
		writtenTargets[fan.ID] = target
	}
	for _, fan := range sample.Fans {
		if _, alreadyManaged := c.lastRPM[fan.ID]; alreadyManaged {
			continue
		}
		if err := c.hardware.SetMode(fan.ID, 1); err != nil {
			return 0, nil, c.fail(err)
		}
	}
	// Apple Silicon can accept the target write but leave F<n>Tg unchanged
	// until manual mode is active. Repeat only each new target after the mode
	// transition. The first write still prevents a stale target when hardware
	// accepts target-before-mode; the second makes the transition effective on
	// machines that require manual mode first.
	for _, fan := range sample.Fans {
		target, newlyManaged := writtenTargets[fan.ID]
		if !newlyManaged {
			continue
		}
		if _, wasManaged := c.lastRPM[fan.ID]; wasManaged {
			continue
		}
		if err := c.hardware.SetTarget(fan.ID, target); err != nil {
			return 0, nil, c.fail(err)
		}
	}
	for id, rpm := range writtenTargets {
		c.lastRPM[id] = rpm
	}
	return temperature, targets, nil
}

func absInt(value int) int {
	if value < 0 {
		return -value
	}
	return value
}

func formatFanPolicySample(temperature float64, targets map[int]int, dryRun bool) string {
	mode := "active"
	if dryRun {
		mode = "dry-run"
	}
	parts := make([]string, 0, len(targets))
	for fanID := 0; fanID < 8; fanID++ {
		if rpm, ok := targets[fanID]; ok {
			parts = append(parts, fmt.Sprintf("fan %d=%d RPM", fanID, rpm))
		}
	}
	return fmt.Sprintf("fan policy %s: CPU P-core %.1f C; %s", mode, temperature, strings.Join(parts, ", "))
}

func acquireFanControlLock(path string) (*os.File, error) {
	lock, err := os.OpenFile(path, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return nil, err
	}
	if err := syscall.Flock(int(lock.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
		_ = lock.Close()
		return nil, errors.New("another mactop fan control process is already running")
	}
	return lock, nil
}

func runFanPolicy(dryRun bool) (runErr error) {
	if fanPolicy && fanPolicyDryRun {
		return errors.New("use only one of --fan-policy and --fan-policy-dry-run")
	}
	if fanControl || fanReset || menubar || menubarWorker || overlay || overlayWorker || headless ||
		dumpTemps || dumpDebug || dumpFPS || prometheusPort != "" {
		return errors.New("fan policy cannot run with another operating mode")
	}
	if !dryRun && !fanControlHasRoot() {
		return errors.New("fan policy requires root; run sudo mactop --fan-policy")
	}
	if err := initSocMetrics(); err != nil {
		return err
	}
	defer cleanupSocMetrics()

	var lock *os.File
	if !dryRun {
		var err error
		lock, err = acquireFanControlLock(fanControlLockPath)
		if err != nil {
			return err
		}
		defer lock.Close()
	}

	sysInfo := getSOCInfo()
	if dryRun {
		sample := normalizeSocMetricsPower(sampleSocMetrics(int(fanPolicySampleTime / time.Millisecond)))
		temperature, targets, err := evaluateFanPolicy(sample, sysInfo, fixedFanCurve())
		if err != nil {
			return err
		}
		fmt.Println(formatFanPolicySample(temperature, targets, true))
		return nil
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM, syscall.SIGHUP)
	defer stop()
	controller := newFanPolicyController(smcFanPolicyHardware{context: ctx})
	defer func() {
		if recovered := recover(); recovered != nil {
			runErr = errors.Join(fmt.Errorf("fan policy panic: %v", recovered), controller.Close())
			return
		}
		runErr = errors.Join(runErr, controller.Close())
	}()

	for {
		sample := normalizeSocMetricsPower(sampleSocMetrics(int(fanPolicySampleTime / time.Millisecond)))
		if ctx.Err() != nil {
			return nil
		}
		temperature, targets, err := controller.apply(sample, sysInfo)
		if err != nil {
			return err
		}
		fmt.Println(formatFanPolicySample(temperature, targets, false))

		select {
		case <-ctx.Done():
			return nil
		case <-time.After(fanPolicyInterval):
		}
	}
}

func prepareFanReset(lockPath string, hasRoot bool) (*os.File, error) {
	if fanControl || fanPolicy || fanPolicyDryRun || menubar || menubarWorker || overlay || overlayWorker || headless ||
		dumpTemps || dumpDebug || dumpFPS || prometheusPort != "" {
		return nil, errors.New("fan reset cannot run with another operating mode")
	}
	if !hasRoot {
		return nil, errors.New("fan reset requires root; run sudo mactop --fan-reset")
	}
	return acquireFanControlLock(lockPath)
}

func runFanReset() error {
	lock, err := prepareFanReset(fanControlLockPath, fanControlHasRoot())
	if err != nil {
		return err
	}
	defer lock.Close()
	if err := initSocMetrics(); err != nil {
		return err
	}
	defer cleanupSocMetrics()
	return resetFansAndClearPolicy(fileFanPolicyStore{
		path: fanHelperStatePath, ownerUID: 0, ownerGID: 0,
	}, ResetFansToAuto)
}

func resetFansAndClearPolicy(store fanPolicyStore, reset func() error) error {
	// Clear the desired manual policy before changing hardware. If cleanup is
	// interrupted, the helper will still start in Apple Default next time.
	if err := store.Save(defaultFanPolicySettings()); err != nil {
		return fmt.Errorf("could not clear saved fan control: %w", err)
	}
	return reset()
}
