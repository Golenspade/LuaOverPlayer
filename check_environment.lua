#!/usr/bin/env luajit
-- 环境依赖检测脚本
-- 检测Mac开发环境和Windows部署的兼容性

local function print_header(title)
    print("\n" .. string.rep("=", 60))
    print("  " .. title)
    print(string.rep("=", 60))
end

local function print_section(title)
    print("\n" .. string.rep("-", 40))
    print("  " .. title)
    print(string.rep("-", 40))
end

local function check_command(cmd, description)
    local handle = io.popen(cmd .. " 2>&1")
    local result = handle:read("*a")
    local success = handle:close()
    
    if success then
        print("✅ " .. description .. ": 可用")
        print("   " .. result:gsub("\n", "\n   "))
    else
        print("❌ " .. description .. ": 不可用")
        print("   " .. result:gsub("\n", "\n   "))
    end
    return success
end

local function check_lua_module(module_name)
    local success, module = pcall(require, module_name)
    if success then
        print("✅ " .. module_name .. ": 可用")
        if module_name == "ffi" then
            print("   FFI架构: " .. require("ffi").arch)
            print("   FFI操作系统: " .. require("ffi").os)
        end
        return true
    else
        print("❌ " .. module_name .. ": 不可用")
        print("   错误: " .. tostring(module))
        return false
    end
end

local function detect_os()
    local os_name = package.config:sub(1,1) == '\\' and "Windows" or "Unix-like"
    print("🖥️  操作系统: " .. os_name)
    
    -- 检测具体系统
    local handle = io.popen("uname -s 2>/dev/null || echo Windows")
    local uname = handle:read("*a"):gsub("\n", "")
    handle:close()
    
    if uname ~= "Windows" then
        print("   具体系统: " .. uname)
    end
    
    return os_name
end

-- 主检测流程
print_header("Lua视频捕获播放器 - 环境依赖检测")

-- 1. 操作系统检测
print_section("操作系统信息")
local current_os = detect_os()

-- 2. Lua环境检测
print_section("Lua运行时环境")
print("📋 Lua版本: " .. _VERSION)
check_command("which luajit", "LuaJIT路径")

-- 3. 核心模块检测
print_section("核心Lua模块")
local ffi_available = check_lua_module("ffi")
check_lua_module("bit")
check_lua_module("os")
check_lua_module("io")

-- 4. LÖVE 2D检测
print_section("LÖVE 2D游戏引擎")
local love_available = check_command("love --version", "LÖVE 2D")

-- 5. 开发工具检测
print_section("开发工具")
check_command("brew --version", "Homebrew包管理器")

-- 6. 项目特定检测
print_section("项目文件检测")
local project_files = {
    "conf.lua",
    "main.lua", 
    "src/ffi_bindings.lua",
    "src/unified_capture_engine.lua"
}

for _, file in ipairs(project_files) do
    local f = io.open(file, "r")
    if f then
        f:close()
        print("✅ " .. file .. ": 存在")
    else
        print("❌ " .. file .. ": 缺失")
    end
end

-- 7. Windows兼容性检测
print_section("Windows部署兼容性")
if ffi_available then
    local ffi = require("ffi")
    print("✅ FFI支持: 可用 (架构: " .. ffi.arch .. ", 系统: " .. ffi.os .. ")")
    
    -- 检测Windows API绑定
    local success, err = pcall(function()
        dofile("src/ffi_bindings.lua")
    end)
    
    if success then
        print("✅ Windows API绑定: 语法正确")
    else
        print("❌ Windows API绑定: 语法错误")
        print("   错误: " .. tostring(err))
    end
else
    print("❌ FFI支持: 不可用，无法进行Windows API绑定")
end

-- 8. 安装建议
print_section("安装建议")

if not love_available then
    print("📦 需要安装LÖVE 2D:")
    print("   brew install --cask love")
end

if current_os ~= "Windows" then
    print("🔄 跨平台开发注意事项:")
    print("   - 当前在Mac环境开发，目标部署Windows")
    print("   - FFI绑定仅在Windows上有效")
    print("   - 建议使用Mock系统进行Mac开发")
    print("   - 最终测试需要在Windows环境进行")
end

-- 9. 总结
print_section("环境检测总结")
local issues = {}

if not love_available then
    table.insert(issues, "LÖVE 2D未安装")
end

if not ffi_available then
    table.insert(issues, "FFI模块不可用")
end

if #issues == 0 then
    print("🎉 环境检测完成！所有核心依赖都已满足。")
    print("💡 可以开始开发，使用Mock系统在Mac上测试。")
else
    print("⚠️  发现以下问题需要解决:")
    for _, issue in ipairs(issues) do
        print("   - " .. issue)
    end
end

print("\n🚀 下一步:")
print("   1. 安装缺失的依赖")
print("   2. 运行 'luajit run_tests.lua' 执行测试")
print("   3. 运行 'love .' 启动应用")
print("   4. 在Windows环境进行最终测试")