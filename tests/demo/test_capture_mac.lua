#!/usr/bin/env love

-- Simple test for capture functionality on Mac
local CaptureEngine = require("src.capture_engine")
local VideoRenderer = require("src.video_renderer")

function love.load()
    print("Testing capture functionality on Mac...")
    
    -- Create capture engine
    capture_engine = CaptureEngine:new({
        frame_rate = 30,
        monitor_performance = true
    })
    
    -- Create video renderer
    renderer = VideoRenderer:new()
    
    -- Get available sources
    local sources = capture_engine:getAvailableSources()
    print("Available sources:")
    for source_type, source_info in pairs(sources) do
        print("  " .. source_type .. ": " .. (source_info.available and "Available" or "Not Available"))
        if source_info.reason then
            print("    Reason: " .. source_info.reason)
        end
    end
    
    -- Try to set screen capture source
    local success, err = capture_engine:setSource("screen", {
        mode = "FULL_SCREEN"
    })
    
    if success then
        print("Screen capture source set successfully")
        
        -- Start capture
        local start_success, start_err = capture_engine:startCapture()
        if start_success then
            print("Capture started successfully")
        else
            print("Failed to start capture: " .. (start_err or "Unknown error"))
        end
    else
        print("Failed to set screen capture source: " .. (err or "Unknown error"))
    end
end

function love.update(dt)
    if capture_engine then
        capture_engine:update(dt)
        
        -- Try to get a frame
        local frame = capture_engine:getFrame()
        if frame then
            print("Frame captured: " .. frame.width .. "x" .. frame.height)
        end
    end
end

function love.draw()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Capture Test - Check console for output", 10, 10)
    
    if capture_engine then
        local stats = capture_engine:getStats()
        local y = 30
        
        love.graphics.print("Capturing: " .. (stats.is_capturing and "YES" or "NO"), 10, y)
        y = y + 20
        love.graphics.print("Frames captured: " .. stats.frames_captured, 10, y)
        y = y + 20
        love.graphics.print("FPS: " .. string.format("%.1f", stats.actual_fps), 10, y)
        y = y + 20
        
        if stats.last_error then
            love.graphics.setColor(1, 0, 0)
            love.graphics.print("Error: " .. stats.last_error, 10, y)
            love.graphics.setColor(1, 1, 1)
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end