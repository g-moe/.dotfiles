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
	fanUnlockAttempts   = 100
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

	directErr := hardware.WriteMode(fanID, mode)
	if directErr == nil {
		return nil
	}
	if err := check(); err != nil {
		return err
	}
	if err := hardware.WriteForceTest(true); err != nil {
		return errors.Join(directErr, fmt.Errorf("could not unlock fan control: %w", err))
	}

	if err := wait(fanUnlockSettleTime); err != nil {
		return errors.Join(err, hardware.WriteForceTest(false))
	}
	var retryErr error
	for attempt := 0; attempt < fanUnlockAttempts; attempt++ {
		if err := check(); err != nil {
			return errors.Join(err, hardware.WriteForceTest(false))
		}
		retryErr = hardware.WriteMode(fanID, mode)
		if retryErr == nil {
			return nil
		}
		if attempt+1 < fanUnlockAttempts {
			if err := wait(fanUnlockRetryTime); err != nil {
				return errors.Join(err, hardware.WriteForceTest(false))
			}
		}
	}

	resetErr := hardware.WriteForceTest(false)
	return errors.Join(
		directErr,
		fmt.Errorf("fan %d did not enter manual mode after the force-test unlock: %w", fanID, retryErr),
		resetErr,
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
