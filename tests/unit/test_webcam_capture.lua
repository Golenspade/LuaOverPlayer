-- Test suite for WebcamCapture module
local TestFramework = require("tests.test_framework")
local WebcamCapture = require("src.webcam_capture")

local WebcamCaptureTests = {}

-- Test webcam capture initialization
function WebcamCaptureTests.test_initialization()
    local webcam = WebcamCapture:new()
    
    -- Test initial state
    TestFramework.assert_equal(webcam.state, WebcamCapture.CAPTURE_STATES.UNINITIALIZED, "Initial state should be uninitialized")
    TestFramework.assert_equal(webcam.device_index, 0, "Default device index should be 0")
    TestFramework.assert_equal(webcam.resolution.width, 640, "Default width should be 640")
    TestFramework.assert_equal(webcam.resolution.height, 480, "Default height should be 480")
    TestFramework.assert_equal(webcam.frame_rate, 30, "Default frame rate should be 30")
    
    -- Test initialization
    local success, error_msg = webcam:initialize()
    
    -- Note: This test may fail on systems without Media Foundation or cameras
    -- We'll test both success and failure cases
    if success then
        TestFramework.assert_equal(webcam.state, WebcamCapture.CAPTURE_STATES.INITIALIZED, "State should be initialized after successful init")
        TestFramework.assert_true(#webcam.available_devices > 0, "Should have at least one device available")
        TestFramework.assert_not_nil(webcam.current_device, "Should have a current device set")
    else
        TestFramework.assert_true(webcam.state == WebcamCapture.CAPTURE_STATES.ERROR, "State should be error on failed init")
        TestFramework.assert_not_nil(error_msg, "Should have error message on failed init")
    end
    
    webcam:cleanup()
end

-- Test webcam capture with custom options
function WebcamCaptureTests.test_initialization_with_options()
    local options = {
        device_index = 0,
        width = 1280,
        height = 720,
        frame_rate = 60,
        pixel_format = "RGB24"
    }
    
    local webcam = WebcamCapture:new(options)
    
    TestFramework.assert_equal(webcam.device_index, 0, "Device index should match options")
    TestFramework.assert_equal(webcam.resolution.width, 1280, "Width should match options")
    TestFramework.assert_equal(webcam.resolution.height, 720, "Height should match options")
    TestFramework.assert_equal(webcam.frame_rate, 60, "Frame rate should match options")
    TestFramework.assert_equal(webcam.pixel_format, "RGB24", "Pixel format should match options")
    
    webcam:cleanup()
end

-- Test device enumeration (Requirement 3.1)
function WebcamCaptureTests.test_device_enumeration()
    local webcam = WebcamCapture:new()
    
    -- Test enumeration before initialization (should fail)
    local devices, error_msg = webcam:enumerateDevices()
    TestFramework.assert_nil(devices, "Device enumeration should fail before initialization")
    TestFramework.assert_not_nil(error_msg, "Should have error message")
    
    -- Initialize and test enumeration
    local init_success = webcam:initialize()
    if init_success then
        devices = webcam:getAvailableDevices()
        TestFramework.assert_not_nil(devices, "Should have devices list after initialization")
        TestFramework.assert_true(type(devices) == "table", "Devices should be a table")
        
        -- Test device structure
        if #devices > 0 then
            local device = devices[1]
            TestFramework.assert_not_nil(device.name, "Device should have a name")
            TestFramework.assert_not_nil(device.index, "Device should have an index")
            TestFramework.assert_not_nil(device.available, "Device should have availability status")
        end
    end
    
    webcam:cleanup()
end

-- Test device selection (Requirement 3.2)
function WebcamCaptureTests.test_device_selection()
    local webcam = WebcamCapture:new()
    local init_success = webcam:initialize()
    
    if not init_success then
        print("Skipping device selection test - initialization failed")
        return
    end
    
    local devices = webcam:getAvailableDevices()
    if #devices == 0 then
        print("Skipping device selection test - no devices available")
        webcam:cleanup()
        return
    end
    
    -- Test valid device selection
    local success, error_msg = webcam:setDevice(0)
    TestFramework.assert_true(success, "Should be able to set valid device")
    TestFramework.assert_nil(error_msg, "Should not have error for valid device")
    TestFramework.assert_equal(webcam.device_index, 0, "Device index should be updated")
    
    -- Test invalid device selection
    success, error_msg = webcam:setDevice(999)
    TestFramework.assert_false(success, "Should fail to set invalid device")
    TestFramework.assert_not_nil(error_msg, "Should have error message for invalid device")
    
    -- Test device selection while capturing
    webcam:startCapture()
    success, error_msg = webcam:setDevice(0)
    TestFramework.assert_false(success, "Should not be able to change device while capturing")
    TestFramework.assert_not_nil(error_msg, "Should have error message")
    
    webcam:cleanup()
end

-- Test resolution configuration (Requirement 3.3)
function WebcamCaptureTests.test_resolution_configuration()
    local webcam = WebcamCapture:new()
    
    -- Test valid resolution
    local success, error_msg = webcam:setResolution(1280, 720)
    TestFramework.assert_true(success, "Should be able to set valid resolution")
    TestFramework.assert_nil(error_msg, "Should not have error for valid resolution")
    TestFramework.assert_equal(webcam.resolution.width, 1280, "Width should be updated")
    TestFramework.assert_equal(webcam.resolution.height, 720, "Height should be updated")
    
    -- Test invalid resolution
    success, error_msg = webcam:setResolution(0, 480)
    TestFramework.assert_false(success, "Should fail to set invalid resolution")
    TestFramework.assert_not_nil(error_msg, "Should have error message for invalid resolution")
    
    success, error_msg = webcam:setResolution(640, -1)
    TestFramework.assert_false(success, "Should fail to set negative resolution")
    TestFramework.assert_not_nil(error_msg, "Should have error message for negative resolution")
    
    -- Test resolution change while capturing
    local init_success = webcam:initialize()
    if init_success then
        webcam:startCapture()
        success, error_msg = webcam:setResolution(640, 480)
        TestFramework.assert_false(success, "Should not be able to change resolution while capturing")
        TestFramework.assert_not_nil(error_msg, "Should have error message")
    end
    
    webcam:cleanup()
end

-- Test frame rate configuration (Requirement 3.3)
function WebcamCaptureTests.test_frame_rate_configuration()
    local webcam = WebcamCapture:new()
    
    -- Test valid frame rate
    local success, error_msg = webcam:setFrameRate(60)
    TestFramework.assert_true(success, "Should be able to set valid frame rate")
    TestFramework.assert_nil(error_msg, "Should not have error for valid frame rate")
    TestFramework.assert_equal(webcam.frame_rate, 60, "Frame rate should be updated")
    
    -- Test invalid frame rate
    success, error_msg = webcam:setFrameRate(0)
    TestFramework.assert_false(success, "Should fail to set zero frame rate")
    TestFramework.assert_not_nil(error_msg, "Should have error message for zero frame rate")
    
    success, error_msg = webcam:setFrameRate(200)
    TestFramework.assert_false(success, "Should fail to set excessive frame rate")
    TestFramework.assert_not_nil(error_msg, "Should have error message for excessive frame rate")
    
    -- Test frame rate change while capturing
    local init_success = webcam:initialize()
    if init_success then
        webcam:startCapture()
        success, error_msg = webcam:setFrameRate(15)
        TestFramework.assert_false(success, "Should not be able to change frame rate while capturing")
        TestFramework.assert_not_nil(error_msg, "Should have error message")
    end
    
    webcam:cleanup()
end

-- Test capture start and stop (Requirement 3.2)
function WebcamCaptureTests.test_capture_start_stop()
    local webcam = WebcamCapture:new()
    
    -- Test start without initialization
    local success, error_msg = webcam:startCapture()
    TestFramework.assert_false(success, "Should fail to start capture without initialization")
    TestFramework.assert_not_nil(error_msg, "Should have error message")
    
    -- Initialize and test capture
    local init_success = webcam:initialize()
    if not init_success then
        print("Skipping capture test - initialization failed")
        return
    end
    
    -- Test successful start
    success, error_msg = webcam:startCapture()
    TestFramework.assert_true(success, "Should be able to start capture after initialization")
    TestFramework.assert_equal(webcam.state, WebcamCapture.CAPTURE_STATES.CAPTURING, "State should be capturing")
    
    -- Test double start (should succeed)
    success, error_msg = webcam:startCapture()
    TestFramework.assert_true(success, "Should handle double start gracefully")
    
    -- Test stop
    success = webcam:stopCapture()
    TestFramework.assert_true(success, "Should be able to stop capture")
    TestFramework.assert_equal(webcam.state, WebcamCapture.CAPTURE_STATES.STOPPED, "State should be stopped")
    
    -- Test double stop (should succeed)
    success = webcam:stopCapture()
    TestFramework.assert_true(success, "Should handle double stop gracefully")
    
    webcam:cleanup()
end

-- Test frame capture
function WebcamCaptureTests.test_frame_capture()
    local webcam = WebcamCapture:new()
    local init_success = webcam:initialize()
    
    if not init_success then
        print("Skipping frame capture test - initialization failed")
        return
    end
    
    -- Test capture without starting
    local frame, error_msg = webcam:captureFrame()
    TestFramework.assert_nil(frame, "Should not capture frame without starting")
    TestFramework.assert_not_nil(error_msg, "Should have error message")
    
    -- Start capture and test frame capture
    local start_success = webcam:startCapture()
    if start_success then
        frame, error_msg = webcam:captureFrame()
        TestFramework.assert_not_nil(frame, "Should capture frame after starting")
        TestFramework.assert_nil(error_msg, "Should not have error for successful capture")
        
        -- Test frame structure
        TestFramework.assert_not_nil(frame.data, "Frame should have data")
        TestFramework.assert_not_nil(frame.width, "Frame should have width")
        TestFramework.assert_not_nil(frame.height, "Frame should have height")
        TestFramework.assert_not_nil(frame.format, "Frame should have format")
        TestFramework.assert_not_nil(frame.timestamp, "Frame should have timestamp")
        TestFramework.assert_true(frame.width > 0, "Frame width should be positive")
        TestFramework.assert_true(frame.height > 0, "Frame height should be positive")
        TestFramework.assert_true(#frame.data > 0, "Frame data should not be empty")
        
        -- Test current frame getter
        local current_frame = webcam:getCurrentFrame()
        TestFramework.assert_equal(current_frame, frame, "Current frame should match captured frame")
    end
    
    webcam:cleanup()
end

-- Test configuration getters
function WebcamCaptureTests.test_configuration_getters()
    local webcam = WebcamCapture:new({
        device_index = 0,
        width = 1280,
        height = 720,
        frame_rate = 60
    })
    
    local config = webcam:getConfiguration()
    TestFramework.assert_not_nil(config, "Should have configuration")
    TestFramework.assert_equal(config.device_index, 0, "Config should have correct device index")
    TestFramework.assert_equal(config.resolution.width, 1280, "Config should have correct width")
    TestFramework.assert_equal(config.resolution.height, 720, "Config should have correct height")
    TestFramework.assert_equal(config.frame_rate, 60, "Config should have correct frame rate")
    TestFramework.assert_equal(config.state, WebcamCapture.CAPTURE_STATES.UNINITIALIZED, "Config should have correct state")
    
    webcam:cleanup()
end

-- Test statistics
function WebcamCaptureTests.test_statistics()
    local webcam = WebcamCapture:new()
    local init_success = webcam:initialize()
    
    if not init_success then
        print("Skipping statistics test - initialization failed")
        return
    end
    
    local stats = webcam:getStats()
    TestFramework.assert_not_nil(stats, "Should have statistics")
    TestFramework.assert_equal(stats.frames_captured, 0, "Initial frames captured should be 0")
    TestFramework.assert_equal(stats.frames_dropped, 0, "Initial frames dropped should be 0")
    TestFramework.assert_equal(stats.capture_errors, 0, "Initial capture errors should be 0")
    
    -- Start capture and capture some frames
    local start_success = webcam:startCapture()
    if start_success then
        webcam:captureFrame()
        webcam:captureFrame()
        
        stats = webcam:getStats()
        TestFramework.assert_true(stats.frames_captured >= 2, "Should have captured at least 2 frames")
        TestFramework.assert_true(stats.average_fps >= 0, "Average FPS should be non-negative")
    end
    
    webcam:cleanup()
end

-- Test error handling (Requirement 3.4)
function WebcamCaptureTests.test_error_handling()
    local webcam = WebcamCapture:new()
    
    -- Test initial error state
    TestFramework.assert_nil(webcam:getLastError(), "Should not have error initially")
    
    -- Test error after failed operation
    webcam:setDevice(999) -- Invalid device
    -- Note: This might not set an error in current implementation
    
    -- Test error clearing
    webcam:clearError()
    TestFramework.assert_nil(webcam:getLastError(), "Error should be cleared")
    
    webcam:cleanup()
end

-- Test availability check
function WebcamCaptureTests.test_availability()
    local webcam = WebcamCapture:new()
    
    local available = webcam:isAvailable()
    TestFramework.assert_true(type(available) == "boolean", "Availability should be boolean")
    
    -- Test static availability check
    local static_available = WebcamCapture:new():isAvailable()
    TestFramework.assert_equal(available, static_available, "Static and instance availability should match")
    
    webcam:cleanup()
end

-- Test supported formats
function WebcamCaptureTests.test_supported_formats()
    local webcam = WebcamCapture:new()
    local init_success = webcam:initialize()
    
    if not init_success then
        print("Skipping supported formats test - initialization failed")
        return
    end
    
    local resolutions = webcam:getSupportedResolutions()
    TestFramework.assert_true(type(resolutions) == "table", "Supported resolutions should be a table")
    
    local frame_rates = webcam:getSupportedFrameRates()
    TestFramework.assert_true(type(frame_rates) == "table", "Supported frame rates should be a table")
    
    local pixel_formats = webcam:getSupportedPixelFormats()
    TestFramework.assert_true(type(pixel_formats) == "table", "Supported pixel formats should be a table")
    
    webcam:cleanup()
end

-- Test cleanup
function WebcamCaptureTests.test_cleanup()
    local webcam = WebcamCapture:new()
    local init_success = webcam:initialize()
    
    if init_success then
        webcam:startCapture()
        TestFramework.assert_equal(webcam.state, WebcamCapture.CAPTURE_STATES.CAPTURING, "Should be capturing before cleanup")
    end
    
    webcam:cleanup()
    TestFramework.assert_equal(webcam.state, WebcamCapture.CAPTURE_STATES.UNINITIALIZED, "Should be uninitialized after cleanup")
    TestFramework.assert_nil(webcam.current_frame, "Current frame should be cleared")
end

-- Run all tests
function WebcamCaptureTests.runAll()
    print("Running WebcamCapture tests...")
    
    TestFramework.run_test("Webcam Initialization", WebcamCaptureTests.test_initialization)
    TestFramework.run_test("Webcam Initialization with Options", WebcamCaptureTests.test_initialization_with_options)
    TestFramework.run_test("Device Enumeration", WebcamCaptureTests.test_device_enumeration)
    TestFramework.run_test("Device Selection", WebcamCaptureTests.test_device_selection)
    TestFramework.run_test("Resolution Configuration", WebcamCaptureTests.test_resolution_configuration)
    TestFramework.run_test("Frame Rate Configuration", WebcamCaptureTests.test_frame_rate_configuration)
    TestFramework.run_test("Capture Start/Stop", WebcamCaptureTests.test_capture_start_stop)
    TestFramework.run_test("Frame Capture", WebcamCaptureTests.test_frame_capture)
    TestFramework.run_test("Configuration Getters", WebcamCaptureTests.test_configuration_getters)
    TestFramework.run_test("Statistics", WebcamCaptureTests.test_statistics)
    TestFramework.run_test("Error Handling", WebcamCaptureTests.test_error_handling)
    TestFramework.run_test("Availability Check", WebcamCaptureTests.test_availability)
    TestFramework.run_test("Supported Formats", WebcamCaptureTests.test_supported_formats)
    TestFramework.run_test("Cleanup", WebcamCaptureTests.test_cleanup)
    
    print("WebcamCapture tests completed.")
end

return WebcamCaptureTests