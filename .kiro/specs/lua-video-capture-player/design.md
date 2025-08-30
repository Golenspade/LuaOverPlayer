# Design Document

## Overview

The Lua Video Capture Player is a Windows-native application built using LuaJIT and LÖVE 2D framework. The system provides real-time video capture from multiple sources (desktop, windows, webcam) with immediate playback capabilities. The architecture leverages LuaJIT's FFI (Foreign Function Interface) to directly interface with Windows APIs for optimal performance, while using LÖVE 2D for graphics rendering and user interface.

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   LÖVE 2D UI    │◄──►│  Capture Engine  │◄──►│  Windows APIs   │
│   (Renderer)    │    │   (Core Logic)   │    │ (GDI32/User32)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Player Controls│    │  Frame Buffer    │    │ DirectShow/MF   │
│  (UI Elements)  │    │  (Memory Mgmt)   │    │  (Camera APIs)  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Core Components

1. **FFI Bindings Layer**: Direct interface to Windows APIs
2. **Capture Engine**: Handles different video sources
3. **Frame Buffer Manager**: Manages video frame data and memory
4. **Renderer**: LÖVE 2D-based display and UI system
5. **Control System**: User interface and interaction handling

## Components and Interfaces

### 1. FFI Bindings Module (`ffi_bindings.lua`)

```lua
-- Core Windows API bindings
local ffi = require("ffi")

ffi.cdef[[
    // User32.dll - Window management
    void* FindWindowA(const char* className, const char* windowName);
    void* GetDC(void* hwnd);
    int ReleaseDC(void* hwnd, void* hdc);
    int GetWindowRect(void* hwnd, void* rect);
    
    // GDI32.dll - Graphics operations
    void* CreateCompatibleDC(void* hdc);
    void* CreateCompatibleBitmap(void* hdc, int width, int height);
    void* SelectObject(void* hdc, void* obj);
    int BitBlt(void* hdcDest, int x, int y, int width, int height,
               void* hdcSrc, int x1, int y1, unsigned int rop);
    int DeleteDC(void* hdc);
    int DeleteObject(void* obj);
    
    // Structures
    typedef struct {
        long left, top, right, bottom;
    } RECT;
]]

local user32 = ffi.load("user32")
local gdi32 = ffi.load("gdi32")
```

**Interface:**
- `getWindowHandle(windowName)`: Find window by name
- `captureWindow(hwnd, rect)`: Capture window content
- `captureScreen(x, y, width, height)`: Capture screen region

### 2. Capture Engine (`capture_engine.lua`)

```lua
local CaptureEngine = {}
CaptureEngine.__index = CaptureEngine

function CaptureEngine:new()
    return setmetatable({
        current_source = nil,
        frame_rate = 30,
        is_capturing = false,
        frame_buffer = nil
    }, self)
end

-- Source types: 'screen', 'window', 'webcam'
function CaptureEngine:setSource(source_type, config)
function CaptureEngine:startCapture()
function CaptureEngine:stopCapture()
function CaptureEngine:getFrame()
```

**Interface:**
- `setSource(type, config)`: Configure capture source
- `startCapture()`: Begin capturing frames
- `stopCapture()`: End capture session
- `getFrame()`: Retrieve latest frame data
- `getStats()`: Return performance metrics

### 3. Frame Buffer Manager (`frame_buffer.lua`)

```lua
local FrameBuffer = {}

function FrameBuffer:new(max_frames)
    return setmetatable({
        frames = {},
        max_frames = max_frames or 3,
        current_index = 1,
        frame_count = 0
    }, self)
end

function FrameBuffer:addFrame(frame_data, width, height)
function FrameBuffer:getLatestFrame()
function FrameBuffer:clear()
```

**Interface:**
- `addFrame(data, width, height)`: Store new frame
- `getLatestFrame()`: Get most recent frame
- `clear()`: Release all frame memory
- `getMemoryUsage()`: Return current memory usage

### 4. Video Renderer (`video_renderer.lua`)

```lua
local VideoRenderer = {}

function VideoRenderer:new()
    return setmetatable({
        current_texture = nil,
        display_mode = 'fit', -- 'fit', 'fill', 'stretch'
        overlay_mode = false,
        transparency = 1.0
    }, self)
end

function VideoRenderer:updateFrame(frame_data, width, height)
function VideoRenderer:render(x, y, scale)
function VideoRenderer:setDisplayMode(mode)
```

**Interface:**
- `updateFrame(data, width, height)`: Update display texture
- `render(x, y, scale)`: Draw frame to screen
- `setDisplayMode(mode)`: Configure scaling behavior
- `setOverlayMode(enabled)`: Toggle overlay display

### 5. UI Controller (`ui_controller.lua`)

```lua
local UIController = {}

function UIController:new(capture_engine, renderer)
    return setmetatable({
        capture_engine = capture_engine,
        renderer = renderer,
        ui_elements = {},
        current_screen = 'main'
    }, self)
end

function UIController:handleInput(key, action)
function UIController:update(dt)
function UIController:draw()
```

**Interface:**
- `handleInput(key, action)`: Process user input
- `update(dt)`: Update UI state
- `draw()`: Render UI elements
- `showSourceSelection()`: Display source picker

## Data Models

### Frame Data Structure

```lua
Frame = {
    data = nil,          -- Raw pixel data (ImageData or string)
    width = 0,           -- Frame width in pixels
    height = 0,          -- Frame height in pixels
    format = 'RGBA',     -- Pixel format
    timestamp = 0,       -- Capture timestamp
    source_info = {}     -- Source-specific metadata
}
```

### Capture Configuration

```lua
CaptureConfig = {
    source_type = 'screen',  -- 'screen', 'window', 'webcam'
    
    -- Screen capture config
    screen = {
        x = 0, y = 0,
        width = 1920, height = 1080,
        monitor_index = 1
    },
    
    -- Window capture config
    window = {
        window_name = "",
        follow_window = true,
        include_borders = false
    },
    
    -- Webcam config
    webcam = {
        device_index = 0,
        resolution = {width = 640, height = 480},
        fps = 30
    },
    
    -- General settings
    frame_rate = 30,
    quality = 'high'
}
```

### Application State

```lua
AppState = {
    is_capturing = false,
    current_source = nil,
    display_settings = {
        window_mode = 'windowed', -- 'windowed', 'overlay'
        always_on_top = false,
        transparency = 1.0,
        position = {x = 100, y = 100},
        size = {width = 800, height = 600}
    },
    performance = {
        fps = 0,
        frame_drops = 0,
        memory_usage = 0
    }
}
```

## Error Handling

### Error Categories

1. **API Errors**: Windows API call failures
2. **Resource Errors**: Memory allocation, device access
3. **Performance Errors**: Frame drops, timeout issues
4. **Configuration Errors**: Invalid settings, missing devices

### Error Handling Strategy

```lua
local ErrorHandler = {}

function ErrorHandler:handleAPIError(api_name, error_code)
    -- Log error with context
    -- Attempt recovery based on error type
    -- Notify user if recovery fails
end

function ErrorHandler:handleResourceError(resource_type, details)
    -- Free unused resources
    -- Reduce quality settings if needed
    -- Provide user feedback
end

function ErrorHandler:handlePerformanceError(metric, threshold)
    -- Adjust frame rate or quality
    -- Enable frame dropping
    -- Update performance display
end
```

### Recovery Mechanisms

- **Automatic Retry**: For transient API failures
- **Graceful Degradation**: Reduce quality when resources are limited
- **Source Switching**: Fall back to alternative capture methods
- **State Persistence**: Save configuration before crashes

## Testing Strategy

### Unit Testing

```lua
-- Test individual components in isolation
local test_capture = require("tests.test_capture_engine")
local test_buffer = require("tests.test_frame_buffer")
local test_renderer = require("tests.test_video_renderer")

-- Mock Windows APIs for testing
local mock_ffi = require("tests.mocks.mock_ffi")
```

### Integration Testing

```lua
-- Test component interactions
local integration_tests = {
    "capture_to_display_pipeline",
    "source_switching_workflow", 
    "error_recovery_scenarios",
    "performance_under_load"
}
```

### Performance Testing

- **Frame Rate Consistency**: Measure actual vs target FPS
- **Memory Usage**: Monitor for leaks during extended capture
- **CPU Usage**: Ensure efficient API usage
- **Latency Testing**: Measure capture-to-display delay

### Manual Testing Scenarios

1. **Multi-Monitor Setup**: Test screen capture across different monitors
2. **Window Tracking**: Verify window capture follows moved/resized windows
3. **Device Switching**: Test webcam enumeration and switching
4. **Overlay Mode**: Verify transparency and always-on-top behavior
5. **Error Conditions**: Test behavior with disconnected devices, low memory

### Test Data and Mocks

```lua
-- Mock frame data for testing
local MockFrameData = {
    createTestFrame = function(width, height, pattern)
        -- Generate test pattern (solid color, gradient, checkerboard)
    end,
    
    createNoiseFrame = function(width, height)
        -- Generate random noise for performance testing
    end
}

-- Mock Windows API responses
local MockWindowsAPI = {
    windows = {
        {name = "Test Window 1", handle = 0x1001},
        {name = "Test Window 2", handle = 0x1002}
    },
    
    simulateError = function(api_name, error_code)
        -- Simulate specific API failures
    end
}
```

This design provides a robust foundation for the Lua video capture player, with clear separation of concerns, comprehensive error handling, and thorough testing strategies. The modular architecture allows for easy extension and maintenance while leveraging the performance benefits of direct Windows API access through LuaJIT's FFI.