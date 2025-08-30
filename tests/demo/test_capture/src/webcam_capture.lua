-- Webcam Capture Module
-- Provides webcam video capture using Windows Media Foundation APIs

local FFIBindings = require("src.ffi_bindings")
local ffi = require("ffi")

local WebcamCapture = {}
WebcamCapture.__index = WebcamCapture

-- Webcam capture states
local CAPTURE_STATES = {
    UNINITIALIZED = "uninitialized",
    INITIALIZED = "initialized", 
    CAPTURING = "capturing",
    STOPPED = "stopped",
    ERROR = "error"
}

function WebcamCapture:new(options)
    options = options or {}
    
    return setmetatable({
        -- Core state
        state = CAPTURE_STATES.UNINITIALIZED,
        last_error = nil,
        
        -- Device information
        available_devices = {},
        current_device = nil,
        device_index = options.device_index or 0,
        
        -- Capture configuration
        resolution = {
            width = options.width or 640,
            height = options.height or 480
        },
        frame_rate = options.frame_rate or 30,
        pixel_format = options.pixel_format or "RGB24",
        
        -- Media Foundation objects (will be initialized later)
        mf_initialized = false,
        source_reader = nil,
        media_source = nil,
        
        -- Frame data
        current_frame = nil,
        frame_timestamp = 0,
        
        -- Statistics
        stats = {
            frames_captured = 0,
            frames_dropped = 0,
            capture_errors = 0,
            last_capture_time = 0,
            average_fps = 0
        }
    }, self)
end

-- Initialize webcam capture system
function WebcamCapture:initialize()
    if self.state ~= CAPTURE_STATES.UNINITIALIZED then
        return true -- Already initialized
    end
    
    -- Check if Media Foundation is available
    if not FFIBindings.isMediaFoundationAvailable() then
        self.last_error = "Media Foundation not available: " .. (FFIBindings.getMediaFoundationError() or "Unknown error")
        self.state = CAPTURE_STATES.ERROR
        return false, self.last_error
    end
    
    -- Initialize Media Foundation
    local success, error_msg = FFIBindings.initializeMediaFoundation()
    if not success then
        self.last_error = "Failed to initialize Media Foundation: " .. error_msg
        self.state = CAPTURE_STATES.ERROR
        return false, self.last_error
    end
    
    self.mf_initialized = true
    
    -- Enumerate available devices (Requirement 3.1)
    local devices, enum_error = self:enumerateDevices()
    if not devices then
        self.last_error = "Failed to enumerate video devices: " .. (enum_error or "Unknown error")
        self.state = CAPTURE_STATES.ERROR
        return false, self.last_error
    end
    
    self.available_devices = devices
    
    -- Set default device if available
    if #devices > 0 then
        local device_to_use = devices[self.device_index + 1] or devices[1]
        self.current_device = device_to_use
    else
        self.last_error = "No video capture devices found"
        self.state = CAPTURE_STATES.ERROR
        return false, self.last_error
    end
    
    self.state = CAPTURE_STATES.INITIALIZED
    return true
end

-- Enumerate available video capture devices (Requirement 3.1)
function WebcamCapture:enumerateDevices()
    if not self.mf_initialized then
        return nil, "Media Foundation not initialized"
    end
    
    -- Use FFI bindings to enumerate devices
    local devices, error_msg = FFIBindings.enumerateVideoDevices()
    if not devices then
        return nil, error_msg
    end
    
    -- For now, we'll return a mock device list since full Media Foundation
    -- implementation would require extensive COM interface handling
    local mock_devices = {
        {
            name = "Default Camera",
            index = 0,
            available = true,
            supported_resolutions = {
                {width = 640, height = 480},
                {width = 1280, height = 720},
                {width = 1920, height = 1080}
            },
            supported_frame_rates = {15, 30, 60},
            pixel_formats = {"RGB24", "YUY2", "NV12"}
        }
    }
    
    -- In a real implementation, we would:
    -- 1. Call MFEnumDeviceSources with video capture attributes
    -- 2. Iterate through returned IMFActivate objects
    -- 3. Extract device names and capabilities
    -- 4. Store device handles for later use
    
    return mock_devices
end

-- Set target device by index (Requirement 3.2)
function WebcamCapture:setDevice(device_index)
    if self.state == CAPTURE_STATES.CAPTURING then
        return false, "Cannot change device while capturing"
    end
    
    if device_index < 0 or device_index >= #self.available_devices then
        return false, "Invalid device index: " .. device_index
    end
    
    self.device_index = device_index
    self.current_device = self.available_devices[device_index + 1]
    
    return true
end

-- Set capture resolution (Requirement 3.3)
function WebcamCapture:setResolution(width, height)
    if self.state == CAPTURE_STATES.CAPTURING then
        return false, "Cannot change resolution while capturing"
    end
    
    if width <= 0 or height <= 0 then
        return false, "Invalid resolution: " .. width .. "x" .. height
    end
    
    -- Check if resolution is supported by current device
    if self.current_device and self.current_device.supported_resolutions then
        local supported = false
        for _, res in ipairs(self.current_device.supported_resolutions) do
            if res.width == width and res.height == height then
                supported = true
                break
            end
        end
        
        if not supported then
            return false, "Resolution " .. width .. "x" .. height .. " not supported by current device"
        end
    end
    
    self.resolution.width = width
    self.resolution.height = height
    
    return true
end

-- Set capture frame rate (Requirement 3.3)
function WebcamCapture:setFrameRate(fps)
    if self.state == CAPTURE_STATES.CAPTURING then
        return false, "Cannot change frame rate while capturing"
    end
    
    if fps <= 0 or fps > 120 then
        return false, "Invalid frame rate: " .. fps
    end
    
    -- Check if frame rate is supported by current device
    if self.current_device and self.current_device.supported_frame_rates then
        local supported = false
        for _, rate in ipairs(self.current_device.supported_frame_rates) do
            if rate == fps then
                supported = true
                break
            end
        end
        
        if not supported then
            return false, "Frame rate " .. fps .. " FPS not supported by current device"
        end
    end
    
    self.frame_rate = fps
    
    return true
end

-- Start capturing frames (Requirement 3.2)
function WebcamCapture:startCapture()
    if self.state == CAPTURE_STATES.CAPTURING then
        return true -- Already capturing
    end
    
    if self.state ~= CAPTURE_STATES.INITIALIZED and self.state ~= CAPTURE_STATES.STOPPED then
        return false, "Webcam not properly initialized"
    end
    
    if not self.current_device then
        return false, "No device selected"
    end
    
    -- In a real implementation, we would:
    -- 1. Create IMFMediaSource from the selected device
    -- 2. Create IMFSourceReader from the media source
    -- 3. Configure media types (resolution, frame rate, pixel format)
    -- 4. Start the capture session
    
    -- For now, simulate successful capture start
    self.state = CAPTURE_STATES.CAPTURING
    self.stats.frames_captured = 0
    self.stats.frames_dropped = 0
    self.stats.capture_errors = 0
    self.stats.last_capture_time = love and love.timer.getTime() or os.clock()
    
    return true
end

-- Stop capturing frames
function WebcamCapture:stopCapture()
    if self.state ~= CAPTURE_STATES.CAPTURING then
        return true -- Already stopped
    end
    
    -- In a real implementation, we would:
    -- 1. Stop the source reader
    -- 2. Release Media Foundation objects
    -- 3. Clean up resources
    
    self.state = CAPTURE_STATES.STOPPED
    self.current_frame = nil
    
    return true
end

-- Capture a single frame
function WebcamCapture:captureFrame()
    if self.state ~= CAPTURE_STATES.CAPTURING then
        return nil, "Not currently capturing"
    end
    
    -- In a real implementation, we would:
    -- 1. Call IMFSourceReader_ReadSample to get the next frame
    -- 2. Extract pixel data from the IMFSample
    -- 3. Convert to the desired pixel format
    -- 4. Return the frame data
    
    -- For now, generate mock frame data
    local width = self.resolution.width
    local height = self.resolution.height
    local pixel_size = 3 -- RGB24 = 3 bytes per pixel
    local frame_size = width * height * pixel_size
    
    -- Create mock frame data (simple gradient pattern)
    local frame_data = {}
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local r = math.floor((x / width) * 255)
            local g = math.floor((y / height) * 255)
            local b = math.floor(((x + y) / (width + height)) * 255)
            
            table.insert(frame_data, string.char(r, g, b))
        end
    end
    
    local frame_string = table.concat(frame_data)
    
    -- Update statistics
    self.stats.frames_captured = self.stats.frames_captured + 1
    self.frame_timestamp = love and love.timer.getTime() or os.clock()
    
    -- Calculate FPS
    local current_time = self.frame_timestamp
    if self.stats.last_capture_time > 0 then
        local time_diff = current_time - self.stats.last_capture_time
        if time_diff > 0 then
            self.stats.average_fps = 1.0 / time_diff
        end
    end
    self.stats.last_capture_time = current_time
    
    self.current_frame = {
        data = frame_string,
        width = width,
        height = height,
        format = self.pixel_format,
        timestamp = self.frame_timestamp,
        size = frame_size
    }
    
    return self.current_frame
end

-- Get current frame data
function WebcamCapture:getCurrentFrame()
    return self.current_frame
end

-- Get available devices
function WebcamCapture:getAvailableDevices()
    return self.available_devices
end

-- Get current device information
function WebcamCapture:getCurrentDevice()
    return self.current_device
end

-- Get current configuration
function WebcamCapture:getConfiguration()
    return {
        device_index = self.device_index,
        resolution = {
            width = self.resolution.width,
            height = self.resolution.height
        },
        frame_rate = self.frame_rate,
        pixel_format = self.pixel_format,
        state = self.state
    }
end

-- Get capture statistics
function WebcamCapture:getStats()
    return {
        frames_captured = self.stats.frames_captured,
        frames_dropped = self.stats.frames_dropped,
        capture_errors = self.stats.capture_errors,
        average_fps = self.stats.average_fps,
        last_capture_time = self.stats.last_capture_time,
        current_device = self.current_device and self.current_device.name or "None",
        resolution = self.resolution.width .. "x" .. self.resolution.height,
        frame_rate = self.frame_rate,
        state = self.state
    }
end

-- Get supported resolutions for current device
function WebcamCapture:getSupportedResolutions()
    if not self.current_device then
        return {}
    end
    
    return self.current_device.supported_resolutions or {}
end

-- Get supported frame rates for current device
function WebcamCapture:getSupportedFrameRates()
    if not self.current_device then
        return {}
    end
    
    return self.current_device.supported_frame_rates or {}
end

-- Get supported pixel formats for current device
function WebcamCapture:getSupportedPixelFormats()
    if not self.current_device then
        return {}
    end
    
    return self.current_device.pixel_formats or {}
end

-- Check if webcam capture is available
function WebcamCapture:isAvailable()
    return FFIBindings.isMediaFoundationAvailable()
end

-- Get last error message (Requirement 3.4)
function WebcamCapture:getLastError()
    return self.last_error
end

-- Clear error state
function WebcamCapture:clearError()
    self.last_error = nil
    if self.state == CAPTURE_STATES.ERROR then
        self.state = CAPTURE_STATES.UNINITIALIZED
    end
end

-- Cleanup and shutdown
function WebcamCapture:cleanup()
    if self.state == CAPTURE_STATES.CAPTURING then
        self:stopCapture()
    end
    
    -- Release Media Foundation resources
    if self.source_reader then
        -- In real implementation: IUnknown_Release(self.source_reader)
        self.source_reader = nil
    end
    
    if self.media_source then
        -- In real implementation: IUnknown_Release(self.media_source)
        self.media_source = nil
    end
    
    if self.mf_initialized then
        FFIBindings.shutdownMediaFoundation()
        self.mf_initialized = false
    end
    
    self.state = CAPTURE_STATES.UNINITIALIZED
end

-- Export capture states for external use
WebcamCapture.CAPTURE_STATES = CAPTURE_STATES

return WebcamCapture