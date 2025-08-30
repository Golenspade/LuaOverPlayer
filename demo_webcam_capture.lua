#!/usr/bin/env luajit

-- Demo script for Webcam Capture functionality
-- This script demonstrates the webcam capture capabilities

-- Add src directory to package path
package.path = package.path .. ";./src/?.lua"

local WebcamCapture = require("src.webcam_capture")
local CaptureEngine = require("src.capture_engine")

-- Function to print device information
local function printDeviceInfo(device, index)
    print(string.format("  Device %d:", index))
    print(string.format("    Name: %s", device.name or "Unknown"))
    print(string.format("    Index: %d", device.index or -1))
    print(string.format("    Available: %s", device.available and "Yes" or "No"))
    
    if device.supported_resolutions then
        print("    Supported Resolutions:")
        for _, res in ipairs(device.supported_resolutions) do
            print(string.format("      %dx%d", res.width, res.height))
        end
    end
    
    if device.supported_frame_rates then
        print("    Supported Frame Rates:")
        local rates = {}
        for _, rate in ipairs(device.supported_frame_rates) do
            table.insert(rates, tostring(rate))
        end
        print("      " .. table.concat(rates, ", ") .. " FPS")
    end
    
    if device.pixel_formats then
        print("    Supported Pixel Formats:")
        print("      " .. table.concat(device.pixel_formats, ", "))
    end
end

-- Function to demonstrate webcam capture
local function demonstrateWebcamCapture()
    print("=== Webcam Capture Demo ===")
    print()
    
    -- Check if webcam capture is available
    local webcam = WebcamCapture:new()
    local available = webcam:isAvailable()
    
    print("Webcam Capture Available: " .. (available and "Yes" or "No"))
    
    if not available then
        print("Reason: Media Foundation not available (Windows only)")
        print("This demo will show the API structure with mock data.")
        print()
    end
    
    -- Initialize webcam capture
    print("Initializing webcam capture...")
    local success, error_msg = webcam:initialize()
    
    if success then
        print("✓ Webcam capture initialized successfully")
        
        -- Get available devices
        local devices = webcam:getAvailableDevices()
        print(string.format("Found %d video capture device(s):", #devices))
        
        for i, device in ipairs(devices) do
            printDeviceInfo(device, i - 1)
        end
        print()
        
        -- Configure webcam
        print("Configuring webcam...")
        local config_success = true
        
        -- Set resolution
        local res_success, res_error = webcam:setResolution(640, 480)
        if res_success then
            print("✓ Resolution set to 640x480")
        else
            print("✗ Failed to set resolution: " .. (res_error or "Unknown error"))
            config_success = false
        end
        
        -- Set frame rate
        local fps_success, fps_error = webcam:setFrameRate(30)
        if fps_success then
            print("✓ Frame rate set to 30 FPS")
        else
            print("✗ Failed to set frame rate: " .. (fps_error or "Unknown error"))
            config_success = false
        end
        
        if config_success then
            -- Start capture
            print("\nStarting webcam capture...")
            local capture_success, capture_error = webcam:startCapture()
            
            if capture_success then
                print("✓ Webcam capture started")
                
                -- Capture a few frames
                print("\nCapturing frames...")
                for i = 1, 5 do
                    local frame = webcam:captureFrame()
                    if frame then
                        print(string.format("Frame %d: %dx%d, %d bytes, format: %s", 
                            i, frame.width, frame.height, #frame.data, frame.format))
                    else
                        print(string.format("Frame %d: Failed to capture", i))
                    end
                    
                    -- Small delay between captures
                    os.execute("sleep 0.1")
                end
                
                -- Show statistics
                print("\nCapture Statistics:")
                local stats = webcam:getStats()
                print(string.format("  Frames Captured: %d", stats.frames_captured))
                print(string.format("  Frames Dropped: %d", stats.frames_dropped))
                print(string.format("  Capture Errors: %d", stats.capture_errors))
                print(string.format("  Average FPS: %.2f", stats.average_fps))
                print(string.format("  Current Device: %s", stats.current_device))
                print(string.format("  Resolution: %s", stats.resolution))
                print(string.format("  Frame Rate: %d FPS", stats.frame_rate))
                print(string.format("  State: %s", stats.state))
                
                -- Stop capture
                print("\nStopping webcam capture...")
                webcam:stopCapture()
                print("✓ Webcam capture stopped")
                
            else
                print("✗ Failed to start webcam capture: " .. (capture_error or "Unknown error"))
            end
        end
        
    else
        print("✗ Failed to initialize webcam capture: " .. (error_msg or "Unknown error"))
    end
    
    -- Cleanup
    webcam:cleanup()
    print("✓ Webcam capture cleaned up")
end

-- Function to demonstrate capture engine integration
local function demonstrateCaptureEngineIntegration()
    print("\n=== Capture Engine Integration Demo ===")
    print()
    
    local engine = CaptureEngine:new()
    
    -- Get available sources
    local sources = engine:getAvailableSources()
    print("Available capture sources:")
    
    for source_type, source_info in pairs(sources) do
        print(string.format("  %s: %s", source_type, source_info.available and "Available" or "Not Available"))
        if not source_info.available and source_info.reason then
            print(string.format("    Reason: %s", source_info.reason))
        end
    end
    print()
    
    -- Test webcam source configuration
    if sources.webcam and sources.webcam.available then
        print("Testing webcam source configuration...")
        
        local config = {
            device_index = 0,
            resolution = {width = 640, height = 480},
            frame_rate = 30
        }
        
        local success, error_msg = engine:setSource("webcam", config)
        if success then
            print("✓ Webcam source configured successfully")
            
            -- Get configuration options
            local config_options = engine:getSourceConfigurationOptions("webcam")
            print("Webcam configuration options:")
            print(string.format("  Available: %s", config_options.available and "Yes" or "No"))
            
            if config_options.options then
                for _, option in ipairs(config_options.options) do
                    print(string.format("  %s (%s): %s", option.name, option.type, option.description))
                end
            end
            
            -- Test capture
            print("\nTesting capture with engine...")
            local capture_success = engine:startCapture()
            if capture_success then
                print("✓ Capture started through engine")
                
                -- Capture a frame
                local frame = engine:captureFrame()
                if frame then
                    print(string.format("✓ Frame captured: %dx%d", frame.width, frame.height))
                else
                    print("✗ Failed to capture frame through engine")
                end
                
                engine:stopCapture()
                print("✓ Capture stopped")
            else
                print("✗ Failed to start capture through engine")
            end
            
        else
            print("✗ Failed to configure webcam source: " .. (error_msg or "Unknown error"))
        end
    else
        print("Webcam source not available for testing")
    end
end

-- Main demo function
local function main()
    print("Lua Video Capture Player - Webcam Capture Demo")
    print("===============================================")
    print()
    
    -- Demonstrate basic webcam capture
    demonstrateWebcamCapture()
    
    -- Demonstrate capture engine integration
    demonstrateCaptureEngineIntegration()
    
    print("\n=== Demo Complete ===")
    print("Note: On non-Windows platforms, this demo uses mock data")
    print("to demonstrate the API structure and functionality.")
end

-- Run the demo
main()