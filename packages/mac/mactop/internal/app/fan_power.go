package app

/*
#cgo LDFLAGS: -framework IOKit

int mactopStartFanPowerNotifications(void);
void mactopStopFanPowerNotifications(void);
*/
import "C"

import (
	"fmt"
	"sync"
)

type fanPowerEvent uint8

const (
	fanPowerEventSleep fanPowerEvent = iota + 1
	fanPowerEventWake
)

var (
	fanPowerNotificationStartMu sync.Mutex
	fanPowerNotificationStarted bool
	fanPowerEvents              = make(chan fanPowerEvent, 8)
)

// startFanPowerNotifications registers the root helper for system sleep and
// wake events. The native registration remains valid until the helper stops it.
func startFanPowerNotifications() (<-chan fanPowerEvent, error) {
	fanPowerNotificationStartMu.Lock()
	defer fanPowerNotificationStartMu.Unlock()

	if fanPowerNotificationStarted {
		return fanPowerEvents, nil
	}
	if C.mactopStartFanPowerNotifications() != 0 {
		return nil, fmt.Errorf("could not register for system power notifications")
	}
	fanPowerNotificationStarted = true
	return fanPowerEvents, nil
}

func stopFanPowerNotifications() {
	fanPowerNotificationStartMu.Lock()
	defer fanPowerNotificationStartMu.Unlock()
	if !fanPowerNotificationStarted {
		return
	}
	C.mactopStopFanPowerNotifications()
	fanPowerNotificationStarted = false
}

//export goFanHelperPowerEvent
func goFanHelperPowerEvent(event C.int) {
	switch fanPowerEvent(event) {
	case fanPowerEventSleep, fanPowerEventWake:
		select {
		case fanPowerEvents <- fanPowerEvent(event):
		default:
			// Sleep and wake notifications are advisory. A full channel must not
			// delay macOS power management. The active policy remains responsible
			// for safe fallback when an event cannot be queued.
		}
	}
}
