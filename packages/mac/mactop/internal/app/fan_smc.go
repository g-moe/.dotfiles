package app

import (
	"context"
	"errors"
	"fmt"
	"time"
)

const (
	fanUnlockSettleTime = 500 * time.Millisecond
	fanUnlockRetryTime  = 100 * time.Millisecond
	fanUnlockAttempts   = 300
	fanResetAttempts    = 50
)

var errFanForceTestUnavailable = errors.New("fan force-test key is unavailable")

type fanModeHardware interface {
	ReadMode(int) (int, error)
	WriteMode(int, int) error
	ReadForceTest() (int, error)
	WriteForceTest(bool) error
}

type nativeFanModeHardware struct{}

type fanWait func(time.Duration) error
type fanControlCheck func() error

func fansHaveManualMode(fans []FanInfo) bool {
	for _, fan := range fans {
		if fan.Mode == 1 {
			return true
		}
	}
	return false
}

func (nativeFanModeHardware) ReadMode(fanID int) (int, error) {
	return readNativeFanMode(fanID)
}

func (nativeFanModeHardware) WriteMode(fanID, mode int) error {
	return writeNativeFanMode(fanID, mode)
}

func (nativeFanModeHardware) ReadForceTest() (int, error) {
	return readNativeFanForceTest()
}

func (nativeFanModeHardware) WriteForceTest(enabled bool) error {
	return SetFanForceTest(enabled)
}

func sleepForFanControl(delay time.Duration) error {
	time.Sleep(delay)
	return nil
}

func waitForFanControlContext(ctx context.Context) fanWait {
	return func(delay time.Duration) error {
		timer := time.NewTimer(delay)
		defer timer.Stop()
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-timer.C:
			return nil
		}
	}
}

func noFanControlCheck() error { return nil }

func checkFanControlContext(ctx context.Context) fanControlCheck {
	if ctx == nil {
		return noFanControlCheck
	}
	return ctx.Err
}

// setFanModeWithHardware moves one fan into manual (1) or automatic (0) mode.
// Manual mode always holds Ftst first when the SMC exposes it.
// Without Ftst, Apple Silicon can accept the mode write and then hand the fan back to the system seconds later.
// Fans starting from zero RPM can reject mode writes until they spin up, so writes retry for the full unlock window.
func setFanModeWithHardware(hardware fanModeHardware, fanID, mode int, wait fanWait, check fanControlCheck) error {
	if mode == 0 {
		return hardware.WriteMode(fanID, mode)
	}
	if check == nil {
		check = noFanControlCheck
	}
	if err := check(); err != nil {
		return err
	}

	// Hold Ftst for the manual session, or continue without it on hardware that has no Ftst key
	forceTest, forceTestErr := hardware.ReadForceTest()
	forceTestAvailable := !errors.Is(forceTestErr, errFanForceTestUnavailable)
	if forceTestErr != nil && forceTestAvailable {
		return forceTestErr
	}
	clearForceTest := func() error { return nil }
	if forceTestAvailable && forceTest == 0 {
		if err := hardware.WriteForceTest(true); err != nil {
			return fmt.Errorf("could not unlock fan control: %w", err)
		}
		clearForceTest = func() error { return hardware.WriteForceTest(false) }
		if err := wait(fanUnlockSettleTime); err != nil {
			return errors.Join(err, clearForceTest())
		}
	}

	// Retry the mode write until the fan accepts it
	var modeErr error
	for attempt := 0; attempt < fanUnlockAttempts; attempt++ {
		if err := check(); err != nil {
			return errors.Join(err, clearForceTest())
		}
		modeErr = hardware.WriteMode(fanID, mode)
		if modeErr == nil {
			return nil
		}
		if attempt+1 < fanUnlockAttempts {
			if err := wait(fanUnlockRetryTime); err != nil {
				return errors.Join(err, clearForceTest())
			}
		}
	}

	return errors.Join(
		fmt.Errorf("fan %d did not enter manual mode: %w", fanID, modeErr),
		clearForceTest(),
	)
}

func resetFansToAutoWithHardware(hardware fanModeHardware, fans []FanInfo, wait fanWait) error {
	if len(fans) == 0 {
		return errors.New("no fans were found")
	}

	for _, fan := range fans {
		mode, err := hardware.ReadMode(fan.ID)
		if err != nil {
			return err
		}
		if mode == 1 {
			// Continue to the force-test reset if this write is rejected. Once
			// force-test mode is off, macOS can still reclaim the fan safely.
			_ = hardware.WriteMode(fan.ID, 0)
		}
	}

	forceTest, forceTestErr := hardware.ReadForceTest()
	if forceTestErr == nil && forceTest != 0 {
		if err := hardware.WriteForceTest(false); err != nil {
			return fmt.Errorf("could not return fan control to macOS: %w", err)
		}
	} else if forceTestErr != nil && !errors.Is(forceTestErr, errFanForceTestUnavailable) {
		return forceTestErr
	}

	for attempt := 0; attempt < fanResetAttempts; attempt++ {
		allAutomatic := true
		for _, fan := range fans {
			mode, err := hardware.ReadMode(fan.ID)
			if err != nil {
				return err
			}
			// Apple automatic mode is 0 on older hardware. Apple Silicon can
			// report 3 while thermalmonitord owns the fan. Only 1 is manual.
			if mode == 1 {
				allAutomatic = false
			}
		}
		if allAutomatic {
			return nil
		}
		if attempt+1 < fanResetAttempts {
			if err := wait(fanUnlockRetryTime); err != nil {
				return err
			}
		}
	}
	return errors.New("fans remained in manual mode after control returned to macOS")
}
