#!/usr/bin/env luajit
-- 统一测试运行器 - 运行所有类型的测试

-- 添加路径
local function addToPath(path)
    package.path = package.path .. ";" .. path .. "/?.lua"
end

addToPath("src")
addToPath("tests")
addToPath("tests/utils")

-- 加载测试框架
local TestFramework = require("test_framework")

-- 测试结果统计
local test_results = {
    unit = {passed = 0, total = 0, failures = {}},
    integration = {passed = 0, total = 0, failures = {}},
    stress = {passed = 0, total = 0, failures = {}},
    demo = {passed = 0, total = 0, failures = {}}
}

-- 运行单个测试文件
local function runTestFile(file_path, test_type)
    print("\n" .. string.rep("=", 60))
    print("运行测试: " .. file_path)
    print(string.rep("=", 60))
    
    local success, result = pcall(function()
        return dofile(file_path)
    end)
    
    if success then
        if type(result) == "table" and result.passed and result.total then
            test_results[test_type].passed = test_results[test_type].passed + result.passed
            test_results[test_type].total = test_results[test_type].total + result.total
            if result.passed < result.total then
                table.insert(test_results[test_type].failures, file_path)
            end
            print(string.format("✅ 测试完成: %d/%d 通过", result.passed, result.total))
        elseif result == true then
            test_results[test_type].passed = test_results[test_type].passed + 1
            test_results[test_type].total = test_results[test_type].total + 1
            print("✅ 测试通过")
        else
            test_results[test_type].total = test_results[test_type].total + 1
            table.insert(test_results[test_type].failures, file_path)
            print("❌ 测试失败")
        end
    else
        test_results[test_type].total = test_results[test_type].total + 1
        table.insert(test_results[test_type].failures, file_path)
        print("❌ 测试执行失败: " .. tostring(result))
    end
end

-- 主函数
local function main()
    print("🚀 开始运行所有测试...")
    print("测试时间: " .. os.date("%Y-%m-%d %H:%M:%S"))
    
    -- 1. 运行单元测试
    print("\n" .. string.rep("🔧", 20) .. " 单元测试 " .. string.rep("🔧", 20))
    local unit_tests = {
        "tests/unit/test_config_manager.lua",
        "tests/unit/test_capture_engine.lua",
        "tests/unit/test_error_handler.lua",
        "tests/unit/test_frame_buffer.lua",
        "tests/unit/test_overlay_manager.lua",
        "tests/unit/test_ui_controller.lua",
        "tests/unit/test_video_renderer.lua"
    }
    
    for _, test_file in ipairs(unit_tests) do
        local file = io.open(test_file, "r")
        if file then
            file:close()
            runTestFile(test_file, "unit")
        else
            print("⚠️  跳过不存在的测试文件: " .. test_file)
        end
    end
    
    -- 2. 运行集成测试
    print("\n" .. string.rep("🔗", 20) .. " 集成测试 " .. string.rep("🔗", 20))
    local integration_tests = {
        "tests/integration/test_config_manager_integration.lua"
    }
    
    for _, test_file in ipairs(integration_tests) do
        local file = io.open(test_file, "r")
        if file then
            file:close()
            runTestFile(test_file, "integration")
        else
            print("⚠️  跳过不存在的测试文件: " .. test_file)
        end
    end
    
    -- 3. 运行压力测试 (可选)
    local run_stress_tests = os.getenv("RUN_STRESS_TESTS") == "1"
    if run_stress_tests then
        print("\n" .. string.rep("💪", 20) .. " 压力测试 " .. string.rep("💪", 20))
        local stress_tests = {
            "tests/stress/test_performance_stress.lua"
        }
        
        for _, test_file in ipairs(stress_tests) do
            local file = io.open(test_file, "r")
            if file then
                file:close()
                runTestFile(test_file, "stress")
            else
                print("⚠️  跳过不存在的测试文件: " .. test_file)
            end
        end
    else
        print("\n" .. string.rep("💪", 20) .. " 压力测试 (跳过) " .. string.rep("💪", 20))
        print("提示: 设置环境变量 RUN_STRESS_TESTS=1 来运行压力测试")
    end
    
    -- 4. 运行演示验证
    print("\n" .. string.rep("🎯", 20) .. " 演示验证 " .. string.rep("🎯", 20))
    local demo_tests = {
        "tests/demo/validate_advanced_features.lua"
    }
    
    for _, test_file in ipairs(demo_tests) do
        local file = io.open(test_file, "r")
        if file then
            file:close()
            runTestFile(test_file, "demo")
        else
            print("⚠️  跳过不存在的测试文件: " .. test_file)
        end
    end
    
    -- 输出总结
    print("\n" .. string.rep("📊", 30))
    print("测试结果总结")
    print(string.rep("📊", 30))
    
    local total_passed = 0
    local total_tests = 0
    local has_failures = false
    
    for test_type, results in pairs(test_results) do
        if results.total > 0 then
            local status = results.passed == results.total and "✅" or "❌"
            print(string.format("%s %s测试: %d/%d 通过", 
                  status, 
                  test_type == "unit" and "单元" or 
                  test_type == "integration" and "集成" or 
                  test_type == "stress" and "压力" or "演示",
                  results.passed, results.total))
            
            if #results.failures > 0 then
                has_failures = true
                for _, failure in ipairs(results.failures) do
                    print("  ❌ " .. failure)
                end
            end
            
            total_passed = total_passed + results.passed
            total_tests = total_tests + results.total
        end
    end
    
    print(string.rep("-", 60))
    print(string.format("总计: %d/%d 测试通过 (%.1f%%)", 
          total_passed, total_tests, 
          total_tests > 0 and (total_passed / total_tests * 100) or 0))
    
    if has_failures then
        print("\n❌ 部分测试失败，请检查上述失败的测试文件")
        os.exit(1)
    else
        print("\n🎉 所有测试通过！")
        os.exit(0)
    end
end

-- 运行主函数
main()