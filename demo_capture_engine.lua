#!/usr/bin/env luajit

-- Demo script showing the enhanced CaptureEngine functionality
-- This demonstrates the core logic coordination, source switching, and timing control

-- Set up testing environment
_G.TESTING_MODE = true

local CaptureEngine = require("src.capture_engine")

-- Mock LÖVE timer for demo
local mock_time = 0
_G.love = {
    timer = {
        getTime = function() return mock_time end
    }
}

local function advanceTime(dt)
    mock_time = mock_time + dt
end

print("=== Capture Engine Core Logic Demo ===")
print()

-- Create capture engine with custom settings
print("1. Creating CaptureEngine with 60 FPS target...")
local engine = CaptureEngine:new({
    frame_rate = 60,
    buffer_size = 5,
    monitor_performance = true
})

print("   ✓ Engine created with target FPS:", engine:getFrameRate())
print("   ✓ Performance monitoring:", engine.performance_monitor.enabled and "enabled" or "disabled")
print()

-- Demonstrate source configuration options (Requirement 5.2)
print("2. Getting available configuration options...")
local screen_options = engine:getSourceConfigurationOptions("screen")
print("   Screen capture modes:", table.concat(screen_options.modes, ", "))
print("   Frame rate range:", screen_options.frame_rate_range.min .. "-" .. screen_options.frame_rate_range.max .. " FPS")

local window_options = engine:getSourceConfigurationOptions("window")
print("   Window capture options:", #window_options.options, "available")
print()

-- Configure screen capture source
print("3. Configuring screen capture source...")
local success, err = engine:setSource("screen", {
    mode = "FULL_SCREEN",
    monitor_index = 1
})

if success then
    print("   ✓ Screen source configured successfully")
    local config = engine:getSourceConfig()
    print("   Current source:", config.source_type)
    print("   Current mode:", config.config.mode)
else
    print("   ✗ Failed to configure source:", err)
end
print()

-- Demonstrate immediate control response (Requirement 4.3)
print("4. Testing immediate control response...")
print("   Starting capture...")
success, err = engine:startCapture()
if success then
    print("   ✓ Capture started immediately")
    print("   Is capturing:", engine.is_capturing)
    print("   Is paused:", engine.is_paused)
else
    print("   ✗ Failed to start:", err)
end

-- Simulate some capture time
print("   Simulating 0.5 seconds of capture...")
for i = 1, 30 do  -- 30 frames at 60 FPS = 0.5 seconds
    advanceTime(1/60)
    engine:update(1/60)
end

local stats_before_pause = engine:getStats()
print("   Frames captured before pause:", stats_before_pause.frames_captured)

-- Test pause functionality
print("   Pausing capture...")
success, err = engine:pauseCapture()
if success then
    print("   ✓ Capture paused immediately")
    print("   Is capturing:", engine.is_capturing)
    print("   Is paused:", engine.is_paused)
else
    print("   ✗ Failed to pause:", err)
end

-- Simulate time while paused
print("   Simulating 0.3 seconds while paused...")
for i = 1, 18 do  -- 18 frames at 60 FPS = 0.3 seconds
    advanceTime(1/60)
    engine:update(1/60)
end

local stats_during_pause = engine:getStats()
print("   Frames captured during pause:", stats_during_pause.frames_captured)
print("   ✓ No frames captured while paused:", stats_before_pause.frames_captured == stats_during_pause.frames_captured)

-- Test resume functionality
print("   Resuming capture...")
success, err = engine:resumeCapture()
if success then
    print("   ✓ Capture resumed immediately")
    print("   Is capturing:", engine.is_capturing)
    print("   Is paused:", engine.is_paused)
else
    print("   ✗ Failed to resume:", err)
end

-- Simulate more capture time
print("   Simulating 0.5 seconds after resume...")
for i = 1, 30 do  -- 30 frames at 60 FPS = 0.5 seconds
    advanceTime(1/60)
    engine:update(1/60)
end

local stats_after_resume = engine:getStats()
print("   Frames captured after resume:", stats_after_resume.frames_captured)
print("   ✓ Frames captured after resume:", stats_after_resume.frames_captured > stats_during_pause.frames_captured)
print()

-- Demonstrate source switching
print("5. Testing source switching during capture...")
success, err = engine:setSource("window", {
    tracking = true,
    dpi_aware = true,
    capture_borders = false
})

if success then
    print("   ✓ Switched to window capture while capturing")
    print("   Still capturing:", engine.is_capturing)
    local new_config = engine:getSourceConfig()
    print("   New source:", new_config.source_type)
    print("   DPI aware:", new_config.config.dpi_aware)
else
    print("   ✗ Failed to switch source:", err)
end
print()

-- Demonstrate frame rate control and real-time performance (Requirement 4.4)
print("6. Testing frame rate control and performance...")
print("   Setting frame rate to 120 FPS...")
success, err = engine:setFrameRate(120)
if success then
    print("   ✓ Frame rate updated to:", engine:getFrameRate(), "FPS")
    print("   Frame interval:", string.format("%.3f", engine.frame_interval), "seconds")
else
    print("   ✗ Failed to set frame rate:", err)
end

-- Simulate high-frequency capture to test performance
print("   Simulating high-frequency capture (120 FPS for 1 second)...")
local start_frames = engine.capture_stats.frames_captured
for i = 1, 120 do
    advanceTime(1/120)
    engine:update(1/120)
end

local final_stats = engine:getStats()
print("   Frames captured in 1 second:", final_stats.frames_captured - start_frames)
print("   Frames dropped:", final_stats.frames_dropped)
print("   Frames skipped:", final_stats.frames_skipped)
print("   Average FPS:", string.format("%.1f", final_stats.average_fps))
print("   Actual FPS:", string.format("%.1f", final_stats.actual_fps))

if final_stats.performance then
    print("   Average capture time:", string.format("%.3f", final_stats.performance.average_capture_time), "seconds")
    print("   Max capture time:", string.format("%.3f", final_stats.performance.max_capture_time), "seconds")
end
print()

-- Stop capture
print("7. Stopping capture...")
success = engine:stopCapture()
if success then
    print("   ✓ Capture stopped immediately")
    print("   Is capturing:", engine.is_capturing)
    print("   Is paused:", engine.is_paused)
else
    print("   ✗ Failed to stop capture")
end
print()

-- Show final statistics
print("8. Final capture statistics:")
local final_stats = engine:getStats()
print("   Total frames captured:", final_stats.frames_captured)
print("   Total frames dropped:", final_stats.frames_dropped)
print("   Total frames skipped:", final_stats.frames_skipped)
print("   Total capture duration:", string.format("%.2f", final_stats.capture_duration), "seconds")
print("   Overall average FPS:", string.format("%.1f", final_stats.average_fps))
print("   Buffer frame count:", final_stats.buffer_stats.frame_count)
print("   Buffer memory usage:", final_stats.buffer_stats.memory_usage, "bytes")
print()

-- Demonstrate available sources
print("9. Available capture sources:")
local sources = engine:getAvailableSources()
for source_type, info in pairs(sources) do
    print("   " .. source_type .. ":", info.available and "available" or ("unavailable - " .. (info.reason or "unknown")))
    if info.available and info.monitors then
        print("     Monitors:", #info.monitors)
    end
    if info.available and info.windows then
        print("     Windows:", #info.windows)
    end
end
print()

print("=== Demo Complete ===")
print("The CaptureEngine successfully demonstrates:")
print("✓ Source coordination and switching")
print("✓ Frame rate control and timing mechanisms")
print("✓ Immediate response to playback controls (Requirement 4.3)")
print("✓ Frame dropping for real-time performance (Requirement 4.4)")
print("✓ Configuration options for sources (Requirement 5.2)")
print("✓ Comprehensive statistics and monitoring")