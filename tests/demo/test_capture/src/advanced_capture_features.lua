-- Advanced Capture Features Module
-- Provides cursor capture, area selection, and hotkey support for enhanced capture functionality

local ffi_bindings = require("src.ffi_bindings")

local AdvancedCaptureFeatures = {}
AdvancedCaptureFeatures.__index = AdvancedCaptureFeatures

-- Cursor capture modes
local CURSOR_MODES = {
    NONE = "none",
    SYSTEM = "system",
    CUSTOM = "custom"
}

-- Area selection states
local SELECTION_STATES = {
    INACTIVE = "inactive",
    SELECTING = "selecting", 
    SELECTED = "selected"
}

-- Hotkey states
local HOTKEY_STATES = {
    NONE = "none",
    PRESSED = "pressed",
    RELEASED = "released"
}

function AdvancedCaptureFeatures:new(options)
    options = options or {}
    
    return setmetatable({
        -- Cursor capture settings
        cursor_capture = {
            enabled = options.cursor_capture or false,
            mode = CURSOR_MODES.SYSTEM,
            custom_cursor = nil,
            cursor_size = {width = 32, height = 32},
            cursor_offset = {x = 0, y = 0}
        },
        
        -- Area selection state
        area_selection = {
            state = SELECTION_STATES.INACTIVE,
            start_pos = {x = 0, y = 0},
            end_pos = {x = 0, y = 0},
            current_area = nil,
            visual_feedback = true,
            selection_color = {r = 0.3, g = 0.6, b = 0.9, a = 0.3},
            border_color = {r = 0.3, g = 0.6, b = 0.9, a = 0.8},
            border_width = 2
        },
        
        -- Hotkey management
        hotkeys = {
            enabled = options.hotkeys_enabled ~= false,
            bindings = {
                toggle_capture = options.toggle_key or "f9",
                pause_capture = options.pause_key or "f10", 
                stop_capture = options.stop_key or "f11",
                area_select = options.area_select_key or "f12",
                cursor_toggle = options.cursor_toggle_key or "ctrl+c"
            },
            states = {},
            callbacks = {}
        },
        
        -- Visual feedback overlay
        overlay = {
            enabled = true,
            font = nil,
            instructions_visible = false,
            crosshair_visible = false,
            grid_visible = false,
            grid_size = 20
        },
        
        -- Internal state
        last_error = nil,
        mouse_pos = {x = 0, y = 0},
        is_selecting = false
    }, self)
end

-- Initialize advanced features
function AdvancedCaptureFeatures:initialize()
    -- Initialize hotkey states
    for key, binding in pairs(self.hotkeys.bindings) do
        self.hotkeys.states[binding] = HOTKEY_STATES.NONE
    end
    
    -- Initialize overlay font if available
    if love and love.graphics then
        self.overlay.font = love.graphics.newFont(12)
    end
    
    return true
end

-- Cursor Capture Implementation (Requirements 1.1, 2.2)

-- Enable/disable cursor capture
function AdvancedCaptureFeatures:setCursorCapture(enabled, mode)
    mode = mode or CURSOR_MODES.SYSTEM
    
    if enabled and not CURSOR_MODES[mode:upper()] then
        self.last_error = "Invalid cursor capture mode: " .. tostring(mode)
        return false, self.last_error
    end
    
    self.cursor_capture.enabled = enabled
    self.cursor_capture.mode = mode:lower()
    
    return true
end

-- Get current cursor position and appearance
function AdvancedCaptureFeatures:getCursorInfo()
    if not self.cursor_capture.enabled then
        return nil
    end
    
    -- Get cursor position from system
    local cursor_pos = ffi_bindings.getCursorPosition()
    if not cursor_pos then
        return nil, "Failed to get cursor position"
    end
    
    -- Get cursor appearance if system mode
    local cursor_data = nil
    if self.cursor_capture.mode == CURSOR_MODES.SYSTEM then
        cursor_data = ffi_bindings.getCurrentCursor()
    elseif self.cursor_capture.mode == CURSOR_MODES.CUSTOM then
        cursor_data = self.cursor_capture.custom_cursor
    end
    
    return {
        position = cursor_pos,
        data = cursor_data,
        size = self.cursor_capture.cursor_size,
        offset = self.cursor_capture.cursor_offset
    }
end

-- Capture screen/window with cursor overlay
function AdvancedCaptureFeatures:captureWithCursor(capture_func, ...)
    -- Perform base capture
    local result = capture_func(...)
    if not result then
        return result
    end
    
    -- Add cursor if enabled
    if self.cursor_capture.enabled then
        local cursor_info = self:getCursorInfo()
        if cursor_info then
            result = self:_overlayCursor(result, cursor_info)
        end
    end
    
    return result
end

-- Overlay cursor onto captured image
function AdvancedCaptureFeatures:_overlayCursor(image_data, cursor_info)
    -- This would typically use image processing to composite the cursor
    -- For now, we'll store the cursor info with the image data
    if type(image_data) == "table" then
        image_data.cursor = cursor_info
    else
        -- Wrap simple image data in table with cursor info
        image_data = {
            data = image_data,
            cursor = cursor_info
        }
    end
    
    return image_data
end

-- Area Selection Implementation (Requirements 1.1, 2.2)

-- Start area selection mode
function AdvancedCaptureFeatures:startAreaSelection()
    self.area_selection.state = SELECTION_STATES.SELECTING
    self.area_selection.start_pos = {x = 0, y = 0}
    self.area_selection.end_pos = {x = 0, y = 0}
    self.area_selection.current_area = nil
    self.overlay.instructions_visible = true
    self.overlay.crosshair_visible = true
    
    return true
end

-- Update area selection based on mouse input
function AdvancedCaptureFeatures:updateAreaSelection(mouse_x, mouse_y, mouse_pressed)
    if self.area_selection.state ~= SELECTION_STATES.SELECTING then
        return false
    end
    
    self.mouse_pos.x = mouse_x
    self.mouse_pos.y = mouse_y
    
    if mouse_pressed and not self.is_selecting then
        -- Start selection
        self.area_selection.start_pos.x = mouse_x
        self.area_selection.start_pos.y = mouse_y
        self.is_selecting = true
        
    elseif not mouse_pressed and self.is_selecting then
        -- End selection
        self.area_selection.end_pos.x = mouse_x
        self.area_selection.end_pos.y = mouse_y
        self.is_selecting = false
        
        -- Calculate selected area
        local area = self:_calculateSelectedArea()
        if area.width > 10 and area.height > 10 then  -- Minimum size check
            self.area_selection.current_area = area
            self.area_selection.state = SELECTION_STATES.SELECTED
            self.overlay.instructions_visible = false
            self.overlay.crosshair_visible = false
            return true, area
        else
            -- Selection too small, restart
            self:startAreaSelection()
        end
        
    elseif self.is_selecting then
        -- Update end position while selecting
        self.area_selection.end_pos.x = mouse_x
        self.area_selection.end_pos.y = mouse_y
    end
    
    return false
end

-- Calculate selected area from start and end positions
function AdvancedCaptureFeatures:_calculateSelectedArea()
    local start_x = math.min(self.area_selection.start_pos.x, self.area_selection.end_pos.x)
    local start_y = math.min(self.area_selection.start_pos.y, self.area_selection.end_pos.y)
    local end_x = math.max(self.area_selection.start_pos.x, self.area_selection.end_pos.x)
    local end_y = math.max(self.area_selection.start_pos.y, self.area_selection.end_pos.y)
    
    return {
        x = start_x,
        y = start_y,
        width = end_x - start_x,
        height = end_y - start_y
    }
end

-- Get current selected area
function AdvancedCaptureFeatures:getSelectedArea()
    if self.area_selection.state == SELECTION_STATES.SELECTED then
        return self.area_selection.current_area
    end
    return nil
end

-- Cancel area selection
function AdvancedCaptureFeatures:cancelAreaSelection()
    self.area_selection.state = SELECTION_STATES.INACTIVE
    self.area_selection.current_area = nil
    self.overlay.instructions_visible = false
    self.overlay.crosshair_visible = false
    self.is_selecting = false
    
    return true
end

-- Hotkey Support Implementation (Requirement 5.4)

-- Register hotkey callback
function AdvancedCaptureFeatures:registerHotkeyCallback(action, callback)
    if not self.hotkeys.bindings[action] then
        self.last_error = "Unknown hotkey action: " .. tostring(action)
        return false, self.last_error
    end
    
    self.hotkeys.callbacks[action] = callback
    return true
end

-- Update hotkey states and trigger callbacks
function AdvancedCaptureFeatures:updateHotkeys(pressed_keys)
    if not self.hotkeys.enabled then
        return
    end
    
    for action, binding in pairs(self.hotkeys.bindings) do
        local is_pressed = self:_isHotkeyPressed(binding, pressed_keys)
        local previous_state = self.hotkeys.states[binding]
        
        if is_pressed and previous_state ~= HOTKEY_STATES.PRESSED then
            -- Key just pressed
            self.hotkeys.states[binding] = HOTKEY_STATES.PRESSED
            
            local callback = self.hotkeys.callbacks[action]
            if callback then
                callback(action, "pressed")
            end
            
        elseif not is_pressed and previous_state == HOTKEY_STATES.PRESSED then
            -- Key just released
            self.hotkeys.states[binding] = HOTKEY_STATES.RELEASED
            
            local callback = self.hotkeys.callbacks[action]
            if callback then
                callback(action, "released")
            end
            
        elseif not is_pressed then
            self.hotkeys.states[binding] = HOTKEY_STATES.NONE
        end
    end
end

-- Check if specific hotkey combination is pressed
function AdvancedCaptureFeatures:_isHotkeyPressed(binding, pressed_keys)
    -- Parse binding (e.g., "ctrl+c", "f9", "shift+alt+s")
    local parts = {}
    for part in binding:gmatch("[^+]+") do
        table.insert(parts, part:lower())
    end
    
    -- Check if all parts of the combination are pressed
    for _, part in ipairs(parts) do
        if not pressed_keys[part] then
            return false
        end
    end
    
    return true
end

-- Set hotkey binding
function AdvancedCaptureFeatures:setHotkeyBinding(action, binding)
    if not self.hotkeys.bindings[action] then
        self.last_error = "Unknown hotkey action: " .. tostring(action)
        return false, self.last_error
    end
    
    -- Clear old state
    local old_binding = self.hotkeys.bindings[action]
    if self.hotkeys.states[old_binding] then
        self.hotkeys.states[old_binding] = nil
    end
    
    -- Set new binding
    self.hotkeys.bindings[action] = binding:lower()
    self.hotkeys.states[binding:lower()] = HOTKEY_STATES.NONE
    
    return true
end

-- Visual Feedback Implementation

-- Draw area selection overlay
function AdvancedCaptureFeatures:drawAreaSelection()
    if not love or not love.graphics then
        return  -- No graphics context available
    end
    
    if self.area_selection.state == SELECTION_STATES.INACTIVE then
        return
    end
    
    -- Draw crosshair at mouse position
    if self.overlay.crosshair_visible then
        self:_drawCrosshair(self.mouse_pos.x, self.mouse_pos.y)
    end
    
    -- Draw selection rectangle
    if self.is_selecting or self.area_selection.state == SELECTION_STATES.SELECTED then
        local area = self:_calculateSelectedArea()
        if area.width > 0 and area.height > 0 then
            self:_drawSelectionRectangle(area)
        end
    end
    
    -- Draw instructions
    if self.overlay.instructions_visible then
        self:_drawInstructions()
    end
    
    -- Draw grid if enabled
    if self.overlay.grid_visible then
        self:_drawGrid()
    end
end

-- Draw crosshair at specified position
function AdvancedCaptureFeatures:_drawCrosshair(x, y)
    love.graphics.setColor(self.area_selection.border_color.r, 
                          self.area_selection.border_color.g, 
                          self.area_selection.border_color.b, 
                          self.area_selection.border_color.a)
    love.graphics.setLineWidth(1)
    
    -- Horizontal line
    love.graphics.line(x - 10, y, x + 10, y)
    -- Vertical line  
    love.graphics.line(x, y - 10, x, y + 10)
end

-- Draw selection rectangle
function AdvancedCaptureFeatures:_drawSelectionRectangle(area)
    -- Fill
    love.graphics.setColor(self.area_selection.selection_color.r,
                          self.area_selection.selection_color.g,
                          self.area_selection.selection_color.b,
                          self.area_selection.selection_color.a)
    love.graphics.rectangle("fill", area.x, area.y, area.width, area.height)
    
    -- Border
    love.graphics.setColor(self.area_selection.border_color.r,
                          self.area_selection.border_color.g,
                          self.area_selection.border_color.b,
                          self.area_selection.border_color.a)
    love.graphics.setLineWidth(self.area_selection.border_width)
    love.graphics.rectangle("line", area.x, area.y, area.width, area.height)
    
    -- Draw dimensions text
    if self.overlay.font then
        love.graphics.setFont(self.overlay.font)
        local text = string.format("%dx%d", area.width, area.height)
        local text_x = area.x + area.width / 2 - self.overlay.font:getWidth(text) / 2
        local text_y = area.y + area.height / 2 - self.overlay.font:getHeight() / 2
        
        -- Text background
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", text_x - 5, text_y - 2, 
                               self.overlay.font:getWidth(text) + 10, 
                               self.overlay.font:getHeight() + 4)
        
        -- Text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(text, text_x, text_y)
    end
end

-- Draw instruction text
function AdvancedCaptureFeatures:_drawInstructions()
    if not self.overlay.font then
        return
    end
    
    love.graphics.setFont(self.overlay.font)
    love.graphics.setColor(1, 1, 1, 0.9)
    
    local instructions = {
        "Click and drag to select capture area",
        "Press ESC to cancel selection",
        "Press ENTER to confirm selection"
    }
    
    local y = 20
    for _, instruction in ipairs(instructions) do
        -- Text background
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 10, y - 2, 
                               self.overlay.font:getWidth(instruction) + 10, 
                               self.overlay.font:getHeight() + 4)
        
        -- Text
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(instruction, 15, y)
        y = y + self.overlay.font:getHeight() + 5
    end
end

-- Draw alignment grid
function AdvancedCaptureFeatures:_drawGrid()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.setLineWidth(1)
    
    -- Vertical lines
    for x = 0, width, self.overlay.grid_size do
        love.graphics.line(x, 0, x, height)
    end
    
    -- Horizontal lines
    for y = 0, height, self.overlay.grid_size do
        love.graphics.line(0, y, width, y)
    end
end

-- Utility Functions

-- Get last error message
function AdvancedCaptureFeatures:getLastError()
    return self.last_error
end

-- Enable/disable visual feedback
function AdvancedCaptureFeatures:setVisualFeedback(enabled)
    self.area_selection.visual_feedback = enabled
    return true
end

-- Enable/disable grid overlay
function AdvancedCaptureFeatures:setGridOverlay(enabled, grid_size)
    self.overlay.grid_visible = enabled
    if grid_size then
        self.overlay.grid_size = grid_size
    end
    return true
end

-- Get current configuration
function AdvancedCaptureFeatures:getConfiguration()
    return {
        cursor_capture = {
            enabled = self.cursor_capture.enabled,
            mode = self.cursor_capture.mode
        },
        area_selection = {
            state = self.area_selection.state,
            current_area = self.area_selection.current_area
        },
        hotkeys = {
            enabled = self.hotkeys.enabled,
            bindings = self.hotkeys.bindings
        },
        overlay = {
            enabled = self.overlay.enabled,
            grid_visible = self.overlay.grid_visible,
            grid_size = self.overlay.grid_size
        }
    }
end

-- Export constants
AdvancedCaptureFeatures.CURSOR_MODES = CURSOR_MODES
AdvancedCaptureFeatures.SELECTION_STATES = SELECTION_STATES
AdvancedCaptureFeatures.HOTKEY_STATES = HOTKEY_STATES

return AdvancedCaptureFeatures