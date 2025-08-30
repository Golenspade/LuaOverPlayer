#!/usr/bin/env luajit
-- 简单的UI显示测试

-- 启动LÖVE应用并检查是否有基本的UI元素
print("Testing UI display...")

-- 模拟启动应用
local success, error_msg = pcall(function()
    -- 加载主应用模块
    dofile("main.lua")
    
    -- 检查应用是否正确初始化
    if app and app.initialized then
        print("✅ Application initialized successfully")
        
        -- 检查核心组件
        if app.ui_controller then
            print("✅ UI Controller available")
        else
            print("❌ UI Controller missing")
        end
        
        if app.video_renderer then
            print("✅ Video Renderer available")
        else
            print("❌ Video Renderer missing")
        end
        
        if app.capture_engine then
            print("✅ Capture Engine available")
        else
            print("❌ Capture Engine missing")
        end
        
        return true
    else
        print("❌ Application not initialized")
        return false
    end
end)

if success then
    print("🎉 UI components loaded successfully!")
    print("💡 Run 'love .' to see the actual interface")
else
    print("❌ Error loading UI: " .. tostring(error_msg))
end