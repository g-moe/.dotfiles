package app

import (
	"os"
	"strings"
	"testing"
)

func TestSettingsWindowUsesSeparateTopTabs(t *testing.T) {
	source, err := os.ReadFile("menubar.m")
	if err != nil {
		t.Fatal(err)
	}
	text := string(source)
	for _, required := range []string{
		`window.title = @"mactop"`,
		`window.backgroundColor = [NSColor windowBackgroundColor]`,
		`window.movable = NO`,
		`[self.window center]`,
		`green:135.0 / 255.0`,
		`blue:238.0 / 255.0`,
		`@interface MactopSegmentedControl : NSSegmentedControl`,
		`mactopSegmentedTrackColor(appearance)`,
		`mactopSegmentedSelectionColor(appearance)`,
		`mactopSettingsCardColor(self.effectiveAppearance)`,
		`mactopIsDarkAppearance`,
		`[NSColor labelColor]`,
		`_settingsPage.edgeInsets = NSEdgeInsetsMake(kSettingsTopMargin, kSettingsMargin,`,
		`pinToStackSides(_menubarView, _settingsPage, kSettingsMargin)`,
		`pinToStackSides(_fansView, _settingsPage, kSettingsMargin)`,
		`[self buildMenubarUI:_menubarView]`,
		`[self buildFansUI:_fansView]`,
		`[self fitWindowToContent]`,
		`[panels.heightAnchor constraintEqualToConstant:kFanPanelHeight]`,
		`_memCheck = [NSButton checkboxWithTitle:messageText(@"Menu_MEM")`,
		`well.accessibilityLabel =`,
		`_fanPolicyDot.color = fanPolicyDotColor(safeState)`,
		`[self showFanPolicyError:message]`,
		`_pressedSegment = -1`,
		`[super setWidth:width forSegment:i]`,
		`style.lineBreakMode = NSLineBreakByTruncatingTail`,
		`NSSetFocusRingStyle(NSFocusRingOnly)`,
		`- (void)mouseDown:(NSEvent *)event`,
		`@interface MactopSettingsCard : NSView`,
		`- (void)viewDidChangeEffectiveAppearance`,
		`checkboxWithTitle:messageText(@"Menu_CPU")`,
		`checkboxWithTitle:messageText(@"Menu_GPU")`,
		`g_config.power_font_size = g_config.font_size`,
		`_widthSlider.accessibilityTitleUIElement = wl`,
		`_fontSizeSlider.accessibilityTitleUIElement = fsl`,
		`NSProgressIndicatorStyleSpinning`,
		`_fanProgressIndicator.accessibilityLabel`,
		`messageText(@"Menu_InstallingFanHelper")`,
		`messageText(@"Menu_FanInstalling")`,
		`messageText(@"Menu_FanApplying")`,
		`[self scheduleFanPolicyRefreshAfter:0.25]`,
		`[self scheduleFanPolicyRefreshAfter:inFlight ? 0.25 : 1.0]`,
		`repeats:NO`,
		`_fanRequestGeneration++`,
		`_fanMutationPending = YES`,
		`if (generation != _fanRequestGeneration)`,
		`if (_fanMutationPending && responseSource == FanSettingsResponsePoll)`,
		`if (responseSource == FanSettingsResponseMutation)`,
		`GoRequestFanPolicyStatus(_fanRequestGeneration)`,
	} {
		if !strings.Contains(text, required) {
			t.Errorf("Settings UI is missing %q", required)
		}
	}
	for _, obsolete := range []string{
		`messageText(@"Menu_SettingsTitle")`,
		`messageText(@"Menu_FanControl")`,
		`_aneCheck`,
		`_aneColorWell`,
		`NSTopTabsBezelBorder`,
		`NSBox *controlBox`,
		`NSBox *statusBox`,
		`NSVisualEffectView *effectView`,
		`_heightSlider`,
		`_powerFontSlider`,
		`_powerCheck`,
		`_percentCheck`,
		`_labelColorWell`,
		`view, messageText(@"Menu_Colors"), NSMakeRect`,
		`selectedSegmentBezelColor = mactopAccentColor()`,
		`Menu_WaitingForAuthorization`,
		`scheduledTimerWithTimeInterval:1.0`,
		`mactopSegmentedBackgroundColor`,
		`NSTabView *settingsTabs`,
		`addSettingsSection`,
		`Menu_FanControlMode`,
		`Menu_FanStatusSection`,
		`Menu_MenubarMetrics`,
		`Menu_MenubarAppearance`,
		`Menu_FanCurveExplanation`,
		`messageText(@"Menu_RAM")
      stringByTrimmingCharactersInSet`,
	} {
		if strings.Contains(text, obsolete) {
			t.Errorf("Settings UI still uses obsolete mixed-layout key %q", obsolete)
		}
	}
}

func TestMenuBarANEIsAlwaysDisabled(t *testing.T) {
	source, err := os.ReadFile("menubar.go")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(source), `ccfg.show_ane = 0`) {
		t.Fatal("menu-bar config must hard-disable the ANE status item")
	}
	menuSource, err := os.ReadFile("menubar.m")
	if err != nil {
		t.Fatal(err)
	}
	for _, obsolete := range []string{
		`.show_ane = 1`,
		`.bar_order = "cpu,gpu,ane,memory,fan"`,
		`@"cpu", @"gpu", @"ane", @"memory", @"fan"`,
		`[item isEqualToString:@"ane"]`,
		`g_config.show_ane && g_config.ane_two_row`,
	} {
		if strings.Contains(string(menuSource), obsolete) {
			t.Errorf("menu-bar renderer still contains disabled ANE path %q", obsolete)
		}
	}
}

func TestMenuBarActionsAreFirstAndLimited(t *testing.T) {
	source, err := os.ReadFile("menubar.m")
	if err != nil {
		t.Fatal(err)
	}
	text := string(source)
	settings := strings.Index(text, `initWithTitle:messageText(@"Menu_Settings")`)
	tui := strings.Index(text, `initWithTitle:messageText(@"Menu_OpenTUI")`)
	quit := strings.Index(text, `initWithTitle:messageText(@"Menu_Quit")`)
	branding := strings.Index(text, `[menu addItem:makeBrandingItem()]`)
	model := strings.Index(text, `g_delegate.modelItem = makeHeaderItem`)
	if branding < 0 || settings < branding || tui < settings || quit < tui || model < quit {
		t.Fatalf("menu must show branding, Settings, TUI, Quit, then metrics")
	}
	for _, obsolete := range []string{`Menu_OpenGitHub`, `openGitHub:`} {
		if strings.Contains(text, obsolete) {
			t.Errorf("menu still contains obsolete action %q", obsolete)
		}
	}
}

func TestMenuBarOmitsHistorySection(t *testing.T) {
	source, err := os.ReadFile("menubar.m")
	if err != nil {
		t.Fatal(err)
	}
	for _, obsolete := range []string{
		`Menu_HISTORY`, `drawSparklineChart`, `makeSparkItem`,
		`SPARKLINE_HISTORY_SIZE`, `pushHistory`, `MactopImageView`,
	} {
		if strings.Contains(string(source), obsolete) {
			t.Errorf("menu still contains history implementation %q", obsolete)
		}
	}
}

func TestMenuBarPlacesFansWithDeviceSummary(t *testing.T) {
	source, err := os.ReadFile("menubar.m")
	if err != nil {
		t.Fatal(err)
	}
	text := string(source)
	model := strings.Index(text, `g_delegate.modelItem = makeHeaderItem`)
	fans := strings.Index(text, `g_delegate.fan0Item =`)
	cpu := strings.Index(text, `[menu addItem:makeHeaderItem(messageText(@"Menu_CPU"))]`)
	if model < 0 || fans < model || cpu < fans {
		t.Fatal("fan rows must appear after the device summary and before CPU metrics")
	}
	for _, obsolete := range []string{`fanHeaderItem`, `fanSepItem`, `messageText(@"Menu_FANS")`} {
		if strings.Contains(text, obsolete) {
			t.Errorf("menu still contains separate fan section element %q", obsolete)
		}
	}
	if strings.Contains(text, `metrics.fan_name[i]`) {
		t.Error("fan rows must use stable Fan 0, Fan 1 labels")
	}
}
