; This script shows the initial setup GUI.
; It is not intended for use after installation.
#requires AutoHotkey v2.0

#NoTrayIcon
#SingleInstance Force

#include inc\ui-base.ahk

A_ScriptName := "AutoHotkey 安装程序"
SetRegView 64
InstallGui.Show()

class InstallGui extends AutoHotkeyUxGui {
    __new() {
        super.__new(A_ScriptName, '-MinimizeBox -MaximizeBox')
        
        DllCall('uxtheme\SetWindowThemeAttribute', 'ptr', this.hwnd, 'int', 1 ; WTA_NONCLIENT
            , 'int64*', 3 | (3<<32), 'int', 8) ; WTNCA_NODRAWCAPTION=1, WTNCA_NODRAWICON=2
        
        static TitleBack := 'BackgroundWhite'
        static TitleFore := 'c3F627F'
        static TotalWidth := 350
        this.AddText('x0 y0 w' TotalWidth ' h84 ' TitleBack)
        this.AddPicture('x32 y16 w32 h32 ' TitleBack, A_AhkPath)
        this.SetFont('s12', 'Segoe UI')
        this.AddText('x+20 yp+4 ' TitleFore ' ' TitleBack, "AutoHotkey v" A_AhkVersion)
        this.SetFont('s9')
        
        ; SS_SUNKEN := 0x1000 ; 4096
        this.AddText('x-4 y84 w' TotalWidth+4 ' h188 0x1000 -Background')
        
        this.AddText('xm yp+16', '安装到(&T):')
        dirEdit := this.AddEdit('vInstallDir w' TotalWidth - (2 * this.MarginX) - 88)
        this.AddButton('vBrowseButton w80 x+8 yp-1', '浏览(&B)')
        .OnEvent('Click', 'Browse')
        
        rect := Buffer(16, 0)
        DllCall('GetClientRect', 'ptr', dirEdit.hwnd, 'ptr', rect)
        NumPut('int', 4, 'int', 2, rect)
        ; DllCall('InflateRect', 'ptr', rect, 'int', 0, 'int', )
        EM_SETRECT := 0xB3 ; 179
        SendMessage 0xB3, 0, rect.ptr, dirEdit
        
        this.AddGroupBox('xm y+0 w' TotalWidth - (2 * this.MarginX) ' h44')
        this.AddText('xp+8 yp+16', "安装模式:")
        this.AddRadio('vModeAll x+m yp Checked', "所有用户(&A)")
        .OnEvent('Click', 'ModeChange')
        this.AddRadio('vModeUser x+4', "当前用户(&C)")
        .OnEvent('Click', 'ModeChange')
        this.AddRadio('vModePortable x+4 Disabled', "便携模式")
        .OnEvent('Click', 'ModeChange')
        
        this.AddButton('vInstallButton x' (TotalWidth - 80) // 2 ' w80 y+36 Default', "安装(&I)")
        .OnEvent('Click', 'Install')
        
        this.ModeChange()
        
        this.MarginY := -1
        this.Show('Hide w' TotalWidth)
        this['InstallButton'].Focus()
    }
    
    Browse(*) {
        if ControlGetStyle(this['InstallDir']) & 0x800 { ; ES_READONLY
            rootKey := this['ModeAll'].Value ? 'HKLM' : 'HKCU'
            message := "不建议更改现有安装目录。"
            if InStr(RegRead(rootKey '\Software\AutoHotkey', 'Version', ''), '1.') = 1
                message .= "`n`n此安装包支持让 v1 和 v2 同时关联 .ahk 文件，但前提是它们安装在同一目录。"
            message .= "`n`n现有文件不会被移动。"
            if MsgBox(message,, "OKCancel Icon!") != "OK"
                return
            this['InstallDir'].Opt('-ReadOnly')
        }
        dir := this.FileSelect('D', this['InstallDir'].Value '\', "选择安装目录")
        if dir != '' {
            this['InstallDir'].Value := dir
            this.InstallDirChange()
        }
    }
    
    ModeChange(p*) {
        if !this.CheckAlreadyInstalled(p.Length = 0, true) {
            ; Ensure InstallDir makes sense for the new mode
            installDir := this['InstallDir'].Value
            if this['ModeAll'].Value {
                if installDir = '' || installDir = InstallUtil.DefaultUserDir
                    this['InstallDir'].Value := InstallUtil.DefaultAllDir, this['InstallDir'].Opt('-ReadOnly')
            } else
                if installDir = '' || IsInProgramFiles(installDir)
                    this['InstallDir'].Value := InstallUtil.DefaultUserDir, this['InstallDir'].Opt('-ReadOnly')
        }
        this.UpdateShield()
    }
    
    InstallDirChange(*) {
        this.UpdateShield()
    }
    
    UpdateShield() {
        requireAdmin := this['ModeAll'].Value && !A_IsAdmin
        SendMessage 0x160C, 0, requireAdmin, this['InstallButton'] ; BCM_SETSHIELD
    }
    
    CheckAlreadyInstalled(setMode:=false, setDir:=false) {
        for rootKey in setMode ? ['HKCU', 'HKLM'] : [this['ModeAll'].Value ? 'HKLM' : 'HKCU'] {
            dir := RegRead(rootKey '\Software\AutoHotkey', 'InstallDir', '')
            if dir != '' {
                if setDir {
                    this['InstallDir'].Value := dir
                    this['InstallDir'].Opt('+ReadOnly')
                }
                if setMode
                    this[A_Index = 1 ? 'ModeUser' : 'ModeAll'].Value := true
                return dir
            }
        }
        return ''
    }
    
    Install(*) {
        problem := ''
        requireAdmin := this['ModeAll'].Value
        installDir := this['InstallDir'].Value
        buf := Buffer(260*2)
        n := DllCall('GetFullPathName', 'str', installDir, 'uint', 260, 'ptr', buf, 'ptr', 0)
        if !n || n > 259 {
            MsgBox "请输入有效的安装路径。",, 'Icon!'
            return
        }
        fullPath := StrGet(buf)
        if installDir != fullPath {
            problem .= '路径 "' installDir '" 实际解析为 "' fullPath '".`n`n'
            installDir := fullPath
        }
        dir := this.CheckAlreadyInstalled()
        if dir && dir != installDir
            problem .= '位于 "' dir '" 的现有安装不会被移动，也不会自动合并到新安装中。`n`n'
        if requireAdmin && !IsInProgramFiles(installDir) && dir != installDir
            problem .= '由于安装目录不在 Program Files 下，将无法启用 UI Access。未启用 UI Access 时，非管理员权限脚本无法与管理员权限程序的窗口交互。`n`n'
        if problem && MsgBox(problem,, 'OKCancel Default2 Icon!') = 'Cancel'
            return
        if A_IsCompiled && IsSet(Installation)
            cmd := Format('"{1}" /to "{2}"', A_ScriptFullPath, installDir)
        else
            cmd := Format('"{1}" /script "{2}\install.ahk" /to "{3}"', A_AhkPath, A_ScriptDir, installDir)
        if !requireAdmin
            cmd .= ' /user'
        else if !A_IsAdmin
            cmd := '*RunAs ' cmd
        try
            Run cmd,,, &pid
        catch as e {
            if A_LastError != 1223 ; ERROR_CANCELLED
                MsgBox e.Message "`n`n" e.Extra,, 'IconX'
        } else {
            this['InstallButton'].Enabled := false
            this['InstallButton'].Text := "正在安装..."
            ProcessWaitClose pid
            ExitApp
        }
    }
}

class InstallUtil {
    static DefaultAllDir := (EnvGet('ProgramW6432') || A_ProgramFiles) '\AutoHotkey'
    static DefaultUserDir := EnvGet('LocalAppData') '\Programs\AutoHotkey'
    static DefaultDir := A_IsAdmin ? this.DefaultAllDir : this.DefaultUserDir
}

IsInProgramFiles(path) {
    other := EnvGet(A_PtrSize=8 ? "ProgramFiles(x86)" : "ProgramW6432")
    return InStr(path, A_ProgramFiles "\") = 1
        || other && InStr(path, other "\") = 1
}