// Copyright (c) 2024-2026 Carsen Klock under MIT License
// menubar.m - Native macOS menu bar status item using AppKit

#import <Cocoa/Cocoa.h>
#include <dispatch/dispatch.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Metrics structure passed from Go
typedef struct {
  double cpu_percent;
  double gpu_percent;
  double ane_percent;
  int gpu_freq_mhz;
  uint64_t mem_used_bytes;
  uint64_t mem_total_bytes;
  uint64_t swap_used_bytes;
  uint64_t swap_total_bytes;
  double total_watts;
  double package_watts;
  double cpu_watts;
  double gpu_watts;
  double ane_watts;
  double dram_watts;
  double soc_temp;
  double cpu_temp;
  double gpu_temp;
  char thermal_state[32];
  char model_name[128];
  int gpu_core_count;
  int e_core_count;
  int p_core_count;
  int s_core_count;
  int ecluster_freq_mhz;
  double ecluster_active;
  int pcluster_freq_mhz;
  double pcluster_active;
  int scluster_freq_mhz;
  double scluster_active;
  double net_in_bytes_per_sec;
  double net_out_bytes_per_sec;
  double disk_read_kb_per_sec;
  double disk_write_kb_per_sec;
  double tflops_fp32;
  char rdma_status[64];
  double dram_bw_combined_gbs;
  int fan_count;
  int fan_rpm[4];
  char fan_name[4][32];
} menubar_metrics_t;

// Config passed from Go
typedef struct {
  int status_bar_width;
  int status_bar_height;
  int sparkline_width;
  int sparkline_height;
  int show_cpu;
  int show_gpu;
  int show_ane;
  int show_memory;
  int show_fan;
  int show_power;
  int show_percent;
  int font_size;
  int power_font_size;
  char cpu_color[8];
  char gpu_color[8];
  char ane_color[8];
  char mem_color[8];
  char label_color[8];
  char bar_order[128];
  char cpu_label[64];
  char gpu_label[64];
  char ane_label[64];
  char memory_label[64];
  int cpu_two_row;
  int gpu_two_row;
  int ane_two_row;
  int memory_two_row;
  int fan_two_row;
  int bar_border_width;
  char bar_border_color[8];
  int bar_height;
} menubar_config_t;

// Go callback for persisting settings
extern void GoSaveMenuBarConfig(int statusBarWidth, int statusBarHeight,
                                int sparklineWidth, int sparklineHeight,
                                int showCPU, int showGPU, int showANE,
                                int showMem, int showPower, int showPercent,
                                int fontSize, int powerFontSize,
                                const char *cpuHex, const char *gpuHex,
                                const char *aneHex, const char *memHex,
                                const char *labelHex);
extern void GoRequestFanPolicyStatus(unsigned long long generation);
extern void GoConfigureFanControl(int mode, int constantRPM,
                                  double startCelsius,
                                  double maximumCelsius,
                                  unsigned long long generation);
extern void GoInstallFanHelper(unsigned long long generation);

enum {
  FanSettingsResponsePoll = 0,
  FanSettingsResponseMutation = 1,
};

// Global state
static menubar_config_t g_config = {
    .status_bar_width = 28,
    .status_bar_height = 18,
    .sparkline_width = 420,
    .sparkline_height = 80,
    .show_cpu = 1,
    .show_gpu = 1,
    .show_ane = 0,
    .show_memory = 0,
    .show_fan = 0,
    .show_power = 1,
    .show_percent = 0,
    .font_size = 10,
    .power_font_size = 11,
    .cpu_color = "",
    .gpu_color = "",
    .ane_color = "",
    .mem_color = "",
    .label_color = "",
    .bar_order = "cpu,gpu,memory,fan",
    .cpu_label = "C",
    .gpu_label = "G",
    .ane_label = "A",
    .memory_label = "M",
    .cpu_two_row = 0,
    .gpu_two_row = 0,
    .ane_two_row = 0,
    .memory_two_row = 0,
    .fan_two_row = 0,
    .bar_border_width = 0,
    .bar_border_color = "",
    .bar_height = 0,
};

// Forward declarations
static NSFont *metricFont(void);
static NSFont *headerFont(void);
static NSColor *labelDimColor(void);
static NSColor *valueColor(void);
static NSColor *headerColor(void);
static NSImage *drawStatusBarImage(double cpu, double gpu, double memPct,
                                   double watts, double cpuTemp,
                                   int fanRPM, int hasFan);
static NSString *formatThroughput(double bps);
static void buildMenu(void);
static void persistConfig(void);
static void refreshAllMenuColors(void);

// ---- Color helpers ----

static NSColor *colorFromHex(const char *hex) {
  if (hex == NULL || hex[0] == '\0')
    return nil;
  NSString *str = [NSString stringWithUTF8String:hex];
  if ([str hasPrefix:@"#"])
    str = [str substringFromIndex:1];
  if (str.length != 6)
    return nil;
  unsigned int rgb = 0;
  [[NSScanner scannerWithString:str] scanHexInt:&rgb];
  return [NSColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                         green:((rgb >> 8) & 0xFF) / 255.0
                          blue:(rgb & 0xFF) / 255.0
                         alpha:1.0];
}

static NSString *hexFromColor(NSColor *color) {
  NSColor *c = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
  if (!c)
    return @"";
  int r = (int)(c.redComponent * 255 + 0.5);
  int g = (int)(c.greenComponent * 255 + 0.5);
  int b = (int)(c.blueComponent * 255 + 0.5);
  return [NSString stringWithFormat:@"#%02X%02X%02X", r, g, b];
}
extern char *GoMessageText(char *id);

static NSString *messageText(NSString *key) {
  const char *cKey = [key UTF8String];
  char *cVal = GoMessageText((char *)cKey);
  if (!cVal)
    return key;
  NSString *res = [NSString stringWithUTF8String:cVal];
  free(cVal);
  return res;
}

static NSColor *cpuColor(void) {
  NSColor *c = colorFromHex(g_config.cpu_color);
  return c ?: [NSColor systemGreenColor];
}
static NSColor *gpuColor(void) {
  NSColor *c = colorFromHex(g_config.gpu_color);
  return c ?: [NSColor systemOrangeColor];
}
static NSColor *aneColor(void) {
  NSColor *c = colorFromHex(g_config.ane_color);
  return c ?: [NSColor systemCyanColor];
}
static NSColor *memColor(void) {
  NSColor *c = colorFromHex(g_config.mem_color);
  return c ?: [NSColor systemPurpleColor];
}
static NSColor *menuBarLabelColor(void) {
  NSColor *c = colorFromHex(g_config.label_color);
  return c ?: [NSColor labelColor];
}

static NSColor *barBorderColor(void) {
  NSColor *color = colorFromHex(g_config.bar_border_color);
  return color ?: menuBarLabelColor();
}

static NSColor *labelDimColor(void) {
  // Dimmed variant of the configured label color (or system secondaryLabelColor
  // when no override is set, to preserve the default appearance).
  if (g_config.label_color[0] == '\0')
    return [NSColor secondaryLabelColor];
  return [menuBarLabelColor() colorWithAlphaComponent:0.7];
}
static NSColor *valueColor(void) { return menuBarLabelColor(); }
static NSColor *headerColor(void) { return menuBarLabelColor(); }

// ---- Settings Window Controller & Delegate Forward Declarations ----

@class SettingsWindowController;
@class MactopMenuBarDelegate;

// ---- Views ----

@interface MactopLabelView : NSView
@property(strong, nonatomic) NSTextField *label;
- (void)refreshColors;
@end
@implementation MactopLabelView
- (instancetype)initWithText:(NSString *)text
                        font:(NSFont *)font
                       color:(NSColor *)color {
  CGFloat chartW = (CGFloat)g_config.sparkline_width;
  CGFloat width = chartW + 16;
  CGFloat height = 24;
  self = [super initWithFrame:NSMakeRect(0, 0, width, height)];
  if (self) {
    _label = [NSTextField labelWithString:text];
    _label.font = font;
    _label.textColor = color;
    _label.frame = NSMakeRect(8, 0, width - 16, height);
    _label.drawsBackground = NO;
    _label.bordered = NO;
    _label.editable = NO;
    _label.selectable = NO;
    [self addSubview:_label];
    self.autoresizingMask = NSViewNotSizable;
  }
  return self;
}
- (void)refreshColors {
  _label.textColor = headerColor();
}
@end

@interface MactopMetricView : NSView
@property(strong, nonatomic) NSTextField *labelField;
@property(strong, nonatomic) NSTextField *valueField;
- (void)refreshColors;
@end
@implementation MactopMetricView
- (instancetype)initWithLabel:(NSString *)lbl value:(NSString *)val {
  CGFloat chartW = (CGFloat)g_config.sparkline_width;
  CGFloat width = chartW + 16;
  CGFloat height = 24;
  self = [super initWithFrame:NSMakeRect(0, 0, width, height)];
  if (self) {
    CGFloat halfW = (width - 16) / 2.0;
    _labelField =
        [[NSTextField alloc] initWithFrame:NSMakeRect(8, 0, halfW, height)];
    _labelField.drawsBackground = NO;
    _labelField.bordered = NO;
    _labelField.editable = NO;
    _labelField.selectable = NO;
    _labelField.font = metricFont();
    _labelField.textColor = labelDimColor();
    _labelField.alignment = NSTextAlignmentLeft;

    _valueField = [[NSTextField alloc]
        initWithFrame:NSMakeRect(8 + halfW, 0, halfW, height)];
    _valueField.drawsBackground = NO;
    _valueField.bordered = NO;
    _valueField.editable = NO;
    _valueField.selectable = NO;
    _valueField.font = metricFont();
    _valueField.textColor = valueColor();
    _valueField.alignment = NSTextAlignmentRight;

    [self addSubview:_labelField];
    [self addSubview:_valueField];
    self.autoresizingMask = NSViewNotSizable;

    [self setTwoToneLabel:lbl value:val];
  }
  return self;
}
- (void)setTwoToneLabel:(NSString *)lbl value:(NSString *)val {
  _labelField.stringValue = lbl;
  _valueField.stringValue = val;
}
- (void)refreshColors {
  _labelField.textColor = labelDimColor();
  _valueField.textColor = valueColor();
}
@end

@interface MactopBrandingView : NSView
@property(strong, nonatomic) NSTextField *field;
- (void)refreshColors;
@end
@implementation MactopBrandingView
- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _field = [[NSTextField alloc] initWithFrame:frame];
    _field.drawsBackground = NO;
    _field.bordered = NO;
    _field.editable = NO;
    _field.selectable = NO;
    _field.alignment = NSTextAlignmentCenter;
    [self addSubview:_field];
    self.autoresizingMask = NSViewNotSizable;
    [self refreshColors];
  }
  return self;
}
- (void)refreshColors {
  NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
  style.alignment = NSTextAlignmentCenter;
  NSAttributedString *as = [[NSAttributedString alloc]
      initWithString:@"mactop"
          attributes:@{
            NSFontAttributeName :
                [NSFont systemFontOfSize:14 weight:NSFontWeightHeavy],
            NSForegroundColorAttributeName : menuBarLabelColor(),
            NSParagraphStyleAttributeName : style
          }];
  _field.attributedStringValue = as;
}
@end

// ---- Delegate Interface ----

@interface MactopMenuBarDelegate : NSObject <NSApplicationDelegate>
@property(strong, nonatomic) NSStatusItem *statusItem;
@property(strong, nonatomic) NSMenu *statusMenu;
@property(strong, nonatomic) NSMenuItem *modelItem;
@property(strong, nonatomic) NSMenuItem *cpuUsageItem;
@property(strong, nonatomic) NSMenuItem *cpuEClusterItem;
@property(strong, nonatomic) NSMenuItem *cpuPClusterItem;
@property(strong, nonatomic) NSMenuItem *cpuSClusterItem;
@property(strong, nonatomic) NSMenuItem *cpuWattsItem;
@property(strong, nonatomic) NSMenuItem *cpuTempItem;
@property(strong, nonatomic) NSMenuItem *gpuUsageItem;
@property(strong, nonatomic) NSMenuItem *gpuWattsItem;
@property(strong, nonatomic) NSMenuItem *gpuTempItem;
@property(strong, nonatomic) NSMenuItem *gpuTflopsItem;
@property(strong, nonatomic) NSMenuItem *memUsageItem;
@property(strong, nonatomic) NSMenuItem *memSwapItem;
@property(strong, nonatomic) NSMenuItem *dramBwItem;
@property(strong, nonatomic) NSMenuItem *netItem;
@property(strong, nonatomic) NSMenuItem *rdmaItem;
@property(strong, nonatomic) NSMenuItem *diskItem;
@property(strong, nonatomic) NSMenuItem *powerTotalItem;
@property(strong, nonatomic) NSMenuItem *powerPackageItem;
@property(strong, nonatomic) NSMenuItem *powerCpuItem;
@property(strong, nonatomic) NSMenuItem *powerGpuItem;
@property(strong, nonatomic) NSMenuItem *powerAneItem;
@property(strong, nonatomic) NSMenuItem *powerDramItem;
@property(strong, nonatomic) NSMenuItem *thermalItem;
@property(strong, nonatomic) NSMenuItem *fan0Item;
@property(strong, nonatomic) NSMenuItem *fan1Item;
@property(strong, nonatomic) NSMenuItem *fan2Item;
@property(strong, nonatomic) NSMenuItem *fan3Item;
- (void)performMetricUpdate:(NSValue *)val;
- (void)openSettings:(id)sender;
- (void)statusBarClicked:(id)sender;
@end

// ---- Settings Window Controller ----

static NSColor *mactopAccentColor(void) {
  return [NSColor colorWithSRGBRed:0.0
                             green:135.0 / 255.0
                              blue:238.0 / 255.0
                             alpha:1.0];
}

static NSColor *mactopSegmentedBackgroundColor(void) {
  return [NSColor colorWithSRGBRed:26.0 / 255.0
                             green:26.0 / 255.0
                              blue:26.0 / 255.0
                             alpha:1.0];
}

// AppKit does not honor selectedSegmentBezelColor for every appearance. Draw
// the standard two-state control here so the selected color stays consistent.
@interface MactopSegmentedControl : NSSegmentedControl {
  NSInteger _pressedSegment;
}
@end

@implementation MactopSegmentedControl
- (instancetype)initWithFrame:(NSRect)frameRect {
  self = [super initWithFrame:frameRect];
  if (self) {
    _pressedSegment = -1;
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    _pressedSegment = -1;
  }
  return self;
}

- (NSFont *)segmentFont {
  CGFloat size = 12;
  CGFloat available = NSWidth(self.bounds);
  while (size > 10) {
    NSFont *font = [NSFont systemFontOfSize:size weight:NSFontWeightMedium];
    CGFloat required = 0;
    for (NSInteger i = 0; i < self.segmentCount; i++) {
      required += [[self labelForSegment:i] sizeWithAttributes:@{
        NSFontAttributeName : font,
      }].width + 24;
    }
    if (required <= available) {
      return font;
    }
    size -= 0.5;
  }
  return [NSFont systemFontOfSize:10 weight:NSFontWeightMedium];
}

- (void)updateSegmentWidths {
  NSInteger count = self.segmentCount;
  CGFloat available = NSWidth(self.bounds);
  if (count <= 0 || available <= 0) {
    return;
  }

  NSFont *font = [self segmentFont];
  NSMutableArray<NSNumber *> *widths = [NSMutableArray arrayWithCapacity:count];
  CGFloat required = 0;
  for (NSInteger i = 0; i < count; i++) {
    CGFloat width = ceil([[self labelForSegment:i] sizeWithAttributes:@{
      NSFontAttributeName : font,
    }].width) + 24;
    [widths addObject:@(width)];
    required += width;
    [self setToolTip:[self labelForSegment:i] forSegment:i];
  }

  CGFloat scale = required > available ? available / required : 1;
  CGFloat extra = required < available ? (available - required) / count : 0;
  CGFloat assigned = 0;
  for (NSInteger i = 0; i < count; i++) {
    CGFloat width = i == count - 1
                        ? available - assigned
                        : floor(widths[i].doubleValue * scale + extra);
    [super setWidth:width forSegment:i];
    assigned += width;
  }
}

- (void)setFrameSize:(NSSize)newSize {
  [super setFrameSize:newSize];
  [self updateSegmentWidths];
}

- (void)setSegmentCount:(NSInteger)segmentCount {
  [super setSegmentCount:segmentCount];
  [self updateSegmentWidths];
}

- (void)setLabel:(NSString *)label forSegment:(NSInteger)segment {
  [super setLabel:label forSegment:segment];
  [self updateSegmentWidths];
}

- (void)setSelectedSegment:(NSInteger)selectedSegment {
  [super setSelectedSegment:selectedSegment];
  [self setNeedsDisplay:YES];
}

- (void)setEnabled:(BOOL)enabled {
  [super setEnabled:enabled];
  [self setNeedsDisplay:YES];
}

- (NSRect)rectForSegment:(NSInteger)segment {
  CGFloat x = NSMinX(self.bounds);
  for (NSInteger i = 0; i < segment; i++) {
    x += [self widthForSegment:i];
  }
  return NSMakeRect(x, NSMinY(self.bounds), [self widthForSegment:segment],
                    NSHeight(self.bounds));
}

- (NSInteger)segmentAtPoint:(NSPoint)point {
  for (NSInteger i = 0; i < self.segmentCount; i++) {
    if (NSPointInRect(point, [self rectForSegment:i])) {
      return i;
    }
  }
  return -1;
}

- (void)mouseDown:(NSEvent *)event {
  _pressedSegment = [self segmentAtPoint:[self convertPoint:event.locationInWindow
                                                     fromView:nil]];
  [self setNeedsDisplay:YES];
  [super mouseDown:event];
  _pressedSegment = -1;
  [self setNeedsDisplay:YES];
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
  [self updateSegmentWidths];
  NSRect bounds = self.bounds;
  CGFloat radius = NSHeight(bounds) / 2.0;
  NSBezierPath *background =
      [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:radius yRadius:radius];
  [mactopSegmentedBackgroundColor() setFill];
  [background fill];

  NSInteger count = self.segmentCount;
  if (count <= 0) {
    return;
  }
  NSInteger selected = self.selectedSegment;
  if (selected >= 0 && selected < count) {
    NSRect selectedRect = NSInsetRect([self rectForSegment:selected], 1, 1);
    NSBezierPath *selection = [NSBezierPath
        bezierPathWithRoundedRect:selectedRect
                         xRadius:MAX(0, radius - 1)
                         yRadius:MAX(0, radius - 1)];
    [[mactopAccentColor()
        colorWithAlphaComponent:self.enabled ? 1.0 : 0.35] setFill];
    [selection fill];
  }

  if (_pressedSegment >= 0 && _pressedSegment < count) {
    NSBezierPath *pressed = [NSBezierPath
        bezierPathWithRoundedRect:NSInsetRect([self rectForSegment:_pressedSegment], 1, 1)
                         xRadius:MAX(0, radius - 1)
                         yRadius:MAX(0, radius - 1)];
    [[[NSColor blackColor] colorWithAlphaComponent:0.12] setFill];
    [pressed fill];
  }

  NSFont *font = [self segmentFont];
  for (NSInteger i = 0; i < count; i++) {
    NSString *label = [self labelForSegment:i] ?: @"";
    NSColor *textColor = i == selected ? [NSColor whiteColor]
                                        : [NSColor secondaryLabelColor];
    if (!self.enabled) {
      textColor = [textColor colorWithAlphaComponent:0.5];
    }
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *attributes = @{
      NSFontAttributeName : font,
      NSForegroundColorAttributeName : textColor,
      NSParagraphStyleAttributeName : style,
    };
    NSRect segmentRect = [self rectForSegment:i];
    NSSize textSize = [label sizeWithAttributes:attributes];
    NSRect textRect = NSInsetRect(segmentRect, 8, 0);
    textRect.origin.y = NSMidY(bounds) - textSize.height / 2;
    textRect.size.height = textSize.height;
    [label drawInRect:textRect withAttributes:attributes];
  }

  if (self.window.firstResponder == self) {
    [NSGraphicsContext saveGraphicsState];
    NSSetFocusRingStyle(NSFocusRingOnly);
    [background fill];
    [NSGraphicsContext restoreGraphicsState];
  }
}
@end

@interface MactopSettingsCard : NSView
@end

@implementation MactopSettingsCard
- (void)drawRect:(NSRect)dirtyRect {
  NSBezierPath *background =
      [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:10 yRadius:10];
  // Keep the card related to the current macOS appearance, but make it 15%
  // darker than the standard control background so sections stay distinct.
  NSColor *cardColor = [[NSColor controlBackgroundColor]
      blendedColorWithFraction:0.15
                        ofColor:[NSColor blackColor]];
  [cardColor setFill];
  [background fill];
}

- (void)viewDidChangeEffectiveAppearance {
  [super viewDidChangeEffectiveAppearance];
  [self setNeedsDisplay:YES];
}
@end

@interface SettingsWindowController : NSWindowController <NSWindowDelegate>
@property(strong) NSButton *cpuCheck;
@property(strong) NSButton *gpuCheck;
@property(strong) NSButton *memCheck;
@property(strong) NSSlider *widthSlider;
@property(strong) NSTextField *widthLabel;
@property(strong) NSSlider *fontSizeSlider;
@property(strong) NSTextField *fontSizeLabel;
@property(strong) NSColorWell *cpuColorWell;
@property(strong) NSColorWell *gpuColorWell;
@property(strong) NSColorWell *memColorWell;
@property(strong) NSSegmentedControl *settingsTabControl;
@property(strong) NSTabView *settingsTabs;
@property(strong) NSSegmentedControl *fanModeControl;
@property(strong) NSView *fanDefaultPanel;
@property(strong) NSView *fanConstantPanel;
@property(strong) NSView *fanCurvePanel;
@property(strong) NSTextField *constantRPMField;
@property(strong) NSStepper *constantRPMStepper;
@property(strong) NSTextField *constantRPMRangeLabel;
@property(strong) NSTextField *startTempField;
@property(strong) NSStepper *startTempStepper;
@property(strong) NSTextField *maximumTempField;
@property(strong) NSStepper *maximumTempStepper;
@property(strong) NSButton *fanApplyButton;
@property(strong) NSTextField *fanPolicyStateLabel;
@property(strong) NSTextField *fanPolicyDetailLabel;
@property(strong) NSTextField *fanPolicyErrorLabel;
@property(strong) NSButton *fanHelperInstallButton;
@property(strong) NSProgressIndicator *fanProgressIndicator;
@property(strong) NSTimer *fanPolicyTimer;
@property(assign) BOOL fanConfigLoaded;
@property(assign) unsigned long long fanRequestGeneration;
@property(assign) BOOL fanMutationPending;
- (void)buildUI:(NSView *)view;
- (void)buildMenubarUI:(NSView *)view;
- (void)buildFansUI:(NSView *)view;
- (void)updateFanPolicyState:(int)state
                        mode:(int)mode
                 constantRPM:(int)constantRPM
                startCelsius:(double)startCelsius
              maximumCelsius:(double)maximumCelsius
                  minimumRPM:(int)minimumRPM
                  maximumRPM:(int)maximumRPM
                rpmRangeState:(int)rpmRangeState
                      generation:(unsigned long long)generation
                  responseSource:(int)responseSource
                      detail:(NSString *)detail
                     message:(NSString *)message;
@end

@implementation SettingsWindowController

// Section titles live above the card so AppKit cannot clip them into a border.
static NSView *addSettingsSection(NSView *parent, NSString *title,
                                  NSRect frame) {
  NSTextField *titleLabel = [NSTextField labelWithString:title];
  titleLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  titleLabel.frame = NSMakeRect(frame.origin.x + 4,
                                NSMaxY(frame) - 20,
                                frame.size.width - 8, 20);
  [parent addSubview:titleLabel];

  NSView *card = [[MactopSettingsCard alloc]
      initWithFrame:NSMakeRect(frame.origin.x, frame.origin.y,
                               frame.size.width, frame.size.height - 28)];
  [parent addSubview:card];
  return card;
}

- (instancetype)init {
  CGFloat w = 480;
  CGFloat h = 620;
  NSRect frame = NSMakeRect(0, 0, w, h);
  NSWindow *window = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  window.title = @"mactop";
  [window center];

  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  window.contentView = contentView;
  window.opaque = YES;
  window.backgroundColor = [NSColor windowBackgroundColor];

  self = [super initWithWindow:window];
  if (self) {
    window.delegate = self;
    [self buildUI:contentView];
  }
  return self;
}

- (void)buildUI:(NSView *)view {
  _settingsTabControl = [[MactopSegmentedControl alloc]
      initWithFrame:NSMakeRect((view.bounds.size.width - 240) / 2,
                               view.bounds.size.height - 44, 240, 28)];
  _settingsTabControl.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin |
                                         NSViewMinYMargin;
  _settingsTabControl.segmentCount = 2;
  [_settingsTabControl setLabel:messageText(@"Menu_SettingsTabMenubar")
                     forSegment:0];
  [_settingsTabControl setLabel:messageText(@"Menu_SettingsTabFans")
                     forSegment:1];
  _settingsTabControl.selectedSegment = 0;
  _settingsTabControl.target = self;
  _settingsTabControl.action = @selector(settingsTabChanged:);
  [view addSubview:_settingsTabControl];

  _settingsTabs = [[NSTabView alloc]
      initWithFrame:NSMakeRect(14, 14, view.bounds.size.width - 28,
                               view.bounds.size.height - 66)];
  _settingsTabs.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  _settingsTabs.tabViewType = NSNoTabsNoBorder;

  NSTabViewItem *menubarTab =
      [[NSTabViewItem alloc] initWithIdentifier:@"menubar"];
  NSTabViewItem *fansTab = [[NSTabViewItem alloc] initWithIdentifier:@"fans"];
  [_settingsTabs addTabViewItem:menubarTab];
  [_settingsTabs addTabViewItem:fansTab];
  [view addSubview:_settingsTabs];

  NSScrollView *menubarScroll =
      [[NSScrollView alloc] initWithFrame:menubarTab.view.bounds];
  menubarScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  menubarScroll.hasVerticalScroller = NO;
  menubarScroll.drawsBackground = NO;
  NSView *menubarView =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 430, 540)];
  menubarScroll.documentView = menubarView;
  [menubarTab.view addSubview:menubarScroll];
  [self buildMenubarUI:menubarView];
  CGFloat top = menubarView.bounds.size.height -
                menubarScroll.contentView.bounds.size.height;
  [menubarScroll.contentView scrollToPoint:NSMakePoint(0, MAX(0, top))];
  [menubarScroll reflectScrolledClipView:menubarScroll.contentView];

  NSScrollView *fansScroll =
      [[NSScrollView alloc] initWithFrame:fansTab.view.bounds];
  fansScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  fansScroll.hasVerticalScroller = YES;
  fansScroll.drawsBackground = NO;
  NSView *fansView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 430, 540)];
  fansScroll.documentView = fansView;
  [fansTab.view addSubview:fansScroll];
  [self buildFansUI:fansView];
}

- (void)settingsTabChanged:(id)sender {
  NSInteger index = _settingsTabControl.selectedSegment;
  if (index >= 0 && index < _settingsTabs.numberOfTabViewItems) {
    [_settingsTabs selectTabViewItemAtIndex:index];
  }
}

- (void)buildFansUI:(NSView *)view {
  CGFloat x = 14;
  CGFloat width = 402;

  NSView *control = addSettingsSection(
      view, messageText(@"Menu_FanControlMode"), NSMakeRect(x, 282, width, 242));

  _fanModeControl = [[MactopSegmentedControl alloc]
      initWithFrame:NSMakeRect(12, 176, width - 28, 28)];
  _fanModeControl.segmentCount = 3;
  [_fanModeControl setLabel:messageText(@"Menu_FanModeDefault") forSegment:0];
  [_fanModeControl setLabel:messageText(@"Menu_FanModeConstant") forSegment:1];
  [_fanModeControl setLabel:messageText(@"Menu_FanModeCurve") forSegment:2];
  _fanModeControl.target = self;
  _fanModeControl.action = @selector(fanModeChanged:);
  _fanModeControl.selectedSegment = 0;
  [control addSubview:_fanModeControl];

  NSRect panelFrame = NSMakeRect(12, 48, width - 28, 112);
  _fanDefaultPanel = [[NSView alloc] initWithFrame:panelFrame];
  NSTextField *defaultHint = [NSTextField
      wrappingLabelWithString:messageText(@"Menu_FanDefaultDescription")];
  defaultHint.font = [NSFont systemFontOfSize:12];
  defaultHint.textColor = [NSColor secondaryLabelColor];
  defaultHint.frame = NSMakeRect(4, 45, panelFrame.size.width - 8, 48);
  [_fanDefaultPanel addSubview:defaultHint];
  [control addSubview:_fanDefaultPanel];

  _fanConstantPanel = [[NSView alloc] initWithFrame:panelFrame];
  NSTextField *rpmLabel = [NSTextField
      labelWithString:messageText(@"Menu_FanConstantRPM")];
  rpmLabel.frame = NSMakeRect(4, 72, 174, 20);
  [_fanConstantPanel addSubview:rpmLabel];
  _constantRPMField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(190, 69, 110, 24)];
  _constantRPMField.integerValue = 2500;
  [_fanConstantPanel addSubview:_constantRPMField];
  _constantRPMStepper =
      [[NSStepper alloc] initWithFrame:NSMakeRect(308, 68, 20, 26)];
  _constantRPMStepper.minValue = 1;
  _constantRPMStepper.maxValue = 20000;
  _constantRPMStepper.increment = 100;
  _constantRPMStepper.integerValue = 2500;
  _constantRPMStepper.target = self;
  _constantRPMStepper.action = @selector(fanStepperChanged:);
  [_fanConstantPanel addSubview:_constantRPMStepper];

  _constantRPMRangeLabel = [NSTextField
      labelWithString:messageText(@"Menu_FanRangeCheckedOnApply")];
  _constantRPMRangeLabel.font = [NSFont systemFontOfSize:11];
  _constantRPMRangeLabel.textColor = [NSColor secondaryLabelColor];
  _constantRPMRangeLabel.frame = NSMakeRect(4, 39, panelFrame.size.width - 8, 18);
  [_fanConstantPanel addSubview:_constantRPMRangeLabel];
  [control addSubview:_fanConstantPanel];

  _fanCurvePanel = [[NSView alloc] initWithFrame:panelFrame];
  NSTextField *startLabel =
      [NSTextField labelWithString:messageText(@"Menu_FanStartRamp")];
  startLabel.frame = NSMakeRect(4, 79, 174, 20);
  [_fanCurvePanel addSubview:startLabel];
  _startTempField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(190, 76, 110, 24)];
  _startTempField.integerValue = 38;
  [_fanCurvePanel addSubview:_startTempField];
  _startTempStepper =
      [[NSStepper alloc] initWithFrame:NSMakeRect(308, 75, 20, 26)];
  _startTempStepper.minValue = 20;
  _startTempStepper.maxValue = 95;
  _startTempStepper.integerValue = 38;
  _startTempStepper.target = self;
  _startTempStepper.action = @selector(fanStepperChanged:);
  [_fanCurvePanel addSubview:_startTempStepper];

  NSTextField *maximumLabel =
      [NSTextField labelWithString:messageText(@"Menu_FanMaximumTemperature")];
  maximumLabel.frame = NSMakeRect(4, 47, 174, 20);
  [_fanCurvePanel addSubview:maximumLabel];
  _maximumTempField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(190, 44, 110, 24)];
  _maximumTempField.integerValue = 85;
  [_fanCurvePanel addSubview:_maximumTempField];
  _maximumTempStepper =
      [[NSStepper alloc] initWithFrame:NSMakeRect(308, 43, 20, 26)];
  _maximumTempStepper.minValue = 25;
  _maximumTempStepper.maxValue = 100;
  _maximumTempStepper.integerValue = 85;
  _maximumTempStepper.target = self;
  _maximumTempStepper.action = @selector(fanStepperChanged:);
  [_fanCurvePanel addSubview:_maximumTempStepper];

  NSTextField *curveHint = [NSTextField
      wrappingLabelWithString:messageText(@"Menu_FanCurveExplanation")];
  curveHint.font = [NSFont systemFontOfSize:11];
  curveHint.textColor = [NSColor secondaryLabelColor];
  curveHint.frame = NSMakeRect(4, 2, panelFrame.size.width - 8, 34);
  [_fanCurvePanel addSubview:curveHint];
  [control addSubview:_fanCurvePanel];

  _fanApplyButton = [NSButton buttonWithTitle:messageText(@"Menu_FanApply")
                                       target:self
                                       action:@selector(applyFanControl:)];
  _fanApplyButton.bezelStyle = NSBezelStyleRounded;
  _fanApplyButton.bezelColor = mactopAccentColor();
  _fanApplyButton.frame = NSMakeRect(12, 12, 100, 28);
  [control addSubview:_fanApplyButton];

  NSView *status = addSettingsSection(
      view, messageText(@"Menu_FanStatusSection"), NSMakeRect(x, 60, width, 202));

  _fanPolicyStateLabel = [NSTextField labelWithString:messageText(@"Menu_FanPolicyChecking")];
  _fanPolicyStateLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
  _fanPolicyStateLabel.frame = NSMakeRect(12, 136, width - 54, 22);
  [status addSubview:_fanPolicyStateLabel];

  _fanProgressIndicator = [[NSProgressIndicator alloc]
      initWithFrame:NSMakeRect(width - 42, 138, 16, 16)];
  _fanProgressIndicator.style = NSProgressIndicatorStyleSpinning;
  _fanProgressIndicator.controlSize = NSControlSizeSmall;
  _fanProgressIndicator.displayedWhenStopped = NO;
  _fanProgressIndicator.hidden = YES;
  [status addSubview:_fanProgressIndicator];

  _fanPolicyDetailLabel = [NSTextField wrappingLabelWithString:messageText(@"Menu_FanCurveDetail")];
  _fanPolicyDetailLabel.font = [NSFont systemFontOfSize:12];
  _fanPolicyDetailLabel.textColor = [NSColor secondaryLabelColor];
  _fanPolicyDetailLabel.frame = NSMakeRect(12, 88, width - 28, 42);
  [status addSubview:_fanPolicyDetailLabel];

  _fanPolicyErrorLabel = [NSTextField wrappingLabelWithString:@""];
  _fanPolicyErrorLabel.font = [NSFont systemFontOfSize:12];
  _fanPolicyErrorLabel.textColor = [NSColor systemRedColor];
  _fanPolicyErrorLabel.frame = NSMakeRect(12, 43, width - 28, 40);
  [status addSubview:_fanPolicyErrorLabel];

  _fanHelperInstallButton = [NSButton buttonWithTitle:messageText(@"Menu_InstallFanHelper")
                                             target:self
                                             action:@selector(installFanHelper:)];
  _fanHelperInstallButton.bezelStyle = NSBezelStyleRounded;
  _fanHelperInstallButton.frame = NSMakeRect(12, 8, 150, 28);
  [status addSubview:_fanHelperInstallButton];
  [self fanModeChanged:_fanModeControl];
}

- (void)buildMenubarUI:(NSView *)view {
  CGFloat x = 14;
  CGFloat width = 402;
  CGFloat lh = 20;

  // Align the first Menubar section with the first Fans section. Keeping the
  // section close to the tab control avoids a large empty band at the top.
  NSView *metrics = addSettingsSection(
      view, messageText(@"Menu_MenubarMetrics"), NSMakeRect(x, 328, width, 196));

  _cpuCheck = [NSButton checkboxWithTitle:messageText(@"Menu_CPU")
                                   target:self
                                   action:@selector(toggleChanged:)];
  _cpuCheck.frame = NSMakeRect(14, 116, 280, lh);
  [metrics addSubview:_cpuCheck];

  _cpuColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(322, 114, 62, 24)];
  _cpuColorWell.accessibilityLabel =
      [NSString stringWithFormat:@"%@ %@", messageText(@"Menu_CPU"),
                                 messageText(@"Menu_Colors")];
  _cpuColorWell.target = self;
  _cpuColorWell.action = @selector(colorChanged:);
  [metrics addSubview:_cpuColorWell];

  _gpuCheck = [NSButton checkboxWithTitle:messageText(@"Menu_GPU")
                                   target:self
                                   action:@selector(toggleChanged:)];
  _gpuCheck.frame = NSMakeRect(14, 72, 280, lh);
  [metrics addSubview:_gpuCheck];

  _gpuColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(322, 70, 62, 24)];
  _gpuColorWell.accessibilityLabel =
      [NSString stringWithFormat:@"%@ %@", messageText(@"Menu_GPU"),
                                 messageText(@"Menu_Colors")];
  _gpuColorWell.target = self;
  _gpuColorWell.action = @selector(colorChanged:);
  [metrics addSubview:_gpuColorWell];

  NSString *memoryTitle = [messageText(@"Menu_RAM")
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                         whitespaceAndNewlineCharacterSet]];
  while ([memoryTitle hasSuffix:@":"] || [memoryTitle hasSuffix:@"："]) {
    memoryTitle = [memoryTitle substringToIndex:memoryTitle.length - 1];
  }
  _memCheck = [NSButton checkboxWithTitle:memoryTitle
                                   target:self
                                   action:@selector(toggleChanged:)];
  _memCheck.frame = NSMakeRect(14, 28, 280, lh);
  [metrics addSubview:_memCheck];

  _memColorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(322, 26, 62, 24)];
  _memColorWell.accessibilityLabel =
      [NSString stringWithFormat:@"%@ %@", memoryTitle,
                                 messageText(@"Menu_Colors")];
  _memColorWell.target = self;
  _memColorWell.action = @selector(colorChanged:);
  [metrics addSubview:_memColorWell];

  NSView *size = addSettingsSection(
      view, messageText(@"Menu_MenubarAppearance"), NSMakeRect(x, 152, width, 136));

  NSTextField *wl = [NSTextField labelWithString:messageText(@"Menu_StatusBarWidth")];
  wl.frame = NSMakeRect(14, 62, 145, lh);
  [size addSubview:wl];

  _widthSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(160, 62, 174, lh)];
  _widthSlider.minValue = 4;
  _widthSlider.maxValue = 120;
  _widthSlider.accessibilityTitleUIElement = wl;
  _widthSlider.accessibilityLabel = wl.stringValue;
  _widthSlider.target = self;
  _widthSlider.action = @selector(sliderChanged:);
  [size addSubview:_widthSlider];

  _widthLabel = [NSTextField labelWithString:@"28"];
  _widthLabel.alignment = NSTextAlignmentRight;
  _widthLabel.frame = NSMakeRect(340, 62, 42, lh);
  [size addSubview:_widthLabel];

  NSTextField *fsl = [NSTextField labelWithString:messageText(@"Menu_BarFontSize")];
  fsl.frame = NSMakeRect(14, 22, 145, lh);
  [size addSubview:fsl];

  _fontSizeSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(160, 22, 174, lh)];
  _fontSizeSlider.minValue = 8;
  _fontSizeSlider.maxValue = 16;
  _fontSizeSlider.accessibilityTitleUIElement = fsl;
  _fontSizeSlider.accessibilityLabel = fsl.stringValue;
  _fontSizeSlider.target = self;
  _fontSizeSlider.action = @selector(sliderChanged:);
  [size addSubview:_fontSizeSlider];

  _fontSizeLabel = [NSTextField labelWithString:@"10"];
  _fontSizeLabel.alignment = NSTextAlignmentRight;
  _fontSizeLabel.frame = NSMakeRect(340, 22, 42, lh);
  [size addSubview:_fontSizeLabel];
}

- (void)showWindow:(id)sender {
  [self syncUI];
  [super showWindow:sender];
  [NSApp activateIgnoringOtherApps:YES];
  [self showFanPolicyTransition:messageText(@"Menu_FanPolicyChecking")];
  _fanRequestGeneration++;
  _fanMutationPending = NO;
  _fanConfigLoaded = NO;
  GoRequestFanPolicyStatus(_fanRequestGeneration);
  [self scheduleFanPolicyRefreshAfter:1.0];
}

- (void)scheduleFanPolicyRefreshAfter:(NSTimeInterval)interval {
  [_fanPolicyTimer invalidate];
  _fanPolicyTimer = nil;
  if (!self.window.visible)
    return;
  _fanPolicyTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                     target:self
                                                   selector:@selector(refreshFanPolicyStatus:)
                                                   userInfo:nil
                                                    repeats:NO];
}

- (void)windowWillClose:(NSNotification *)notification {
  [_fanPolicyTimer invalidate];
  _fanPolicyTimer = nil;
}

- (void)refreshFanPolicyStatus:(NSTimer *)timer {
  _fanPolicyTimer = nil;
  GoRequestFanPolicyStatus(_fanRequestGeneration);
}

- (void)showFanPolicyTransition:(NSString *)state {
  _fanPolicyStateLabel.stringValue = state;
  _fanModeControl.enabled = NO;
  _constantRPMField.enabled = NO;
  _constantRPMStepper.enabled = NO;
  _startTempField.enabled = NO;
  _startTempStepper.enabled = NO;
  _maximumTempField.enabled = NO;
  _maximumTempStepper.enabled = NO;
  _fanApplyButton.enabled = NO;
  _fanHelperInstallButton.enabled = NO;
  _fanPolicyErrorLabel.stringValue = @"";
  _fanProgressIndicator.accessibilityLabel = state;
  _fanProgressIndicator.hidden = NO;
  [_fanProgressIndicator startAnimation:nil];
}

- (void)fanModeChanged:(id)sender {
  int mode = (int)_fanModeControl.selectedSegment;
  BOOL constant = mode == 1;
  BOOL curve = mode == 2;
  BOOL canEdit = _fanModeControl.enabled;
  _fanDefaultPanel.hidden = mode != 0;
  _fanConstantPanel.hidden = !constant;
  _fanCurvePanel.hidden = !curve;
  _constantRPMField.enabled = constant && canEdit;
  _constantRPMStepper.enabled = constant && canEdit;
  _startTempField.enabled = curve && canEdit;
  _startTempStepper.enabled = curve && canEdit;
  _maximumTempField.enabled = curve && canEdit;
  _maximumTempStepper.enabled = curve && canEdit;
}

- (void)fanStepperChanged:(id)sender {
  if (sender == _constantRPMStepper)
    _constantRPMField.integerValue = _constantRPMStepper.integerValue;
  if (sender == _startTempStepper)
    _startTempField.integerValue = _startTempStepper.integerValue;
  if (sender == _maximumTempStepper)
    _maximumTempField.integerValue = _maximumTempStepper.integerValue;
}

- (void)applyFanControl:(id)sender {
  int mode = (int)_fanModeControl.selectedSegment;
  int rpm = _constantRPMField.intValue;
  int start = _startTempField.intValue;
  int maximum = _maximumTempField.intValue;
  if ((mode == 1 && rpm <= 0) ||
      (mode == 2 && (start < 20 || maximum > 100 || maximum - start < 5))) {
    _fanPolicyErrorLabel.stringValue = messageText(@"Menu_FanInvalidSettings");
    return;
  }
  _fanRequestGeneration++;
  _fanMutationPending = YES;
  _fanConfigLoaded = NO;
  [self showFanPolicyTransition:messageText(@"Menu_FanApplying")];
  _fanApplyButton.title = messageText(@"Menu_FanApplying");
  [self scheduleFanPolicyRefreshAfter:0.25];
  GoConfigureFanControl(mode, rpm, start, maximum, _fanRequestGeneration);
}

- (void)installFanHelper:(id)sender {
  _fanRequestGeneration++;
  _fanMutationPending = YES;
  [self showFanPolicyTransition:messageText(@"Menu_InstallingFanHelper")];
  _fanHelperInstallButton.title = messageText(@"Menu_FanInstalling");
  [self scheduleFanPolicyRefreshAfter:0.25];
  GoInstallFanHelper(_fanRequestGeneration);
}

- (void)updateFanPolicyState:(int)state
                        mode:(int)mode
                 constantRPM:(int)constantRPM
                startCelsius:(double)startCelsius
              maximumCelsius:(double)maximumCelsius
                  minimumRPM:(int)minimumRPM
                  maximumRPM:(int)maximumRPM
                rpmRangeState:(int)rpmRangeState
                      generation:(unsigned long long)generation
                  responseSource:(int)responseSource
                      detail:(NSString *)detail
                     message:(NSString *)message {
  if (generation != _fanRequestGeneration)
    return;
  if (_fanMutationPending && responseSource == FanSettingsResponsePoll)
    return;
  if (responseSource == FanSettingsResponseMutation)
    _fanMutationPending = NO;
  NSArray<NSString *> *names = @[
    messageText(@"Menu_FanHelperMissing"), messageText(@"Menu_FanPolicyOff"),
    messageText(@"Menu_FanPolicyStarting"), messageText(@"Menu_FanPolicyActive"),
    messageText(@"Menu_FanPolicyStopping"), messageText(@"Menu_FanPolicyError"),
    messageText(@"Menu_FanHelperUpdate"), messageText(@"Menu_FanHelperUnhealthyState"),
    messageText(@"Menu_FanPolicySuspended")
  ];
  int safeState = (state >= 0 && state < (int)names.count) ? state : 5;
  _fanPolicyStateLabel.stringValue = names[safeState];
  _fanPolicyDetailLabel.stringValue = detail ?: @"";
  _fanPolicyErrorLabel.stringValue = message ?: @"";
  if (rpmRangeState == 1 && minimumRPM > 0 && maximumRPM >= minimumRPM) {
    _constantRPMStepper.minValue = minimumRPM;
    _constantRPMStepper.maxValue = maximumRPM;
    _constantRPMRangeLabel.stringValue = [NSString
        stringWithFormat:messageText(@"Menu_FanValidRPMRange"), minimumRPM,
                         maximumRPM];
  } else if (rpmRangeState == 2) {
    _constantRPMRangeLabel.stringValue =
        messageText(@"Menu_FanNoCommonRPMRange");
  } else {
    _constantRPMRangeLabel.stringValue =
        messageText(@"Menu_FanRangeCheckedOnApply");
  }
  if (!_fanConfigLoaded) {
    _fanModeControl.selectedSegment = mode >= 0 && mode <= 2 ? mode : 0;
    if (constantRPM > 0) {
      _constantRPMField.integerValue = constantRPM;
      _constantRPMStepper.integerValue = constantRPM;
    }
    if (startCelsius > 0) {
      _startTempField.integerValue = (NSInteger)startCelsius;
      _startTempStepper.integerValue = (NSInteger)startCelsius;
    }
    if (maximumCelsius > 0) {
      _maximumTempField.integerValue = (NSInteger)maximumCelsius;
      _maximumTempStepper.integerValue = (NSInteger)maximumCelsius;
    }
    _fanConfigLoaded = YES;
  }
  BOOL inFlight = safeState == 2 || safeState == 4;
  BOOL canControl = safeState == 1 || safeState == 3 || safeState == 5 || safeState == 8;
  _fanApplyButton.title = inFlight ? messageText(@"Menu_FanApplying")
                                   : messageText(@"Menu_FanApply");
  if (inFlight) {
    _fanProgressIndicator.accessibilityLabel = names[safeState];
    _fanProgressIndicator.hidden = NO;
    [_fanProgressIndicator startAnimation:nil];
  } else {
    [_fanProgressIndicator stopAnimation:nil];
    _fanProgressIndicator.hidden = YES;
  }
  _fanModeControl.enabled = canControl && !inFlight;
  _fanApplyButton.enabled = canControl && !inFlight;
  [self fanModeChanged:_fanModeControl];
  BOOL showHelperAction = safeState == 0 || safeState == 6 || safeState == 7;
  _fanHelperInstallButton.title = safeState == 6
                                      ? messageText(@"Menu_UpdateFanHelper")
                                      : messageText(@"Menu_InstallFanHelper");
  _fanHelperInstallButton.hidden = !showHelperAction;
  _fanHelperInstallButton.enabled = showHelperAction;
  [self scheduleFanPolicyRefreshAfter:inFlight ? 0.25 : 1.0];
}

- (void)syncUI {
  _cpuCheck.state =
      g_config.show_cpu ? NSControlStateValueOn : NSControlStateValueOff;
  _gpuCheck.state =
      g_config.show_gpu ? NSControlStateValueOn : NSControlStateValueOff;
  _memCheck.state =
      g_config.show_memory ? NSControlStateValueOn : NSControlStateValueOff;

  _widthSlider.integerValue = g_config.status_bar_width;
  _widthLabel.stringValue =
      [NSString stringWithFormat:@"%d", g_config.status_bar_width];

  _fontSizeSlider.integerValue = g_config.font_size;
  _fontSizeLabel.stringValue =
      [NSString stringWithFormat:@"%d", g_config.font_size];

  _cpuColorWell.color = cpuColor();
  _gpuColorWell.color = gpuColor();
  _memColorWell.color = memColor();
}

- (void)toggleChanged:(id)sender {
  g_config.show_cpu = _cpuCheck.state == NSControlStateValueOn;
  g_config.show_gpu = _gpuCheck.state == NSControlStateValueOn;
  g_config.show_memory = _memCheck.state == NSControlStateValueOn;
  persistConfig();
}

- (void)sliderChanged:(id)sender {
  g_config.status_bar_width = _widthSlider.intValue;
  _widthLabel.stringValue =
      [NSString stringWithFormat:@"%d", g_config.status_bar_width];

  g_config.font_size = _fontSizeSlider.intValue;
  g_config.power_font_size = g_config.font_size;
  _fontSizeLabel.stringValue =
      [NSString stringWithFormat:@"%d", g_config.font_size];

  // Force button font update immediately
  MactopMenuBarDelegate *delegate = (MactopMenuBarDelegate *)[NSApp delegate];
  if (delegate && delegate.statusItem) {
    delegate.statusItem.button.font = [NSFont
        monospacedDigitSystemFontOfSize:(CGFloat)g_config.font_size
                                 weight:NSFontWeightMedium];
  }

  persistConfig();
}

- (void)colorChanged:(id)sender {
  void (^updateColor)(char *, NSColor *) = ^(char *dest, NSColor *c) {
    NSString *hex = hexFromColor(c);
    strlcpy(dest, [hex UTF8String], 8);
  };

  if (sender == _cpuColorWell)
    updateColor(g_config.cpu_color, _cpuColorWell.color);
  if (sender == _gpuColorWell)
    updateColor(g_config.gpu_color, _gpuColorWell.color);
  if (sender == _memColorWell)
    updateColor(g_config.mem_color, _memColorWell.color);
  persistConfig();
}

@end

static SettingsWindowController *g_settingsWindow = nil;

static MactopMenuBarDelegate *g_delegate = nil;

// ---- Typography ----
static NSFont *metricFont(void) {
  return [NSFont monospacedDigitSystemFontOfSize:15 weight:NSFontWeightMedium];
}
static NSFont *headerFont(void) {
  return [NSFont systemFontOfSize:15 weight:NSFontWeightHeavy];
}

// Helpers
static NSMenuItem *makeHeaderItem(NSString *title) {
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@""
                                                action:nil
                                         keyEquivalent:@""];
  MactopLabelView *view = [[MactopLabelView alloc] initWithText:title
                                                           font:headerFont()
                                                          color:headerColor()];
  item.view = view;
  return item;
}
static NSMenuItem *makeMetricItem(NSString *label, NSString *value) {
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@""
                                                action:nil
                                         keyEquivalent:@""];
  MactopMetricView *view = [[MactopMetricView alloc] initWithLabel:label
                                                             value:value];
  item.view = view;
  return item;
}
static NSMenuItem *makeBrandingItem(void) {
  NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@""
                                                action:nil
                                         keyEquivalent:@""];
  CGFloat chartW = (CGFloat)g_config.sparkline_width;
  CGFloat width = chartW + 16;
  CGFloat height = 24;
  MactopBrandingView *container =
      [[MactopBrandingView alloc] initWithFrame:NSMakeRect(0, 0, width, height)];
  item.view = container;
  return item;
}

// ---- Drawing ----

static CGFloat statusBarPercentWidth(CGFloat fontSize) {
  NSFont *font = [NSFont monospacedDigitSystemFontOfSize:fontSize
                                                  weight:NSFontWeightRegular];
  return [@"100%" sizeWithAttributes:@{NSFontAttributeName : font}].width;
}

static CGFloat statusBarItemWidth(NSString *label, CGFloat barWidth,
                                  CGFloat fontSize, int showPercent,
                                  int twoRow) {
  NSFont *labelFont =
      [NSFont monospacedDigitSystemFontOfSize:fontSize
                                      weight:NSFontWeightBold];
  CGFloat labelWidth =
      [label sizeWithAttributes:@{NSFontAttributeName : labelFont}].width;
  CGFloat percentWidth = showPercent ? statusBarPercentWidth(fontSize) : 0.0;
  if (twoRow) {
    CGFloat textWidth = labelWidth + (showPercent ? percentWidth + 4 : 0);
    return MAX(textWidth, barWidth);
  }
  return labelWidth + 4 + barWidth +
         (showPercent ? percentWidth + 4 : 0);
}

static CGFloat statusBarFanWidth(NSString *temp, NSString *fan, CGFloat fontSize,
                                 int twoRow) {
  NSFont *font = [NSFont monospacedDigitSystemFontOfSize:fontSize
                                                  weight:NSFontWeightMedium];
  NSDictionary *attrs = @{NSFontAttributeName : font};
  CGFloat tempWidth = [temp sizeWithAttributes:attrs].width;
  CGFloat fanWidth = [fan sizeWithAttributes:attrs].width;
  return twoRow ? MAX(tempWidth, fanWidth) : tempWidth + 4 + fanWidth;
}

static void drawStatusBarFan(NSString *temp, NSString *fan, CGFloat x,
                             CGFloat imageHeight, CGFloat fontSize,
                             int twoRow) {
  NSFont *font = [NSFont monospacedDigitSystemFontOfSize:fontSize
                                                  weight:NSFontWeightMedium];
  NSDictionary *attrs = @{
    NSFontAttributeName : font,
    NSForegroundColorAttributeName : menuBarLabelColor()
  };
  NSSize tempSize = [temp sizeWithAttributes:attrs];
  NSSize fanSize = [fan sizeWithAttributes:attrs];
  if (twoRow) {
    CGFloat rowHeight = MAX(tempSize.height, fanSize.height);
    CGFloat blockHeight = rowHeight * 2;
    CGFloat bottom = (imageHeight - blockHeight) / 2.0 - 1;
    [fan drawAtPoint:NSMakePoint(x, bottom) withAttributes:attrs];
    [temp drawAtPoint:NSMakePoint(x, bottom + rowHeight) withAttributes:attrs];
    return;
  }

  CGFloat y = (imageHeight - MAX(tempSize.height, fanSize.height)) / 2.0 - 1;
  [temp drawAtPoint:NSMakePoint(x, y) withAttributes:attrs];
  [fan drawAtPoint:NSMakePoint(x + tempSize.width + 4, y)
     withAttributes:attrs];
}

static void drawHBar(NSString *label, double pct, NSColor *color, CGFloat x,
                     CGFloat imageHeight, CGFloat barW, CGFloat inlineBarH,
                     int showPercent, int twoRow) {
  // Use configured font size, Bold
  CGFloat fontSize =
      (CGFloat)(g_config.font_size > 0 ? g_config.font_size : 10);
  NSFont *lf = [NSFont monospacedDigitSystemFontOfSize:fontSize
                                                weight:NSFontWeightBold];
  NSDictionary *la = @{
    NSFontAttributeName : lf,
    NSForegroundColorAttributeName : menuBarLabelColor()
  };
  NSSize labelSize = [label sizeWithAttributes:la];
  CGFloat itemWidth =
      statusBarItemWidth(label, barW, fontSize, showPercent, twoRow);
  CGFloat barX = x + labelSize.width + 4;
  CGFloat barY = (imageHeight - inlineBarH) / 2.0;
  CGFloat barH = inlineBarH;
  CGFloat labelY = barY + (barH - labelSize.height) / 2.0 - 1;

  if (twoRow) {
    barX = x;
    barY = 1;
    barW = itemWidth;
    barH = g_config.bar_height > 0 ? (CGFloat)g_config.bar_height : 4;
    labelY = barY + barH + 2;
  }

  CGFloat fill = (pct / 100.0) * barW;
  if (fill < 1.0 && pct > 0)
    fill = 1.0;

  [label drawAtPoint:NSMakePoint(x, labelY) withAttributes:la];

  [[NSColor colorWithWhite:0.5 alpha:0.2] set];
  NSBezierPath *track =
      [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(barX, barY, barW, barH)
                                      xRadius:2
                                      yRadius:2];
  [track fill];

  if (fill > 0) {
    [color set];
    NSBezierPath *bar =
        [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(barX, barY, fill, barH)
                                        xRadius:2
                                        yRadius:2];
    [bar fill];
  }

  if (g_config.bar_border_width > 0) {
    CGFloat borderWidth = (CGFloat)g_config.bar_border_width;
    NSRect borderRect =
        NSInsetRect(NSMakeRect(barX, barY, barW, barH), borderWidth / 2.0,
                    borderWidth / 2.0);
    NSBezierPath *border =
        [NSBezierPath bezierPathWithRoundedRect:borderRect xRadius:2 yRadius:2];
    border.lineWidth = borderWidth;
    [barBorderColor() setStroke];
    [border stroke];
  }

  if (showPercent) {
    NSFont *pf = [NSFont monospacedDigitSystemFontOfSize:fontSize
                                                  weight:NSFontWeightRegular];
    NSDictionary *pa = @{
      NSFontAttributeName : pf,
      NSForegroundColorAttributeName : menuBarLabelColor()
    };
    NSString *pStr = [NSString stringWithFormat:@"%.0f%%", pct];
    NSSize percentSize = [pStr sizeWithAttributes:pa];
    CGFloat px = twoRow ? x + itemWidth - percentSize.width : barX + barW + 4;
    CGFloat py = twoRow ? labelY
                        : barY + (barH - percentSize.height) / 2.0 - 1;
    [pStr drawAtPoint:NSMakePoint(px, py) withAttributes:pa];
  }
}

static NSString *configuredLabel(const char *label, NSString *fallback) {
  if (label == NULL || label[0] == '\0')
    return fallback;
  return [NSString stringWithUTF8String:label] ?: fallback;
}

static NSArray<NSString *> *statusBarOrder(void) {
  NSArray<NSString *> *defaults = @[@"cpu", @"gpu", @"memory", @"fan"];
  NSSet<NSString *> *valid = [NSSet setWithArray:defaults];
  NSMutableArray<NSString *> *order = [NSMutableArray array];
  NSMutableSet<NSString *> *seen = [NSMutableSet set];
  NSString *configured =
      [NSString stringWithUTF8String:g_config.bar_order] ?: @"";

  for (NSString *part in [configured componentsSeparatedByString:@","]) {
    NSString *item = [[part
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
        lowercaseString];
    if ([valid containsObject:item] && ![seen containsObject:item]) {
      [order addObject:item];
      [seen addObject:item];
    }
  }
  for (NSString *item in defaults) {
    if (![seen containsObject:item])
      [order addObject:item];
  }
  return order;
}

static NSImage *drawStatusBarImage(double cpu, double gpu, double memPct,
                                   double watts, double cpuTemp,
                                   int fanRPM, int hasFan) {
  int showFan = g_config.show_fan && hasFan;
  NSArray<NSString *> *order = statusBarOrder();
  BOOL (^itemEnabled)(NSString *) = ^BOOL(NSString *item) {
    if ([item isEqualToString:@"cpu"])
      return g_config.show_cpu;
    if ([item isEqualToString:@"gpu"])
      return g_config.show_gpu;
    if ([item isEqualToString:@"memory"])
      return g_config.show_memory;
    return [item isEqualToString:@"fan"] && showFan;
  };
  int barCount = 0;
  for (NSString *item in order) {
    if (itemEnabled(item))
      barCount++;
  }

  // One font size controls labels, percentages, and wattage text.
  CGFloat fontSize =
      (CGFloat)(g_config.font_size > 0 ? g_config.font_size : 10);
  CGFloat powerFontSize = fontSize;

  // Height follows font size. Two-row layouts add room for their bar below
  // the text without exposing another size control.
  CGFloat h = fontSize + 8;
  int hasTwoRow = (g_config.show_cpu && g_config.cpu_two_row) ||
                  (g_config.show_gpu && g_config.gpu_two_row) ||
                  (g_config.show_memory && g_config.memory_two_row) ||
                  (showFan && g_config.fan_two_row);
  CGFloat twoRowBarH =
      g_config.bar_height > 0 ? (CGFloat)g_config.bar_height : 4;
  if (hasTwoRow && h < fontSize + twoRowBarH + 6)
    h = fontSize + twoRowBarH + 6;

  CGFloat gap = 6;
  CGFloat barH = g_config.bar_height > 0 ? (CGFloat)g_config.bar_height : h - 10;
  if (g_config.bar_height == 0 && barH < 4)
    barH = 4;
  if (h < barH + 4)
    h = barH + 4;
  CGFloat barW = (CGFloat)g_config.status_bar_width;
  NSString *cpuLabel = configuredLabel(g_config.cpu_label, @"C");
  NSString *gpuLabel = configuredLabel(g_config.gpu_label, @"G");
  NSString *memoryLabel = configuredLabel(g_config.memory_label, @"M");
  NSString *tempStr = [NSString stringWithFormat:@"%.0f°C", cpuTemp];
  NSString *fanStr = [NSString stringWithFormat:@"%d RPM", fanRPM];
  CGFloat (^itemWidth)(NSString *) = ^CGFloat(NSString *item) {
    if ([item isEqualToString:@"cpu"])
      return statusBarItemWidth(cpuLabel, barW, fontSize, g_config.show_percent,
                                g_config.cpu_two_row);
    if ([item isEqualToString:@"gpu"])
      return statusBarItemWidth(gpuLabel, barW, fontSize, g_config.show_percent,
                                g_config.gpu_two_row);
    if ([item isEqualToString:@"memory"])
      return statusBarItemWidth(memoryLabel, barW, fontSize,
                                g_config.show_percent,
                                g_config.memory_two_row);
    return statusBarFanWidth(tempStr, fanStr, fontSize, g_config.fan_two_row);
  };

  CGFloat textW = 0;
  NSString *wattStr = nil;
  NSDictionary *wattAttrs = nil;

  if (g_config.show_power) {
    wattStr = [NSString stringWithFormat:@" %.1fW ", watts];
    NSFont *pf = [NSFont monospacedDigitSystemFontOfSize:powerFontSize
                                                  weight:NSFontWeightMedium];
    wattAttrs = @{
      NSFontAttributeName : pf,
      NSForegroundColorAttributeName : menuBarLabelColor()
    };
    textW = [wattStr sizeWithAttributes:wattAttrs].width;
  }

  CGFloat totalW = (barCount > 0 ? (barCount - 1) * gap : 0) + 4;
  for (NSString *item in order) {
    if (itemEnabled(item))
      totalW += itemWidth(item);
  }
  if (g_config.show_power) {
    if (barCount > 0)
      totalW += gap; // Add gap if there are other bars
    totalW += textW;
  }

  NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(totalW, h)];
  [img lockFocus];

  CGFloat x = 2;
  for (NSString *item in order) {
    if (!itemEnabled(item))
      continue;
    if ([item isEqualToString:@"cpu"])
      drawHBar(cpuLabel, cpu, cpuColor(), x, h, barW, barH,
               g_config.show_percent, g_config.cpu_two_row);
    else if ([item isEqualToString:@"gpu"])
      drawHBar(gpuLabel, gpu, gpuColor(), x, h, barW, barH,
               g_config.show_percent, g_config.gpu_two_row);
    else if ([item isEqualToString:@"memory"])
      drawHBar(memoryLabel, memPct, memColor(), x, h, barW, barH,
               g_config.show_percent, g_config.memory_two_row);
    else
      drawStatusBarFan(tempStr, fanStr, x, h, fontSize, g_config.fan_two_row);
    x += itemWidth(item) + gap;
  }

  // Draw Wattage
  if (g_config.show_power && wattStr) {
    // Vertically center the text
    NSSize textSize = [wattStr sizeWithAttributes:wattAttrs];
    CGFloat ty = (h - textSize.height) / 2.0 - 1; // -1 optical adjustment
    [wattStr drawAtPoint:NSMakePoint(x, ty) withAttributes:wattAttrs];
  }

  [img unlockFocus];
  [img setTemplate:NO];
  return img;
}

static NSString *formatThroughput(double bps) {
  if (bps >= 1024 * 1024 * 1024)
    return [NSString stringWithFormat:@"%.1f GB/s", bps / (1024 * 1024 * 1024)];
  if (bps >= 1024 * 1024)
    return [NSString stringWithFormat:@"%.1f MB/s", bps / (1024 * 1024)];
  if (bps >= 1024)
    return [NSString stringWithFormat:@"%.1f KB/s", bps / 1024];
  return [NSString stringWithFormat:@"%.0f B/s", bps];
}

static void persistConfig(void) {
  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        GoSaveMenuBarConfig(
            g_config.status_bar_width, g_config.status_bar_height,
            g_config.sparkline_width, g_config.sparkline_height,
            g_config.show_cpu, g_config.show_gpu, g_config.show_ane,
            g_config.show_memory, g_config.show_power, g_config.show_percent,
            g_config.font_size, g_config.power_font_size, g_config.cpu_color,
            g_config.gpu_color, g_config.ane_color, g_config.mem_color,
            g_config.label_color);
      });
}

// refreshAllMenuColors walks the dropdown menu and re-applies textColors to
// any item.view that supports it. Required because NSTextField.textColor is
// cached at view creation, so existing items don't pick up label color
// changes from the Settings window without an explicit refresh.
static void refreshAllMenuColors(void) {
  if (!g_delegate || !g_delegate.statusMenu)
    return;
  for (NSMenuItem *it in g_delegate.statusMenu.itemArray) {
    NSView *v = it.view;
    if ([v respondsToSelector:@selector(refreshColors)]) {
      [(id)v refreshColors];
    }
  }
}

void setMenuBarConfig(menubar_config_t *cfg) {
  if (cfg) {
    g_config = *cfg;
    dispatch_async(dispatch_get_main_queue(), ^{
      refreshAllMenuColors();
      if (g_settingsWindow) {
        [g_settingsWindow syncUI];
      }
    });
  }
}

void updateMenuBarFanPolicyStatus(int state, int mode, int constantRPM,
                                  double startCelsius, double maximumCelsius,
                                  int minimumRPM, int maximumRPM, int rpmRangeState,
                                  unsigned long long generation, int responseSource,
                                  const char *detail, const char *message) {
  NSString *detailText = detail ? [NSString stringWithUTF8String:detail] : @"";
  NSString *messageText = message ? [NSString stringWithUTF8String:message] : @"";
  dispatch_async(dispatch_get_main_queue(), ^{
    if (g_settingsWindow) {
      [g_settingsWindow updateFanPolicyState:state mode:mode
                                 constantRPM:constantRPM
                                startCelsius:startCelsius
                              maximumCelsius:maximumCelsius
                                  minimumRPM:minimumRPM
                                  maximumRPM:maximumRPM
                                rpmRangeState:rpmRangeState
                                      generation:generation
                                  responseSource:responseSource
                                      detail:detailText
                                     message:messageText];
    }
  });
}

static void buildMenu(void) {
  @autoreleasepool {
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    g_delegate.statusItem =
        [statusBar statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *button = g_delegate.statusItem.button;
    button.title = @" mactop ";
    button.toolTip = messageText(@"Menu_Tooltip");
    CGFloat pfSize = (CGFloat)(g_config.font_size > 0 ? g_config.font_size : 10);
    button.font = [NSFont monospacedDigitSystemFontOfSize:pfSize
                                                   weight:NSFontWeightMedium];
    button.imagePosition = NSImageLeading;

    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;
    menu.minimumWidth = (CGFloat)g_config.sparkline_width + 16.0;

    [menu addItem:makeBrandingItem()];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *settingsItem =
        [[NSMenuItem alloc] initWithTitle:messageText(@"Menu_Settings")
                                   action:@selector(openSettings:)
                            keyEquivalent:@","];
    settingsItem.target = g_delegate;
    [menu addItem:settingsItem];
    NSMenuItem *tuiItem =
        [[NSMenuItem alloc] initWithTitle:messageText(@"Menu_OpenTUI")
                                   action:@selector(openTUI:)
                            keyEquivalent:@"t"];
    tuiItem.target = g_delegate;
    [menu addItem:tuiItem];
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:messageText(@"Menu_Quit")
                                                      action:@selector(quitApp:)
                                               keyEquivalent:@"q"];
    quitItem.target = g_delegate;
    [menu addItem:quitItem];
    [menu addItem:[NSMenuItem separatorItem]];

    g_delegate.modelItem = makeHeaderItem(messageText(@"Menu_AppleSilicon"));
    [menu addItem:g_delegate.modelItem];

    // Fan speeds are part of the device summary, not a separate metric group.
    g_delegate.fan0Item =
        makeMetricItem([NSString stringWithFormat:@"%@:", [NSString stringWithFormat:messageText(@"Menu_FanItem"), 0]],
                       @"\u2014");
    [menu addItem:g_delegate.fan0Item];
    g_delegate.fan1Item =
        makeMetricItem([NSString stringWithFormat:@"%@:", [NSString stringWithFormat:messageText(@"Menu_FanItem"), 1]],
                       @"\u2014");
    [menu addItem:g_delegate.fan1Item];
    g_delegate.fan2Item =
        makeMetricItem([NSString stringWithFormat:@"%@:", [NSString stringWithFormat:messageText(@"Menu_FanItem"), 2]],
                       @"\u2014");
    [menu addItem:g_delegate.fan2Item];
    g_delegate.fan3Item =
        makeMetricItem([NSString stringWithFormat:@"%@:", [NSString stringWithFormat:messageText(@"Menu_FanItem"), 3]],
                       @"\u2014");
    [menu addItem:g_delegate.fan3Item];
    g_delegate.fan0Item.hidden = YES;
    g_delegate.fan1Item.hidden = YES;
    g_delegate.fan2Item.hidden = YES;
    g_delegate.fan3Item.hidden = YES;
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:makeHeaderItem(messageText(@"Menu_CPU"))];
    g_delegate.cpuUsageItem = makeMetricItem(messageText(@"Menu_Usage"), @"\u2014");
    [menu addItem:g_delegate.cpuUsageItem];
    g_delegate.cpuEClusterItem = makeMetricItem(messageText(@"Menu_ECluster"), @"\u2014");
    [menu addItem:g_delegate.cpuEClusterItem];
    g_delegate.cpuPClusterItem = makeMetricItem(messageText(@"Menu_PCluster"), @"\u2014");
    [menu addItem:g_delegate.cpuPClusterItem];
    g_delegate.cpuSClusterItem = makeMetricItem(messageText(@"Menu_SCluster"), @"\u2014");
    [menu addItem:g_delegate.cpuSClusterItem];
    g_delegate.cpuSClusterItem.hidden =
        YES; // Hidden until S-cluster data arrives
    g_delegate.cpuWattsItem = makeMetricItem(messageText(@"Menu_Power"), @"\u2014");
    [menu addItem:g_delegate.cpuWattsItem];
    g_delegate.cpuTempItem = makeMetricItem(messageText(@"Menu_Temp"), @"\u2014");
    [menu addItem:g_delegate.cpuTempItem];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:makeHeaderItem(messageText(@"Menu_GPU"))];
    g_delegate.gpuUsageItem = makeMetricItem(messageText(@"Menu_Usage"), @"\u2014");
    [menu addItem:g_delegate.gpuUsageItem];
    g_delegate.gpuWattsItem = makeMetricItem(messageText(@"Menu_Power"), @"\u2014");
    [menu addItem:g_delegate.gpuWattsItem];
    g_delegate.gpuTflopsItem = makeMetricItem(messageText(@"Menu_TFLOPs"), @"\u2014");
    [menu addItem:g_delegate.gpuTflopsItem];
    g_delegate.gpuTempItem = makeMetricItem(messageText(@"Menu_Temp"), @"\u2014");
    [menu addItem:g_delegate.gpuTempItem];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:makeHeaderItem(messageText(@"Menu_MEMORY"))];
    g_delegate.memUsageItem = makeMetricItem(messageText(@"Menu_RAM"), @"\u2014");
    [menu addItem:g_delegate.memUsageItem];
    g_delegate.memSwapItem = makeMetricItem(messageText(@"Menu_Swap"), @"\u2014");
    [menu addItem:g_delegate.memSwapItem];
    g_delegate.dramBwItem = makeMetricItem(messageText(@"Menu_DRAMBW"), @"\u2014");
    [menu addItem:g_delegate.dramBwItem];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:makeHeaderItem(messageText(@"Menu_NETWORK"))];
    g_delegate.netItem = makeMetricItem(messageText(@"Menu_Network"), @"\u2014");
    [menu addItem:g_delegate.netItem];
    g_delegate.rdmaItem = makeMetricItem(messageText(@"Menu_RDMA"), @"\u2014");
    [menu addItem:g_delegate.rdmaItem];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:makeHeaderItem(messageText(@"Menu_DISK"))];
    g_delegate.diskItem = makeMetricItem(messageText(@"Menu_Disk"), @"\u2014");
    [menu addItem:g_delegate.diskItem];
    [menu addItem:[NSMenuItem separatorItem]];

    [menu addItem:makeHeaderItem(messageText(@"Menu_POWER"))];
    g_delegate.powerTotalItem = makeMetricItem(messageText(@"Menu_Total"), @"\u2014");
    [menu addItem:g_delegate.powerTotalItem];
    g_delegate.powerPackageItem = makeMetricItem(messageText(@"Menu_System"), @"\u2014");
    [menu addItem:g_delegate.powerPackageItem];
    g_delegate.powerCpuItem = makeMetricItem([NSString stringWithFormat:@"%@:", messageText(@"Menu_CPU")], @"\u2014");
    [menu addItem:g_delegate.powerCpuItem];
    g_delegate.powerGpuItem = makeMetricItem([NSString stringWithFormat:@"%@:", messageText(@"Menu_GPU")], @"\u2014");
    [menu addItem:g_delegate.powerGpuItem];
    g_delegate.powerAneItem = makeMetricItem([NSString stringWithFormat:@"%@:", messageText(@"Overlay_ANE")], @"\u2014");
    [menu addItem:g_delegate.powerAneItem];
    g_delegate.powerDramItem = makeMetricItem([NSString stringWithFormat:@"%@:", messageText(@"Overlay_DRAM")], @"\u2014");
    [menu addItem:g_delegate.powerDramItem];
    g_delegate.thermalItem = makeMetricItem(messageText(@"Menu_Thermal"), @"\u2014");
    [menu addItem:g_delegate.thermalItem];
    [menu addItem:[NSMenuItem separatorItem]];

    g_delegate.statusMenu = menu;

    // Do NOT set statusItem.menu — that couples menu width to button width.
    // Instead, handle clicks manually to present the menu independently.
    g_delegate.statusItem.button.action = @selector(statusBarClicked:);
    g_delegate.statusItem.button.target = g_delegate;
    [g_delegate.statusItem.button
        sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
  }
}

int startMenuBarInBackground(void) {
  @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    g_delegate = [[MactopMenuBarDelegate alloc] init];
    [NSApp setDelegate:g_delegate];
    buildMenu();
    [NSApp finishLaunching];
    return 0;
  }
}
int initMenuBar(void) {
  @autoreleasepool {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    g_delegate = [[MactopMenuBarDelegate alloc] init];
    [NSApp setDelegate:g_delegate];
    buildMenu();
    return 0;
  }
}
void updateMenuBarMetrics(menubar_metrics_t *m) {
  @autoreleasepool {
    if (g_delegate == nil || m == NULL)
      return;
    menubar_metrics_t copy = *m;
    NSValue *val = [NSValue valueWithBytes:&copy
                                  objCType:@encode(menubar_metrics_t)];
    dispatch_async(dispatch_get_main_queue(), ^{
      // The inner pool is optional now but kept for safety/consistency if more is added later.
      @autoreleasepool {
        [g_delegate performMetricUpdate:val];
      }
    });
  }
}
void pumpMenuBarEvents(void) {
  @autoreleasepool {
    NSEvent *event;
    while ((event = [NSApp nextEventMatchingMask:NSEventMaskAny
                                       untilDate:nil
                                          inMode:NSDefaultRunLoopMode
                                         dequeue:YES])) {
      [NSApp sendEvent:event];
    }
  }
}
void runMenuBarLoop(void) { [NSApp run]; }
void cleanupMenuBar(void) {
  if (g_delegate != nil) {
    if (g_delegate.statusItem != nil) {
      [[NSStatusBar systemStatusBar] removeStatusItem:g_delegate.statusItem];
      g_delegate.statusItem = nil;
    }
    g_delegate = nil;
  }
}

@implementation MactopMenuBarDelegate
- (void)quitApp:(id)sender {
  [NSApp terminate:nil];
}
- (void)openTUI:(id)sender {
  NSString *processPath =
      [[NSProcessInfo processInfo] arguments].firstObject ?: @"mactop";
  NSString *script =
      [NSString stringWithFormat:@"tell application \"Terminal\"\n  activate\n "
                                 @" do script \"%@\"\nend tell",
                                 processPath];
  NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
  [appleScript executeAndReturnError:nil];
}
- (void)openSettings:(id)sender {
  if (g_settingsWindow == nil) {
    g_settingsWindow = [[SettingsWindowController alloc] init];
  }
  [g_settingsWindow showWindow:sender];
}
- (void)statusBarClicked:(id)sender {
  NSStatusBarButton *button = self.statusItem.button;
  // Anchor first item at the top of the button so menu drops below menu bar
  NSMenuItem *first = self.statusMenu.itemArray.firstObject;
  [self.statusMenu
      popUpMenuPositioningItem:first
                    atLocation:NSMakePoint(0, button.bounds.size.height + 6)
                        inView:button];
}
- (void)performMetricUpdate:(NSValue *)val {
  menubar_metrics_t metrics;
  [val getValue:&metrics];
  [self doUpdate:&metrics];
}
- (void)doUpdate:(menubar_metrics_t *)mptr {
  @autoreleasepool {
    menubar_metrics_t metrics = *mptr;
    double memPct = 0;
    if (metrics.mem_total_bytes > 0) {
      memPct = (double)metrics.mem_used_bytes /
               (double)metrics.mem_total_bytes * 100.0;
    }
    int fanRPM = 0;
    for (int i = 0; i < metrics.fan_count; i++) {
      fanRPM = MAX(fanRPM, metrics.fan_rpm[i]);
    }

    self.statusItem.button.image =
        drawStatusBarImage(metrics.cpu_percent, metrics.gpu_percent,
                           memPct, metrics.total_watts, metrics.cpu_temp,
                           fanRPM, metrics.fan_count > 0);

    // Clear title as it is now drawn in image
    self.statusItem.button.title = @"";

    // Update menu views...
    MactopLabelView *mv = (MactopLabelView *)self.modelItem.view;
    // Build dynamic core summary — only show core types with non-zero counts
    NSMutableString *coreStr = [NSMutableString string];
    if (metrics.e_core_count > 0) {
      [coreStr appendFormat:@"%dE + ", metrics.e_core_count];
    }
    [coreStr appendFormat:@"%dP", metrics.p_core_count];
    if (metrics.s_core_count > 0) {
      [coreStr appendFormat:@" + %dS", metrics.s_core_count];
    }
    [coreStr appendFormat:@" + %dGPU", metrics.gpu_core_count];
    mv.label.stringValue = [NSString
        stringWithFormat:@"%s  (%@)", metrics.model_name, coreStr];

    MactopMetricView *v = (MactopMetricView *)self.cpuUsageItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Usage")
                 value:[NSString
                           stringWithFormat:@"%.1f%%", metrics.cpu_percent]];
    // E-Cluster: hide when e_core_count is 0 (M5+ has no E-cores)
    if (metrics.e_core_count > 0) {
      self.cpuEClusterItem.hidden = NO;
      v = (MactopMetricView *)self.cpuEClusterItem.view;
      [v setTwoToneLabel:messageText(@"Menu_ECluster")
                   value:[NSString stringWithFormat:@"%d MHz (%.1f%%)",
                                                    metrics.ecluster_freq_mhz,
                                                    metrics.ecluster_active]];
    } else {
      self.cpuEClusterItem.hidden = YES;
    }
    v = (MactopMetricView *)self.cpuPClusterItem.view;
    [v setTwoToneLabel:messageText(@"Menu_PCluster")
                 value:[NSString stringWithFormat:@"%d MHz (%.1f%%)",
                                                  metrics.pcluster_freq_mhz,
                                                  metrics.pcluster_active]];

    // S-Cluster: only show when data is present (M5+)
    if (metrics.scluster_freq_mhz > 0 || metrics.scluster_active > 0) {
      self.cpuSClusterItem.hidden = NO;
      v = (MactopMetricView *)self.cpuSClusterItem.view;
      [v setTwoToneLabel:messageText(@"Menu_SCluster")
                   value:[NSString stringWithFormat:@"%d MHz (%.1f%%)",
                                                    metrics.scluster_freq_mhz,
                                                    metrics.scluster_active]];
    }
    v = (MactopMetricView *)self.cpuWattsItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Power")
                 value:[NSString
                           stringWithFormat:@"%.2f W", metrics.cpu_watts]];
    v = (MactopMetricView *)self.cpuTempItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Temp")
                 value:[NSString stringWithFormat:@"%.1f°C", metrics.cpu_temp]];

    v = (MactopMetricView *)self.gpuUsageItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Usage")
                 value:[NSString stringWithFormat:@"%.1f%% (%d MHz)",
                                                  metrics.gpu_percent,
                                                  metrics.gpu_freq_mhz]];
    v = (MactopMetricView *)self.gpuWattsItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Power")
                 value:[NSString
                           stringWithFormat:@"%.2f W", metrics.gpu_watts]];
    double activeTF = (metrics.gpu_percent / 100.0) * metrics.tflops_fp32;
    v = (MactopMetricView *)self.gpuTflopsItem.view;
    [v setTwoToneLabel:messageText(@"Menu_TFLOPs")
                 value:[NSString stringWithFormat:@"%.2f / %.2f FP32", activeTF,
                                                  metrics.tflops_fp32]];
    v = (MactopMetricView *)self.gpuTempItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Temp")
                 value:[NSString stringWithFormat:@"%.1f°C", metrics.gpu_temp]];

    double memUsedGB =
        (double)metrics.mem_used_bytes / (1024.0 * 1024.0 * 1024.0);
    double memTotalGB =
        (double)metrics.mem_total_bytes / (1024.0 * 1024.0 * 1024.0);
    v = (MactopMetricView *)self.memUsageItem.view;
    [v setTwoToneLabel:messageText(@"Menu_RAM")
                 value:[NSString stringWithFormat:@"%.1f / %.0f GB (%.1f%%)",
                                                  memUsedGB, memTotalGB,
                                                  memPct]];
    double swapUsedGB =
        (double)metrics.swap_used_bytes / (1024.0 * 1024.0 * 1024.0);
    double swapTotalGB =
        (double)metrics.swap_total_bytes / (1024.0 * 1024.0 * 1024.0);
    v = (MactopMetricView *)self.memSwapItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Swap")
                 value:[NSString stringWithFormat:@"%.1f / %.1f GB", swapUsedGB,
                                                  swapTotalGB]];
    v = (MactopMetricView *)self.dramBwItem.view;
    [v setTwoToneLabel:messageText(@"Menu_DRAMBW")
                 value:[NSString
                           stringWithFormat:@"%.1f GB/s",
                                            metrics.dram_bw_combined_gbs]];

    v = (MactopMetricView *)self.netItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Network")
                 value:[NSString
                           stringWithFormat:@"↓ %@  ↑ %@",
                                            formatThroughput(
                                                metrics.net_in_bytes_per_sec),
                                            formatThroughput(
                                                metrics
                                                    .net_out_bytes_per_sec)]];
    v = (MactopMetricView *)self.rdmaItem.view;
    [v setTwoToneLabel:messageText(@"Menu_RDMA")
                 value:[NSString stringWithUTF8String:metrics.rdma_status]];

    v = (MactopMetricView *)self.diskItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Disk")
                 value:[NSString stringWithFormat:messageText(@"Menu_DiskRate"),
                                                  metrics.disk_read_kb_per_sec,
                                                  metrics.disk_write_kb_per_sec]];

    v = (MactopMetricView *)self.powerTotalItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Total")
                 value:[NSString
                           stringWithFormat:@"%.2f W", metrics.total_watts]];
    v = (MactopMetricView *)self.powerPackageItem.view;
    [v setTwoToneLabel:messageText(@"Menu_System")
                 value:[NSString
                           stringWithFormat:@"%.2f W", metrics.package_watts]];
    v = (MactopMetricView *)self.powerCpuItem.view;
    [v setTwoToneLabel:[NSString stringWithFormat:@"%@:", messageText(@"Menu_CPU")]
                 value:[NSString
                           stringWithFormat:@"%.2f W", metrics.cpu_watts]];
    v = (MactopMetricView *)self.powerGpuItem.view;
    [v setTwoToneLabel:[NSString stringWithFormat:@"%@:", messageText(@"Menu_GPU")]
                 value:[NSString
                           stringWithFormat:@"%.2f W", metrics.gpu_watts]];
    v = (MactopMetricView *)self.powerAneItem.view;
    [v setTwoToneLabel:[NSString stringWithFormat:@"%@:", messageText(@"Overlay_ANE")]
                 value:[NSString
                           stringWithFormat:@"%.2f W", metrics.ane_watts]];
    v = (MactopMetricView *)self.powerDramItem.view;
    [v setTwoToneLabel:[NSString stringWithFormat:@"%@:", messageText(@"Overlay_Memory")]
                 value:[NSString
                           stringWithFormat:@"%.2f W", metrics.dram_watts]];
    v = (MactopMetricView *)self.thermalItem.view;
    [v setTwoToneLabel:messageText(@"Menu_Thermal")
                 value:[NSString stringWithUTF8String:metrics.thermal_state]];

    // Fan data — show/hide individual items based on count
    NSMenuItem *fanItems[4] = {self.fan0Item, self.fan1Item, self.fan2Item, self.fan3Item};
    for (int i = 0; i < 4; i++) {
      if (i < metrics.fan_count) {
        fanItems[i].hidden = NO;
        v = (MactopMetricView *)fanItems[i].view;
        NSString *label = [NSString stringWithFormat:messageText(@"Menu_FanItem"), i];
        [v setTwoToneLabel:[NSString stringWithFormat:@"%@:", label]
                     value:[NSString stringWithFormat:@"%d RPM", metrics.fan_rpm[i]]];
      } else {
        fanItems[i].hidden = YES;
      }
    }
  } // @autoreleasepool
}
@end
