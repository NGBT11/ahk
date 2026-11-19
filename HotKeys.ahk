#Requires AutoHotkey v1.1
#SingleInstance Force
FileEncoding, UTF-8

; ВАЖНО: файл должен быть сохранён как UTF-8 с BOM, иначе русские буквы
; в строках (шаблоны, раскладка) превратятся в кракозябры.

; --- НАСТРОЙКИ ---
global TaskbarHidden := false
global TaskbarHotkeyEnabled := false
global DesktopsEnabled := true
global GameMode := false
global CheatVisible := false

global MenuTaskbar := "Enable Taskbar Hotkey (F12)"
global MenuDesktops := "Enable Desktop Switching (CapsLock+1/2)"
global MenuGame := "Game Mode (Ctrl+Alt+G)"
global MenuCheat := "Hotkey cheat sheet (CapsLock+H)"
global MenuAutostart := "Run at Windows startup"

; --- ТВОИ ТЕКСТОВЫЕ ШАБЛОНЫ (CapsLock+3/4/5) - поменяй на свои ---
global Snip1 := "your.email@example.com"
global Snip2 := "Иван Иванов"
global Snip3 := "+7 900 000-00-00"

; --- ТРЕЙ ---
Menu, Tray, NoStandard
Menu, Tray, Tip, Hotkey Manager
Menu, Tray, Add, %MenuTaskbar%, ToggleTaskbar
Menu, Tray, Add, %MenuDesktops%, ToggleDesktops
Menu, Tray, Add, %MenuGame%, ToggleGameMode
Menu, Tray, Add
Menu, Tray, Add, %MenuCheat%, ShowCheat
Menu, Tray, Add, %MenuAutostart%, ToggleAutostart
Menu, Tray, Add
Menu, Tray, Add, Exit, ExitScript
Menu, Tray, Default, %MenuDesktops%   ; двойной клик по иконке

UpdateMenu()
OnExit("RestoreTaskbar")
SetCapsLockState, AlwaysOff           ; CapsLock теперь только модификатор
return

; --- ПЕРЕКЛЮЧАТЕЛИ ---
ToggleTaskbar:
    TaskbarHotkeyEnabled := !TaskbarHotkeyEnabled
    if (!TaskbarHotkeyEnabled && TaskbarHidden)
        SetTaskbar(true)
    UpdateMenu()
    Notify("Taskbar hotkey", TaskbarHotkeyEnabled)
return

ToggleDesktops:
    DesktopsEnabled := !DesktopsEnabled
    UpdateMenu()
    Notify("Desktop switching", DesktopsEnabled)
return

ToggleGameMode:
    GameMode := !GameMode
    UpdateMenu()
    Notify("Game mode", GameMode)
return

ShowCheat:
    ShowCheatSheet()
return

HideCheat:
    ToolTip
    CheatVisible := false
return

ToggleAutostart:
    lnk := A_Startup "\" . RegExReplace(A_ScriptName, "\.ahk$") . ".lnk"
    if FileExist(lnk)
        FileDelete, %lnk%
    else
        FileCreateShortcut, %A_ScriptFullPath%, %lnk%, %A_ScriptDir%
    UpdateMenu()
return

ExitScript:
    ExitApp
return

; --- ГОРЯЧИЕ КЛАВИШИ ---

; Win+F12 - включить/выключить режим скрытия панели
#F12::Gosub, ToggleTaskbar

; Ctrl+Alt+G - игровой режим (работает всегда, в том числе чтобы его выключить)
^!g::Gosub, ToggleGameMode

#If TaskbarHotkeyEnabled
F12::SetTaskbar(TaskbarHidden)        ; скрыта - показать, видна - скрыть
#If

; Игровой режим: блокируем клавиши Win
#If GameMode
LWin::return
RWin::return
#If

; Shift+CapsLock - обычный CapsLock
+CapsLock::SetCapsLockState, % GetKeyState("CapsLock", "T") ? "AlwaysOff" : "AlwaysOn"

; CapsLock+1 / CapsLock+2 - рабочие столы (влево / вправо)
#If (DesktopsEnabled && !GameMode)
CapsLock & 1::Send, ^#{Left}
CapsLock & 2::Send, ^#{Right}
#If

; Все остальные CapsLock-комбинации. В игровом режиме они отключены.
; Буквы заданы по скан-кодам (SCxxx), поэтому работают и в русской раскладке.
#If !GameMode

; --- Окна ---
CapsLock & SC014::WinSet, AlwaysOnTop, Toggle, A   ; T - окно поверх всех
CapsLock & SC010::WinClose, A                      ; Q - закрыть окно

; --- Прозрачность окна ---
CapsLock & WheelUp::AdjustTransparency(15)         ; колесо вверх - плотнее
CapsLock & WheelDown::AdjustTransparency(-15)      ; колесо вниз - прозрачнее
CapsLock & MButton::WinSet, Transparent, Off, A    ; средняя кнопка - сброс

; --- Звук ---
CapsLock & Up::Send, {Volume_Up}
CapsLock & Down::Send, {Volume_Down}
CapsLock & SC032::Send, {Volume_Mute}              ; M

; --- Раскладка окон по экрану (учитывает несколько мониторов) ---
CapsLock & SC01E::SnapWindow(0, 0, 0.5, 1)         ; A - левая половина
CapsLock & SC020::SnapWindow(0.5, 0, 0.5, 1)       ; D - правая половина
CapsLock & SC01F::SnapWindow(0.15, 0.1, 0.7, 0.8)  ; S - по центру
CapsLock & SC011::ToggleMaximize()                 ; W - развернуть / вернуть

; --- Запуск программ ---
CapsLock & SC012::Run, explorer.exe                ; E - проводник
CapsLock & SC031::Run, notepad.exe                 ; N - блокнот
CapsLock & SC02E::Run, calc.exe                    ; C - калькулятор
CapsLock & SC030::Run, https://www.google.com      ; B - браузер по умолчанию
CapsLock & SC013::                                 ; R - терминал
    try Run, wt.exe
    catch
        Run, cmd.exe
return

; --- Вставка текстовых шаблонов ---
CapsLock & 3::PasteText(Snip1)
CapsLock & 4::PasteText(Snip2)
CapsLock & 5::PasteText(Snip3)

; --- Текст: исправление раскладки и поиск выделенного ---
CapsLock & SC039::FixLayout()                      ; Space - исправить раскладку
CapsLock & SC022::SearchSelected("https://www.google.com/search?q={q}")           ; G - Google
CapsLock & SC015::SearchSelected("https://yandex.ru/search/?text={q}")            ; Y - Яндекс
CapsLock & SC02D::SearchSelected("https://translate.google.com/?sl=auto&tl=ru&op=translate&text={q}")  ; X - перевод

; --- Шпаргалка ---
CapsLock & SC023::ShowCheatSheet()                 ; H - показать / скрыть

#If

; --- ФУНКЦИИ ---
UpdateMenu() {
    act := TaskbarHotkeyEnabled ? "Check" : "Uncheck"
    Menu, Tray, %act%, %MenuTaskbar%
    act := DesktopsEnabled ? "Check" : "Uncheck"
    Menu, Tray, %act%, %MenuDesktops%
    act := GameMode ? "Check" : "Uncheck"
    Menu, Tray, %act%, %MenuGame%
    lnk := A_Startup "\" . RegExReplace(A_ScriptName, "\.ahk$") . ".lnk"
    act := FileExist(lnk) ? "Check" : "Uncheck"
    Menu, Tray, %act%, %MenuAutostart%
}

Notify(title, state) {
    TrayTip, %title%, % (state ? "ON" : "OFF"), 1, 0x10
}

SetTaskbar(show) {
    global TaskbarHidden
    action := show ? "Show" : "Hide"
    DoWin(action, "ahk_class Shell_TrayWnd")
    WinGet, list, List, ahk_class Shell_SecondaryTrayWnd
    Loop, %list%
    {
        id := list%A_Index%
        DoWin(action, "ahk_id " id)
    }
    TaskbarHidden := !show
}

DoWin(action, title) {
    if (action = "Show")
        WinShow, %title%
    else
        WinHide, %title%
}

RestoreTaskbar() {
    global TaskbarHidden
    if (TaskbarHidden)
        SetTaskbar(true)
}

PasteText(text) {
    saved := ClipboardAll
    Clipboard := text
    ClipWait, 1
    Send, ^v
    Sleep, 150
    Clipboard := saved
}

ToggleMaximize() {
    WinGet, state, MinMax, A
    if (state = 1)
        WinRestore, A
    else
        WinMaximize, A
}

SnapWindow(xp, yp, wp, hp) {
    WinGet, hwnd, ID, A
    WinGet, state, MinMax, ahk_id %hwnd%
    if (state != 0)
        WinRestore, ahk_id %hwnd%
    WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%
    cx := wx + ww // 2
    cy := wy + wh // 2

    ; ищем монитор, на котором сейчас окно
    found := 1
    SysGet, count, MonitorCount
    Loop, %count%
    {
        SysGet, m, MonitorWorkArea, %A_Index%
        if (cx >= mLeft && cx < mRight && cy >= mTop && cy < mBottom) {
            found := A_Index
            break
        }
    }

    SysGet, m, MonitorWorkArea, %found%
    aw := mRight - mLeft
    ah := mBottom - mTop
    WinMove, ahk_id %hwnd%, , Round(mLeft + aw * xp), Round(mTop + ah * yp), Round(aw * wp), Round(ah * hp)
}

; Прозрачность активного окна: delta > 0 плотнее, delta < 0 прозрачнее
AdjustTransparency(delta) {
    WinGet, t, Transparent, A
    if (t = "")
        t := 255
    t := t + delta
    if (t < 40)
        t := 40
    if (t >= 255)
        WinSet, Transparent, Off, A
    else
        WinSet, Transparent, %t%, A
}

; Копирует выделенный текст и возвращает его (буфер обмена восстанавливается)
GetSelectedText() {
    saved := ClipboardAll
    Clipboard := ""
    Send, ^c
    ClipWait, 0.5
    text := ErrorLevel ? "" : Clipboard
    Clipboard := saved
    return text
}

; Исправление раскладки: EN <-> RU, направление определяется автоматически
FixLayout() {
    en := "qwertyuiop[]asdfghjkl;'zxcvbnm,./``QWERTYUIOP{}ASDFGHJKL:""ZXCVBNM<>?~"
    ru := "йцукенгшщзхъфывапролджэячсмитьбю.ёЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,Ё"

    saved := ClipboardAll
    Clipboard := ""
    Send, ^c
    ClipWait, 0.5
    if (ErrorLevel) {
        Clipboard := saved
        TrayTip, Layout fix, Nothing selected, 1, 0x10
        return
    }
    text := Clipboard

    cyr := StrLen(RegExReplace(text, "[^а-яА-ЯёЁ]"))
    lat := StrLen(RegExReplace(text, "[^a-zA-Z]"))
    toRU := (lat >= cyr)

    result := ""
    Loop, Parse, text
    {
        ch := A_LoopField
        if (toRU) {
            pos := InStr(en, ch, true)
            result .= pos ? SubStr(ru, pos, 1) : ch
        } else {
            pos := InStr(ru, ch, true)
            ; точку и запятую в русском тексте не трогаем
            if (pos && ch != "." && ch != ",")
                result .= SubStr(en, pos, 1)
            else
                result .= ch
        }
    }

    Clipboard := result
    ClipWait, 1
    Send, ^v
    Sleep, 150
    Clipboard := saved
}

; Поиск выделенного текста. В urlTemplate вместо {q} подставляется запрос
SearchSelected(urlTemplate) {
    text := Trim(GetSelectedText(), " `t`r`n")
    if (text = "") {
        TrayTip, Search, Nothing selected, 1, 0x10
        return
    }
    url := StrReplace(urlTemplate, "{q}", UriEncode(text))
    Run, %url%
}

UriEncode(str) {
    VarSetCapacity(var, StrPut(str, "UTF-8"), 0)
    StrPut(str, &var, "UTF-8")
    res := ""
    Loop {
        code := NumGet(var, A_Index - 1, "UChar")
        if (!code)
            break
        if ((code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A) || code = 0x2D || code = 0x2E || code = 0x5F || code = 0x7E)
            res .= Chr(code)
        else
            res .= "%" . Format("{:02X}", code)
    }
    return res
}

; Шпаргалка по хоткеям: показать на 12 секунд, повторный вызов скрывает
ShowCheatSheet() {
    if (CheatVisible) {
        SetTimer, HideCheat, Off
        Gosub, HideCheat
        return
    }
    text =
    (LTrim
    HOTKEYS (CapsLock + ...)
    ------------------------------------------
    1 / 2          рабочий стол влево / вправо
    A / D          окно: левая / правая половина
    S              окно по центру
    W              развернуть / вернуть окно
    T              окно поверх всех
    Q              закрыть окно
    Колесо         прозрачность окна (вверх плотнее)
    Ср. кнопка     сбросить прозрачность
    Up / Down / M  громкость + / - / mute
    E N C B R      проводник, блокнот, калькулятор, браузер, терминал
    3 / 4 / 5      вставить шаблон 1 / 2 / 3
    Space          исправить раскладку выделенного
    G / Y / X      Google / Яндекс / перевод выделенного
    H              эта шпаргалка
    ------------------------------------------
    Shift+CapsLock обычный CapsLock
    Ctrl+Alt+G     игровой режим
    Win+F12        режим скрытия панели задач (потом F12)
    )
    CheatVisible := true
    ToolTip, %text%, 20, 20
    SetTimer, HideCheat, -12000
}
