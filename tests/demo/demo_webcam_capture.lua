#!/usr/bin/env luajit

-- Demo script for Webcam Capture functionality
-- This script demonstrates the webcam capture capabilities

--- Add src directory to package path
local function addToPath(path)
    package.path = package.path .. ";" .. path .. "/?.lua"
end

addToPath("src")
addToPath("tests")

-- Load required modules
local WebcamCapture = require("src.webcam_capture")
local CaptureEngine = require("src.capture_engine")

-- Function to print section headers
local function printHeader(title)
    print("\n" .. string.rep("=", 60))
    print("  " .. title)
    print(string.rep("=", 60))
end

-- Function to print subsection headers
local function printSubHeader(title)
    print("\n" .. string.rep("-", 40))
    print("  " .. title)
    print(string.rep("-", 40))
end

-- Function to check webcam availability
local function checkWebcamAvailability()
    printHeader("WEBCAM AVAILABILITY CHECK")
    
    local webcam = WebcamCapture:new()
    local available = webcam:isAvailable()
    
    print("Webcam Support Available: " .. (available and "YES" or "NO"))
    
    if not available then
        print("Reason: Media Foundation not available (Windows only)")
        print("This demo will show the API structure with mock data.")
        print()
    end
    
    return available, webcam
end

-- Function to demonstrate webcam capture
local function demonstrateWebcamCapture()
    print("=== Webcam Capture Demo ===")
    print()
    
    local webcam = WebcamCapture:new()
    local available = webcam:isAvailable()
    
    print("Webcam available:", available)
    
    if not available then
        print("Reason: Media Foundation not available (Windows only)")
        print("This demo will show the API structure with mock data.")
        print()
    end