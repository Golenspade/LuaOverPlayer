-- FFI Bindings for Windows APIs
-- Provides direct interface to User32 and GDI32 APIs for video capture

local ffi = require("ffi")
local bit = require("bit")

-- Check if we're on Windows
local function isWindows()
    return package.config:sub(1,1) == '\\'
end

-- Define Windows API structures and functions
ffi.cdef[[
    // Basic types
    typedef void* HWND;
    typedef void* HDC;
    typedef void* HBITMAP;
    typedef void* HGDIOBJ;
    typedef unsigned long DWORD;
    typedef int BOOL;
    
    // Rectangle structure
    typedef struct {
        long left;
        long top;
        long right;
        long bottom;
    } RECT;
    
    // Bitmap info structures
    typedef struct {
        DWORD biSize;
        long biWidth;
        long biHeight;
        unsigned short biPlanes;
        unsigned short biBitCount;
        DWORD biCompression;
        DWORD biSizeImage;
        long biXPelsPerMeter;
        long biYPelsPerMeter;
        DWORD biClrUsed;
        DWORD biClrImportant;
    } BITMAPINFOHEADER;
    
    typedef struct {
        BITMAPINFOHEADER bmiHeader;
    } BITMAPINFO;
    
    // Monitor enumeration callback type
    typedef BOOL (*MONITORENUMPROC)(void* hMonitor, HDC hdcMonitor, RECT* lprcMonitor, long dwData);
    
    // Window enumeration callback type
    typedef BOOL (*WNDENUMPROC)(HWND hwnd, long lParam);
    
    // Monitor info structure
    typedef struct {
        DWORD cbSize;
        RECT rcMonitor;
        RECT rcWork;
        DWORD dwFlags;
    } MONITORINFO;
    
    // Cursor and icon structures for cursor capture
    typedef struct {
        BOOL fIcon;
        DWORD xHotspot;
        DWORD yHotspot;
        HBITMAP hbmMask;
        HBITMAP hbmColor;
    } ICONINFO;
    
    typedef struct {
        long x;
        long y;
    } POINT;
    
    // Cursor information structure
    typedef struct {
        DWORD cbSize;
        DWORD flags;
        void* hCursor;
        POINT ptScreenPos;
    } CURSORINFO;
    
    // User32.dll - Window management functions
    HWND FindWindowA(const char* lpClassName, const char* lpWindowName);
    HWND GetDesktopWindow();
    HWND GetForegroundWindow();
    HWND GetActiveWindow();
    HDC GetDC(HWND hWnd);
    HDC GetWindowDC(HWND hWnd);
    int ReleaseDC(HWND hWnd, HDC hDC);
    BOOL GetWindowRect(HWND hWnd, RECT* lpRect);
    BOOL GetClientRect(HWND hWnd, RECT* lpRect);
    BOOL SetWindowPos(HWND hWnd, HWND hWndInsertAfter, int X, int Y, int cx, int cy, unsigned int uFlags);
    BOOL MoveWindow(HWND hWnd, int X, int Y, int nWidth, int nHeight, BOOL bRepaint);
    BOOL IsWindow(HWND hWnd);
    BOOL IsWindowVisible(HWND hWnd);
    BOOL IsIconic(HWND hWnd);
    BOOL IsZoomed(HWND hWnd);
    
    // Extended window style functions for overlay support
    long GetWindowLongA(HWND hWnd, int nIndex);
    long SetWindowLongA(HWND hWnd, int nIndex, long dwNewLong);
    BOOL SetLayeredWindowAttributes(HWND hwnd, DWORD crKey, unsigned char bAlpha, DWORD dwFlags);
    BOOL ShowWindow(HWND hWnd, int nCmdShow);
    int GetSystemMetrics(int nIndex);
    int GetWindowTextA(HWND hWnd, char* lpString, int nMaxCount);
    int GetWindowTextLengthA(HWND hWnd);
    BOOL EnumWindows(WNDENUMPROC lpEnumFunc, long lParam);
    HWND GetParent(HWND hWnd);
    HWND GetWindow(HWND hWnd, unsigned int uCmd);
    DWORD GetWindowThreadProcessId(HWND hWnd, DWORD* lpdwProcessId);
    
    // Cursor functions for cursor capture
    BOOL GetCursorPos(POINT* lpPoint);
    BOOL GetCursorInfo(CURSORINFO* pci);
    void* GetCursor();
    BOOL GetIconInfo(void* hIcon, ICONINFO* piconinfo);
    BOOL DrawIconEx(HDC hdc, int xLeft, int yTop, void* hIcon, int cxWidth, int cyHeight, 
                    unsigned int istepIfAniCur, void* hbrFlickerFreeDraw, unsigned int diFlags);
    
    // DPI awareness functions (Windows 8.1+)
    BOOL SetProcessDPIAware();
    int GetDeviceCaps(HDC hdc, int index);
    
    // Monitor enumeration functions
    BOOL EnumDisplayMonitors(HDC hdc, const RECT* lprcClip, MONITORENUMPROC lpfnEnum, long dwData);
    BOOL GetMonitorInfoA(void* hMonitor, MONITORINFO* lpmi);
    
    // GDI32.dll - Graphics operations
    HDC CreateCompatibleDC(HDC hdc);
    HBITMAP CreateCompatibleBitmap(HDC hdc, int cx, int cy);
    HBITMAP CreateDIBSection(HDC hdc, const BITMAPINFO* lpbmi, unsigned int usage, void** ppvBits, void* hSection, DWORD offset);
    HGDIOBJ SelectObject(HDC hdc, HGDIOBJ h);
    BOOL BitBlt(HDC hdc, int x, int y, int cx, int cy, HDC hdcSrc, int x1, int y1, DWORD rop);
    BOOL DeleteDC(HDC hdc);
    BOOL DeleteObject(HGDIOBJ ho);
    int GetDIBits(HDC hdc, HBITMAP hbm, unsigned int start, unsigned int cLines, void* lpvBits, BITMAPINFO* lpbmi, unsigned int usage);
    
    // Media Foundation types and structures for webcam capture
    typedef struct {
        unsigned long Data1;
        unsigned short Data2;
        unsigned short Data3;
        unsigned char Data4[8];
    } GUID;
    
    typedef void* IMFMediaSource;
    typedef void* IMFSourceReader;
    typedef void* IMFMediaType;
    typedef void* IMFSample;
    typedef void* IMFMediaBuffer;
    typedef void* IMFAttributes;
    typedef void* IMFActivate;
    typedef unsigned long HRESULT;
    typedef long LONG;
    typedef unsigned long ULONG;
    typedef unsigned long long UINT64;
    typedef void* LPVOID;
    
    // Media Foundation sample structure
    typedef struct {
        LONG lSampleFlags;
        UINT64 llSampleTime;
        UINT64 llSampleDuration;
    } MF_SAMPLE_INFO;
    
    // Video format structure
    typedef struct {
        GUID guidFormat;
        UINT64 frameSize;
        UINT64 frameRate;
        UINT64 pixelAspectRatio;
        ULONG interlaceMode;
        ULONG videoLighting;
        ULONG defaultStride;
        ULONG paletteEntries;
    } MFVIDEOFORMAT;
]]

-- Load Windows DLLs (only on Windows)
local user32, gdi32

if isWindows() then
    user32 = ffi.load("user32")
    gdi32 = ffi.load("gdi32")
else
    -- On non-Windows platforms, create mock objects
    user32 = {}
    gdi32 = {}
end

-- Media Foundation function declarations (Windows only)
if isWindows() then
    ffi.cdef[[
        // Media Foundation initialization and cleanup
        HRESULT MFStartup(ULONG Version, ULONG dwFlags);
        HRESULT MFShutdown();
        
        // Device enumeration
        HRESULT MFEnumDeviceSources(IMFAttributes* pAttributes, IMFActivate*** pppSourceActivate, ULONG* pcSourceActivate);
        
        // Source reader creation and management
        HRESULT MFCreateSourceReaderFromMediaSource(IMFMediaSource* pMediaSource, IMFAttributes* pAttributes, IMFSourceReader** ppSourceReader);
        HRESULT MFCreateAttributes(IMFAttributes** ppMFAttributes, UINT32 cInitialSize);
        
        // Sample reading
        HRESULT IMFSourceReader_ReadSample(IMFSourceReader* pReader, ULONG dwStreamIndex, ULONG dwControlFlags, ULONG* pdwActualStreamIndex, ULONG* pdwStreamFlags, UINT64* pllTimestamp, IMFSample** ppSample);
        
        // Media type management
        HRESULT IMFSourceReader_GetCurrentMediaType(IMFSourceReader* pReader, ULONG dwStreamIndex, IMFMediaType** ppMediaType);
        HRESULT IMFSourceReader_SetCurrentMediaType(IMFSourceReader* pReader, ULONG dwStreamIndex, ULONG* pdwReserved, IMFMediaType* pMediaType);
        
        // Sample data access
        HRESULT IMFSample_ConvertToContiguousBuffer(IMFSample* pSample, IMFMediaBuffer** ppBuffer);
        HRESULT IMFMediaBuffer_Lock(IMFMediaBuffer* pBuffer, unsigned char** ppbBuffer, ULONG* pcbMaxLength, ULONG* pcbCurrentLength);
        HRESULT IMFMediaBuffer_Unlock(IMFMediaBuffer* pBuffer);
        
        // COM interface management
        ULONG IUnknown_AddRef(void* pUnk);
        ULONG IUnknown_Release(void* pUnk);
        
        // GUID definitions for Media Foundation
        extern const GUID MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE;
        extern const GUID MF_DEVSOURCE_ATTRIBUTE_SOURCE_TYPE_VIDCAP_GUID;
        extern const GUID MF_DEVSOURCE_ATTRIBUTE_FRIENDLY_NAME;
    ]]
end

-- Try to load Media Foundation DLLs (Windows only)
local mf_available = false
local mfplat, mfreadwrite

local function loadMediaFoundation()
    if not isWindows() then
        return false, "Media Foundation only available on Windows"
    end
    
    local success, mfplat_lib = pcall(ffi.load, "mfplat")
    if not success then
        return false, "Failed to load mfplat.dll"
    end
    
    local success2, mfreadwrite_lib = pcall(ffi.load, "mfreadwrite")
    if not success2 then
        return false, "Failed to load mfreadwrite.dll"
    end
    
    mfplat = mfplat_lib
    mfreadwrite = mfreadwrite_lib
    mf_available = true
    return true
end

-- Initialize Media Foundation on module load (Windows only)
local mf_init_success, mf_init_error
if isWindows() then
    mf_init_success, mf_init_error = loadMediaFoundation()
else
    mf_init_success, mf_init_error = false, "Not running on Windows"
end

local FFIBindings = {}

-- Constants
local SM_CXSCREEN = 0
local SM_CYSCREEN = 1
local SM_CXVIRTUALSCREEN = 78  -- Virtual screen width
local SM_CYVIRTUALSCREEN = 79  -- Virtual screen height
local SM_XVIRTUALSCREEN = 76   -- Virtual screen left
local SM_YVIRTUALSCREEN = 77   -- Virtual screen top
local SRCCOPY = 0x00CC0020
local DIB_RGB_COLORS = 0

-- Cursor constants
local CURSOR_SHOWING = 0x00000001
local DI_NORMAL = 0x0003
local DI_COMPAT = 0x0004
local DI_DEFAULTSIZE = 0x0008
local SWP_NOSIZE = 0x0001
local SWP_NOMOVE = 0x0002
local SWP_NOZORDER = 0x0004
local SWP_NOREDRAW = 0x0008
local SWP_NOACTIVATE = 0x0010
local SWP_FRAMECHANGED = 0x0020
local SWP_SHOWWINDOW = 0x0040
local SWP_HIDEWINDOW = 0x0080

-- Extended window style constants for overlay support
local GWL_EXSTYLE = -20
local WS_EX_LAYERED = 0x00080000
local WS_EX_TOPMOST = 0x00000008
local WS_EX_TOOLWINDOW = 0x00000080
local WS_EX_TRANSPARENT = 0x00000020
local LWA_ALPHA = 0x00000002
local LWA_COLORKEY = 0x00000001
local HWND_TOPMOST = ffi.cast("HWND", -1)
local HWND_NOTOPMOST = ffi.cast("HWND", -2)
local SW_HIDE = 0
local SW_SHOW = 5

-- DPI constants
local LOGPIXELSX = 88  -- Logical pixels/inch in X
local LOGPIXELSY = 90  -- Logical pixels/inch in Y

-- DPI awareness and scaling functions
function FFIBindings.setProcessDPIAware()
    return user32.SetProcessDPIAware() ~= 0
end

function FFIBindings.getDPIScaling()
    local desktopDC = user32.GetDC(nil)
    if desktopDC == nil then
        return 1.0, 1.0  -- Default to no scaling
    end
    
    local dpiX = gdi32.GetDeviceCaps(desktopDC, LOGPIXELSX)
    local dpiY = gdi32.GetDeviceCaps(desktopDC, LOGPIXELSY)
    user32.ReleaseDC(nil, desktopDC)
    
    -- Standard DPI is 96, so scaling factor is current DPI / 96
    local scaleX = dpiX / 96.0
    local scaleY = dpiY / 96.0
    
    return scaleX, scaleY
end

function FFIBindings.convertLogicalToPhysical(x, y, width, height)
    local scaleX, scaleY = FFIBindings.getDPIScaling()
    
    return {
        x = math.floor(x * scaleX + 0.5),
        y = math.floor(y * scaleY + 0.5),
        width = math.floor(width * scaleX + 0.5),
        height = math.floor(height * scaleY + 0.5),
        scaleX = scaleX,
        scaleY = scaleY
    }
end

function FFIBindings.convertPhysicalToLogical(x, y, width, height)
    local scaleX, scaleY = FFIBindings.getDPIScaling()
    
    return {
        x = math.floor(x / scaleX + 0.5),
        y = math.floor(y / scaleY + 0.5),
        width = math.floor(width / scaleX + 0.5),
        height = math.floor(height / scaleY + 0.5),
        scaleX = scaleX,
        scaleY = scaleY
    }
end

-- Get screen dimensions
function FFIBindings.getScreenDimensions()
    if not isWindows() then
        return 1920, 1080  -- Mock dimensions
    end
    
    local width = user32.GetSystemMetrics(SM_CXSCREEN)
    local height = user32.GetSystemMetrics(SM_CYSCREEN)
    return width, height
end

-- Get virtual screen dimensions (multi-monitor support)
function FFIBindings.getVirtualScreenDimensions()
    local width = user32.GetSystemMetrics(SM_CXVIRTUALSCREEN)
    local height = user32.GetSystemMetrics(SM_CYVIRTUALSCREEN)
    local left = user32.GetSystemMetrics(SM_XVIRTUALSCREEN)
    local top = user32.GetSystemMetrics(SM_YVIRTUALSCREEN)
    return {
        width = width,
        height = height,
        left = left,
        top = top,
        right = left + width,
        bottom = top + height
    }
end

-- Get window client area dimensions
function FFIBindings.getClientRect(hwnd)
    if hwnd == nil then
        return nil, "Invalid window handle"
    end
    
    local rect = ffi.new("RECT")
    local success = user32.GetClientRect(hwnd, rect)
    if success == 0 then
        return nil, "Failed to get client rectangle"
    end
    
    return {
        left = rect.left,
        top = rect.top,
        right = rect.right,
        bottom = rect.bottom,
        width = rect.right - rect.left,
        height = rect.bottom - rect.top
    }
end

-- Get window title
function FFIBindings.getWindowTitle(hwnd)
    if hwnd == nil then
        return nil, "Invalid window handle"
    end
    
    local buffer = ffi.new("char[256]")
    local length = user32.GetWindowTextA(hwnd, buffer, 256)
    if length == 0 then
        return ""
    end
    
    return ffi.string(buffer, length)
end

-- Check if window is valid and visible
function FFIBindings.isWindowValid(hwnd)
    if hwnd == nil then
        return false
    end
    
    if not isWindows() then
        return hwnd ~= nil and hwnd > 0  -- Mock validation
    end
    
    return user32.IsWindow(hwnd) ~= 0
end

function FFIBindings.isWindowVisible(hwnd)
    if hwnd == nil then
        return false
    end
    
    if not isWindows() then
        return true  -- Mock: assume visible
    end
    
    return user32.IsWindowVisible(hwnd) ~= 0
end

function FFIBindings.isWindowMinimized(hwnd)
    if hwnd == nil then
        return false
    end
    
    if not isWindows() then
        return false  -- Mock: assume not minimized
    end
    
    return user32.IsIconic(hwnd) ~= 0
end

function FFIBindings.isWindowMaximized(hwnd)
    if hwnd == nil then
        return false
    end
    
    if not isWindows() then
        return false  -- Mock: assume not maximized
    end
    
    return user32.IsZoomed(hwnd) ~= 0
end

-- Get window parent
function FFIBindings.getWindowParent(hwnd)
    if hwnd == nil then
        return nil
    end
    return user32.GetParent(hwnd)
end

-- Get window process ID
function FFIBindings.getWindowProcessId(hwnd)
    if hwnd == nil then
        return nil
    end
    
    local processId = ffi.new("DWORD[1]")
    user32.GetWindowThreadProcessId(hwnd, processId)
    return processId[0]
end

-- Get active/foreground window
function FFIBindings.getForegroundWindow()
    return user32.GetForegroundWindow()
end

function FFIBindings.getActiveWindow()
    return user32.GetActiveWindow()
end

-- Window positioning and sizing
function FFIBindings.moveWindow(hwnd, x, y, width, height, repaint)
    if hwnd == nil then
        return false, "Invalid window handle"
    end
    
    repaint = repaint == nil and true or repaint
    local success = user32.MoveWindow(hwnd, x, y, width, height, repaint and 1 or 0)
    return success ~= 0
end

function FFIBindings.setWindowPos(hwnd, x, y, width, height, flags)
    if hwnd == nil then
        return false, "Invalid window handle"
    end
    
    flags = flags or 0
    local success = user32.SetWindowPos(hwnd, nil, x, y, width, height, flags)
    return success ~= 0
end

-- Find window by name
function FFIBindings.findWindow(windowName)
    local hwnd = user32.FindWindowA(nil, windowName)
    return hwnd
end

-- Get desktop window handle
function FFIBindings.getDesktopWindow()
    return user32.GetDesktopWindow()
end

-- Get window rectangle (with DPI awareness)
function FFIBindings.getWindowRect(hwnd, dpiAware)
    if not isWindows() then
        -- Return mock window rectangle
        local result = {
            left = 100,
            top = 100,
            right = 900,
            bottom = 700,
            width = 800,
            height = 600
        }
        
        if dpiAware then
            result.physical = {
                left = 150,
                top = 150,
                right = 1350,
                bottom = 1050,
                width = 1200,
                height = 900,
                scaleX = 1.5,
                scaleY = 1.5
            }
            result.logical = {
                left = result.left,
                top = result.top,
                width = result.width,
                height = result.height
            }
        end
        
        return result
    end
    
    local rect = ffi.new("RECT")
    local success = user32.GetWindowRect(hwnd, rect)
    if success == 0 then
        return nil, "Failed to get window rectangle"
    end
    
    local result = {
        left = rect.left,
        top = rect.top,
        right = rect.right,
        bottom = rect.bottom,
        width = rect.right - rect.left,
        height = rect.bottom - rect.top
    }
    
    -- If DPI aware, also provide physical coordinates
    if dpiAware then
        local physical = FFIBindings.convertLogicalToPhysical(
            result.left, result.top, result.width, result.height
        )
        result.physical = physical
        result.logical = {
            left = result.left,
            top = result.top,
            width = result.width,
            height = result.height
        }
    end
    
    return result
end

-- Capture screen region
function FFIBindings.captureScreen(x, y, width, height)
    if not isWindows() then
        -- Mock screen capture for non-Windows platforms
        x = x or 0
        y = y or 0
        width = width or FFIBindings.getScreenDimensions()
        height = height or select(2, FFIBindings.getScreenDimensions())
        
        -- Create mock bitmap data (simple gradient pattern)
        local mock_bitmap = {}
        for i = 1, width * height * 4 do  -- RGBA format
            mock_bitmap[i] = math.random(0, 255)
        end
        
        return table.concat(mock_bitmap), width, height
    end
    
    x = x or 0
    y = y or 0
    width = width or FFIBindings.getScreenDimensions()
    height = height or select(2, FFIBindings.getScreenDimensions())
    
    -- Get desktop DC
    local desktopHwnd = user32.GetDesktopWindow()
    local desktopDC = user32.GetDC(desktopHwnd)
    if desktopDC == nil then
        return nil, "Failed to get desktop DC"
    end
    
    -- Create compatible DC and bitmap
    local memDC = gdi32.CreateCompatibleDC(desktopDC)
    if memDC == nil then
        user32.ReleaseDC(desktopHwnd, desktopDC)
        return nil, "Failed to create compatible DC"
    end
    
    local bitmap = gdi32.CreateCompatibleBitmap(desktopDC, width, height)
    if bitmap == nil then
        gdi32.DeleteDC(memDC)
        user32.ReleaseDC(desktopHwnd, desktopDC)
        return nil, "Failed to create compatible bitmap"
    end
    
    -- Select bitmap into memory DC
    local oldBitmap = gdi32.SelectObject(memDC, bitmap)
    
    -- Perform the bit block transfer
    local success = gdi32.BitBlt(memDC, 0, 0, width, height, desktopDC, x, y, SRCCOPY)
    
    -- Cleanup
    gdi32.SelectObject(memDC, oldBitmap)
    gdi32.DeleteDC(memDC)
    user32.ReleaseDC(desktopHwnd, desktopDC)
    
    if success == 0 then
        gdi32.DeleteObject(bitmap)
        return nil, "BitBlt operation failed"
    end
    
    return bitmap
end

-- Capture specific window (with DPI awareness)
function FFIBindings.captureWindow(hwnd, dpiAware)
    if hwnd == nil then
        return nil, "Invalid window handle"
    end
    
    if not isWindows() then
        -- Mock window capture for non-Windows platforms
        local width, height = 800, 600
        local mock_bitmap = {}
        for i = 1, width * height * 4 do  -- RGBA format
            mock_bitmap[i] = math.random(0, 255)
        end
        
        return {
            bitmap = table.concat(mock_bitmap),
            width = width,
            height = height,
            logical = {width = width, height = height},
            physical = {width = width, height = height},
            scaleX = 1.0,
            scaleY = 1.0
        }
    end
    
    -- Get window rectangle with DPI information
    local rect, err = FFIBindings.getWindowRect(hwnd, dpiAware)
    if not rect then
        return nil, err
    end
    
    -- Determine capture dimensions
    local captureWidth, captureHeight
    if dpiAware and rect.physical then
        -- Use physical dimensions for DPI-aware capture
        captureWidth = rect.physical.width
        captureHeight = rect.physical.height
    else
        -- Use logical dimensions
        captureWidth = rect.width
        captureHeight = rect.height
    end
    
    -- Get window DC
    local windowDC = user32.GetWindowDC(hwnd)
    if windowDC == nil then
        return nil, "Failed to get window DC"
    end
    
    -- Create compatible DC and bitmap
    local memDC = gdi32.CreateCompatibleDC(windowDC)
    if memDC == nil then
        user32.ReleaseDC(hwnd, windowDC)
        return nil, "Failed to create compatible DC"
    end
    
    local bitmap = gdi32.CreateCompatibleBitmap(windowDC, captureWidth, captureHeight)
    if bitmap == nil then
        gdi32.DeleteDC(memDC)
        user32.ReleaseDC(hwnd, windowDC)
        return nil, "Failed to create compatible bitmap"
    end
    
    -- Select bitmap and perform capture
    local oldBitmap = gdi32.SelectObject(memDC, bitmap)
    local success = gdi32.BitBlt(memDC, 0, 0, captureWidth, captureHeight, windowDC, 0, 0, SRCCOPY)
    
    -- Cleanup
    gdi32.SelectObject(memDC, oldBitmap)
    gdi32.DeleteDC(memDC)
    user32.ReleaseDC(hwnd, windowDC)
    
    if success == 0 then
        gdi32.DeleteObject(bitmap)
        return nil, "BitBlt operation failed"
    end
    
    -- Return bitmap with DPI information
    local result = {
        bitmap = bitmap,
        width = captureWidth,
        height = captureHeight,
        logical = {
            width = rect.width,
            height = rect.height
        }
    }
    
    if dpiAware and rect.physical then
        result.physical = {
            width = rect.physical.width,
            height = rect.physical.height
        }
        result.scaleX = rect.physical.scaleX
        result.scaleY = rect.physical.scaleY
    end
    
    return result
end

-- Backward compatible window capture (returns old format)
function FFIBindings.captureWindowLegacy(hwnd)
    local result = FFIBindings.captureWindow(hwnd, false)
    if type(result) == "table" and result.bitmap then
        return result.bitmap, result.width, result.height
    else
        return result  -- Error case
    end
end

-- Convert bitmap to raw pixel data
function FFIBindings.bitmapToPixelData(bitmap, width, height)
    if bitmap == nil then
        return nil, "Invalid bitmap handle"
    end
    
    if not isWindows() then
        -- For non-Windows platforms, bitmap is already pixel data string
        if type(bitmap) == "string" then
            return bitmap
        else
            -- Create mock pixel data
            local mock_data = {}
            for i = 1, width * height * 4 do
                mock_data[i] = string.char(math.random(0, 255))
            end
            return table.concat(mock_data)
        end
    end
    
    -- Create a temporary DC
    local tempDC = gdi32.CreateCompatibleDC(nil)
    if tempDC == nil then
        return nil, "Failed to create temporary DC"
    end
    
    -- Setup bitmap info for 32-bit RGBA
    local bitmapInfo = ffi.new("BITMAPINFO")
    bitmapInfo.bmiHeader.biSize = ffi.sizeof("BITMAPINFOHEADER")
    bitmapInfo.bmiHeader.biWidth = width
    bitmapInfo.bmiHeader.biHeight = -height  -- Negative for top-down bitmap
    bitmapInfo.bmiHeader.biPlanes = 1
    bitmapInfo.bmiHeader.biBitCount = 32
    bitmapInfo.bmiHeader.biCompression = 0  -- BI_RGB
    bitmapInfo.bmiHeader.biSizeImage = 0
    
    -- Allocate buffer for pixel data
    local dataSize = width * height * 4  -- 4 bytes per pixel (RGBA)
    local pixelData = ffi.new("uint8_t[?]", dataSize)
    
    -- Get bitmap bits
    local result = gdi32.GetDIBits(tempDC, bitmap, 0, height, pixelData, bitmapInfo, DIB_RGB_COLORS)
    
    gdi32.DeleteDC(tempDC)
    
    if result == 0 then
        return nil, "Failed to get bitmap bits"
    end
    
    return ffi.string(pixelData, dataSize)
end

-- Monitor enumeration support
local monitors = {}

-- Window enumeration support
local enumWindows = {}

-- Callback function for window enumeration
local function windowEnumCallback(hwnd, lParam)
    -- Skip invalid windows
    if not FFIBindings.isWindowValid(hwnd) then
        return 1  -- Continue enumeration
    end
    
    -- Get window title
    local title = FFIBindings.getWindowTitle(hwnd)
    
    -- Skip windows without titles (unless we want all windows)
    local includeAll = (lParam == 1)
    if not includeAll and (not title or title == "") then
        return 1  -- Continue enumeration
    end
    
    -- Skip child windows (get only top-level windows)
    local parent = FFIBindings.getWindowParent(hwnd)
    if parent ~= nil then
        return 1  -- Continue enumeration
    end
    
    local windowInfo = {
        handle = hwnd,
        title = title,
        visible = FFIBindings.isWindowVisible(hwnd),
        minimized = FFIBindings.isWindowMinimized(hwnd),
        maximized = FFIBindings.isWindowMaximized(hwnd),
        processId = FFIBindings.getWindowProcessId(hwnd)
    }
    
    -- Get window rectangle if visible
    if windowInfo.visible then
        local rect = FFIBindings.getWindowRect(hwnd)
        if rect then
            windowInfo.rect = rect
        end
    end
    
    table.insert(enumWindows, windowInfo)
    return 1  -- Continue enumeration
end

-- Callback function for monitor enumeration
local function monitorEnumCallback(hMonitor, hdcMonitor, lprcMonitor, dwData)
    local monitorInfo = ffi.new("MONITORINFO")
    monitorInfo.cbSize = ffi.sizeof("MONITORINFO")
    
    if user32.GetMonitorInfoA(hMonitor, monitorInfo) ~= 0 then
        local monitor = {
            handle = hMonitor,
            left = monitorInfo.rcMonitor.left,
            top = monitorInfo.rcMonitor.top,
            right = monitorInfo.rcMonitor.right,
            bottom = monitorInfo.rcMonitor.bottom,
            width = monitorInfo.rcMonitor.right - monitorInfo.rcMonitor.left,
            height = monitorInfo.rcMonitor.bottom - monitorInfo.rcMonitor.top,
            workLeft = monitorInfo.rcWork.left,
            workTop = monitorInfo.rcWork.top,
            workRight = monitorInfo.rcWork.right,
            workBottom = monitorInfo.rcWork.bottom,
            workWidth = monitorInfo.rcWork.right - monitorInfo.rcWork.left,
            workHeight = monitorInfo.rcWork.bottom - monitorInfo.rcWork.top,
            isPrimary = (monitorInfo.dwFlags == 1)
        }
        table.insert(monitors, monitor)
    end
    return 1  -- Continue enumeration
end

-- Get all available monitors
function FFIBindings.enumerateMonitors()
    if not isWindows() then
        -- Return mock monitor data on non-Windows platforms
        return {
            {
                handle = 1,
                left = 0,
                top = 0,
                right = 1920,
                bottom = 1080,
                width = 1920,
                height = 1080,
                workLeft = 0,
                workTop = 0,
                workRight = 1920,
                workBottom = 1040,
                workWidth = 1920,
                workHeight = 1040,
                isPrimary = true
            }
        }
    end
    
    monitors = {}  -- Clear previous results
    
    -- Create callback function pointer
    local callback = ffi.cast("MONITORENUMPROC", monitorEnumCallback)
    
    -- Enumerate all monitors
    local success = user32.EnumDisplayMonitors(nil, nil, callback, 0)
    
    -- Clean up callback
    callback:free()
    
    if success == 0 then
        return nil, "Failed to enumerate monitors"
    end
    
    return monitors
end

-- Get primary monitor info
function FFIBindings.getPrimaryMonitor()
    local allMonitors = FFIBindings.enumerateMonitors()
    if not allMonitors then
        return nil, "Failed to enumerate monitors"
    end
    
    for _, monitor in ipairs(allMonitors) do
        if monitor.isPrimary then
            return monitor
        end
    end
    
    -- Fallback to first monitor if no primary found
    return allMonitors[1]
end

-- Capture screen region with monitor support
function FFIBindings.captureScreenRegion(x, y, width, height, monitorIndex)
    x = x or 0
    y = y or 0
    
    -- If no dimensions specified, use primary monitor or specified monitor
    if not width or not height then
        local monitor
        if monitorIndex then
            local monitors = FFIBindings.enumerateMonitors()
            if monitors and monitors[monitorIndex] then
                monitor = monitors[monitorIndex]
            end
        end
        
        if not monitor then
            monitor = FFIBindings.getPrimaryMonitor()
        end
        
        if monitor then
            x = x + monitor.left
            y = y + monitor.top
            width = width or monitor.width
            height = height or monitor.height
        else
            -- Fallback to system metrics
            width = width or user32.GetSystemMetrics(SM_CXSCREEN)
            height = height or select(2, FFIBindings.getScreenDimensions())
        end
    end
    
    return FFIBindings.captureScreen(x, y, width, height)
end

-- Capture entire virtual screen (all monitors)
function FFIBindings.captureVirtualScreen()
    local virtualScreen = FFIBindings.getVirtualScreenDimensions()
    return FFIBindings.captureScreen(
        virtualScreen.left,
        virtualScreen.top,
        virtualScreen.width,
        virtualScreen.height
    )
end

-- Capture specific monitor
function FFIBindings.captureMonitor(monitorIndex)
    local monitors = FFIBindings.enumerateMonitors()
    if not monitors or not monitors[monitorIndex] then
        return nil, "Invalid monitor index"
    end
    
    local monitor = monitors[monitorIndex]
    return FFIBindings.captureScreen(
        monitor.left,
        monitor.top,
        monitor.width,
        monitor.height
    )
end

-- Window enumeration functions
function FFIBindings.enumerateWindows(includeAll)
    if not isWindows() then
        -- Return mock window data on non-Windows platforms
        return {
            {
                handle = 1,
                title = "Mock Window 1",
                visible = true,
                minimized = false,
                maximized = false,
                processId = 1234,
                rect = {left = 100, top = 100, right = 900, bottom = 700, width = 800, height = 600}
            },
            {
                handle = 2,
                title = "Mock Window 2",
                visible = true,
                minimized = false,
                maximized = false,
                processId = 5678,
                rect = {left = 200, top = 200, right = 1000, bottom = 800, width = 800, height = 600}
            }
        }
    end
    
    enumWindows = {}  -- Clear previous results
    
    -- Create callback function pointer
    local callback = ffi.cast("WNDENUMPROC", windowEnumCallback)
    
    -- Enumerate all windows (lParam: 0 = titled windows only, 1 = all windows)
    local lParam = includeAll and 1 or 0
    local success = user32.EnumWindows(callback, lParam)
    
    -- Clean up callback
    callback:free()
    
    if success == 0 then
        return nil, "Failed to enumerate windows"
    end
    
    return enumWindows
end

-- Find windows by title pattern
function FFIBindings.findWindowsByTitle(pattern)
    local windows = FFIBindings.enumerateWindows(false)
    if not windows then
        return nil, "Failed to enumerate windows"
    end
    
    local matches = {}
    for _, window in ipairs(windows) do
        if window.title and string.find(window.title:lower(), pattern:lower()) then
            table.insert(matches, window)
        end
    end
    
    return matches
end

-- Get window by exact title
function FFIBindings.getWindowByTitle(title)
    local hwnd = user32.FindWindowA(nil, title)
    if hwnd == nil then
        return nil
    end
    
    return {
        handle = hwnd,
        title = title,
        visible = FFIBindings.isWindowVisible(hwnd),
        minimized = FFIBindings.isWindowMinimized(hwnd),
        maximized = FFIBindings.isWindowMaximized(hwnd),
        processId = FFIBindings.getWindowProcessId(hwnd),
        rect = FFIBindings.getWindowRect(hwnd)
    }
end

-- Cursor Capture Functions

-- Get current cursor position
function FFIBindings.getCursorPosition()
    if not isWindows() then
        -- Return mock cursor position on non-Windows platforms
        return {x = 100, y = 100}
    end
    
    local point = ffi.new("POINT")
    local success = user32.GetCursorPos(point)
    
    if success == 0 then
        return nil, "Failed to get cursor position"
    end
    
    return {
        x = point.x,
        y = point.y
    }
end

-- Get current cursor information including visibility and handle
function FFIBindings.getCursorInfo()
    if not isWindows() then
        -- Return mock cursor info on non-Windows platforms
        return {
            visible = true,
            position = {x = 100, y = 100},
            handle = 1
        }
    end
    
    local cursorInfo = ffi.new("CURSORINFO")
    cursorInfo.cbSize = ffi.sizeof("CURSORINFO")
    
    local success = user32.GetCursorInfo(cursorInfo)
    if success == 0 then
        return nil, "Failed to get cursor info"
    end
    
    return {
        visible = bit.band(cursorInfo.flags, CURSOR_SHOWING) ~= 0,
        position = {
            x = cursorInfo.ptScreenPos.x,
            y = cursorInfo.ptScreenPos.y
        },
        handle = cursorInfo.hCursor
    }
end

-- Get current cursor handle
function FFIBindings.getCurrentCursor()
    if not isWindows() then
        return 1  -- Mock cursor handle
    end
    
    return user32.GetCursor()
end

-- Get cursor icon information
function FFIBindings.getCursorIconInfo(hCursor)
    if not isWindows() then
        -- Return mock icon info on non-Windows platforms
        return {
            isIcon = false,
            hotspot = {x = 0, y = 0},
            maskBitmap = nil,
            colorBitmap = nil
        }
    end
    
    if hCursor == nil then
        return nil, "Invalid cursor handle"
    end
    
    local iconInfo = ffi.new("ICONINFO")
    local success = user32.GetIconInfo(hCursor, iconInfo)
    
    if success == 0 then
        return nil, "Failed to get icon info"
    end
    
    return {
        isIcon = iconInfo.fIcon ~= 0,
        hotspot = {
            x = iconInfo.xHotspot,
            y = iconInfo.yHotspot
        },
        maskBitmap = iconInfo.hbmMask,
        colorBitmap = iconInfo.hbmColor
    }
end

-- Draw cursor on device context
function FFIBindings.drawCursor(hdc, x, y, hCursor, width, height)
    if not isWindows() then
        return true  -- Mock success on non-Windows platforms
    end
    
    if hdc == nil or hCursor == nil then
        return false, "Invalid parameters"
    end
    
    width = width or 0  -- 0 means use default size
    height = height or 0
    
    local success = user32.DrawIconEx(hdc, x, y, hCursor, width, height, 0, nil, DI_NORMAL)
    return success ~= 0
end

-- Capture screen with cursor overlay
function FFIBindings.captureScreenWithCursor(x, y, width, height)
    x = x or 0
    y = y or 0
    width = width or FFIBindings.getScreenDimensions()
    height = height or select(2, FFIBindings.getScreenDimensions())
    
    -- First capture the screen normally
    local bitmap = FFIBindings.captureScreen(x, y, width, height)
    if not bitmap then
        return nil, "Failed to capture screen"
    end
    
    -- Get cursor information
    local cursorInfo = FFIBindings.getCursorInfo()
    if not cursorInfo or not cursorInfo.visible then
        return bitmap  -- Return without cursor if not visible
    end
    
    -- Check if cursor is within capture area
    local cursor_x = cursorInfo.position.x - x
    local cursor_y = cursorInfo.position.y - y
    
    if cursor_x < 0 or cursor_x >= width or cursor_y < 0 or cursor_y >= height then
        return bitmap  -- Cursor outside capture area
    end
    
    -- Create a device context for the bitmap to draw cursor on it
    local memDC = gdi32.CreateCompatibleDC(nil)
    if memDC == nil then
        return bitmap  -- Return original bitmap if can't create DC
    end
    
    local oldBitmap = gdi32.SelectObject(memDC, bitmap)
    
    -- Draw cursor on the bitmap
    if cursorInfo.handle then
        FFIBindings.drawCursor(memDC, cursor_x, cursor_y, cursorInfo.handle)
    end
    
    -- Cleanup
    gdi32.SelectObject(memDC, oldBitmap)
    gdi32.DeleteDC(memDC)
    
    return bitmap
end

-- Capture window with cursor overlay
function FFIBindings.captureWindowWithCursor(hwnd, dpiAware)
    -- First capture the window normally
    local result = FFIBindings.captureWindow(hwnd, dpiAware)
    if not result or type(result) == "string" then
        return result  -- Return error
    end
    
    -- Get window rectangle to determine cursor position relative to window
    local windowRect = FFIBindings.getWindowRect(hwnd, dpiAware)
    if not windowRect then
        return result  -- Return without cursor if can't get window rect
    end
    
    -- Get cursor information
    local cursorInfo = FFIBindings.getCursorInfo()
    if not cursorInfo or not cursorInfo.visible then
        return result  -- Return without cursor if not visible
    end
    
    -- Calculate cursor position relative to window
    local cursor_x = cursorInfo.position.x - windowRect.left
    local cursor_y = cursorInfo.position.y - windowRect.top
    
    -- Check if cursor is within window bounds
    if cursor_x < 0 or cursor_x >= windowRect.width or 
       cursor_y < 0 or cursor_y >= windowRect.height then
        return result  -- Cursor outside window
    end
    
    -- Create a device context for the bitmap to draw cursor on it
    local memDC = gdi32.CreateCompatibleDC(nil)
    if memDC == nil then
        return result  -- Return original result if can't create DC
    end
    
    local bitmap = result.bitmap or result
    local oldBitmap = gdi32.SelectObject(memDC, bitmap)
    
    -- Draw cursor on the bitmap
    if cursorInfo.handle then
        FFIBindings.drawCursor(memDC, cursor_x, cursor_y, cursorInfo.handle)
    end
    
    -- Cleanup
    gdi32.SelectObject(memDC, oldBitmap)
    gdi32.DeleteDC(memDC)
    
    return result
end

-- Delete bitmap resource
function FFIBindings.deleteBitmap(bitmap)
    if bitmap and isWindows() then
        gdi32.DeleteObject(bitmap)
    end
end

-- Cleanup bitmap resource
function FFIBindings.deleteBitmap(bitmap)
    if bitmap and isWindows() and gdi32 then
        gdi32.DeleteObject(bitmap)
    end
    -- On non-Windows platforms, bitmap is just a string, no cleanup needed
end

-- Media Foundation helper functions
function FFIBindings.isMediaFoundationAvailable()
    return mf_available
end

function FFIBindings.getMediaFoundationError()
    return mf_init_error
end

-- Overlay and transparency support functions

-- Set window to always on top
function FFIBindings.setWindowAlwaysOnTop(hwnd, enabled)
    if not isWindows() then
        return true  -- Mock success on non-Windows
    end
    
    if hwnd == nil then
        return false, "Invalid window handle"
    end
    
    local insertAfter = enabled and HWND_TOPMOST or HWND_NOTOPMOST
    local success = user32.SetWindowPos(hwnd, insertAfter, 0, 0, 0, 0, 
                                       SWP_NOMOVE + SWP_NOSIZE + SWP_NOACTIVATE)
    return success ~= 0
end

-- Set window transparency
function FFIBindings.setWindowTransparency(hwnd, alpha)
    if not isWindows() then
        return true  -- Mock success on non-Windows
    end
    
    if hwnd == nil then
        return false, "Invalid window handle"
    end
    
    -- Clamp alpha to valid range (0-255)
    alpha = math.max(0, math.min(255, math.floor(alpha)))
    
    -- Get current extended window style
    local exStyle = user32.GetWindowLongA(hwnd, GWL_EXSTYLE)
    
    -- Add layered window style if not present
    if bit.band(exStyle, WS_EX_LAYERED) == 0 then
        exStyle = bit.bor(exStyle, WS_EX_LAYERED)
        user32.SetWindowLongA(hwnd, GWL_EXSTYLE, exStyle)
    end
    
    -- Set the transparency
    local success = user32.SetLayeredWindowAttributes(hwnd, 0, alpha, LWA_ALPHA)
    return success ~= 0
end

-- Set window borderless
function FFIBindings.setWindowBorderless(hwnd, borderless)
    if not isWindows() then
        return true  -- Mock success on non-Windows
    end
    
    if hwnd == nil then
        return false, "Invalid window handle"
    end
    
    -- This would typically require changing window styles
    -- For LÖVE 2D, this is better handled through love.window.setMode
    -- But we can provide the API for completeness
    return true
end

-- Set window click-through (transparent to mouse input)
function FFIBindings.setWindowClickThrough(hwnd, enabled)
    if not isWindows() then
        return true  -- Mock success on non-Windows
    end
    
    if hwnd == nil then
        return false, "Invalid window handle"
    end
    
    local exStyle = user32.GetWindowLongA(hwnd, GWL_EXSTYLE)
    
    if enabled then
        exStyle = bit.bor(exStyle, WS_EX_TRANSPARENT)
    else
        exStyle = bit.band(exStyle, bit.bnot(WS_EX_TRANSPARENT))
    end
    
    local success = user32.SetWindowLongA(hwnd, GWL_EXSTYLE, exStyle)
    return success ~= 0
end

-- Hide window from taskbar
function FFIBindings.setWindowTaskbarVisible(hwnd, visible)
    if not isWindows() then
        return true  -- Mock success on non-Windows
    end
    
    if hwnd == nil then
        return false, "Invalid window handle"
    end
    
    local exStyle = user32.GetWindowLongA(hwnd, GWL_EXSTYLE)
    
    if not visible then
        exStyle = bit.bor(exStyle, WS_EX_TOOLWINDOW)
    else
        exStyle = bit.band(exStyle, bit.bnot(WS_EX_TOOLWINDOW))
    end
    
    local success = user32.SetWindowLongA(hwnd, GWL_EXSTYLE, exStyle)
    return success ~= 0
end

-- Get current window extended styles
function FFIBindings.getWindowExtendedStyle(hwnd)
    if not isWindows() then
        return 0  -- Mock value on non-Windows
    end
    
    if hwnd == nil then
        return 0
    end
    
    return user32.GetWindowLongA(hwnd, GWL_EXSTYLE)
end

-- Check if window has specific extended style
function FFIBindings.hasWindowExtendedStyle(hwnd, style)
    local exStyle = FFIBindings.getWindowExtendedStyle(hwnd)
    return bit.band(exStyle, style) ~= 0
end

-- Get LÖVE window handle (platform-specific)
function FFIBindings.getLoveWindowHandle()
    if not isWindows() then
        return nil  -- Not available on non-Windows
    end
    
    -- Try to get LÖVE window by title
    local title = love.window.getTitle()
    if title then
        return FFIBindings.findWindow(title)
    end
    
    return nil
end

-- Initialize Media Foundation
function FFIBindings.initializeMediaFoundation()
    if not isWindows() then
        return false, "Media Foundation only available on Windows"
    end
    
    if not mf_available then
        return false, mf_init_error or "Media Foundation not available"
    end
    
    -- MF_VERSION is typically 0x20070 for Windows 7+
    local MF_VERSION = 0x20070
    local MFSTARTUP_NOSOCKET = 0x1
    
    local hr = mfplat.MFStartup(MF_VERSION, MFSTARTUP_NOSOCKET)
    if hr ~= 0 then
        return false, "MFStartup failed with HRESULT: " .. string.format("0x%08X", hr)
    end
    
    return true
end

-- Shutdown Media Foundation
function FFIBindings.shutdownMediaFoundation()
    if not isWindows() or not mf_available then
        return
    end
    
    mfplat.MFShutdown()
end

-- Enumerate video capture devices
function FFIBindings.enumerateVideoDevices()
    if not isWindows() then
        return nil, "Video device enumeration only available on Windows"
    end
    
    if not mf_available then
        return nil, "Media Foundation not available"
    end
    
    -- This is a simplified implementation
    -- In a full implementation, we would need to:
    -- 1. Create attributes for device enumeration
    -- 2. Set the source type to video capture
    -- 3. Enumerate devices
    -- 4. Extract device information
    
    -- For now, return a placeholder indicating the function exists
    return {
        {
            name = "Default Camera",
            index = 0,
            available = true
        }
    }, nil
end

return FFIBindings
