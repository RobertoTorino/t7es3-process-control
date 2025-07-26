; YouTube: @game_play267
; Twitch: RR_357000
; X:@relliK_2048
; Discord:
; T7ES3 Process Control
#SingleInstance force
#Persistent
#NoEnv

SetWorkingDir %A_ScriptDir%

; ─── Globals. ─────────────────────────────────────────────────────────────────────────────────────────────────────────
OnExit("SaveSettings")
logInterval := 120000
lastResourceLog := 0


; ─── Global config variables. ─────────────────────────────────────────────────────────────────────────────────────────
global muteSound    := 0
baseDir             := A_ScriptDir
iniFile             := A_Temp . "\t7es3.ini"
logFile             := A_ScriptDir . "\t7es3.log"
fallbackLog         := A_ScriptDir . "\t7es3_fallback.log"
t7es3               := A_ScriptDir  . "\TekkenGame-Win64-Shipping.exe"


; ─── Conditionally set default priority if it's not already set. ──────────────────────────────────────────────────────
IniRead, priorityValue, %iniFile%, PRIORITY, Priority
if (priorityValue = "")
    IniWrite, Normal, %iniFile%, PRIORITY, Priority


; ─── Read T7ES3 path and extract executable name if found. ────────────────────────────────────────────────────────────
IniRead, t7es3Path, %iniFile%, T7ES3, Path
if (t7es3Path != "") {
    global t7es3
    SplitPath, t7es3Path, t7es3
}


; ─── Set as admin. ────────────────────────────────────────────────────────────────────────────────────────────────────
if not A_IsAdmin
{
    try
    {
        Run *RunAs "%A_ScriptFullPath%"
    }
    catch
    {
        MsgBox, 0, Error, This script needs to be run as Administrator.
    }
    ExitApp
}


; ─── Unique window class name. ────────────────────────────────────────────────────────────────────────────────────────
#WinActivateForce
scriptTitle := "T7ES3 Process Priority"
if WinExist("ahk_class AutoHotkey ahk_exe " A_ScriptName) && !A_IsCompiled {
    ;Re-run if script is not compiled
    ExitApp
}

;Try to send a message to existing instance
if A_Args[1] = "activate" {
    PostMessage, 0x5555,,,, ahk_class AutoHotkey
    ExitApp
}

; AutoHotkey portion to embed assets
FileInstall, t7es3_media\T7ES3_GOOD_MORNING.wav, %A_Temp%\T7ES3_GOOD_MORNING.wav
FileInstall, t7es3_media\T7ES3_GAME_OVER.wav, %A_Temp%\T7ES3_GAME_OVER.wav
FileInstall, t7es3pc.ini, %A_Temp%\t7es3pc.ini

; ─── Sound settings at startup. ───────────────────────────────────────────────────────────────────────────────────────
IniRead, muteSound, %iniFile%, MUTE_SOUND, Mute, 0


; ─── Start GUI. ───────────────────────────────────────────────────────────────────────────────────────────────────────
title := "T7ES3 Process Priority - " . Chr(169) . " " . A_YYYY . " - Philip"
Gui, Show, w490 h200, %title%
Gui, +LastFound +AlwaysOnTop
Gui, Font, s10 q5, Segoe UI
Gui, Margin, 15, 15
GuiHwnd := WinExist()

; Priority section.
Gui, Font, s10 q5, Segoe UI
Gui, Add, Text,                          x10 y10, Select Process Priority:
Gui, Add, DropDownList, vPriorityChoice  x10 y30 w150 r6, Idle|Below Normal|Normal|Above Normal|High|Realtime
LoadSettings()
Gui, Add, Text,                         x172 y10, Use Escape button for sound test or to quit T7ES3.
Gui, Add, Button, gToggleMute vMuteBtn  x170 y30 w150 h27 +Center +0x200, % (muteSound ? "UNMUTE" : "MUTE")
Gui, Add, Button, gSetPriority           x10 y60 w150 h75, SET PROCESS PRIORITY
Gui, Add, Button, gRefreshPath          x170 y60 w150 h75, REFRESH GAME PATH
Gui, Add, Button, gSett7es3Path         x330 y60 w150 h75, SET GAME PATH AND/OR START THE GAME FROM HERE


; ─── Custom status bar, 1 is used for T7ES3 status, use 2 and 3. ──────────────────────────────────────────────────────
Gui, Add, GroupBox,                   x0 y146 w490 h33
Gui, Add, Text, vCurrentPriority      x6 y157 w490,

; ─── Bottom statusbar, 1 is reserved for process priority status, use 2. ──────────────────────────────────────────────
Gui, Add, StatusBar, vStatusBar1 hWndhStatusBar
SB_SetParts(490)
UpdateStatusBar(msg, segment := 1) {
    SB_SetText(msg, segment)
}

; ─── Start timers for cpu/memory every x second(s). ───────────────────────────────────────────────────────────────────
SetTimer, UpdateCPUMem, 1000

; ─── Force one immediate priority update. ─────────────────────────────────────────────────────────────────────────────
Gosub, UpdatePriority

; ─── Start priority timer after a delay (3s between updates), runs every 3 seconds. ───────────────────────────────────
SetTimer, UpdatePriority, 3000

; ─── Record timestamp of last update. ─────────────────────────────────────────────────────────────────────────────────
FormatTime, timeStamp, , yyyy-MM-dd HH:mm:ss
Log("DEBUG", "Writing Timestamp " . timeStamp . " to " . iniFile)
IniWrite, %timeStamp%, %iniFile%, LAST_UPDATE, LastUpdated


; ─── System tray. ────────────────────────────────────────────────────────────
Menu, Tray, NoStandard                                  ;Remove default items like "Pause Script"
Menu, Tray, Add, Show GUI, ShowGui                      ;Add a custom "Show GUI" option
Menu, Tray, Add                                         ;Add a separator line
Menu, Tray, Add, About T7ES3PC..., ShowAboutDialog
Menu, Tray, Default, Show GUI                           ;Make "Show GUI" the default double-click action
Menu, Tray, Tip, T7ES3 Process Control                  ;Tooltip when hovering


; ─── This return ends all updates to the gui. ─────────────────────────────────────────────────────────────────────────
return
; ─── END GUI. ─────────────────────────────────────────────────────────────────────────────────────────────────────────


OpenScriptDir:
Run, %A_ScriptDir%
return


; ─── Toggle sound in app. ─────────────────────────────────────────────────────────────────────────────────────────────
ToggleMute:
    muteSound := !muteSound
    IniWrite, %muteSound%, %iniFile%, MUTE_SOUND, Mute
    GuiControl,, MuteBtn, % (muteSound ? "UNMUTE" : "MUTE")
    SoundBeep, 750, 150
return


; ─── Refresh path. ────────────────────────────────────────────────────────────────────────────────────────────────────
Refresht7es3Path()


; ─── Refresh path to pcs3.exe. ────────────────────────────────────────────────────────────────────────────────────────
RefreshPath:
    Refresht7es3Path()
    CustomTrayTip("Path refreshed: " t7es3Path, 1)
    Log("DEBUG", "Path refreshed: " . t7es3Path)
return


; ─── Set path to TekkenGame-Win64-Shipping.exe function. ──────────────────────────────────────────────────────────────────────────────────
Sett7es3Path:
    Global t7es3Path, t7es3
    FileSelectFile, selectedPath,, , Select T7ES3 executable, Executable Files (*.exe)
    if (selectedPath != "" && FileExist(selectedPath)) {
        Savet7es3Path(selectedPath)

        t7es3Path := selectedPath
        SplitPath, t7es3Path, t7es3

        Log("INFO", "Path saved: " . selectedPath)
    } else {
        CustomTrayTip("Path not selected or invalid.", 3)
        Log("ERROR", "No valid T7ES3 executable selected.")
    }
Return


; ─── Get path to TekkenGame-Win64-Shipping.exe function. ──────────────────────────────────────────────────────────────────────────────────
Gett7es3Path() {
    static iniFile := A_ScriptDir . "\t7es3pc.ini"
    local path

    if !FileExist(iniFile) {
        CustomTrayTip("Missing t7es3pc.ini.", 3)
        Log("ERROR", "Missing t7es3pc.ini when calling Gett7es3Path()")
        return ""
    }

    IniRead, path, %iniFile%, T7ES3, Path
    if (ErrorLevel) {
        CustomTrayTip("Could not read [T7ES3] path from t7es3pc.ini.", 3)
        Log("ERROR", "Could not read [T7ES3] path from t7es3pc.ini")
        return ""
    }

    path := Trim(path, "`" " ")  ; trim surrounding quotes and spaces

    Log("DEBUG", "Gett7es3Path, Path is: " . path)

    if (path != "" && FileExist(path) && SubStr(path, -3) = ".exe")
        return path

    CustomTrayTip("Could not read [T7ES3] path from: " . path, 3)
    Log("ERROR", "Invalid or non-existent path in t7es3pc.ini: " . path)
    return ""
}

Savet7es3Path(path) {
    static iniFile := A_ScriptDir . "\t7es3pc.ini"
    IniWrite, %path%, %iniFile%, T7ES3, Path
    Log("DEBUG", "Saved path to config: " . t7es3Path)
    CustomTrayTip("Saved Path to config: " . t7es3Path, 1)
}

t7es3Path := Gett7es3Path()
Log("DEBUG", "Saved path to config: " . t7es3Path)

if (t7es3Path = "") {
    MsgBox, 52, Warning, Path not set or invalid. Please select it now.
    FileSelectFile, selectedPath,, , Select T7ES3 executable, Executable Files (*.exe)
    if (selectedPath != "" && FileExist(selectedPath)) {
        Savet7es3Path(selectedPath)
        t7es3Path := selectedPath
        MsgBox, 64, Info, Saved Path:`n%t7es3Path%
    } else {
        MsgBox, 16, Error, No valid path selected. Exiting.
        ExitApp
    }
} else {
    MsgBox, 64, Info, Using Path:`n%t7es3Path%
}
Return


; ─── T7ES3 path function. ─────────────────────────────────────────────────────────────────────────────────────────────
t7es3Path:
    FileSelectFile, selectedPath,, 3, Select T7ES3 executable, Executable Files (*.exe)
    if (selectedPath != "")
    {
        t7es3Path := selectedPath
        IniWrite, %t7es3Path%, %iniFile%, T7ES3, Path
        Log("INFO", "Path saved: " . selectedPath)
    }
Return


; ─── Set process priority function. ───────────────────────────────────────────────────────────────────────────────────
SetPriority:
    Gui, Submit, NoHide
    if PriorityChoice =  ;empty or not selected
    {
        CustomTrayTip("Please select a priority before setting.", 2)
        return
    }

    priorityCode := ""
    if (PriorityChoice = "Idle")
        priorityCode := "L"
    else if (PriorityChoice = "Below Normal")
        priorityCode := "B"
    else if (PriorityChoice = "Normal")
        priorityCode := "N"
    else if (PriorityChoice = "Above Normal")
        priorityCode := "A"
    else if (PriorityChoice = "High")
        priorityCode := "H"
    else if (PriorityChoice = "Realtime")
        priorityCode := "R"

    Process, Exist, TekkenGame-Win64-Shipping.exe
    if (ErrorLevel) {
        Process, Priority, %ErrorLevel%, %priorityCode%
        CustomTrayTip("Set to: " PriorityChoice, 1)
        Log("INFO", "Set T7ES3 priority to " . PriorityChoice)
        IniWrite, %PriorityChoice%, %iniFile%, PRIORITY, Priority
    } else {
        CustomTrayTip("exe is not running.", 1)
        Log("WARN", "Attempted to set priority, but TekkenGame-Win64-Shipping.exe is not running.")
    }
return


; ─── Update process priority function. ────────────────────────────────────────────────────────────────────────────────
UpdatePriority:
    Process, Exist, TekkenGame-Win64-Shipping.exe
    if (!ErrorLevel) {
        GuiControl,, CurrentPriority, T7ES3 is not running.
        GuiControl, Disable, PriorityChoice
        GuiControl, Disable, Set Priority
        UpdateCPUMem()
        return
    }

    pid := ErrorLevel
    current := GetPriority(pid)

    GuiControl,, CurrentPriority, Priority: %current%

    Global lastPriority
    if (current != lastPriority) {
        GuiControl,, PriorityChoice, %current%
        lastPriority := current
    }

    GuiControl, Enable, PriorityChoice
    GuiControl, Enable, Set Priority
    UpdateCPUMem()
return


; ─── Get currrent process priority function. ──────────────────────────────────────────────────────────────────────────
GetPriority(pid) {
    try {
        wmi := ComObjGet("winmgmts:")
        query := "Select Priority from Win32_Process where ProcessId=" pid
        for proc in wmi.ExecQuery(query)
            return MapPriority(proc.Priority)
        return "Unknown"
    } catch e {
        CustomTrayTip("Failed to get priority.", 3)
        return "Error"
    }
}

MapPriority(val) {
    if (val = 4)
        return "Idle"
    if (val = 6)
        return "Below Normal"
    if (val = 8)
        return "Normal"
    if (val = 10)
        return "Above Normal"
    if (val = 13)
        return "High"
    if (val = 24)
        return "Realtime"
    if (val = 32)
        return "Normal"
    if (val = 64)
        return "Idle"
    if (val = 128)
        return "High"
    if (val = 256)
        return "Realtime"
    if (val = 16384)
        return "Below Normal"
    if (val = 32768)
        return "Above Normal"
    return "Unknown (" val ")"
}


; ─── Load settings function. ──────────────────────────────────────────────────────────────────────────────────────────
LoadSettings() {
    Global PriorityChoice, iniFile, t7es3

    Process, Exist, %t7es3%
    if (!ErrorLevel) {
        defaultPriority := "Normal"
        IniWrite, %defaultPriority%, %iniFile%, PRIORITY, Priority

        ; Extract just the filename for display
        SplitPath, iniFile, iniFileName

        ; Status bar message with clean formatting
        CustomTrayTip("Initial Priority Set to " defaultPriority, 1)

        ; Update GUI
        GuiControl, ChooseString, PriorityChoice, %defaultPriority%
        PriorityChoice := defaultPriority

        Log("INFO", "Set default priority to " defaultPriority " in " iniFile)
    }
    else {
        ; Load saved priority if process exists
        IniRead, savedPriority, %iniFile%, PRIORITY, Priority, Normal
        GuiControl, ChooseString, PriorityChoice, %savedPriority%
        PriorityChoice := savedPriority
    }
}


; ─── Save current settings function. ──────────────────────────────────────────────────────────────────────────────────
SaveSettings() {
    Global PriorityChoice, iniFile

    ; Get current selection from GUI (important!)
    GuiControlGet, currentPriority,, PriorityChoice
    Log("DEBUG", "Attempting to save priority: " currentPriority)

    ; Save to INI
    ; IniWrite, %currentPriority%, %iniFile%, PRIORITY, Priority
    Log("INFO", "TrayTip shown: Priority set to " currentPriority)
}


; ─── Log system usage with time interval function. ────────────────────────────────────────────────────────────────────
LogSystemUsageIfDue(cpuLoad, freeMem, totalMem) {
    Global lastResourceLog, logInterval
    timeNow := A_TickCount
    if (timeNow - lastResourceLog >= logInterval) {
        lastResourceLog := timeNow
        Log("DEBUG", "CPU: " . cpuLoad . "% | Free RAM: " . freeMem . " MB / " . totalMem . " MB")
    }
}


; ─── Update CPU status function. ──────────────────────────────────────────────────────────────────────────────────────
UpdateCPUMem() {
    try {
        ComObjError(false)
        objWMIService := ComObjGet("winmgmts:\\.\root\cimv2")
        colCompSys := objWMIService.ExecQuery("Select * from Win32_OperatingSystem")
        for obj in colCompSys {
            totalMem := Round(obj.TotalVisibleMemorySize / 1024, 1)
            freeMem := Round(obj.FreePhysicalMemory / 1024, 1)
        }

        colProc := objWMIService.ExecQuery("Select * from Win32_Processor")
        for objItem in colProc {
            cpuLoad := objItem.LoadPercentage
        }

        SB_SetText(" CPU: " . cpuLoad . "% | Free RAM: " . freeMem . " MB / " . totalMem . " MB")

        Global lastResourceLog := 0  ; Global variable to track last log time
        Global logInterval := logInterval   ; 5 seconds in milliseconds

        LogSystemUsageIfDue(cpuLoad, freeMem, totalMem)

    } catch e {
        SB_SetText("Error fetching CPU/memory: " . e.Message, 2)
    }
}


; ─── Kill T7ES3 process with escape button function. ──────────────────────────────────────────────────────────────────
Esc::
    wav := A_Temp . "\T7ES3_GAME_OVER.wav"
    if FileExist(wav)
    SoundPlay, %wav%
    else
    MsgBox, WAV not found at: %wav%

    Process, Exist, TekkenGame-Win64-Shipping.exe
    if (ErrorLevel) {
        CustomTrayTip("ESC pressed. Killing T7ES3 processes.", 2)
        Log("WARN", "ESC pressed. Killing all T7ES3 processes.")
        KillAllProcessesEsc()
    } else {
        CustomTrayTip("No T7ES3 processes found.", 1)
        Log("INFO", "Pressed escape key but no T7ES3 processes found.")
    }
return


KillAllProcessesEsc() {
    RunWait, taskkill /im TekkenGame-Win64-Shipping.exe /F,, Hide
    RunWait, taskkill /im powershell.exe /F,, Hide
    ;RunWait, taskkill /im autohotkey.exe /F,, Hide
    Log("INFO", "ESC pressed. Killing all T7ES3 processes.")
}


; ─── T7ES3 refresh path function. ─────────────────────────────────────────────────────────────────────────────────────
Refresht7es3Path() {
    global t7es3Path
    global iniFile

    IniRead, path, %iniFile%, T7ES3, Path
    path := Trim(path, "`" " ")

    if (path = "" || !FileExist(path) || SubStr(path, -3) != ".exe") {
        MsgBox, 48, Path, Invalid path in INI file. Please select TekkenGame-Win64-Shipping.exe manually.

        FileSelectFile, userPath, 3, , Select T7ES3 Executable, Executable (*.exe)
        if (userPath = "") {
            MsgBox, 48, Cancelled, No file selected. Path unchanged.
            return
        }

        userPath := Trim(userPath, "`" " ")
        IniWrite, %userPath%, %iniFile%, T7ES3, Path
        t7es3Path := userPath
        Log("INFO", "User manually selected Path: " . userPath)
        MsgBox, 64, Path Updated, Path successfully updated to:`n%userPath%
        return
    }

    t7es3Path := path
    Log("INFO", "Path refreshed: " . path)
    CustomTrayTip("Path refreshed: " . path, 1)
}


; ─── T7ES3 check if running function. ─────────────────────────────────────────────────────────────────────────────────
GetT7ES3WindowID(ByRef hwnd) {
    WinGet, hwnd, ID, ahk_exe TekkenGame-Win64-Shipping.exe
    if !hwnd {
        MsgBox, TekkenGame-Win64-Shipping.exe is not running.
        return false
    }
    return true
}


; ─── Process exists. ──────────────────────────────────────────────────────────────────────────────────────────────────
ProcessExist(name) {
    Process, Exist, %name%
    return ErrorLevel
}


; ─── Raw ini valuer. ──────────────────────────────────────────────────────────────────────────────────────────────────
GetIniValueRaw(file, section, key) {
    sectionFound := false
    Loop, Read, %file%
    {
        line := A_LoopReadLine
        if (RegExMatch(line, "^\s*\[" . section . "\]\s*$")) {
            sectionFound := true
            continue
        }
        if (sectionFound && RegExMatch(line, "^\s*\[.*\]\s*$")) {
            break
        }
        if (sectionFound && RegExMatch(line, "^\s*" . key . "\s*=\s*(.*)$", m)) {
            return m1
        }
    }
    return ""
}


; ─── Log function. ────────────────────────────────────────────────────────────────────────────────────────────────────
Log(level, msg) {
Global logFile
    static needsRotation := true
    static inLog := false

    if (inLog)
        return

    inLog := true

    if (needsRotation && FileExist( logfile)) {
        FileGetSize, logSize, %logfile%
        if (logSize > 1024000) {  ;>1MB
            FormatTime, timestamp,, yyyyMMdd_HHmmss
            FileMove, %logfile%, %A_ScriptDir%\t7es3_%timestamp%.log
        }
        needsRotation := false
    }

    try {
        FormatTime, timestamp,, yyyy-MM-dd HH:mm:ss
        logEntry := "[" timestamp "] [" level "] " msg "`n"
        FileAppend, %logEntry%, %logfile%
    }
    catch e {
        FormatTime, timestamp,, yyyy-MM-dd HH:mm:ss
        FileAppend, [%timestamp%] [MAIN-LOG-FAILED] %e%`n, %fallbackLog%
        FileAppend, %logEntry%, %fallbackLog%
    }

    inLog := false
}


; ─── rotate logs function. ────────────────────────────────────────────────────────────────────────────────────────────
RotateFfmpegLog(maxLogs = "", maxSize = "") {
    if (maxLogs = "")
        maxLogs := 5
    if (maxSize = "")
        maxSize := 1024 * 1024  ; 1 MB

    logDir := A_ScriptDir
    logFile := logDir . "\t7es3_ffmpeg.log"

    ; Step 1: Rotate if file is too big
    if FileExist(logFile) {
        FileGetSize, logSize, %logFile%
        if (logSize > maxSize) {
            FormatTime, timestamp,, yyyyMMdd_HHmmss
            FileMove, %logFile%, %logDir%\t7es3_ffmpeg_%timestamp%.log
        }
    }

    ; Step 2: Delete old logs if more than maxLogs
    logPattern := logDir . "\t7es3_ffmpeg_*.log"
    logs := []

    Loop, Files, %logPattern%, F
        logs.push(A_LoopFileFullPath)

    if (logs.MaxIndex() > maxLogs) {
        SortLogsByDate(logs)
        Loop, % logs.MaxIndex() - maxLogs
            FileDelete, % logs[A_Index]
    }
}

SortLogsByDate(ByRef arr) {
    Loop, % arr.MaxIndex()
        Loop, % arr.MaxIndex() - A_Index
            if (FileExist(arr[A_Index]) && FileExist(arr[A_Index + 1])) {
                FileGetTime, time1, % arr[A_Index], M
                FileGetTime, time2, % arr[A_Index + 1], M
                if (time1 > time2) {
                    temp := arr[A_Index]
                    arr[A_Index] := arr[A_Index + 1]
                    arr[A_Index + 1] := temp
                }
            }
}


; ─── Custom tray tip function ─────────────────────────────────────────────────────────────────────────────────────────
CustomTrayTip(Text, Icon := 1) {
    ; Parameters:
    ; Text  - Message to display
    ; Icon  - 0=None, 1=Info, 2=Warning, 3=Error (default=1)
    static Title := "T7ES3 Process Control"
    ; Validate icon input (clamp to 0-3 range)
    Icon := (Icon >= 0 && Icon <= 3) ? Icon : 1
    ; 16 = No sound (bitwise OR with icon value)
    TrayTip, %Title%, %Text%, , % Icon|16
}


; ─── Show "about" dialog function. ────────────────────────────────────────────────────────────────────
ShowAboutDialog() {
    ; Extract embedded version.dat resource to temp file
    tempFile := A_Temp "\version.dat"
    hRes := DllCall("FindResource", "Ptr", 0, "VERSION_FILE", "Ptr", 10) ;RT_RCDATA = 10
    if (hRes) {
        hData := DllCall("LoadResource", "Ptr", 0, "Ptr", hRes)
        pData := DllCall("LockResource", "Ptr", hData)
        size := DllCall("SizeofResource", "Ptr", 0, "Ptr", hRes)
        if (pData && size) {
            File := FileOpen(tempFile, "w")
            if IsObject(File) {
                File.RawWrite(pData + 0, size)
                File.Close()
            }
        }
    }
    ; Read version string
    FileRead, verContent, %tempFile%
    version := "Unknown"
    if (verContent != "") {
        version := verContent
    }

aboutText := "T7ES3 Process Control`n"
           . "Realtime Process Priority Management for T7ES3`n"
           . "Version: " . version . "`n"
           . Chr(169) . " " . A_YYYY . " Philip" . "`n"
           . "YouTube: @game_play267" . "`n"
           . "Twitch: RR_357000" . "`n"
           . "X: @relliK_2048" . "`n"
           . "Discord:"

MsgBox, 64, About T7ES3PC, %aboutText%
}

; ─── Show GUI. ────────────────────────────────────────────────────────────────────────────────────────────────────────
ShowGui:
    Gui, Show
return

ExitScript:
    Log("INFO", "Exiting script via tray menu.")
    ExitApp
return

GuiClose:
    ExitApp
return
