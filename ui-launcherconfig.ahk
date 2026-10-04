; This script shows a GUI for configuring the launcher.
#requires AutoHotkey v2.0

#NoTrayIcon

#include inc\launcher-common.ahk
#include inc\ui-base.ahk

GetVersions() {
    vmap := Map(1, Map(), 2, Map())
    vmap.UIA := false ; Just detect whether any are present for now, to cover the most common cases (UIA supported by all or none).
    for ,f in GetUsableAutoHotkeyExes() {
        try {
            vmap[GetMajor(f.Version)][f.Version] := true
            if SubStr(f.Path, -8) = "_UIA.exe"
                vmap.UIA := true
        }
        catch as e
            trace "-[Launcher] " type(e) " checking file " A_LoopFileName ": " e.message
    }
    vmap[1] := [vmap[1]*]
    vmap[2] := [vmap[2]*]
    return vmap
}

class LauncherConfigGui extends AutoHotkeyUxGui {
    __new() {
        super.__new("AutoHotkey 启动设置")
        
        cmd := RegRead('HKCR\AutoHotkeyScript\shell\open\command',, '')
        usingLauncher := InStr(cmd, 'UX\launcher.ahk') != 0
        currentExe := !usingLauncher && RegExMatch(cmd, '^"(.*?)"(?= )', &m) ? m.1 : ""
        try
            if currentExe && GetExeInfo(currentExe).Description = "AutoHotkey Launcher" ; Support compiled launcher
                usingLauncher := true, currentExe := ""
        if InStr(currentExe, '\AutoHotkeyUX.exe')
            currentExe := "" ; Don't default to AutoHotkeyUX.exe when disabling launcher
        
        versions := GetVersions()
        
        ; this.AddCheckbox("Checked", "Enable drag && drop on .ahk files")
        
        this.AddRadio('vUseLauncher Checked' usingLauncher, "启动脚本时自动检测版本")
        .OnEvent('Click', 'ChangedMode')
        this.AddRadio('vUseSpecific Checked' (!usingLauncher), "始终使用指定解释器运行脚本")
        .OnEvent('Click', 'ChangedMode')
        
        tab := this.AddTab('w0 h0 y+0 vTab -TabStop', ["自动启动器", "指定解释器"])
        
        tab.UseTab(1)
        this.AddText('xm yp+12 Section', "按主版本选择首选解释器")
        this.AddDDL('vVersion1 y+3 w110 Choose1', ["最新 1.x", versions[1]*])
        .OnEvent('Change', "ChangedVersion")
        this.AddComboBox('vBuild1 yp w150', ["Unicode 64-bit", "Unicode 32-bit", "ANSI 32-bit"])
        .OnEvent('Change', 'ChangedBuild')
        this.AddCheckBox('vUIA1 x+m yp+2 Disabled' (!versions.UIA), "UI Access（UI 访问）")
        .OnEvent('Click', 'ChangedUIA')
        this.AddDDL('vVersion2 xs w110 Choose1', ["最新 2.x", versions[2]*])
        .OnEvent('Change', 'ChangedVersion')
        this.AddComboBox('vBuild2 yp w150', ["64-bit", "32-bit"])
        .OnEvent('Change', 'ChangedBuild')
        this.AddCheckBox('vUIA2 x+m yp+2 Disabled' (!versions.UIA), "UI Access（UI 访问）")
        .OnEvent('Click', 'ChangedUIA')
        this.AddText('xs y+m+8', "自动检测失败时")
        this.AddDDL('vFallback y+3 w110 Choose3', ["使用 v1.x", "使用 v2.x", "询问用户"])
        .OnEvent('Change', "ChangedFallback")
        this.AddCheckbox('vIdentify xs y+m+8 Checked', "尝试根据语法识别版本")
        .OnEvent('Click', (c, *) => ConfigWrite(c.Value, 'Launcher', 'Identify'))
        this.AddCheckbox('vLauncherUTF8 xs Checked', "即使是 v1 脚本也默认使用 UTF-8")
        .OnEvent('Click', (c, *) => ConfigWrite(c.Value, 'Launcher\v1', 'UTF8'))
        
        tab.UseTab(2)
        exeBox := this.AddEdit('vExePath xs ys w326 ReadOnly')
        if currentExe
            exeBox.Text := currentExe
        else if FileExist(f := ROOT_DIR '\v2\AutoHotkey' (A_Is64bitOS ? '64' : '32') '.exe')
            exeBox.Text := f
        
        static BrowseIcon := LoadPicture("imageres.dll", 'Icon-1025 w' SysGet(49), &imgtype)
        this.AddIconButton('vBrowse x+0 yp-1 w28 hp+2', BrowseIcon, "浏览(&B)")
        .OnEvent('Click', 'BrowseForExe')
        
        this.AddCheckBox('vCustomUTF8 xm y+m+4 Hidden', "默认使用 UTF-8")
        .OnEvent('Click', 'UpdateVerbs')
        
        tab.UseTab()
        this.AddButton('vClose x292 w70 Default', "关闭(&C)")
        .OnEvent('Click', (ctrl, *) => ctrl.Gui.Hide())
        
        ; size := 32 * A_ScreenDPI // 96
        ; DllCall("comctl32\LoadIconWithScaleDown", "ptr", 0, "int", 32514, "int", size, "int", size, "ptr*", &icon:=0, "hresult")
        ; help := this.AddButton('0x40 x322 ym w' 40 ' h' 40)
        ; SendMessage(0xF7, 1, icon, help)
        
        tab.Choose(usingLauncher ? 1 : 2)
        
        Loop 2 {
            section := 'Launcher\v' A_Index
            v := ConfigRead(section, 'Version', '')
            try this['Version' A_Index].Text := v || '最新 ' A_Index '.x'
            try this['Build' A_Index].Text := ConfigRead(section, 'Build', '')
            try this['UIA' A_Index].Value := ConfigRead(section, 'UIA', false)
            if this['Build' A_Index].Text = ""
                ControlChooseIndex(1, this['Build' A_Index])
        }
        v := ConfigRead('Launcher', 'Fallback', '')
        IsInteger(v) && this['Fallback'].Value := v
        this['Identify'].Value := ConfigRead('Launcher', 'Identify', true)
        this['LauncherUTF8'].Value := ConfigRead('Launcher\v1', 'UTF8', false)
        
        this.ChangedMode()
        this.ChangedExe()
    }
    
    ChangedMode(sourceCtrl:=false, *) {
        usingLauncher := this['UseLauncher'].Value
        this['Tab'].Choose(usingLauncher ? 1 : 2)
        this[usingLauncher ? 'LauncherUTF8' : 'CustomUTF8'].GetPos(, &y1, , &h1)
        this['Close'].GetPos(,,, &h2)
        this['Close'].Move(, y1)
        this.Show('h' (y1 + h2 + 10))
        if sourceCtrl
            this.UpdateVerbs()
    }
    
    ChangedExe() {
        exe := this['ExePath'].Text
        if exe = ""
            return
        try
            exeVersion := FileGetVersion(exe)
        catch {
            MsgBox "所选 EXE 似乎无效。`n`n具体信息：" exe,, 'Icon!'
            return
        }
        if !this['CustomUTF8'].Visible && this['LauncherUTF8'].Value
            this['CustomUTF8'].Value := true
        this['CustomUTF8'].Visible := VerCompare(exeVersion, '2') < 0
    }
    
    ChangedVersion(ctrl, *) =>
        ConfigWrite(ctrl.Value = 1 ? '' : ctrl.Text, 'Launcher\v' SubStr(ctrl.Name, -1), 'Version')
    
    ChangedBuild(ctrl, *) =>
        ConfigWrite(ctrl.Text, 'Launcher\v' SubStr(ctrl.Name, -1), 'Build')
    
    ChangedUIA(ctrl, *) =>
        ConfigWrite(ctrl.Value, 'Launcher\v' SubStr(ctrl.Name, -1), 'UIA')
    
    ChangedFallback(ctrl, *) =>
        ConfigWrite(ctrl.Value = 3 ? '' : ctrl.Value, 'Launcher', 'Fallback')
    
    BrowseForExe(*) {
        exe := this.FileSelect('3', this['ExePath'].Text, "选择 AutoHotkey.exe", "EXE 文件 (*.exe)")
        if exe = ""
            return
        this['ExePath'].Text := exe
        this.ChangedExe()
        this.UpdateVerbs()
    }
    
    UpdateVerbs(*) {
        ; FIXME: reg key and FriendlyAppName should be defined in only one place
        static key := 'HKCU\Software\Classes\AutoHotkeyScript\Shell\'
        if this['UseLauncher'].Value {
            cmd := Format('"{1}" "{2}\launcher.ahk" "%1" %*', A_AhkPath, A_ScriptDir)
            appname := "AutoHotkey Launcher"
        } else {
            exe := this['ExePath'].Text
            if exe = ""
                return
            if !FileExist(exe)
                throw
            exe_uia := SubStr(exe, 1, -4) "_UIA.exe"
            switches := this['CustomUTF8'].Visible && this['CustomUTF8'].Value ? '/cp65001 ' : ''
            cmd := Format('"{1}" {2}"%1" %*', exe, switches)
            ; Deleting FriendlyAppName from HKCU won't work if the installer uses HKLM,
            ; so explicitly set it to the file's description
            appname := GetExeInfo(exe).Description
        }
        RegWrite appname, 'REG_SZ', key 'Open', 'FriendlyAppName'
        RegWrite cmd, 'REG_SZ', key 'Open\Command'
        RegWrite cmd, 'REG_SZ', key 'RunAs\Command'
        if RegRead('HKCR\AutoHotkeyScript\Shell\UIAccess\Command',, '') {
            if IsSet(exe_uia) && FileExist(exe_uia)
                cmd := StrReplace(cmd, exe, exe_uia)
            else
                cmd := Format('"{1}" "{2}\launcher.ahk" /runwith UIA "%1" %*', A_AhkPath, A_ScriptDir)
            RegWrite cmd, 'REG_SZ', key 'UIAccess\Command'
        }
    }
}

if A_ScriptFullPath = A_LineFile
    LauncherConfigGui.Show()