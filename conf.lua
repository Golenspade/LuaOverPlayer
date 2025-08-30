-- LÖVE 2D Configuration for Lua Video Capture Player
function love.conf(t)
    -- Basic application info
    t.identity = "lua-video-capture-player"
    t.version = "11.4"
    t.console = false
    t.accelerometerjoystick = false
    t.externalstorage = false
    t.gammacorrect = false

    -- Window configuration
    t.window.title = "Lua Video Capture Player"
    t.window.max_width = 3840
    t.window.max_height = 2160
    t.window.icon = nil
    t.window.width = 800
    t.window.height = 600
    t.window.borderless = false
    t.window.resizable = true
    t.window.minwidth = 400
    t.window.minheight = 300
    t.window.fullscreen = false
    t.window.fullscreentype = "desktop"
    t.window.vsync = 1
    t.window.msaa = 0
    t.window.depth = nil
    t.window.stencil = nil
    t.window.display = 1
    t.window.highdpi = false
    t.window.usedpiscale = true
    t.window.x = nil
    t.window.y = nil

    -- Audio configuration (minimal for video capture)
    t.audio.mic = false
    t.audio.mixwithsystem = true

    -- Module configuration
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = false
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = false
    t.modules.system = true
    t.modules.thread = true
    t.modules.timer = true
    t.modules.touch = false
    t.modules.video = false
    t.modules.window = true
end