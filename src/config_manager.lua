-- Configuration Manager for Lua Video Capture Player
-- Handles persistent storage, validation, and runtime updates of user preferences

local json = require("src.json_utils")
local lfs = require("src.lfs_utils")

local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- Default configuration values
local DEFAULT_CONFIG = {
    -- General application settings
    app = {
        window_width = 800,
        window_height = 600,
        window_x = 100,
        window_y = 100,
        always_on_top = false,
        transparency = 1.0,
        theme = "default"
    },
    
    -- Capture source configurations
    capture = {
        default_source = "screen",
        frame_rate = 30,
        quality = "high",
        
        -- Screen capture settings (Requirement 5.2)
        screen = {
            x = 0,
            y = 0,
            width = 1920,
            height = 1080,
            monitor_index = 1,
            capture_cursor = true
        },
        
        -- Window capture settings (Requirement 5.2)
        window = {
            window_name = "",
            follow_window = true,
            include_borders = false,
            capture_cursor = true
        },
        
        -- Webcam settings (Requirement 3.3)
        webcam = {
            device_index = 0,
            resolution = {
                width = 640,
                height = 480
            },
            fps = 30,
            auto_exposure = true,
            brightness = 0.5,
            contrast = 0.5
        }
    },
    
    -- Display and overlay settings (Requirement 7.3)
    display = {
        scaling_mode = "fit", -- "fit", "fill", "stretch"
        overlay_mode = false,
        overlay = {
            x = 100,
            y = 100,
            width = 400,
            height = 300,
            transparency = 0.8,
            always_on_top = true,
            borderless = true
        }
    },
    
    -- Performance settings
    performance = {
        max_frame_buffer = 3,
        enable_frame_dropping = true,
        memory_limit_mb = 512,
        cpu_limit_percent = 80
    },
    
    -- UI preferences
    ui = {
        show_fps = true,
        show_stats = false,
        control_panel_visible = true,
        hotkeys_enabled = true
    }
}

-- Configuration file path
local CONFIG_DIR = "config"
local CONFIG_FILE = CONFIG_DIR .. "/settings.json"

function ConfigManager:new()
    local instance = setmetatable({
        config = {},
        config_file = CONFIG_FILE,
        callbacks = {}, -- Runtime update callbacks
        validation_rules = {}
    }, self)
    
    -- Ensure config directory exists
    self:_ensureConfigDirectory()
    
    -- Load configuration
    instance:load()
    
    -- Set up validation rules
    instance:_setupValidationRules()
    
    return instance
end

-- Ensure configuration directory exists
function ConfigManager:_ensureConfigDirectory()
    local attr = lfs.attributes(CONFIG_DIR)
    if not attr then
        local success, err = lfs.mkdir(CONFIG_DIR)
        if not success then
            error("Failed to create config directory: " .. (err or "unknown error"))
        end
    elseif attr.mode ~= "directory" then
        error("Config path exists but is not a directory: " .. CONFIG_DIR)
    end
end

-- Deep copy function for tables
function ConfigManager:_deepCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = self:_deepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

-- Merge configuration tables (new values override existing ones)
function ConfigManager:_mergeConfig(base, override)
    local result = self:_deepCopy(base)
    
    for key, value in pairs(override) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = self:_mergeConfig(result[key], value)
        else
            result[key] = value
        end
    end
    
    return result
end

-- Load configuration from file
function ConfigManager:load()
    local file = io.open(self.config_file, "r")
    if not file then
        -- No config file exists, use defaults
        self.config = self:_deepCopy(DEFAULT_CONFIG)
        return true
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or content == "" then
        self.config = self:_deepCopy(DEFAULT_CONFIG)
        return true
    end
    
    local success, loaded_config = pcall(json.decode, content)
    if not success then
        error("Failed to parse configuration file: " .. (loaded_config or "invalid JSON"))
    end
    
    -- Merge loaded config with defaults to ensure all keys exist
    self.config = self:_mergeConfig(DEFAULT_CONFIG, loaded_config)
    
    -- Validate loaded configuration
    local validation_result = self:validate()
    if not validation_result.valid then
        error("Invalid configuration loaded: " .. table.concat(validation_result.errors, ", "))
    end
    
    return true
end

-- Save configuration to file
function ConfigManager:save()
    local file, err = io.open(self.config_file, "w")
    if not file then
        error("Failed to open config file for writing: " .. (err or "unknown error"))
    end
    
    local success, json_content = pcall(json.encode, self.config)
    if not success then
        file:close()
        error("Failed to encode configuration to JSON: " .. (json_content or "unknown error"))
    end
    
    file:write(json_content)
    file:close()
    
    return true
end

-- Get configuration value by path (e.g., "capture.webcam.resolution.width")
function ConfigManager:get(path)
    local keys = {}
    for key in path:gmatch("[^%.]+") do
        table.insert(keys, key)
    end
    
    local current = self.config
    for _, key in ipairs(keys) do
        if type(current) ~= "table" or current[key] == nil then
            return nil
        end
        current = current[key]
    end
    
    return current
end

-- Set configuration value by path with validation
function ConfigManager:set(path, value)
    local keys = {}
    for key in path:gmatch("[^%.]+") do
        table.insert(keys, key)
    end
    
    if #keys == 0 then
        error("Invalid configuration path: " .. path)
    end
    
    -- Navigate to parent and set the final key
    local current = self.config
    for i = 1, #keys - 1 do
        local key = keys[i]
        if type(current[key]) ~= "table" then
            current[key] = {}
        end
        current = current[key]
    end
    
    local final_key = keys[#keys]
    local old_value = current[final_key]
    current[final_key] = value
    
    -- Validate the change
    local validation_result = self:validate()
    if not validation_result.valid then
        -- Revert the change
        current[final_key] = old_value
        error("Invalid configuration value: " .. table.concat(validation_result.errors, ", "))
    end
    
    -- Notify callbacks about the change
    self:_notifyCallbacks(path, value, old_value)
    
    return true
end

-- Register callback for configuration changes
function ConfigManager:onConfigChange(path, callback)
    if not self.callbacks[path] then
        self.callbacks[path] = {}
    end
    table.insert(self.callbacks[path], callback)
end

-- Notify callbacks about configuration changes
function ConfigManager:_notifyCallbacks(path, new_value, old_value)
    -- Notify exact path callbacks
    if self.callbacks[path] then
        for _, callback in ipairs(self.callbacks[path]) do
            pcall(callback, path, new_value, old_value)
        end
    end
    
    -- Notify parent path callbacks (e.g., "capture" for "capture.webcam.fps")
    local parent_path = ""
    for key in path:gmatch("[^%.]+") do
        if parent_path ~= "" then
            parent_path = parent_path .. "."
        end
        parent_path = parent_path .. key
        
        if self.callbacks[parent_path] and parent_path ~= path then
            for _, callback in ipairs(self.callbacks[parent_path]) do
                pcall(callback, path, new_value, old_value)
            end
        end
    end
end

-- Setup validation rules
function ConfigManager:_setupValidationRules()
    self.validation_rules = {
        -- App settings validation
        ["app.window_width"] = function(value)
            return type(value) == "number" and value > 0 and value <= 4096
        end,
        ["app.window_height"] = function(value)
            return type(value) == "number" and value > 0 and value <= 4096
        end,
        ["app.transparency"] = function(value)
            return type(value) == "number" and value >= 0 and value <= 1
        end,
        
        -- Capture settings validation
        ["capture.frame_rate"] = function(value)
            return type(value) == "number" and value >= 1 and value <= 120
        end,
        ["capture.quality"] = function(value)
            return type(value) == "string" and (value == "low" or value == "medium" or value == "high")
        end,
        
        -- Webcam validation (Requirement 3.3)
        ["capture.webcam.resolution.width"] = function(value)
            return type(value) == "number" and value > 0 and value <= 4096
        end,
        ["capture.webcam.resolution.height"] = function(value)
            return type(value) == "number" and value > 0 and value <= 4096
        end,
        ["capture.webcam.fps"] = function(value)
            return type(value) == "number" and value >= 1 and value <= 120
        end,
        
        -- Display/overlay validation (Requirement 7.3)
        ["display.overlay.x"] = function(value)
            return type(value) == "number" and value >= 0
        end,
        ["display.overlay.y"] = function(value)
            return type(value) == "number" and value >= 0
        end,
        ["display.overlay.width"] = function(value)
            return type(value) == "number" and value > 0
        end,
        ["display.overlay.height"] = function(value)
            return type(value) == "number" and value > 0
        end,
        ["display.overlay.transparency"] = function(value)
            return type(value) == "number" and value >= 0 and value <= 1
        end,
        
        -- Performance validation
        ["performance.max_frame_buffer"] = function(value)
            return type(value) == "number" and value >= 1 and value <= 10
        end,
        ["performance.memory_limit_mb"] = function(value)
            return type(value) == "number" and value >= 64 and value <= 4096
        end
    }
end

-- Validate current configuration
function ConfigManager:validate()
    local errors = {}
    
    -- Validate using rules
    for path, rule in pairs(self.validation_rules) do
        local value = self:get(path)
        if value ~= nil and not rule(value) then
            table.insert(errors, "Invalid value for " .. path .. ": " .. tostring(value))
        end
    end
    
    return {
        valid = #errors == 0,
        errors = errors
    }
end

-- Reset configuration to defaults
function ConfigManager:resetToDefaults()
    self.config = self:_deepCopy(DEFAULT_CONFIG)
    self:save()
    
    -- Notify all callbacks about the reset
    for path, _ in pairs(self.callbacks) do
        local value = self:get(path)
        self:_notifyCallbacks(path, value, nil)
    end
end

-- Get all configuration as a copy
function ConfigManager:getAll()
    return self:_deepCopy(self.config)
end

-- Update multiple configuration values at once
function ConfigManager:updateBatch(updates)
    local old_values = {}
    local applied_changes = {}
    
    -- First, validate all changes
    for path, value in pairs(updates) do
        old_values[path] = self:get(path)
        
        -- Temporarily apply the change for validation
        local keys = {}
        for key in path:gmatch("[^%.]+") do
            table.insert(keys, key)
        end
        
        local current = self.config
        for i = 1, #keys - 1 do
            local key = keys[i]
            if type(current[key]) ~= "table" then
                current[key] = {}
            end
            current = current[key]
        end
        
        local final_key = keys[#keys]
        current[final_key] = value
        table.insert(applied_changes, {current, final_key, old_values[path]})
    end
    
    -- Validate all changes
    local validation_result = self:validate()
    if not validation_result.valid then
        -- Revert all changes
        for _, change in ipairs(applied_changes) do
            local current, key, old_value = change[1], change[2], change[3]
            current[key] = old_value
        end
        error("Batch update validation failed: " .. table.concat(validation_result.errors, ", "))
    end
    
    -- Notify callbacks for all changes
    for path, value in pairs(updates) do
        self:_notifyCallbacks(path, value, old_values[path])
    end
    
    return true
end

return ConfigManager