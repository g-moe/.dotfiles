package app

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

func newSleepResumeTestService() (*fanHelperService, *recordedFanHelperDiagnostics) {
	service, _ := newTestFanHelperService()
	service.setCommonRPMRange(1000, 5000, nil)
	service.resetFunc = func() error { return nil }
	return service, configureFanHelperDiagnosticRecording(service)
}

func TestFanHelperSleepSuspendsActivePolicyAndResumesOnce(t *testing.T) {
	service, diagnostics := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 2)
	manualActive := make(chan struct{})
	manualStopped := make(chan struct{})
	resumeVerified := make(chan struct{})
	resumeStopped := make(chan struct{})
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		source := fanPolicySourceFromContext(ctx)
		started <- source
		service.setStatus("active", 40, map[int]int{0: 2200}, "")
		if source == fanPolicyRunSourceManual {
			close(manualActive)
		}
		if source == fanPolicyRunSourceWakeResume {
			if !service.finishWakeResume(fanPolicyGenerationFromContext(ctx)) {
				return errors.New("wake resume became invalid before verification")
			}
			close(resumeVerified)
			<-ctx.Done()
			close(resumeStopped)
			return nil
		}
		<-ctx.Done()
		close(manualStopped)
		return nil
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	waitForFanSignal(t, manualActive, "manual policy did not become active")
	service.suspendForSleep()
	waitForFanSignal(t, manualStopped, "manual policy did not stop for sleep")
	if status := service.status(); status.State != "suspended" || status.Mode != fanModeConstant {
		t.Fatalf("suspended status = %+v", status)
	}
	requireFanDiagnosticEvent(t, diagnostics, "policy_suspend_requested", "sleep")

	resumeDone := service.scheduleWakeResume()
	requireFanPolicySource(t, started, fanPolicyRunSourceWakeResume)
	waitForWakeResume(t, resumeDone)
	waitForFanSignal(t, resumeVerified, "resumed policy did not verify")
	requireFanDiagnosticEvent(t, diagnostics, "wake_resume_queued", "")
	requireFanDiagnosticEvent(t, diagnostics, "wake_resume_started", "")

	if status := service.reset(); status.State != "off" {
		t.Fatalf("reset status = %+v", status)
	}
	waitForFanSignal(t, resumeStopped, "resumed policy did not stop")
}

func TestFanHelperWakeWaitsForSuspendedPolicyCleanup(t *testing.T) {
	service, _ := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 2)
	manualCancelled := make(chan struct{})
	allowManualStop := make(chan struct{})
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		source := fanPolicySourceFromContext(ctx)
		started <- source
		if source == fanPolicyRunSourceManual {
			<-ctx.Done()
			close(manualCancelled)
			<-allowManualStop
			return nil
		}
		<-ctx.Done()
		return nil
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.suspendForSleep()
	waitForFanSignal(t, manualCancelled, "manual policy did not receive sleep cancellation")
	resumeDone := service.scheduleWakeResume()
	if resumeDone == nil {
		t.Fatal("wake did not queue a resume")
	}

	close(allowManualStop)
	requireFanPolicySource(t, started, fanPolicyRunSourceWakeResume)
	waitForWakeResume(t, resumeDone)
	service.reset()
}

func TestFanHelperIdenticalSettingsReplaceQueuedWakeResume(t *testing.T) {
	service, store := newTestFanHelperService()
	service.setCommonRPMRange(1000, 5000, nil)
	service.resetFunc = func() error { return nil }
	started := make(chan fanPolicyRunSource, 2)
	manualCancelled := make(chan struct{})
	allowManualStop := make(chan struct{})
	resumedStopped := make(chan struct{})
	defaultSaved := make(chan struct{})
	var manualRuns atomic.Int32
	store.saveFunc = func(settings fanPolicySettings) error {
		if settings.Mode == fanModeDefault {
			close(defaultSaved)
		}
		return nil
	}
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		source := fanPolicySourceFromContext(ctx)
		started <- source
		if source == fanPolicyRunSourceManual && manualRuns.Add(1) == 1 {
			select {
			case <-ctx.Done():
				close(manualCancelled)
				<-allowManualStop
				return nil
			case <-time.After(time.Second):
				return errors.New("manual policy did not receive sleep cancellation")
			}
		}
		<-ctx.Done()
		close(resumedStopped)
		return nil
	}

	settings := fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200}
	service.configure(settings)
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.suspendForSleep()
	waitForFanSignal(t, manualCancelled, "manual policy did not receive sleep cancellation")
	resumeDone := service.scheduleWakeResume()
	if resumeDone == nil {
		t.Fatal("wake did not queue a resume")
	}
	service.commandMu.Lock()
	configured := make(chan fanHelperStatus, 1)
	go func() { configured <- service.configure(settings) }()
	waitForFanSignal(t, defaultSaved, "identical configuration did not replace saved policy")
	close(allowManualStop)
	if status := <-configured; status.State != "starting" {
		t.Fatalf("identical settings during resume = %+v", status)
	}
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.commandMu.Unlock()
	waitForWakeResume(t, resumeDone)
	service.reset()
	waitForFanSignal(t, resumedStopped, "replacement policy did not stop")
}

func TestFanHelperReSleepDuringCanceledResumeSetupKeepsNextWake(t *testing.T) {
	service, _ := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 3)
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		source := fanPolicySourceFromContext(ctx)
		started <- source
		<-ctx.Done()
		if source == fanPolicyRunSourceWakeResume {
			return ctx.Err()
		}
		return nil
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.suspendForSleep()
	firstResume := service.scheduleWakeResume()
	requireFanPolicySource(t, started, fanPolicyRunSourceWakeResume)
	waitForWakeResume(t, firstResume)

	service.suspendForSleep()
	secondResume := service.scheduleWakeResume()
	requireFanPolicySource(t, started, fanPolicyRunSourceWakeResume)
	waitForWakeResume(t, secondResume)
	service.reset()
}

func TestFanHelperSleepDuringConfigurationResumesSavedPolicy(t *testing.T) {
	service, store := newTestFanHelperService()
	service.setCommonRPMRange(1000, 5000, nil)
	service.resetFunc = func() error { return nil }
	saveStarted := make(chan struct{})
	allowSave := make(chan struct{})
	store.saveFunc = func(settings fanPolicySettings) error {
		if settings.Mode == fanModeConstant {
			close(saveStarted)
			<-allowSave
		}
		return nil
	}
	started := make(chan fanPolicyRunSource, 1)
	stopped := make(chan struct{})
	resumeVerified := make(chan struct{})
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		source := fanPolicySourceFromContext(ctx)
		started <- source
		if source == fanPolicyRunSourceWakeResume {
			if !service.finishWakeResume(fanPolicyGenerationFromContext(ctx)) {
				return errors.New("wake resume became invalid before verification")
			}
			close(resumeVerified)
		}
		<-ctx.Done()
		close(stopped)
		return nil
	}

	configured := make(chan fanHelperStatus, 1)
	go func() {
		configured <- service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	}()
	waitForFanSignal(t, saveStarted, "manual configuration did not reach persistent storage")
	service.suspendForSleep()
	close(allowSave)
	status := <-configured
	if status.State != "suspended" || status.Mode != fanModeConstant {
		t.Fatalf("configuration during sleep = %+v", status)
	}
	ensureNoFanPolicyStart(t, started)

	resumeDone := service.scheduleWakeResume()
	requireFanPolicySource(t, started, fanPolicyRunSourceWakeResume)
	waitForWakeResume(t, resumeDone)
	waitForFanSignal(t, resumeVerified, "resumed policy did not verify")
	service.reset()
	waitForFanSignal(t, stopped, "resumed policy did not stop")
}

func TestFanHelperReSleepCancelsResumeBeforeAnyWrite(t *testing.T) {
	service, diagnostics := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 2)
	resumeCancelled := make(chan struct{})
	allowWrite := make(chan struct{})
	var writes atomic.Int32
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		source := fanPolicySourceFromContext(ctx)
		started <- source
		if source == fanPolicyRunSourceManual {
			<-ctx.Done()
			return nil
		}
		<-ctx.Done()
		close(resumeCancelled)
		<-allowWrite
		if ctx.Err() == nil {
			writes.Add(1)
		}
		return nil
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.suspendForSleep()
	resumeDone := service.scheduleWakeResume()
	requireFanPolicySource(t, started, fanPolicyRunSourceWakeResume)
	waitForWakeResume(t, resumeDone)

	service.suspendForSleep()
	waitForFanSignal(t, resumeCancelled, "resume policy did not stop for re-sleep")
	close(allowWrite)
	if writes.Load() != 0 {
		t.Fatalf("resume performed %d writes after re-sleep", writes.Load())
	}
	requireFanDiagnosticEvent(t, diagnostics, "wake_resume_cancelled", "sleep")
	service.reset()
}

func TestFanHelperWakeResumeUsesOnlyLatestSleepGeneration(t *testing.T) {
	service, _ := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 3)
	manualCancelled := make(chan struct{})
	allowManualStop := make(chan struct{})
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		source := fanPolicySourceFromContext(ctx)
		started <- source
		if source == fanPolicyRunSourceManual {
			<-ctx.Done()
			close(manualCancelled)
			<-allowManualStop
			return nil
		}
		<-ctx.Done()
		return nil
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.suspendForSleep()
	waitForFanSignal(t, manualCancelled, "manual policy did not receive first sleep cancellation")
	firstResume := service.scheduleWakeResume()
	service.suspendForSleep()
	secondResume := service.scheduleWakeResume()
	close(allowManualStop)
	waitForWakeResume(t, firstResume)
	waitForWakeResume(t, secondResume)
	requireFanPolicySource(t, started, fanPolicyRunSourceWakeResume)
	service.reset()
}

func TestFanHelperAppleDefaultCancelsPendingResume(t *testing.T) {
	service, _ := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 1)
	manualCancelled := make(chan struct{})
	allowManualStop := make(chan struct{})
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		started <- fanPolicySourceFromContext(ctx)
		<-ctx.Done()
		close(manualCancelled)
		<-allowManualStop
		return nil
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.suspendForSleep()
	waitForFanSignal(t, manualCancelled, "manual policy did not receive sleep cancellation")
	close(allowManualStop)
	waitForHelperState(t, service, "suspended")
	if status := service.configure(defaultFanPolicySettings()); status.State != "off" {
		t.Fatalf("Apple Default status = %+v", status)
	}
	if resumeDone := service.scheduleWakeResume(); resumeDone != nil {
		t.Fatal("Apple Default queued a wake resume")
	}
}

func TestFanHelperShutdownCancelsQueuedResume(t *testing.T) {
	service, _ := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 2)
	manualCancelled := make(chan struct{})
	allowManualStop := make(chan struct{})
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		started <- fanPolicySourceFromContext(ctx)
		<-ctx.Done()
		close(manualCancelled)
		<-allowManualStop
		return nil
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.suspendForSleep()
	waitForFanSignal(t, manualCancelled, "manual policy did not receive sleep cancellation")
	resumeDone := service.scheduleWakeResume()
	service.beginShutdown()
	close(allowManualStop)
	waitForWakeResume(t, resumeDone)
	ensureNoFanPolicyStart(t, started)
}

func TestFanHelperWakeDoesNotResumeAfterPolicyCleanupFailure(t *testing.T) {
	service, diagnostics := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 2)
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		started <- fanPolicySourceFromContext(ctx)
		<-ctx.Done()
		return errors.New("could not restore automatic fan control")
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.suspendForSleep()
	resumeDone := service.scheduleWakeResume()
	waitForWakeResume(t, resumeDone)
	waitForHelperState(t, service, "error")
	ensureNoFanPolicyStart(t, started)
	requireFanDiagnosticEvent(t, diagnostics, "wake_resume_cancelled", "policy_cleanup_failed")
}

func TestFanHelperDoesNotResumeAfterNonSleepFailure(t *testing.T) {
	service, _ := newSleepResumeTestService()
	var starts atomic.Int32
	service.runPolicyFunc = func(context.Context, fanPolicySettings) error {
		starts.Add(1)
		return errors.New("CPU P-core sensor unavailable")
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	waitForHelperState(t, service, "error")
	service.handlePowerEvent(fanPowerEventSleep)
	service.handlePowerEvent(fanPowerEventWake)
	if starts.Load() != 1 {
		t.Fatalf("sleep retried a non-sleep failure: %d starts", starts.Load())
	}
}

func TestFanHelperWakeResumeFailureOnlyAppliesBeforeVerification(t *testing.T) {
	service, diagnostics := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 2)
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		source := fanPolicySourceFromContext(ctx)
		started <- source
		if source == fanPolicyRunSourceManual {
			<-ctx.Done()
			return nil
		}
		return errors.New("fan control did not become ready after wake")
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.suspendForSleep()
	resumeDone := service.scheduleWakeResume()
	requireFanPolicySource(t, started, fanPolicyRunSourceWakeResume)
	waitForWakeResume(t, resumeDone)
	waitForHelperState(t, service, "error")
	requireFanDiagnosticEvent(t, diagnostics, "wake_resume_failed", "")
}

func TestFanHelperLatePolicyFailureIsNotWakeResumeFailure(t *testing.T) {
	service, diagnostics := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 2)
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		source := fanPolicySourceFromContext(ctx)
		started <- source
		if source == fanPolicyRunSourceManual {
			<-ctx.Done()
			return nil
		}
		if !service.finishWakeResume(fanPolicyGenerationFromContext(ctx)) {
			return errors.New("wake resume became invalid before verification")
		}
		return errors.New("later SMC readback failure")
	}

	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)
	service.suspendForSleep()
	resumeDone := service.scheduleWakeResume()
	requireFanPolicySource(t, started, fanPolicyRunSourceWakeResume)
	waitForWakeResume(t, resumeDone)
	waitForHelperState(t, service, "error")
	if hasFanDiagnosticEvent(diagnostics, "wake_resume_failed") {
		t.Fatal("later policy failure was logged as a wake-resume failure")
	}
}

func TestServeFanHelperPowerEventsDeliversSleepAndWake(t *testing.T) {
	service, _ := newSleepResumeTestService()
	started := make(chan fanPolicyRunSource, 2)
	service.runPolicyFunc = func(ctx context.Context, _ fanPolicySettings) error {
		started <- fanPolicySourceFromContext(ctx)
		<-ctx.Done()
		return nil
	}
	service.configure(fanPolicySettings{Mode: fanModeConstant, ConstantRPM: 2200})
	requireFanPolicySource(t, started, fanPolicyRunSourceManual)

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
	requireFanPolicySource(t, started, fanPolicyRunSourceWakeResume)
	cancel()
	waitForFanSignal(t, done, "power event loop did not stop")
	service.reset()
}

func requireFanPolicySource(t *testing.T, started <-chan fanPolicyRunSource, want fanPolicyRunSource) {
	t.Helper()
	select {
	case got := <-started:
		if got != want {
			t.Fatalf("policy source = %d, want %d", got, want)
		}
	case <-time.After(time.Second):
		t.Fatalf("policy source %d did not start", want)
	}
}

func ensureNoFanPolicyStart(t *testing.T, started <-chan fanPolicyRunSource) {
	t.Helper()
	select {
	case source := <-started:
		t.Fatalf("unexpected policy source %d started", source)
	default:
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

func hasFanDiagnosticEvent(diagnostics *recordedFanHelperDiagnostics, name string) bool {
	for {
		select {
		case event := <-diagnostics.events:
			if event.Event == name {
				return true
			}
		default:
			return false
		}
	}
}

func waitForWakeResume(t *testing.T, done <-chan struct{}) {
	t.Helper()
	if done == nil {
		t.Fatal("wake resume was not queued")
	}
	waitForFanSignal(t, done, "wake resume did not finish")
}

func waitForFanSignal(t *testing.T, done <-chan struct{}, message string) {
	t.Helper()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal(message)
	}
}
