package app

import "testing"

func TestLoadMenuBarConfigLabels(t *testing.T) {
	tests := []struct {
		name       string
		menuBar    *MenuBarConfig
		wantCPU    string
		wantGPU    string
		wantANE    string
		wantMemory string
	}{
		{
			name:       "defaults",
			wantCPU:    "C",
			wantGPU:    "G",
			wantANE:    "A",
			wantMemory: "M",
		},
		{
			name: "custom labels",
			menuBar: &MenuBarConfig{
				CPULabel:    "CPU",
				GPULabel:    "Graphics",
				ANELabel:    "Neural",
				MemoryLabel: "RAM",
			},
			wantCPU:    "CPU",
			wantGPU:    "Graphics",
			wantANE:    "Neural",
			wantMemory: "RAM",
		},
		{
			name: "empty labels use defaults",
			menuBar: &MenuBarConfig{
				CPULabel:    "",
				GPULabel:    "",
				ANELabel:    "",
				MemoryLabel: "",
			},
			wantCPU:    "C",
			wantGPU:    "G",
			wantANE:    "A",
			wantMemory: "M",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			previousConfig := currentConfig
			currentConfig = AppConfig{MenuBar: test.menuBar}
			t.Cleanup(func() { currentConfig = previousConfig })

			got := loadMenuBarConfig()
			if got.CPULabel != test.wantCPU {
				t.Errorf("CPULabel = %q, want %q", got.CPULabel, test.wantCPU)
			}
			if got.GPULabel != test.wantGPU {
				t.Errorf("GPULabel = %q, want %q", got.GPULabel, test.wantGPU)
			}
			if got.ANELabel != test.wantANE {
				t.Errorf("ANELabel = %q, want %q", got.ANELabel, test.wantANE)
			}
			if got.MemoryLabel != test.wantMemory {
				t.Errorf("MemoryLabel = %q, want %q", got.MemoryLabel, test.wantMemory)
			}
		})
	}
}

func TestLoadMenuBarConfigLayouts(t *testing.T) {
	tests := []struct {
		name       string
		menuBar    *MenuBarConfig
		wantCPU    string
		wantGPU    string
		wantANE    string
		wantMemory string
		wantFan    string
	}{
		{
			name:       "defaults",
			wantCPU:    "inline",
			wantGPU:    "inline",
			wantANE:    "inline",
			wantMemory: "inline",
			wantFan:    "inline",
		},
		{
			name: "two row layouts",
			menuBar: &MenuBarConfig{
				CPULayout:    "two_row",
				GPULayout:    "two_row",
				ANELayout:    "two_row",
				MemoryLayout: "two_row",
				FanLayout:    "two_row",
			},
			wantCPU:    "two_row",
			wantGPU:    "two_row",
			wantANE:    "two_row",
			wantMemory: "two_row",
			wantFan:    "two_row",
		},
		{
			name: "unknown layouts use defaults",
			menuBar: &MenuBarConfig{
				CPULayout:    "stacked",
				GPULayout:    "two-row",
				ANELayout:    "sideways",
				MemoryLayout: "compact",
				FanLayout:    "stacked",
			},
			wantCPU:    "inline",
			wantGPU:    "inline",
			wantANE:    "inline",
			wantMemory: "inline",
			wantFan:    "inline",
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			previousConfig := currentConfig
			currentConfig = AppConfig{MenuBar: test.menuBar}
			t.Cleanup(func() { currentConfig = previousConfig })

			got := loadMenuBarConfig()
			if got.CPULayout != test.wantCPU {
				t.Errorf("CPULayout = %q, want %q", got.CPULayout, test.wantCPU)
			}
			if got.GPULayout != test.wantGPU {
				t.Errorf("GPULayout = %q, want %q", got.GPULayout, test.wantGPU)
			}
			if got.ANELayout != test.wantANE {
				t.Errorf("ANELayout = %q, want %q", got.ANELayout, test.wantANE)
			}
			if got.MemoryLayout != test.wantMemory {
				t.Errorf("MemoryLayout = %q, want %q", got.MemoryLayout, test.wantMemory)
			}
			if got.FanLayout != test.wantFan {
				t.Errorf("FanLayout = %q, want %q", got.FanLayout, test.wantFan)
			}
		})
	}
}

func TestLoadMenuBarConfigShowFan(t *testing.T) {
	show := true
	previousConfig := currentConfig
	currentConfig = AppConfig{MenuBar: &MenuBarConfig{ShowFan: &show}}
	t.Cleanup(func() { currentConfig = previousConfig })

	got := loadMenuBarConfig()
	if got.ShowFan == nil || !*got.ShowFan {
		t.Error("ShowFan should be enabled")
	}
}

func TestLoadMenuBarConfigBarOrder(t *testing.T) {
	tests := []struct {
		name  string
		order string
		want  string
	}{
		{name: "default", want: "cpu,gpu,memory,fan"},
		{name: "custom", order: "fan,cpu,gpu,ane,memory", want: "fan,cpu,gpu,ane,memory"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			previousConfig := currentConfig
			currentConfig = AppConfig{MenuBar: &MenuBarConfig{BarOrder: test.order}}
			t.Cleanup(func() { currentConfig = previousConfig })

			if got := loadMenuBarConfig().BarOrder; got != test.want {
				t.Errorf("BarOrder = %q, want %q", got, test.want)
			}
		})
	}
}

func TestLoadMenuBarConfigBorder(t *testing.T) {
	tests := []struct {
		name      string
		menuBar   *MenuBarConfig
		wantWidth int
		wantColor string
	}{
		{name: "disabled by default"},
		{
			name:      "custom border",
			menuBar:   &MenuBarConfig{BarBorderWidth: 1, BarBorderColor: "#A0A0A0"},
			wantWidth: 1,
			wantColor: "#A0A0A0",
		},
		{
			name:      "negative width is disabled",
			menuBar:   &MenuBarConfig{BarBorderWidth: -1},
			wantWidth: 0,
		},
		{
			name:      "width is capped",
			menuBar:   &MenuBarConfig{BarBorderWidth: 10},
			wantWidth: 3,
		},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			previousConfig := currentConfig
			currentConfig = AppConfig{MenuBar: test.menuBar}
			t.Cleanup(func() { currentConfig = previousConfig })

			got := loadMenuBarConfig()
			if got.BarBorderWidth != test.wantWidth {
				t.Errorf("BarBorderWidth = %d, want %d", got.BarBorderWidth, test.wantWidth)
			}
			if got.BarBorderColor != test.wantColor {
				t.Errorf("BarBorderColor = %q, want %q", got.BarBorderColor, test.wantColor)
			}
		})
	}
}

func TestLoadMenuBarConfigBarHeight(t *testing.T) {
	tests := []struct {
		name       string
		configured int
		want       int
	}{
		{name: "automatic by default"},
		{name: "fixed height", configured: 6, want: 6},
		{name: "negative height is automatic", configured: -1},
		{name: "height is capped", configured: 20, want: 12},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			previousConfig := currentConfig
			currentConfig = AppConfig{MenuBar: &MenuBarConfig{BarHeight: test.configured}}
			t.Cleanup(func() { currentConfig = previousConfig })

			if got := loadMenuBarConfig().BarHeight; got != test.want {
				t.Errorf("BarHeight = %d, want %d", got, test.want)
			}
		})
	}
}
