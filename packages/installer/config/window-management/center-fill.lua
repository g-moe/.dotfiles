hs.window.animationDuration = 0

local gap = 16

local function placeWindow(win)
  if not win then
    return
  end

  hs.timer.doAfter(0.1, function()
    if win:isMaximizable() == true then
      -- Fill the usable desktop without entering macOS Full Screen.
      local frame = win:screen():frame()
      win:setFrame({
        x = frame.x + gap,
        y = frame.y + gap,
        w = frame.w - gap * 2,
        h = frame.h - gap * 2,
      }, 0)
    else
      -- Keep fixed-size windows at their existing size and center them.
      win:centerOnScreen(nil, true, 0)
    end
  end)
end

centerFillWindowWatcher = hs.window.filter.new(function(win)
  return win:role() == "AXWindow"
end)

centerFillWindowWatcher:subscribe({
  hs.window.filter.windowCreated,
  hs.window.filter.windowFocused,
  hs.window.filter.windowUnminimized,
}, placeWindow)

for _, win in ipairs(centerFillWindowWatcher:getWindows()) do
  placeWindow(win)
end
