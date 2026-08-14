package app

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

func TestFanHelperWakeKeepsVerifiedManualPolicy(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.setCommonRPMRange(1000, 5000, nil)
	service.resetFunc = func() error { return nil }
	diagnostics := configureFanHelperDiagnosticRecording(service)

	started := make(chan fanPolicyRunSource, 2)
	stopped := make(chan struct{}, 1)
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		started <- fanPolicySourceFromContext(ctx)
		service.setStatus("active", 40, map[int]int{0: 2200}, "")
		<-ctx.Done()
		stopped <- struct{}{}
		service.setStatus("off", 0, nil, "")
		return nil
	}

	service.handle(fanHelperRequest{
		Protocol: fanHelperProtocolVersion, Command: "configure", Mode: fanModeConstant, ConstantRPM: 2200,
	})
	if source := <-started; source != fanPolicyRunSourceManual {
		t.Fatalf("initial policy source = %d, want manual", source)
	}
	waitForHelperState(t, service, "active")

	service.recordSleepForWakeRecovery()
	wakeDone := service.scheduleWakeRecovery()
	service.recordPolicyVerification()
	requireFanDiagnosticEvent(t, diagnostics, "wake_reapply_skipped", "manual_policy_still_verified")
	waitForWakeRecovery(t, wakeDone)

	select {
	case <-stopped:
		t.Fatal("wake recovery stopped a verified policy")
	case source := <-started:
		t.Fatalf("wake recovery started %d while the policy remained verified", source)
	default:
	}
	if status := service.reset(); status.State != "off" {
		t.Fatalf("reset status = %+v", status)
	}
}

func TestFanHelperWakeReappliesOnlyAfterManualOwnershipLoss(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.resetFunc = func() error { return nil }
	configureFanHelperDiagnosticRecording(service)
	service.settings = fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200}

	started := make(chan fanPolicyRunSource, 1)
	var runs atomic.Int32
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		if runs.Add(1) == 1 {
			return fanManualOwnershipLostError{fanID: 0}
		}
		started <- fanPolicySourceFromContext(ctx)
		service.setStatus("active", 40, map[int]int{0: 2200}, "")
		<-ctx.Done()
		service.setStatus("off", 0, nil, "")
		return nil
	}

	service.enable()
	waitForHelperState(t, service, "error")
	service.handlePowerEvent(fanPowerEventSleep)
	service.handlePowerEvent(fanPowerEventWake)
	select {
	case source := <-started:
		if source != fanPolicyRunSourceWakeRecovery {
			t.Fatalf("wake policy source = %d, want wake recovery", source)
		}
	case <-time.After(time.Second):
		t.Fatal("wake recovery did not start after manual ownership loss")
	}
	if status := service.reset(); status.State != "off" {
		t.Fatalf("reset status = %+v", status)
	}
}

func TestFanHelperWakeWaitsForPostWakeOwnershipLossBeforeOneReapply(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.setCommonRPMRange(1000, 5000, nil)
	service.resetFunc = func() error { return nil }
	diagnostics := configureFanHelperDiagnosticRecording(service)

	initialPolicyFailure := make(chan struct{})
	started := make(chan fanPolicyRunSource, 2)
	var runs atomic.Int32
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		run := runs.Add(1)
		source := fanPolicySourceFromContext(ctx)
		started <- source
		if run == 1 {
			service.setStatus("active", 40, map[int]int{0: 2200}, "")
			select {
			case <-ctx.Done():
				return nil
			case <-initialPolicyFailure:
				return fanManualOwnershipLostError{fanID: 0}
			}
		}
		service.setStatus("active", 40, map[int]int{0: 2200}, "")
		<-ctx.Done()
		service.setStatus("off", 0, nil, "")
		return nil
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	if source := <-started; source != fanPolicyRunSourceManual {
		t.Fatalf("initial policy source = %d, want manual", source)
	}
	waitForHelperState(t, service, "active")
	service.handlePowerEvent(fanPowerEventSleep)
	service.handlePowerEvent(fanPowerEventWake)
	if runs.Load() != 1 {
		t.Fatalf("recovery started before post-wake ownership loss: %d runs", runs.Load())
	}

	close(initialPolicyFailure)
	select {
	case source := <-started:
		if source != fanPolicyRunSourceWakeRecovery {
			t.Fatalf("recovery source = %d, want wake recovery", source)
		}
	case <-time.After(time.Second):
		t.Fatal("manual ownership loss did not start one wake recovery")
	}
	requireFanDiagnosticEvent(t, diagnostics, "wake_reapply_started", "")
	if runs.Load() != 2 {
		t.Fatalf("wake recovery runs = %d, want 2", runs.Load())
	}
	if status := service.reset(); status.State != "off" {
		t.Fatalf("reset status = %+v", status)
	}
}

func TestFanHelperWakeDoesNotRetryGeneralPolicyFailure(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.settings = fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200}
	var starts atomic.Int32
	service.runPolicyFunc = func(context.Context, fanPolicySettings) error {
		if starts.Add(1) == 1 {
			return errors.New("CPU P-core sensor unavailable")
		}
		return errors.New("wake recovery unexpectedly started")
	}

	service.enable()
	waitForHelperState(t, service, "error")
	service.recordSleepForWakeRecovery()
	if wakeDone := service.scheduleWakeRecovery(); wakeDone != nil {
		t.Fatal("general policy failure scheduled wake recovery")
	}
	if starts.Load() != 1 {
		t.Fatalf("wake recovery started %d policies after a general policy failure", starts.Load()-1)
	}
}

func TestFanHelperWakeRecoveryRequiresMatchedSleepEvent(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.settings = fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200}
	service.manualLost = true
	var starts atomic.Int32
	service.runPolicyFunc = func(context.Context, fanPolicySettings) error {
		starts.Add(1)
		return nil
	}

	if wakeDone := service.scheduleWakeRecovery(); wakeDone != nil {
		t.Fatal("wake without a preceding sleep scheduled recovery")
	}
	if starts.Load() != 0 {
		t.Fatalf("wake without a preceding sleep started %d recovery policies", starts.Load())
	}
}

func TestServeFanHelperPowerEventsDeliversSleepBeforeWake(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.resetFunc = func() error { return nil }
	service.settings = fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200}
	service.manualLost = true

	started := make(chan fanPolicyRunSource, 1)
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		started <- fanPolicySourceFromContext(ctx)
		<-ctx.Done()
		return nil
	}

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	events := make(chan fanPowerEvent, 2)
	done := make(chan struct{})
	go func() {
		defer close(done)
		serveFanHelperPowerEvents(ctx, service, events)
	}()
	events <- fanPowerEventSleep
	events <- fanPowerEventWake

	select {
	case source := <-started:
		if source != fanPolicyRunSourceWakeRecovery {
			t.Fatalf("power-event recovery source = %d, want wake recovery", source)
		}
	case <-time.After(time.Second):
		t.Fatal("power-event loop did not deliver the paired sleep and wake events")
	}
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("power-event loop did not stop after cancellation")
	}
	if status := service.reset(); status.State != "off" {
		t.Fatalf("reset status = %+v", status)
	}
}

func TestFanHelperWakeRecoveryCancelsStaleSameSettingsJob(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.setCommonRPMRange(1000, 5000, nil)
	service.resetFunc = func() error { return nil }
	diagnostics := configureFanHelperDiagnosticRecording(service)

	started := make(chan fanPolicyRunSource, 2)
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		started <- fanPolicySourceFromContext(ctx)
		service.setStatus("active", 40, map[int]int{0: 2200}, "")
		<-ctx.Done()
		service.setStatus("off", 0, nil, "")
		return nil
	}
	settings := fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200}
	service.configure(settings)
	<-started
	waitForHelperState(t, service, "active")

	service.recordSleepForWakeRecovery()
	wakeDone := service.scheduleWakeRecovery()
	if status := service.configure(settings); status.State != "active" {
		t.Fatalf("same-policy configure status = %+v", status)
	}
	service.recordPolicyVerification()
	waitForWakeRecovery(t, wakeDone)
	select {
	case source := <-started:
		t.Fatalf("stale wake job started %d", source)
	default:
	}
	for {
		select {
		case event := <-diagnostics.events:
			if event.Event == "wake_reapply_started" {
				t.Fatal("stale wake job started a recovery")
			}
		default:
			if status := service.reset(); status.State != "off" {
				t.Fatalf("reset status = %+v", status)
			}
			return
		}
	}
}

func TestFanHelperWakeRecoveryUsesOnlyTheLatestWakeGeneration(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.setCommonRPMRange(1000, 5000, nil)
	service.resetFunc = func() error { return nil }
	diagnostics := configureFanHelperDiagnosticRecording(service)

	started := make(chan fanPolicyRunSource, 2)
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		started <- fanPolicySourceFromContext(ctx)
		service.setStatus("active", 40, map[int]int{0: 2200}, "")
		<-ctx.Done()
		service.setStatus("off", 0, nil, "")
		return nil
	}
	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	<-started
	waitForHelperState(t, service, "active")

	service.recordSleepForWakeRecovery()
	firstWakeDone := service.scheduleWakeRecovery()
	service.recordSleepForWakeRecovery()
	secondWakeDone := service.scheduleWakeRecovery()
	service.recordPolicyVerification()
	requireFanDiagnosticEvent(t, diagnostics, "wake_reapply_skipped", "manual_policy_still_verified")
	waitForWakeRecovery(t, firstWakeDone)
	waitForWakeRecovery(t, secondWakeDone)

	skipped := 0
	for {
		select {
		case event := <-diagnostics.events:
			if event.Event == "wake_reapply_skipped" {
				skipped++
			}
		default:
			if skipped != 0 {
				t.Fatalf("wake recovery recorded %d duplicate skip events", skipped)
			}
			if status := service.reset(); status.State != "off" {
				t.Fatalf("reset status = %+v", status)
			}
			return
		}
	}
}

func TestFanHelperWakeRecoveryCancelsWhenAppleDefaultIsSelected(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.setCommonRPMRange(1000, 5000, nil)
	service.resetFunc = func() error { return nil }

	started := make(chan fanPolicyRunSource, 2)
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		started <- fanPolicySourceFromContext(ctx)
		service.setStatus("active", 40, map[int]int{0: 2200}, "")
		<-ctx.Done()
		service.setStatus("off", 0, nil, "")
		return nil
	}
	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	<-started
	waitForHelperState(t, service, "active")

	service.recordSleepForWakeRecovery()
	wakeDone := service.scheduleWakeRecovery()
	if status := service.configure(defaultFanPolicySettings()); status.State != "off" {
		t.Fatalf("Apple Default status = %+v", status)
	}
	service.recordPolicyVerification()
	waitForWakeRecovery(t, wakeDone)
	select {
	case source := <-started:
		t.Fatalf("Apple Default allowed a stale wake recovery %d", source)
	default:
	}
}

func TestFanHelperWakeRecoveryIgnoresCanceledJobDuringShutdown(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.settings = fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200}
	service.manualLost = true
	var starts atomic.Int32
	service.runPolicyFunc = func(context.Context, fanPolicySettings) error {
		starts.Add(1)
		return nil
	}

	service.commandMu.Lock()
	service.recordSleepForWakeRecovery()
	wakeDone := service.scheduleWakeRecovery()
	service.beginShutdown()
	service.commandMu.Unlock()
	waitForWakeRecovery(t, wakeDone)
	if starts.Load() != 0 {
		t.Fatalf("shutdown allowed %d wake recovery starts", starts.Load())
	}
}

func TestFanHelperWakeRecoveryReportsFailedReapply(t *testing.T) {
	service, _ := newTestFanHelperService()
	service.settings = fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200}
	service.manualLost = true
	service.setStatus("error", 0, nil, "fan 0 did not enter manual mode")
	diagnostics := configureFanHelperDiagnosticRecording(service)
	var starts atomic.Int32
	service.runPolicyFunc = func(context.Context, fanPolicySettings) error {
		starts.Add(1)
		return errors.New("fan control did not become ready after wake")
	}

	service.handlePowerEvent(fanPowerEventSleep)
	service.handlePowerEvent(fanPowerEventWake)
	requireFanDiagnosticEvent(t, diagnostics, "wake_reapply_failed", "")
	waitForHelperState(t, service, "error")
	if starts.Load() != 1 {
		t.Fatalf("failed wake recovery started %d policies, want one", starts.Load())
	}
}

func requireFanDiagnosticEvent(t *testing.T, diagnostics *recordedFanHelperDiagnostics, name, reason string) {
	t.Helper()
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		select {
		case event := <-diagnostics.events:
			if event.Event == name && event.Reason == reason {
				return
			}
		case <-time.After(time.Millisecond):
		}
	}
	t.Fatalf("did not record diagnostic %q with reason %q", name, reason)
}

func waitForWakeRecovery(t *testing.T, done <-chan struct{}) {
	t.Helper()
	if done == nil {
		t.Fatal("wake recovery was not scheduled")
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("wake recovery did not finish")
	}
}
