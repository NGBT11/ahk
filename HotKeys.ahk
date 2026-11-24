#Requires AutoHotkey v1.1
#SingleInstance Force
FileEncoding, UTF-8

; --- ПРАВА АДМИНИСТРАТОРА ---
; Без них скрипт не работает в окнах, запущенных от администратора (Диспетчер устройств,
; диспетчер задач, часть установщиков). При запуске сам просит права (окно UAC) и перезапускается.
; Если отказаться в окне UAC, скрипт продолжит работу без прав администратора.
if (!A_IsAdmin) {
    try {
        Run, *RunAs "%A_ScriptFullPath%"
        ExitApp
    }
}

; ВАЖНО: файл должен быть сохранён как UTF-8 с BOM, иначе русские буквы
; в строках (шаблоны, раскладка) превратятся в кракозябры.

; --- НАСТРОЙКИ ---
global TaskbarHidden := false
global TaskbarHotkeyEnabled := false
global DesktopsEnabled := true
global GameMode := false
global GamepadMode := false
global CheatVisible := false

; Состояние геймпад-режима
global XInputFn := 0          ; адрес функции XInputGetState
global GpPad := -1            ; номер найденного геймпада (0-3), -1 = нет
global GpLeft := false        ; левая кнопка мыши зажата геймпадом
global GpMiddle := false        ; средняя кнопка мыши зажата геймпадом
global GpRight := false       ; правая кнопка мыши зажата геймпадом
global GpPrev := 0            ; кнопки в прошлом опросе
global GpFx := 0              ; дробный остаток движения по X
global GpFy := 0              ; дробный остаток движения по Y
global GpScroll := 0          ; накопленная прокрутка
global GpAltTab := false      ; открыт переключатель окон (Alt зажат программно)
global GpAltTabLast := 0      ; время последнего нажатия в переключателе
global AltTabIdleMs := 2000   ; через сколько мс бездействия переключатель сам выберет окно
global GpComboStart := 0      ; когда начали держать оба стика (для выключения режима)
global GpBlock := 0           ; кнопки, которые игнорируем до отпускания (после выбора окна)
global GpRepeat := {}         ; таймеры автоповтора для крестовины

global MenuTaskbar := "Enable Taskbar Hotkey (F12)"
global MenuDesktops := "Enable Desktop Switching (CapsLock+1/2)"
global MenuGame := "Game Mode (Ctrl+Alt+G)"
global MenuGamepad := "Gamepad as mouse (Ctrl+Alt+M)"
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
Menu, Tray, Add, %MenuGamepad%, ToggleGamepad
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

ToggleGamepad:
    GamepadMode := !GamepadMode
    if (GamepadMode) {
        GamepadInit()
        SetTimer, GamepadTick, 15
    } else {
        SetTimer, GamepadTick, Off
        GamepadRelease()
    }
    UpdateMenu()
    Notify("Gamepad mouse", GamepadMode)
return

GamepadTick:
    GamepadPoll()
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

; Ctrl+Alt+M - геймпад как мышь (вкл / выкл)
^!m::Gosub, ToggleGamepad

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

; --- Курсор с клавиатуры (если мышь не работает) ---
; Держишь CapsLock + I/J/K/L: курсор едет, чем дольше держишь, тем быстрее.
; Короткое нажатие двигает курсор на пару пикселей (точная подстройка).
CapsLock & SC017::MouseNav()                       ; I - вверх
CapsLock & SC024::MouseNav()                       ; J - влево
CapsLock & SC025::MouseNav()                       ; K - вниз
CapsLock & SC026::MouseNav()                       ; L - вправо
CapsLock & SC016::MouseButton("Left", "SC016")     ; U - левая кнопка (удержание = перетаскивание)
CapsLock & SC018::MouseButton("Right", "SC018")    ; O - правая кнопка
CapsLock & SC019::MouseButton("Middle", "SC019")   ; P - средняя кнопка (колёсико)
CapsLock & SC033::Click, WheelUp                   ; , - прокрутка вверх
CapsLock & SC034::Click, WheelDown                 ; . - прокрутка вниз

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
    act := GamepadMode ? "Check" : "Uncheck"
    Menu, Tray, %act%, %MenuGamepad%
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

; ===== ГЕЙМПАД КАК МЫШЬ (XInput) =====
; Геймпад Xbox читается напрямую через xinput*.dll, без сторонних библиотек.
; Пока режим включён, таймер GamepadTick опрашивает его каждые 15 мс.
;   левый стик - курсор, правый стик - прокрутка
;   A или RT - левая кнопка (удержание = перетаскивание), B или LT - правая
;   X - Enter, Y - экранная клавиатура, Back - Esc, Start - клавиша Win
;   крестовина - стрелки (с автоповтором)
;   RB - переключатель окон (Alt+Tab): RB / LB листают вперёд / назад, A - выбрать,
;        B - отмена, сам выберет окно после 2 секунд бездействия
;   LB - назад (кнопка «Назад» в браузере и проводнике; при открытом Alt+Tab листает назад)
;   зажать оба стика (L3 + R3) на секунду - выключить режим

GamepadInit() {
    global XInputFn, GpPad
    GpPad := -1
    if (XInputFn)
        return
    for i, dll in ["xinput1_4.dll", "xinput1_3.dll", "xinput9_1_0.dll"] {
        lib := DllCall("LoadLibrary", "Str", dll, "Ptr")
        if (lib) {
            XInputFn := DllCall("GetProcAddress", "Ptr", lib, "AStr", "XInputGetState", "Ptr")
            if (XInputFn)
                break
        }
    }
    if (!XInputFn)
        TrayTip, Gamepad, XInput not found, 3, 0x10
}

; Нормализованное значение стика: мёртвая зона + мягкая кривая, знак сохраняется
GpAxis(v) {
    dz := 7849
    if (Abs(v) < dz)
        return 0
    n := (Abs(v) - dz) / (32767 - dz)
    if (n > 1)
        n := 1
    n := n * n
    return (v < 0) ? -n : n
}

MouseEv(flags, data := 0) {
    DllCall("mouse_event", "UInt", flags, "UInt", 0, "UInt", 0, "Int", data, "UPtr", 0)
}

; Alt+Tab с геймпада: первое нажатие RB зажимает Alt и открывает переключатель окон,
; дальше RB / LB листают вперёд / назад, A выбирает, B отменяет, а при бездействии
; (AltTabIdleMs) выбор подтверждается сам.
AltTabStep(dir) {
    global GpAltTab, GpAltTabLast
    if (!GpAltTab) {
        Send, {Alt down}
        GpAltTab := true
    }
    if (dir > 0)
        Send, {Tab}
    else
        Send, +{Tab}
    GpAltTabLast := A_TickCount
}

AltTabEnd(confirm) {
    global GpAltTab
    if (!GpAltTab)
        return
    if (!confirm)
        Send, {Esc}
    Send, {Alt up}
    GpAltTab := false
}

; Отпускаем всё, что геймпад мог зажать (при выключении, отключении, игровом режиме)
GamepadRelease() {
    global GpLeft, GpRight, GpMiddle, GpPrev, GpAltTab, GpBlock
    if (GpLeft) {
        MouseEv(0x4)
        GpLeft := false
    }
    if (GpRight) {
        MouseEv(0x10)
        GpRight := false
    }
    if (GpMiddle) {
        MouseEv(0x40)
        GpMiddle := false
    }
    if (GpAltTab) {
        Send, {Esc}{Alt up}
        GpAltTab := false
    }
    GpBlock := 0
    GpPrev := 0
}

GamepadPoll() {
    global XInputFn, GpPad, GameMode, GpLeft, GpRight, GpMiddle, GpPrev, GpFx, GpFy, GpScroll, GpRepeat
    global GpAltTab, GpAltTabLast, AltTabIdleMs, GpBlock, GpComboStart
    static lastScan := 0

    ; в игровом режиме геймпад не трогаем
    if (!XInputFn || GameMode) {
        GamepadRelease()
        return
    }

    VarSetCapacity(state, 16, 0)

    ; ищем подключённый геймпад (раз в секунду, чтобы не грузить систему)
    if (GpPad < 0) {
        if (A_TickCount - lastScan < 1000)
            return
        lastScan := A_TickCount
        Loop, 4 {
            if (DllCall(XInputFn, "UInt", A_Index - 1, "Ptr", &state, "UInt") = 0) {
                GpPad := A_Index - 1
                break
            }
        }
        if (GpPad < 0)
            return
    }
    if (DllCall(XInputFn, "UInt", GpPad, "Ptr", &state, "UInt") != 0) {
        GpPad := -1
        GamepadRelease()
        return
    }

    btn := NumGet(state, 4, "UShort")
    lt := NumGet(state, 6, "UChar")
    rt := NumGet(state, 7, "UChar")
    lx := NumGet(state, 8, "Short")
    ly := NumGet(state, 10, "Short")
    ry := NumGet(state, 14, "Short")

    ; кнопки, которыми только что выбрали окно, игнорируем, пока их не отпустят
    GpBlock := GpBlock & btn
    btn := btn & ~GpBlock

    ; оба стика (L3 + R3) зажаты секунду - выключить режим
    if ((btn & 0xC0) = 0xC0) {
        if (!GpComboStart) {
            GpComboStart := A_TickCount
        } else if (A_TickCount - GpComboStart > 1000) {
            GpComboStart := 0
            Gosub, ToggleGamepad
            return
        }
    } else {
        GpComboStart := 0
    }

    ; новые нажатия (кнопки, нажатые именно сейчас)
    pressed := btn & ~GpPrev
    GpPrev := btn

    ; переключатель окон (Alt+Tab): пока он открыт, кнопки работают только на него
    if (GpAltTab && A_TickCount - GpAltTabLast > AltTabIdleMs)
        AltTabEnd(true)
    if (GpAltTab) {
        if (pressed & 0x200)
            AltTabStep(1)
        else if (pressed & 0x100)
            AltTabStep(-1)
        if (pressed & 0x1000) {
            AltTabEnd(true)
            GpBlock |= 0x1000
        } else if (pressed & 0x2000) {
            AltTabEnd(false)
            GpBlock |= 0x2000
        }
        for i, d in [[0x1, "Up"], [0x2, "Down"], [0x4, "Left"], [0x8, "Right"]] {
            if (pressed & d[1]) {
                Send, % "{" d[2] "}"
                GpAltTabLast := A_TickCount
            }
        }
        return
    }

    ; левый стик - курсор (дробный остаток копим, чтобы слабый наклон тоже двигал)
    mx := GpAxis(lx)
    my := GpAxis(ly)
    if (mx != 0 || my != 0) {
        speed := 18
        GpFx += mx * speed
        GpFy -= my * speed
        dx := ((GpFx < 0) ? -1 : 1) * Floor(Abs(GpFx))
        dy := ((GpFy < 0) ? -1 : 1) * Floor(Abs(GpFy))
        if (dx != 0 || dy != 0) {
            MouseMove, % dx, % dy, 0, R
            GpFx -= dx
            GpFy -= dy
        }
    } else {
        GpFx := 0
        GpFy := 0
    }

    ; правый стик по вертикали - прокрутка
    ryn := GpAxis(ry)
    if (ryn != 0) {
        GpScroll += ryn * 25
        notches := Floor(Abs(GpScroll) / 120)
        if (notches > 0) {
            sgn := (GpScroll < 0) ? -1 : 1
            MouseEv(0x800, sgn * notches * 120)
            GpScroll -= sgn * notches * 120
        }
    } else {
        GpScroll := 0
    }

    ; кнопки мыши: A / RT - левая, B / LT - правая
    left := ((btn & 0x1000) || rt > 100) ? true : false
    right := ((btn & 0x2000) || lt > 100) ? true : false
    if (left != GpLeft) {
        MouseEv(left ? 0x2 : 0x4)
        GpLeft := left
    }
    if (right != GpRight) {
        MouseEv(right ? 0x8 : 0x10)
        GpRight := right
    }
    ; нажатие правого стика (R3) - средняя кнопка
    middle := ((btn & 0x80) && !(btn & 0x40)) ? true : false
    if (middle != GpMiddle) {
        MouseEv(middle ? 0x20 : 0x40)
        GpMiddle := middle
    }

    ; одноразовые действия - только в момент нажатия
    if (pressed & 0x200)
        AltTabStep(1)
    if (pressed & 0x100)
        Send, {Browser_Back}
    if (pressed & 0x4000)
        Send, {Enter}
    if (pressed & 0x8000)
        Run, osk.exe
    if (pressed & 0x20)
        Send, {Esc}
    if (pressed & 0x10)
        Send, {LWin}

    ; крестовина - стрелки: сразу при нажатии, потом автоповтор
    for i, d in [[0x1, "Up"], [0x2, "Down"], [0x4, "Left"], [0x8, "Right"]] {
        if (btn & d[1]) {
            if (pressed & d[1]) {
                Send, % "{" d[2] "}"
                GpRepeat[d[2]] := A_TickCount + 400
            } else if (A_TickCount >= GpRepeat[d[2]]) {
                Send, % "{" d[2] "}"
                GpRepeat[d[2]] := A_TickCount + 70
            }
        }
    }
}

; Движение курсора клавишами I/J/K/L (с CapsLock). Цикл крутится, пока клавиши
; зажаты, поэтому можно держать две сразу (диагональ). Скорость растёт со временем.
MouseNav() {
    static running := false
    if (running)
        return
    running := true
    start := A_TickCount
    while (GetKeyState("CapsLock", "P") && (GetKeyState("SC017", "P") || GetKeyState("SC024", "P") || GetKeyState("SC025", "P") || GetKeyState("SC026", "P"))) {
        dx := (GetKeyState("SC026", "P") ? 1 : 0) - (GetKeyState("SC024", "P") ? 1 : 0)
        dy := (GetKeyState("SC025", "P") ? 1 : 0) - (GetKeyState("SC017", "P") ? 1 : 0)
        step := Min(3 + (A_TickCount - start) // 60, 25)
        MouseMove, % dx * step, % dy * step, 0, R
        Sleep, 15
    }
    running := false
}

; Клик кнопкой мыши: пока клавиша зажата, кнопка удерживается (перетаскивание)
MouseButton(btn, key) {
    Click, %btn% Down
    KeyWait, %key%
    Click, %btn% Up
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
    I J K L        курсор мыши (держи, разгоняется)
    U / O          левая / правая кнопка мыши
    , / .          прокрутка вверх / вниз
    P              средняя кнопка мыши (колёсико)
    H              эта шпаргалка
    ------------------------------------------
    Shift+CapsLock обычный CapsLock
    Ctrl+Alt+G     игровой режим
    Ctrl+Alt+M     геймпад как мышь вкл / выкл
                   стик - курсор, A/RT - левый клик, B/LT - правый,
                   пр. стик - прокрутка, нажатие пр. стика - средняя кнопка,
                   Y - экранная клавиатура, X - Enter,
                   RB - окна (Alt+Tab), A - выбрать, B - отмена, LB - назад
    Win+F12        режим скрытия панели задач (потом F12)
    )
    CheatVisible := true
    ToolTip, %text%, 20, 20
    SetTimer, HideCheat, -12000
}