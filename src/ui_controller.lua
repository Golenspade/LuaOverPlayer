-- UIController: Handles user interface and interaction for video capture
-- Provides source selection, capture controls, and visual feedback

local OverlayManager = require("src.overlay_manager")

local UIController = {}
UIController.__index = UIController

-- UI States
local UI_STATES = {
    MAIN = "main",
    SOURCE_SELECTION = "source_selection",
    CAPTURE_ACTIVE = "capture_active",
    SETTINGS = "settings",
    OVERLAY_SETTINGS = "overlay_settings"
}

-- Button states
local BUTTON_STATES = {
    NORMAL = "normal",
    HOVER = "hover", 
    PRESSED = "pressed",
    DISABLED = "disabled"
}

-- Create new UIController instance
function UIController:new(capture_engine, renderer, options)
    if not capture_engine then
        error("UIController requires a capture engine")
    end
    
    if not renderer then
        error("UIController requires a video renderer")
    end
    
    options = options or {}
    
    return setmetatable({
        -- Core components
        capture_engine = capture_engine,
        renderer = renderer,
        overlay_manager = OverlayManager:new(),
        
        -- Optional components from options
        config_manager = options.config_manager,
        performance_monitor = options.performance_monitor,
        error_handler = options.error_handler,
        
        -- UI state management
        current_screen = UI_STATES.MAIN,
        previous_screen = nil,
        
        -- UI elements and layout
        ui_elements = {},
        buttons = {},
        layout = {
            margin = 20,
            button_height = 40,
            button_width = 120,
            spacing = 10,
            font_size = 14
        },
        
        -- Input handling
        mouse = {
            x = 0,
            y = 0,
            pressed = false,
            last_pressed = false
        },
        
        -- Visual feedback and status
        status_message = "",
        status_timeout = 0,
        capture_status = {
            is_capturing = false,
            is_paused = false,
            source_type = nil,
            fps = 0,
            frames_captured = 0,
            elapsed_time = 0
        },
        
        -- Source selection data
        available_sources = {},
        selected_source = nil,
        source_configs = {},
        
        -- Colors and styling
        colors = {
            background = {0.1, 0.1, 0.1, 1.0},
            text = {1.0, 1.0, 1.0, 1.0},
            button_normal = {0.3, 0.3, 0.3, 1.0},
            button_hover = {0.4, 0.4, 0.4, 1.0},
            button_pressed = {0.2, 0.2, 0.2, 1.0},
            button_disabled = {0.15, 0.15, 0.15, 1.0},
            button_active = {0.2, 0.6, 0.2, 1.0},
            button_danger = {0.6, 0.2, 0.2, 1.0},
            accent = {0.3, 0.6, 0.9, 1.0},
            success = {0.2, 0.8, 0.2, 1.0},
            warning = {0.9, 0.6, 0.2, 1.0},
            error = {0.8, 0.2, 0.2, 1.0}
        },
        
        -- Fonts
        fonts = {},
        
        -- Performance tracking
        update_stats = {
            last_update_time = 0,
            update_count = 0
        },
        
        -- Performance display settings
        performance_display = {
            enabled = options.show_performance ~= false,
            position = {x = 10, y = 10},
            background_alpha = 0.7,
            update_interval = 0.5  -- Update display every 0.5 seconds
        },
        
        -- Performance data cache
        performance_cache = {
            last_update = 0,
            metrics = {},
            summary = {}
        }
    }, self)
end

-- Initialize UI controller with fonts and initial state
function UIController:initialize()
    -- Initialize fonts
    self.fonts.normal = love.graphics.newFont(self.layout.font_size)
    self.fonts.large = love.graphics.newFont(self.layout.font_size + 4)
    self.fonts.small = love.graphics.newFont(self.layout.font_size - 2)
    
    -- Set default font
    love.graphics.setFont(self.fonts.normal)
    
    -- Initialize overlay manager
    local success = self.overlay_manager:initialize()
    if not success then
        print("Warning: Failed to initialize overlay manager")
    end
    
    -- Initialize available sources
    self:_refreshAvailableSources()
    
    -- Create initial UI elements
    self:_createMainScreenElements()
    
    return true
end

-- Refresh available capture sources from engine
function UIController:_refreshAvailableSources()
    self.available_sources = self.capture_engine:getAvailableSources()
    
    -- Update source configurations
    for source_type, source_info in pairs(self.available_sources) do
        if source_info.available then
            self.source_configs[source_type] = self.capture_engine:getSourceConfigurationOptions(source_type)
        end
    end
end

-- Create UI elements for main screen (Requirement 5.1)
function UIController:_createMainScreenElements()
    self.buttons = {}
    
    local window_width = love.graphics.getWidth()
    local window_height = love.graphics.getHeight()
    local center_x = window_width / 2
    local start_y = window_height / 2 - 100
    
    -- Source selection button
    self.buttons.select_source = {
        x = center_x - self.layout.button_width / 2,
        y = start_y,
        width = self.layout.button_width,
        height = self.layout.button_height,
        text = "Select Source",
        state = BUTTON_STATES.NORMAL,
        enabled = true,
        action = function() self:_showSourceSelection() end
    }
    
    -- Start capture button
    self.buttons.start_capture = {
        x = center_x - self.layout.button_width / 2,
        y = start_y + self.layout.button_height + self.layout.spacing,
        width = self.layout.button_width,
        height = self.layout.button_height,
        text = "Start Capture",
        state = BUTTON_STATES.NORMAL,
        enabled = false, -- Disabled until source is selected
        action = function() self:_startCapture() end
    }
    
    -- Stop capture button
    self.buttons.stop_capture = {
        x = center_x - self.layout.button_width / 2,
        y = start_y + (self.layout.button_height + self.layout.spacing) * 2,
        width = self.layout.button_width,
        height = self.layout.button_height,
        text = "Stop Capture",
        state = BUTTON_STATES.NORMAL,
        enabled = false, -- Disabled until capture is active
        action = function() self:_stopCapture() end
    }
    
    -- Pause/Resume capture button
    self.buttons.pause_capture = {
        x = center_x - self.layout.button_width / 2,
        y = start_y + (self.layout.button_height + self.layout.spacing) * 3,
        width = self.layout.button_width,
        height = self.layout.button_height,
        text = "Pause",
        state = BUTTON_STATES.NORMAL,
        enabled = false, -- Disabled until capture is active
        action = function() self:_togglePause() end
    }
    
    -- Overlay settings button
    self.buttons.overlay_settings = {
        x = center_x - self.layout.button_width / 2,
        y = start_y + (self.layout.button_height + self.layout.spacing) * 4,
        width = self.layout.button_width,
        height = self.layout.button_height,
        text = "Overlay Settings",
        state = BUTTON_STATES.NORMAL,
        enabled = true,
        action = function() self:_showOverlaySettings() end
    }
end

-- Show source selection interface (Requirement 5.1, 5.2)
function UIController:_showSourceSelection()
    self.previous_screen = self.current_screen
    self.current_screen = UI_STATES.SOURCE_SELECTION
    
    -- Create source selection buttons
    self.buttons = {}
    
    local window_width = love.graphics.getWidth()
    local start_y = 100
    local button_y = start_y
    
    -- Back button
    self.buttons.back = {
        x = self.layout.margin,
        y = self.layout.margin,
        width = 80,
        height = 30,
        text = "Back",
        state = BUTTON_STATES.NORMAL,
        enabled = true,
        action = function() self:_showMainScreen() end
    }
    
    -- Create buttons for each available source
    for source_type, source_info in pairs(self.available_sources) do
        if source_info.available then
            local button_id = "source_" .. source_type
            
            self.buttons[button_id] = {
                x = window_width / 2 - self.layout.button_width / 2,
                y = button_y,
                width = self.layout.button_width,
                height = self.layout.button_height,
                text = self:_getSourceDisplayName(source_type),
                state = BUTTON_STATES.NORMAL,
                enabled = true,
                source_type = source_type,
                action = function() self:_selectSource(source_type) end
            }
            
            button_y = button_y + self.layout.button_height + self.layout.spacing
        end
    end
end

-- Show overlay settings interface (Requirement 7.1, 7.2, 7.3)
function UIController:_showOverlaySettings()
    self.previous_screen = self.current_screen
    self.current_screen = UI_STATES.OVERLAY_SETTINGS
    
    -- Create overlay settings buttons
    self.buttons = {}
    
    local window_width = love.graphics.getWidth()
    local start_y = 100
    local button_y = start_y
    local button_width = 180
    
    -- Back button
    self.buttons.back = {
        x = self.layout.margin,
        y = self.layout.margin,
        width = 80,
        height = 30,
        text = "Back",
        state = BUTTON_STATES.NORMAL,
        enabled = true,
        action = function() self:_showMainScreen() end
    }
    
    -- Get current overlay configuration
    local config = self.overlay_manager:getConfiguration()
    
    -- Overlay mode buttons
    local modes = {
        {mode = OverlayManager.MODES.NORMAL, text = "Normal Window"},
        {mode = OverlayManager.MODES.OVERLAY, text = "Overlay Mode"},
        {mode = OverlayManager.MODES.TRANSPARENT_OVERLAY, text = "Transparent Overlay"},
        {mode = OverlayManager.MODES.CLICK_THROUGH, text = "Click-Through"}
    }
    
    for i, mode_info in ipairs(modes) do
        local button_id = "mode_" .. mode_info.mode
        local is_active = (config.mode == mode_info.mode)
        
        self.buttons[button_id] = {
            x = window_width / 2 - button_width / 2,
            y = button_y,
            width = button_width,
            height = self.layout.button_height,
            text = mode_info.text .. (is_active and " ✓" or ""),
            state = BUTTON_STATES.NORMAL,
            enabled = true,
            mode = mode_info.mode,
            action = function() self:_setOverlayMode(mode_info.mode) end
        }
        
        button_y = button_y + self.layout.button_height + self.layout.spacing
    end
    
    button_y = button_y + self.layout.spacing
    
    -- Transparency controls
    self.buttons.transparency_decrease = {
        x = window_width / 2 - button_width / 2 - 60,
        y = button_y,
        width = 50,
        height = self.layout.button_height,
        text = "- α",
        state = BUTTON_STATES.NORMAL,
        enabled = true,
        action = function() self:_adjustTransparency(-0.1) end
    }
    
    self.buttons.transparency_increase = {
        x = window_width / 2 + button_width / 2 + 10,
        y = button_y,
        width = 50,
        height = self.layout.button_height,
        text = "+ α",
        state = BUTTON_STATES.NORMAL,
        enabled = true,
        action = function() self:_adjustTransparency(0.1) end
    }
    
    button_y = button_y + self.layout.button_height + self.layout.spacing * 2
    
    -- Toggle buttons for overlay features
    local toggles = {
        {key = "always_on_top", text = "Always On Top", action = function() self:_toggleAlwaysOnTop() end},
        {key = "borderless", text = "Borderless", action = function() self:_toggleBorderless() end},
        {key = "click_through", text = "Click Through", action = function() self:_toggleClickThrough() end},
        {key = "hide_from_taskbar", text = "Hide From Taskbar", action = function() self:_toggleTaskbarVisible() end}
    }
    
    for i, toggle in ipairs(toggles) do
        local button_id = "toggle_" .. toggle.key
        local is_enabled = config[toggle.key]
        
        self.buttons[button_id] = {
            x = window_width / 2 - button_width / 2,
            y = button_y,
            width = button_width,
            height = self.layout.button_height,
            text = toggle.text .. (is_enabled and " ✓" or ""),
            state = BUTTON_STATES.NORMAL,
            enabled = true,
            action = toggle.action
        }
        
        button_y = button_y + self.layout.button_height + self.layout.spacing
    end
end

-- Get display name for source type
function UIController:_getSourceDisplayName(source_type)
    local display_names = {
        screen = "Screen Capture",
        window = "Window Capture", 
        webcam = "Webcam Capture"
    }
    
    return display_names[source_type] or source_type
end

-- Select a capture source (Requirement 5.2)
function UIController:_selectSource(source_type)
    self.selected_source = source_type
    
    -- Configure source with default settings
    local default_config = self:_getDefaultSourceConfig(source_type)
    local success, error_msg = self.capture_engine:setSource(source_type, default_config)
    
    if success then
        self:_setStatusMessage("Selected " .. self:_getSourceDisplayName(source_type), "success")
        self:_showMainScreen()
        
        -- Enable capture controls
        self.buttons.start_capture.enabled = true
    else
        self:_setStatusMessage("Failed to select source: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Get default configuration for source type
function UIController:_getDefaultSourceConfig(source_type)
    if source_type == "screen" then
        return {
            mode = "FULL_SCREEN",
            monitor_index = 1
        }
    elseif source_type == "window" then
        -- Get first available window
        local windows = self.available_sources.window.windows
        if windows and #windows > 0 then
            return {
                window = windows[1].title,
                tracking = true,
                dpi_aware = true
            }
        end
        return {}
    elseif source_type == "webcam" then
        return {
            device_index = 0,
            resolution = {width = 640, height = 480},
            frame_rate = 30
        }
    end
    
    return {}
end

-- Show main screen
function UIController:_showMainScreen()
    self.current_screen = UI_STATES.MAIN
    self:_createMainScreenElements()
    
    -- Update button states based on current status
    self:_updateButtonStates()
end

-- Set overlay mode (Requirement 7.1)
function UIController:_setOverlayMode(mode)
    local success, error_msg = self.overlay_manager:setOverlayMode(mode)
    
    if success then
        self:_setStatusMessage("Overlay mode: " .. mode, "success")
        -- Refresh the overlay settings screen to update checkmarks
        if self.current_screen == UI_STATES.OVERLAY_SETTINGS then
            self:_showOverlaySettings()
        end
    else
        self:_setStatusMessage("Failed to set overlay mode: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Adjust transparency (Requirement 7.2)
function UIController:_adjustTransparency(delta)
    local config = self.overlay_manager:getConfiguration()
    local new_transparency = math.max(0.0, math.min(1.0, config.transparency + delta))
    
    local success, error_msg = self.overlay_manager:setTransparency(new_transparency)
    
    if success then
        self:_setStatusMessage(string.format("Transparency: %.1f", new_transparency), "success")
    else
        self:_setStatusMessage("Failed to set transparency: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Toggle always on top
function UIController:_toggleAlwaysOnTop()
    local config = self.overlay_manager:getConfiguration()
    local new_state = not config.always_on_top
    
    local success, error_msg = self.overlay_manager:setAlwaysOnTop(new_state)
    
    if success then
        self:_setStatusMessage("Always on top: " .. (new_state and "ON" or "OFF"), "success")
        -- Refresh the overlay settings screen to update checkmarks
        if self.current_screen == UI_STATES.OVERLAY_SETTINGS then
            self:_showOverlaySettings()
        end
    else
        self:_setStatusMessage("Failed to toggle always on top: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Toggle borderless mode
function UIController:_toggleBorderless()
    local config = self.overlay_manager:getConfiguration()
    local new_state = not config.borderless
    
    local success, error_msg = self.overlay_manager:setBorderless(new_state)
    
    if success then
        self:_setStatusMessage("Borderless: " .. (new_state and "ON" or "OFF"), "success")
        -- Refresh the overlay settings screen to update checkmarks
        if self.current_screen == UI_STATES.OVERLAY_SETTINGS then
            self:_showOverlaySettings()
        end
    else
        self:_setStatusMessage("Failed to toggle borderless: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Toggle click through mode
function UIController:_toggleClickThrough()
    local config = self.overlay_manager:getConfiguration()
    local new_state = not config.click_through
    
    local success, error_msg = self.overlay_manager:setClickThrough(new_state)
    
    if success then
        self:_setStatusMessage("Click through: " .. (new_state and "ON" or "OFF"), "success")
        -- Refresh the overlay settings screen to update checkmarks
        if self.current_screen == UI_STATES.OVERLAY_SETTINGS then
            self:_showOverlaySettings()
        end
    else
        self:_setStatusMessage("Failed to toggle click through: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Toggle taskbar visibility
function UIController:_toggleTaskbarVisible()
    local config = self.overlay_manager:getConfiguration()
    local new_state = not config.hide_from_taskbar
    
    local success, error_msg = self.overlay_manager:setTaskbarVisible(new_state)
    
    if success then
        self:_setStatusMessage("Hide from taskbar: " .. (not new_state and "ON" or "OFF"), "success")
        -- Refresh the overlay settings screen to update checkmarks
        if self.current_screen == UI_STATES.OVERLAY_SETTINGS then
            self:_showOverlaySettings()
        end
    else
        self:_setStatusMessage("Failed to toggle taskbar visibility: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Advanced Features Implementation (Requirements 1.1, 2.2, 5.4)

-- Toggle cursor capture
function UIController:_toggleCursorCapture()
    if not self.selected_source then
        self:_setStatusMessage("No source selected", "error")
        return
    end
    
    local source = self:_getCurrentCaptureSource()
    if not source then
        self:_setStatusMessage("Cannot access capture source", "error")
        return
    end
    
    -- Get current cursor capture state
    local config = source:getAdvancedConfiguration()
    local new_state = not config.cursor_capture.enabled
    
    local success, error_msg = source:setCursorCapture(new_state)
    
    if success then
        self:_setStatusMessage("Cursor capture: " .. (new_state and "ON" or "OFF"), "success")
    else
        self:_setStatusMessage("Failed to toggle cursor capture: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Start area selection mode
function UIController:_startAreaSelection()
    if self.selected_source ~= "screen" then
        self:_setStatusMessage("Area selection only available for screen capture", "warning")
        return
    end
    
    local source = self:_getCurrentCaptureSource()
    if not source then
        self:_setStatusMessage("Cannot access screen capture source", "error")
        return
    end
    
    local success, error_msg = source:startAreaSelection()
    
    if success then
        self:_setStatusMessage("Click and drag to select capture area", "success")
        -- Switch to a special area selection state
        self.area_selection_active = true
    else
        self:_setStatusMessage("Failed to start area selection: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Check if area selection is active
function UIController:_isAreaSelectionActive()
    return self.area_selection_active or false
end

-- Handle input during area selection
function UIController:_handleAreaSelectionInput(key, action)
    if action == "pressed" then
        if key == "escape" then
            -- Cancel area selection
            self:_cancelAreaSelection()
            return true
        elseif key == "return" or key == "enter" then
            -- Confirm area selection
            self:_confirmAreaSelection()
            return true
        end
    end
    
    return false
end

-- Cancel area selection
function UIController:_cancelAreaSelection()
    local source = self:_getCurrentCaptureSource()
    if source and source.cancelAreaSelection then
        source:cancelAreaSelection()
    end
    
    self.area_selection_active = false
    self:_setStatusMessage("Area selection cancelled", "warning")
end

-- Confirm area selection
function UIController:_confirmAreaSelection()
    local source = self:_getCurrentCaptureSource()
    if not source then
        self:_cancelAreaSelection()
        return
    end
    
    local area = source:getSelectedArea()
    if area then
        self.area_selection_active = false
        self:_setStatusMessage(string.format("Area selected: %dx%d at (%d,%d)", 
                                           area.width, area.height, area.x, area.y), "success")
    else
        self:_setStatusMessage("No area selected", "warning")
    end
end

-- Handle hotkey actions
function UIController:_handleHotkey(action)
    if action == "toggle_capture" then
        if self.capture_status.is_capturing then
            if self.capture_status.is_paused then
                self:_togglePause()
            else
                self:_stopCapture()
            end
        elseif self.selected_source then
            self:_startCapture()
        end
    elseif action == "pause_capture" then
        if self.capture_status.is_capturing then
            self:_togglePause()
        end
    elseif action == "stop_capture" then
        if self.capture_status.is_capturing then
            self:_stopCapture()
        end
    elseif action == "area_select" then
        self:_startAreaSelection()
    end
end

-- Get current capture source object
function UIController:_getCurrentCaptureSource()
    if not self.selected_source then
        return nil
    end
    
    -- Get the appropriate capture source from the engine
    if self.selected_source == "screen" then
        return self.capture_engine.screen_capture
    elseif self.selected_source == "window" then
        return self.capture_engine.window_capture
    elseif self.selected_source == "webcam" then
        return self.capture_engine.webcam_capture
    end
    
    return nil
end

-- Toggle performance display
function UIController:_togglePerformanceDisplay()
    self.performance_display.enabled = not self.performance_display.enabled
    self:_setStatusMessage("Performance display: " .. (self.performance_display.enabled and "ON" or "OFF"), "success")
end

-- Start capture (Requirement 4.3 - immediate response to controls)
function UIController:_startCapture()
    if not self.selected_source then
        self:_setStatusMessage("No source selected", "error")
        return
    end
    
    local success, error_msg = self.capture_engine:startCapture()
    
    if success then
        self.capture_status.is_capturing = true
        self.capture_status.is_paused = false
        self.capture_status.source_type = self.selected_source
        self.capture_status.start_time = love.timer.getTime()
        
        self:_setStatusMessage("Capture started", "success")
        self:_updateButtonStates()
    else
        self:_setStatusMessage("Failed to start capture: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Stop capture (Requirement 4.3 - immediate response to controls)
function UIController:_stopCapture()
    local success, error_msg = self.capture_engine:stopCapture()
    
    if success then
        self.capture_status.is_capturing = false
        self.capture_status.is_paused = false
        
        self:_setStatusMessage("Capture stopped", "success")
        self:_updateButtonStates()
    else
        self:_setStatusMessage("Failed to stop capture: " .. (error_msg or "Unknown error"), "error")
    end
end

-- Toggle pause/resume capture (Requirement 4.3 - immediate response to controls)
function UIController:_togglePause()
    if not self.capture_status.is_capturing then
        return
    end
    
    local success, error_msg
    
    if self.capture_status.is_paused then
        success, error_msg = self.capture_engine:resumeCapture()
        if success then
            self.capture_status.is_paused = false
            self:_setStatusMessage("Capture resumed", "success")
        end
    else
        success, error_msg = self.capture_engine:pauseCapture()
        if success then
            self.capture_status.is_paused = true
            self:_setStatusMessage("Capture paused", "warning")
        end
    end
    
    if not success then
        self:_setStatusMessage("Failed to toggle pause: " .. (error_msg or "Unknown error"), "error")
    end
    
    self:_updateButtonStates()
end

-- Update button states based on current capture status
function UIController:_updateButtonStates()
    if not self.buttons then
        return
    end
    
    -- Update main screen buttons
    if self.current_screen == UI_STATES.MAIN then
        -- Start button
        if self.buttons.start_capture then
            self.buttons.start_capture.enabled = self.selected_source ~= nil and not self.capture_status.is_capturing
        end
        
        -- Stop button
        if self.buttons.stop_capture then
            self.buttons.stop_capture.enabled = self.capture_status.is_capturing
        end
        
        -- Pause button
        if self.buttons.pause_capture then
            self.buttons.pause_capture.enabled = self.capture_status.is_capturing
            self.buttons.pause_capture.text = self.capture_status.is_paused and "Resume" or "Pause"
        end
    end
end

-- Set status message with timeout and type
function UIController:_setStatusMessage(message, type)
    self.status_message = message
    self.status_timeout = love.timer.getTime() + 3.0 -- Show for 3 seconds
    self.status_type = type or "normal"
end

-- Handle user input (Requirement 5.4)
function UIController:handleInput(key, action)
    -- First check if we're in area selection mode
    if self:_isAreaSelectionActive() then
        return self:_handleAreaSelectionInput(key, action)
    end
    
    if action == "pressed" then
        -- Handle keyboard shortcuts
        if key == "escape" then
            if self.current_screen ~= UI_STATES.MAIN then
                self:_showMainScreen()
                return true
            end
        elseif key == "space" then
            -- Space bar toggles capture
            if self.capture_status.is_capturing then
                self:_togglePause()
            elseif self.selected_source then
                self:_startCapture()
            end
            return true
        elseif key == "s" then
            -- 'S' key stops capture
            if self.capture_status.is_capturing then
                self:_stopCapture()
            end
            return true
        elseif key == "r" then
            -- 'R' key refreshes sources
            self:_refreshAvailableSources()
            self:_setStatusMessage("Sources refreshed", "success")
            return true
        elseif key == "o" then
            -- 'O' key opens overlay settings
            self:_showOverlaySettings()
            return true
        elseif key == "t" then
            -- 'T' key toggles always on top
            self:_toggleAlwaysOnTop()
            return true
        elseif key == "b" then
            -- 'B' key toggles borderless
            self:_toggleBorderless()
            return true
        elseif key == "=" or key == "+" then
            -- '+' key increases transparency
            self:_adjustTransparency(0.1)
            return true
        elseif key == "-" then
            -- '-' key decreases transparency
            self:_adjustTransparency(-0.1)
            return true
        elseif key == "p" then
            -- 'P' key toggles performance display
            self:_togglePerformanceDisplay()
            return true
        elseif key == "c" then
            -- 'C' key toggles cursor capture
            self:_toggleCursorCapture()
            return true
        elseif key == "a" then
            -- 'A' key starts area selection
            self:_startAreaSelection()
            return true
        elseif key == "f9" then
            -- F9 key toggles capture (hotkey)
            self:_handleHotkey("toggle_capture")
            return true
        elseif key == "f10" then
            -- F10 key pauses capture (hotkey)
            self:_handleHotkey("pause_capture")
            return true
        elseif key == "f11" then
            -- F11 key stops capture (hotkey)
            self:_handleHotkey("stop_capture")
            return true
        elseif key == "f12" then
            -- F12 key starts area selection (hotkey)
            self:_handleHotkey("area_select")
            return true
        end
    end
    
    return false
end

-- Handle mouse input
function UIController:handleMouseInput(x, y, button, action)
    self.mouse.x = x
    self.mouse.y = y
    
    -- Handle area selection mouse input first
    if self:_isAreaSelectionActive() then
        return self:_handleAreaSelectionMouse(x, y, button, action)
    end
    
    if button == 1 then -- Left mouse button
        self.mouse.last_pressed = self.mouse.pressed
        self.mouse.pressed = (action == "pressed")
        
        -- Check for button clicks
        if action == "pressed" then
            return self:_checkButtonClicks(x, y)
        end
    end
    
    return false
end

-- Handle mouse input during area selection
function UIController:_handleAreaSelectionMouse(x, y, button, action)
    if button == 1 then -- Left mouse button
        local mouse_pressed = (action == "pressed" or action == "held")
        
        local source = self:_getCurrentCaptureSource()
        if source and source.updateAreaSelection then
            local completed, area = source:updateAreaSelection(x, y, mouse_pressed)
            
            if completed and area then
                self.area_selection_active = false
                self:_setStatusMessage(string.format("Area selected: %dx%d", area.width, area.height), "success")
                return true
            end
        end
    end
    
    return true -- Consume all mouse input during area selection
end

-- Check if mouse click hits any buttons
function UIController:_checkButtonClicks(x, y)
    for button_id, button in pairs(self.buttons) do
        if button.enabled and self:_isPointInButton(x, y, button) then
            button.state = BUTTON_STATES.PRESSED
            
            -- Execute button action
            if button.action then
                button.action()
            end
            
            return true
        end
    end
    
    return false
end

-- Check if point is within button bounds
function UIController:_isPointInButton(x, y, button)
    return x >= button.x and x <= button.x + button.width and
           y >= button.y and y <= button.y + button.height
end

-- Update UI state (Requirement 5.3 - display recording status)
function UIController:update(dt)
    self.update_stats.update_count = self.update_stats.update_count + 1
    self.update_stats.last_update_time = love.timer.getTime()
    
    -- Update capture status from engine
    if self.capture_status.is_capturing then
        local stats = self.capture_engine:getStats()
        if stats then
            self.capture_status.fps = stats.actual_fps or 0
            self.capture_status.frames_captured = stats.frames_captured or 0
            
            if self.capture_status.start_time then
                self.capture_status.elapsed_time = love.timer.getTime() - self.capture_status.start_time
            end
        end
    end
    
    -- Update performance metrics cache
    self:_updatePerformanceCache()
    
    -- Update button hover states
    self:_updateButtonHoverStates()
    
    -- Clear expired status messages
    if self.status_timeout > 0 and love.timer.getTime() > self.status_timeout then
        self.status_message = ""
        self.status_timeout = 0
    end
    
    -- Update capture engine
    self.capture_engine:update(dt)
    
    -- Update overlay manager
    self.overlay_manager:update(dt)
    
    -- Update renderer with latest frame
    if self.capture_status.is_capturing then
        local frame = self.capture_engine:getFrame()
        if frame and frame.data then
            self.renderer:updateFrame(frame.data, frame.width, frame.height)
        end
    end
end

-- Update button hover states based on mouse position
function UIController:_updateButtonHoverStates()
    for button_id, button in pairs(self.buttons) do
        if button.enabled then
            if self:_isPointInButton(self.mouse.x, self.mouse.y, button) then
                if button.state == BUTTON_STATES.NORMAL then
                    button.state = BUTTON_STATES.HOVER
                end
            else
                if button.state == BUTTON_STATES.HOVER then
                    button.state = BUTTON_STATES.NORMAL
                elseif button.state == BUTTON_STATES.PRESSED then
                    button.state = BUTTON_STATES.NORMAL
                end
            end
        end
    end
end

-- Update performance metrics cache
function UIController:_updatePerformanceCache()
    local current_time = love.timer.getTime()
    
    -- Only update cache periodically to avoid performance impact
    if current_time - self.performance_cache.last_update < self.performance_display.update_interval then
        return
    end
    
    self.performance_cache.last_update = current_time
    
    -- Get performance monitor from stored reference
    if self.performance_monitor then
        self.performance_cache.metrics = self.performance_monitor:getMetrics()
        self.performance_cache.summary = self.performance_monitor:getPerformanceSummary()
    end
end

-- Draw UI elements
function UIController:draw()
    -- Clear background
    love.graphics.setColor(self.colors.background)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw video frame if capturing
    if self.capture_status.is_capturing then
        self.renderer:render(0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end
    
    -- Draw UI overlay
    self:_drawUIOverlay()
end

-- Draw UI overlay with controls and status
function UIController:_drawUIOverlay()
    -- Draw current screen
    if self.current_screen == UI_STATES.MAIN then
        self:_drawMainScreen()
    elseif self.current_screen == UI_STATES.SOURCE_SELECTION then
        self:_drawSourceSelection()
    elseif self.current_screen == UI_STATES.OVERLAY_SETTINGS then
        self:_drawOverlaySettings()
    end
    
    -- Draw area selection overlay if active
    if self:_isAreaSelectionActive() then
        self:_drawAreaSelectionOverlay()
    end
    
    -- Draw status message
    self:_drawStatusMessage()
    
    -- Draw capture status (Requirement 5.3)
    if self.capture_status.is_capturing then
        self:_drawCaptureStatus()
    end
    
    -- Draw performance metrics (Requirement 6.3, 4.4, 5.3)
    if self.performance_display.enabled then
        self:_drawPerformanceMetrics()
    end
end

-- Draw area selection overlay
function UIController:_drawAreaSelectionOverlay()
    local source = self:_getCurrentCaptureSource()
    if source and source.drawAreaSelection then
        source:drawAreaSelection()
    end
end

-- Draw main screen UI
function UIController:_drawMainScreen()
    -- Draw title
    love.graphics.setFont(self.fonts.large)
    love.graphics.setColor(self.colors.text)
    local title = "Lua Video Capture Player"
    local title_width = self.fonts.large:getWidth(title)
    love.graphics.print(title, love.graphics.getWidth() / 2 - title_width / 2, 50)
    
    -- Draw selected source info
    if self.selected_source then
        love.graphics.setFont(self.fonts.normal)
        local source_text = "Selected: " .. self:_getSourceDisplayName(self.selected_source)
        local source_width = self.fonts.normal:getWidth(source_text)
        love.graphics.print(source_text, love.graphics.getWidth() / 2 - source_width / 2, 90)
    end
    
    -- Draw buttons
    self:_drawButtons()
end

-- Draw source selection screen
function UIController:_drawSourceSelection()
    -- Draw title
    love.graphics.setFont(self.fonts.large)
    love.graphics.setColor(self.colors.text)
    local title = "Select Capture Source"
    local title_width = self.fonts.large:getWidth(title)
    love.graphics.print(title, love.graphics.getWidth() / 2 - title_width / 2, 50)
    
    -- Draw available sources info
    love.graphics.setFont(self.fonts.small)
    local y_offset = 80
    
    for source_type, source_info in pairs(self.available_sources) do
        local status_text = self:_getSourceDisplayName(source_type) .. ": " .. 
                           (source_info.available and "Available" or "Not Available")
        
        if source_info.available then
            love.graphics.setColor(self.colors.success)
        else
            love.graphics.setColor(self.colors.error)
        end
        
        love.graphics.print(status_text, self.layout.margin, y_offset)
        y_offset = y_offset + 20
    end
    
    -- Draw buttons
    self:_drawButtons()
end

-- Draw overlay settings screen (Requirement 7.1, 7.2, 7.3)
function UIController:_drawOverlaySettings()
    -- Draw title
    love.graphics.setFont(self.fonts.large)
    love.graphics.setColor(self.colors.text)
    local title = "Overlay Settings"
    local title_width = self.fonts.large:getWidth(title)
    love.graphics.print(title, love.graphics.getWidth() / 2 - title_width / 2, 50)
    
    -- Draw current overlay status
    love.graphics.setFont(self.fonts.small)
    local config = self.overlay_manager:getConfiguration()
    
    local status_lines = {
        "Current Mode: " .. config.mode,
        "Transparency: " .. string.format("%.1f", config.transparency),
        "Position: " .. config.position.x .. ", " .. config.position.y,
        "Size: " .. config.size.width .. " x " .. config.size.height,
        "Active: " .. (config.is_active and "YES" or "NO")
    }
    
    local y_offset = 80
    for _, line in ipairs(status_lines) do
        love.graphics.setColor(self.colors.text)
        love.graphics.print(line, self.layout.margin, y_offset)
        y_offset = y_offset + 16
    end
    
    -- Draw transparency slider representation
    local slider_x = love.graphics.getWidth() / 2 - 90
    local slider_y = 320
    local slider_width = 180
    local slider_height = 20
    
    -- Draw slider background
    love.graphics.setColor(0.3, 0.3, 0.3, 1.0)
    love.graphics.rectangle("fill", slider_x, slider_y, slider_width, slider_height)
    
    -- Draw slider fill
    love.graphics.setColor(self.colors.accent)
    love.graphics.rectangle("fill", slider_x, slider_y, slider_width * config.transparency, slider_height)
    
    -- Draw slider border
    love.graphics.setColor(self.colors.text)
    love.graphics.rectangle("line", slider_x, slider_y, slider_width, slider_height)
    
    -- Draw transparency label
    love.graphics.setFont(self.fonts.small)
    local transparency_text = "Transparency: " .. string.format("%.1f", config.transparency)
    local text_width = self.fonts.small:getWidth(transparency_text)
    love.graphics.print(transparency_text, slider_x + slider_width / 2 - text_width / 2, slider_y - 20)
    
    -- Draw buttons
    self:_drawButtons()
end

-- Draw all buttons with visual feedback
function UIController:_drawButtons()
    love.graphics.setFont(self.fonts.normal)
    
    for button_id, button in pairs(self.buttons) do
        -- Choose button color based on state
        local color = self.colors.button_normal
        
        if not button.enabled then
            color = self.colors.button_disabled
        elseif button.state == BUTTON_STATES.HOVER then
            color = self.colors.button_hover
        elseif button.state == BUTTON_STATES.PRESSED then
            color = self.colors.button_pressed
        elseif button_id == "start_capture" and self.capture_status.is_capturing then
            color = self.colors.button_active
        elseif button_id == "stop_capture" and self.capture_status.is_capturing then
            color = self.colors.button_danger
        end
        
        -- Draw button background
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
        
        -- Draw button border
        love.graphics.setColor(self.colors.text)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
        
        -- Draw button text
        local text_color = button.enabled and self.colors.text or {0.5, 0.5, 0.5, 1.0}
        love.graphics.setColor(text_color)
        
        local text_width = self.fonts.normal:getWidth(button.text)
        local text_height = (self.fonts.normal.getHeight and self.fonts.normal:getHeight()) or self.layout.font_size
        local text_x = button.x + (button.width - text_width) / 2
        local text_y = button.y + (button.height - text_height) / 2
        
        love.graphics.print(button.text, text_x, text_y)
    end
end

-- Draw status message
function UIController:_drawStatusMessage()
    if self.status_message == "" then
        return
    end
    
    love.graphics.setFont(self.fonts.normal)
    
    -- Choose color based on status type
    local color = self.colors.text
    if self.status_type == "success" then
        color = self.colors.success
    elseif self.status_type == "warning" then
        color = self.colors.warning
    elseif self.status_type == "error" then
        color = self.colors.error
    end
    
    love.graphics.setColor(color)
    
    -- Draw status message at bottom of screen
    local text_width = self.fonts.normal:getWidth(self.status_message)
    local x = love.graphics.getWidth() / 2 - text_width / 2
    local y = love.graphics.getHeight() - 50
    
    love.graphics.print(self.status_message, x, y)
end

-- Draw capture status information (Requirement 5.3)
function UIController:_drawCaptureStatus()
    love.graphics.setFont(self.fonts.small)
    love.graphics.setColor(self.colors.text)
    
    local status_lines = {
        "Recording: " .. (self.capture_status.is_paused and "PAUSED" or "ACTIVE"),
        "Source: " .. (self.capture_status.source_type or "Unknown"),
        "FPS: " .. string.format("%.1f", self.capture_status.fps),
        "Frames: " .. self.capture_status.frames_captured,
        "Time: " .. self:_formatTime(self.capture_status.elapsed_time)
    }
    
    -- Draw status box background
    local box_width = 200
    local box_height = #status_lines * 16 + 10
    local box_x = love.graphics.getWidth() - box_width - self.layout.margin
    local box_y = self.layout.margin
    
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", box_x, box_y, box_width, box_height)
    
    love.graphics.setColor(self.colors.text)
    love.graphics.rectangle("line", box_x, box_y, box_width, box_height)
    
    -- Draw status text
    for i, line in ipairs(status_lines) do
        love.graphics.print(line, box_x + 5, box_y + 5 + (i - 1) * 16)
    end
end

-- Format time in MM:SS format
function UIController:_formatTime(seconds)
    if not seconds or seconds < 0 then
        return "00:00"
    end
    
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    
    return string.format("%02d:%02d", minutes, secs)
end

-- Draw performance metrics overlay (Requirement 6.3, 4.4, 5.3)
function UIController:_drawPerformanceMetrics()
    if not self.performance_cache.summary or not next(self.performance_cache.summary) then
        return
    end
    
    local summary = self.performance_cache.summary
    local metrics = self.performance_cache.metrics
    
    -- Performance display box dimensions
    local box_width = 200
    local box_height = 140
    local pos = self.performance_display.position
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, self.performance_display.background_alpha)
    love.graphics.rectangle("fill", pos.x, pos.y, box_width, box_height)
    
    -- Draw border with color based on performance state
    local border_color = self.colors.success
    if metrics.performance_state == "warning" then
        border_color = self.colors.warning
    elseif metrics.performance_state == "critical" then
        border_color = self.colors.error
    end
    
    love.graphics.setColor(border_color)
    love.graphics.rectangle("line", pos.x, pos.y, box_width, box_height)
    
    -- Draw performance metrics
    love.graphics.setFont(self.fonts.small)
    love.graphics.setColor(self.colors.text)
    
    local text_x = pos.x + 5
    local text_y = pos.y + 5
    local line_height = 14
    
    local performance_lines = {
        "Performance Monitor",
        "FPS: " .. summary.fps .. " / " .. summary.avg_fps .. " avg",
        "Frame Time: " .. summary.frame_time,
        "Memory: " .. summary.memory,
        "State: " .. summary.state:upper(),
        "Drops: " .. summary.drops .. " (" .. summary.drop_rate .. ")",
        "Skips: " .. summary.skips,
        "Session: " .. summary.session_time
    }
    
    for i, line in ipairs(performance_lines) do
        -- Color code certain lines
        if i == 1 then
            love.graphics.setColor(self.colors.accent)
        elseif line:find("State:") then
            love.graphics.setColor(border_color)
        elseif line:find("Drops:") and metrics.frames_dropped > 0 then
            love.graphics.setColor(self.colors.warning)
        else
            love.graphics.setColor(self.colors.text)
        end
        
        love.graphics.print(line, text_x, text_y + (i - 1) * line_height)
    end
    
    -- Draw performance recommendations if in warning/critical state
    if metrics.performance_state ~= "good" then
        self:_drawPerformanceRecommendations(pos.x, pos.y + box_height + 5)
    end
end

-- Draw performance recommendations
function UIController:_drawPerformanceRecommendations(x, y)
    if not self.performance_monitor then
        return
    end
    
    local recommendations = self.performance_monitor:getPerformanceRecommendations()
    if not recommendations or #recommendations == 0 then
        return
    end
    
    local box_width = 300
    local box_height = #recommendations * 16 + 10
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, self.performance_display.background_alpha)
    love.graphics.rectangle("fill", x, y, box_width, box_height)
    
    love.graphics.setColor(self.colors.warning)
    love.graphics.rectangle("line", x, y, box_width, box_height)
    
    -- Draw recommendations
    love.graphics.setFont(self.fonts.small)
    love.graphics.setColor(self.colors.text)
    
    for i, recommendation in ipairs(recommendations) do
        love.graphics.print(recommendation, x + 5, y + 5 + (i - 1) * 16)
    end
end

-- Toggle performance display
function UIController:_togglePerformanceDisplay()
    self.performance_display.enabled = not self.performance_display.enabled
    local status = self.performance_display.enabled and "ON" or "OFF"
    self:_setStatusMessage("Performance display: " .. status, "success")
end

-- Set performance display position
function UIController:setPerformanceDisplayPosition(x, y)
    self.performance_display.position.x = x
    self.performance_display.position.y = y
end

-- Enable/disable performance display
function UIController:setPerformanceDisplayEnabled(enabled)
    self.performance_display.enabled = enabled
end

-- Get current UI state
function UIController:getState()
    return {
        current_screen = self.current_screen,
        selected_source = self.selected_source,
        capture_status = self.capture_status,
        available_sources = self.available_sources,
        status_message = self.status_message,
        update_stats = self.update_stats,
        performance_display = self.performance_display,
        performance_cache = self.performance_cache
    }
end

-- Clean up resources
function UIController:cleanup()
    -- Clean up overlay manager
    if self.overlay_manager then
        self.overlay_manager:cleanup()
    end
    
    -- Clean up fonts
    for font_name, font in pairs(self.fonts) do
        if font and font.release then
            font:release()
        end
    end
    
    self.fonts = {}
    self.buttons = {}
    self.ui_elements = {}
end

return UIController