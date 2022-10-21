#SingleInstance off
#NoEnv
#MaxMem, 512
#NoTrayIcon

OnExit("Exitapp")

if (!A_IsCompiled) {
	IfWinActive, ahk_exe SCiTE.exe
	{
		t = %1%
		if (t != "fromscite") {
			Run, "%A_ScriptFullPath%" "fromscite"
			exitapp
		}
	}
}

SetBatchLines, -1
CoordMode, Mouse, Screen

; Основные
global hstdin, hstdout, pc_result, attached, no_suspend, no_attach, process_pid, CurrentProcessPath, cmd_text
global version := "2.15"
global root := A_AppData "\by.strdev"
global config := A_AppData "\by.strdev\rshell_config.ini"
global host := "http://mrakw.eternalhost.info/renux"
global title := "Renux Shell"
global beta := 0
global started := 0
global exit_code := 0

if (!A_IsCompiled)
	beta := 1

; Определение системного диска + папка пользователя
SplitPath, A_WinDir,,,,, SYSDRIVE
userdir := SysDrive "\Users\" A_UserName
global userdir, sysdrive

; Для ProcessArgument()
global shell_mode := 0
global shell_file := ""
global hide_mode := 0
global ignore_errors := 0
global ignore_warnings := 0
global ignore_information := 0
global output_mode := "print"
global debug := 0
global gui := 0
global vkcmd_mode := 0
global vkcmd_pid := ""

; Для ProcessCMD()
global procvar, api, whr, response, ignore_err_vkapi, log, mainwid, perm_download, cmd_hks, shell_mline, shell_lines, debug_pause_menu, installed, start_transparent, _async, shell_from, http, note_for_update, trash_remove
global cmd_variables := []
global cmd_labels := []
global cmd_source := []
global cmd_hotkeys := []
global cmd_functions := []
global crypt_info := []
global addons := []
global tvs := []
global justgen := 0

; Для перенаправления вывода
global allow_console_writing := 1
global console_output_to := ""

; Доп. текст для людей, которые обновились до этой версии
note_for_update := ""

global cmd_list

OnError("error")

error(e) {
	global
	Critical
	
	if (!attached) {
		console.cmd("title Сессия Renux Shell завершена. & cls & color 1F")
		Winset, Style, -0x40000, ahk_id %mainwid%
		WinSet, Style, -0x10000, ahk_id %mainwid%
		WinRestore, ahk_id %mainwid%
		WinGetPos, x, y,,, ahk_id %mainwid%
	}
	
	Gui, dbg:destroy
	
	err_message := Trim(e.Message), err_line := Trim(e.Line)
	msg := string.up(StrReplace(StrReplace(err_message, " ", "_"), ".") "_" err_line)
	what := string.up(e.what)
	
	if (!attached) {
		loop, 3
			console.writeln("")
	}
	
	if (shell_mode) {
		cmd_last := cmd_last "`n`n	При исполнении пакетного файла: " shell_file
	}
	
	text =
	(
	
	Сессия Renux Shell была принудительна завершена.
	
	Похоже, что-то вызвало фатальную ошибку в программном коде Renux, которую не предусмотрел разработчик.
	
	Информация, которая понадобится разработчику: %A_OSType%_%A_OSVersion%_%A_Is64bitOS%_%msg%_%what%_%shell_mode%.
	
	Ошибка была вызвана командой: %cmd_last%
	
	Пожалуйста, сообщите об этой ошибке разработчику (vk.com/strdev).
	)
	
	console.write(text)
	
	if attached
		console.writeln("`n`n	Программа была автоматически закрыта.")
	
	if (!attached) {
		pause
	}
	
	exitapp
	sleep 30000
}

GetIconFromResource(dest, source, idx)
{
   ; info: http://msdn.microsoft.com/en-us/library/ms997538.aspx
   SetBatchLines, -1
   if !hModule := Validation(dest, source, idx)
      Return
   
   for key, handle in FindGroup(source, idx, hModule)
   {
      pGroupInfo := GetResData(hModule, handle)
      if !IsObject(DataArray := CreateDataArray(hModule, pGroupInfo, CountIcons, size, idx ? idx : A_Index))
      {
         if (DataArray = 6)
            continue
         else
            break
      }
      pData := CreateDataBuff(DataArray, pGroupInfo, CountIcons, size)
      res := Data2icoFile(pData, dest, size, idx)
   } until !res
   
   DllCall("FreeLibrary", Ptr, hModule)
}

Validation(dest, source, idx)
{
   if !((idx + 1) > 0 && source := ValidateName(source))
      Return
   
   static dwFlags := (LOAD_LIBRARY_AS_DATAFILE := 0x2 | LOAD_LIBRARY_AS_IMAGE_RESOURCE := 0x20)
   if !hModule := DllCall("LoadLibraryEx", Str, source, Ptr, 0, UInt, dwFlags, Ptr)
      Return, 0, DllCall("MessageBox", Ptr, 0, Str, "Невозможно загрузить указанный модуль!`nОшибка " A_LastError, Str, "", UInt, 0)
         
   Return hModule
}

ValidateName(FilePath)
{
   SplitPath, FilePath,,, ext
   if !(ext ~= "i)exe|dll") && Error := "Допустимы только dll и exe файлы"
      Return, 0, DllCall("MessageBox", Ptr, 0, Str, Error, Str, "", UInt, 0)
   
   if !FileExist(FilePath)
   {
      EnvGet, PathVar, Path
      Loop, parse, PathVar, `;
         continue
      until FileExist(p := RTrim(A_LoopField, "\") . "\" . FilePath) && (FilePath := p) && found := 1
      
      if !found && Text := "Файл " FilePath " не найден"
         Return, 0, DllCall("MessageBox", Ptr, 0, Str, Text, Str, "", UInt, 0)
   }
   
   Return FilePath
}

FindGroup(source, idx, hModule)
{
   Names := [idx, 0]
   DllCall("EnumResourceNames", Ptr, hModule, UInt, RT_GROUP_ICON := 14
      , Ptr, RegisterCallback("EnumGroupIconProc", "Fast", 4), Ptr, pNames := Object(Names))
   ObjRelease(pNames)
   
   if (Names.3 = "") && Text := idx ? "Иконка " . idx . " в файле " . source . " не найдена"
                                    : "Иконки в файле " . source . " не найдены"
      Return, 0, DllCall("MessageBox", Ptr, 0, Str, Text, Str, "", UInt, 0)
   
   Names.Remove(1, 2)
   for i, Name in Names
      Names[i] := DllCall("FindResource", Ptr, hModule, Name + 1 ? "UInt" : "Str", Name, UInt, RT_GROUP_ICON, Ptr)
   Return Names
}

EnumGroupIconProc(hModule, Type, Name, lp)
{
   (Name>>16) ? Name := LTrim(StrGet(Name+0), "#")
   obj := Object(lp)
   if !obj.1
      obj.Insert(Name)
   else if ((obj.2 += 1) = obj.1)
      Return, 0, obj.3 := Name
   Return 1
}

GetResData(hModule, hRes)
{
   hData := DllCall("LoadResource", Ptr, hModule, Ptr, hRes, Ptr)
   Return DllCall("LockResource", Ptr, hData, Ptr)
}

CreateDataArray(hModule, pIconGroup, ByRef CountIcons, ByRef offset, idx)
{
   if NumGet(pIconGroup+0, 2, "UShort") != 1 && Text := "Ресурс " Idx " неправильного типа. Возможно, файл сжат или зашифрован`nПродолжить?"
      Return DllCall("MessageBox", Ptr, 0, Str, Text, Str, "Неправильный ресурс", UInt, 4)
   
   DataArray := [], RT_ICON := 3
   CountIcons := NumGet(pIconGroup+0, 4, "UShort")
   offset := 6 + CountIcons*16
   
   Loop % CountIcons
   {
      id := NumGet(pIconGroup + 6 + 14*A_Index - 2, "UShort")
      hRes := DllCall("FindResource", Ptr, hModule, UInt, id, UInt, RT_ICON, Ptr)
      pIcon := GetResData(hModule, hRes)
      DataArray[A_Index] := {ptr: pIcon
                           , size: s := NumGet(pIconGroup + 6 + 14*A_Index - 6, "UInt")
                           , offset: offset}
      offset += s
   }
   Return DataArray
}

CreateDataBuff(DataArray, pIconGroup, CountIcons, size)
{
   static IconData
   VarSetCapacity(IconData, size)
   DllCall("RtlMoveMemory", Ptr, &IconData, Ptr, pIconGroup, Ptr, 6)

   offset := 6
   Loop % CountIcons
   {
      DllCall("RtlMoveMemory", Ptr, &IconData + offset, Ptr, pIconGroup + offset - 2*(A_Index - 1), Ptr, 12)
      NumPut(DataArray[A_Index].offset, &IconData + offset + 12, "UInt"), offset += 16
      DllCall("RtlMoveMemory", Ptr, &IconData + DataArray[A_Index].offset, Ptr, DataArray[A_Index].ptr, Ptr, DataArray[A_Index].size)
   }
   Return &IconData
}

Data2icoFile(pData, Dest, size, idx)
{
   static i = 0
   SplitPath, Dest,, Dir, Ext, OutNameNoExt
   if !FileExist(Dir)
   {
      FileCreateDir, % Dir
      if ErrorLevel && Text := "Невозможно создать папку " Dir "`nОшибка " A_LastError
         Return, 0, DllCall("MessageBox", Ptr, 0, Str, Text, Str, "", UInt, 0)
   }
   
   (!idx) ? Dest := (Ext ? SubStr(Dest, 1, -(StrLen(Ext) + 1)) : Dest) . "(" . ++i . ")" . (Ext ? "." . Ext : "")
   
   if !(File := FileOpen(Dest, "w")) && Text := "Невозможно открыть файл " Dest "на запись`nОшибка " A_LastError
      Return, 0, DllCall("MessageBox", Ptr, 0, Str, Text, Str, "", UInt, 0)
         
   File.Seek(0), File.RawWrite(pData+0, size), File.Close()
   Return 1
}

; Title: Scintilla Wrapper for AHK

class scintilla {
    hwnd            := 0        ; Component Handle
    notify          := ""       ; Name of the function that will handle the window messages sent by the control

                                ; Messages which set this variables.
                                ; ---------------------------------------------------------------------------------------------------------------
    idFrom          := 0        ; The handle from which the notification was sent
    scnCode         := 0        ; The SCN_* notification code
    position        := 0        ; SCN_STYLENEEDED, SCN_DOUBLECLICK, SCN_MODIFIED, SCN_MARGINCLICK
                                ; SCN_NEEDSHOWN, SCN_DWELLSTART, SCN_DWELLEND, SCN_CALLTIPCLICK
                                ; SCN_HOTSPOTCLICK, SCN_HOTSPOTDOUBLECLICK, SCN_HOTSPOTRELEASECLICK
                                ; SCN_INDICATORCLICK, SCN_INDICATORRELEASE
                                ; SCN_USERLISTSELECTION, SCN_AUTOCSELECTION

    ch              := 0        ; SCN_CHARADDED, SCN_KEY
    modifiers       := 0        ; SCN_KEY, SCN_DOUBLECLICK, SCN_HOTSPOTCLICK, SCN_HOTSPOTDOUBLECLICK
                                ; SCN_HOTSPOTRELEASECLICK, SCN_INDICATORCLICK, SCN_INDICATORRELEASE

    modType         := 0        ; SCN_MODIFIED
    text            := 0        ; SCN_MODIFIED, SCN_USERLISTSELECTION, SCN_AUTOCSELECTION, SCN_URIDROPPED
    length          := 0        ; SCN_MODIFIED
    linesAdded      := 0        ; SCN_MODIFIED
    macMessage      := 0        ; SCN_MACRORECORD
    macwParam       := 0        ; SCN_MACRORECORD
    maclParam       := 0        ; SCN_MACRORECORD
    line            := 0        ; SCN_MODIFIED
    foldLevelNow    := 0        ; SCN_MODIFIED
    foldLevelPrev   := 0        ; SCN_MODIFIED
    margin          := 0        ; SCN_MARGINCLICK
    listType        := 0        ; SCN_USERLISTSELECTION
    x               := 0        ; SCN_DWELLSTART, SCN_DWELLEND
    y               := 0        ; SCN_DWELLSTART, SCN_DWELLEND
    token           := 0        ; SCN_MODIFIED with SC_MOD_CONTAINER
    annotLinesAdded := 0        ; SCN_MODIFIED with SC_MOD_CHANGEANNOTATION
    updated         := false    ; SCN_UPDATEUI

    __new(params*){
        if (params.MaxIndex())
            __SCI(this.hwnd := __Add(params*), this)
        else
            return this
    }

    __call(msg, ByRef wParam=0, ByRef lParam=0, params*){

        if (msg = "Add")
            __SCI(this.hwnd := __Add(wParam, lParam, params*), this)
        else
        {
            (wParam && !(wParam+0) && !isObject(wParam)) ? (VarSetCapacity(wParamA, StrPut(wParam, "CP0"))
                                                           ,StrPut(wParam, &wParamA, "CP0")
                                                           ,wParam:=&wParamA) : null

            (lParam && !(lParam+0) && !isObject(lParam)) ? (VarSetCapacity(lParamA, StrPut(lParam, "CP0"))
                                                           ,StrPut(lParam, &lParamA, "CP0")
                                                           ,lParam:=&lParamA) : null

            /*
              Special Operations
              Due to the fact that some functions require the user to manually prepare bufferst to store text
              I decided to make most of those operations internally to have cleaner code later on.
            */

            (msg = "GetText") ? (VarSetCapacity(lParam, wParam * (a_isunicode ? 2 : 1)+8), lParam := &lParam, buf:=true) : null
            (msg = "GetLine") ? (VarSetCapacity(lParam, this.linelength(wParam)+1 * (a_isunicode ? 2 : 1)),lParam := &lParam, buf:=true) : null
	    (msg = "GetCurLine") ? (VarSetCapacity(lParam, this.linelength(wParam)+1 * (a_isunicode ? 2 : 1)), lParam := &lParam, buf:=true) : null
            (msg = "GetTextRange") ? (range:=abs(wParam.1 - wParam.2)+1, dSize :=  __sendEditor(this.hwnd, "GetLength")
                                     ,VarSetCapacity(lParam, range > dSize ? (dSize, wParam.2 := dSize) : range)
                                     ,VarSetCapacity(textRange, 12, 0)
                                     ,NumPut(wParam.1,textRange,0,"UInt")
                                     ,NumPut(wParam.2,textRange,4,"UInt")
                                     ,NumPut(&lParam,textRange,8,"UInt")
                                     ,blParam := &lParam, wParam := false,lParam := &textRange, buf:=true) : null

            __isHexColor(lParam, msg) ? lParam := (lParam & 0xFF) <<16 | (lParam & 0xFF00) | (lParam >>16) : null
            __isHexColor(wParam, msg) ? wParam := (wParam & 0xFF) <<16 | (wParam & 0xFF00) | (wParam >>16) : null

            res := __sendEditor(this.hwnd, msg, wParam, lParam)

            ; Retrieve Text from buffer
            ; I must switch lParam to another variable when using GetTextRange because lParam cant be overwriten
            ; It has the pointer to the TextRange Structure
            buf ? (lParam := StrGet((msg = "GetTextRange") ? blParam : &lParam, "CP0"), buf:=false) : null ; convert the text from ANSI
            return res
        }
    }
}

class sciCharRange {

    __new(_cMin=0, _cMax=0){

        this.cMin := _cMin
        this.cMax := _cMax
    }
}
class sciTextRange {

    __new(_chrg=0, _pStr=0){

        if (!isObject(_chrg)){
            Msgbox % 0x0
                   , % "sciTextRange Object Error"
                   , % "The first parameter must match a sciCharRange object"
            Exit
        }

        this.chrg := _chrg ? _chrg : new sciCharRange
        this.pStr := _pStr
    }
}
class sciTextToFind {

    __new(_chrg=0, _text="", _found=0){

        if (!isObject(_chrg) || !isObject(_found)) {
            Msgbox % 0x0
                   , % "sciTextToFind Object Error"
                   , % "The first and last parameters must match a sciCharRange object"
            Exit
        }

        this.chrg   := _chrg ? _chrg : new sciCharRange
        this.text   := _text
        this.found  := _found ? _found : new sciCharRange
    }
}
class sciRectangle {

    __new(_left=0, _top=0, _right=0, _bottom=0){

        this.left    := _left
        this.top     := _top
        this.right   := _right
        this.bottom  := _bottom
    }
}
class sciRangeToFormat {

    __new(_hdc=0, _hdcTarget=0, _rc=0, _rcPage=0, _chrg=0){
        this.hdc         := _hdc                                        ; The Surface ID we print to
        this.hdcTarget   := _hdcTarget                                  ; The Surface ID we use for measuring (may be same as hdc)
        this.rc          := _rc ? _rc : new sciRectangle                ; Rectangle in which to print
        this.rcPage      := _rcPage ? _rcPage : new sciRectangle        ; Physically printable page size
        this.chrg        := _chrg ? _chrg : new sciCharRange            ; Range of characters to print
    }
}

; | Internal Functions |

/*
    Function: __Add
    Creates a Scintilla component and adds it to the Parent GUI.

    This function initializes the Scintilla Component.
    See <http://www.scintilla.org/Steps.html> for more information on how to add the component to a GUI/Control.

    Parameters:
    __Add(hParent, [x, y, w, h, DllPath, Styles])

    hParent     -   Hwnd of the parent control who will host the Scintilla Component
    x           -   x position for the control (default 5)
    y           -   y position for the control (default 5)
    w           -   Width of the control (default 590)
    h           -   Height of the control (default 390)
    DllPath     -   Path to the SciLexer.dll file, if omitted the function looks for it in *a_scriptdir*.
    Styles      -   List of window style variable names separated by spaces.
                    The WS_ prefix for the variables is optional.
                    Full list of Style names can be found at
                    <http://msdn.microsoft.com/en-us/library/czada357.aspx>.

    Returns:
    HWND        -   Component handle.

    Examples:
    (start code)
    #include ..\SCI.ahk
    #singleinstance force

    ;---------------------
    ; This script adds a component with default values.
    ; If no path was specified when creating the object it expects scilexer.dll to be on the script's location.
    ; The default values are calculated to fit optimally on a 600x400 GUI/Control

    Gui +LastFound
    sci := new scintilla(WinExist())

    Gui, show, w600 h400
    return

    GuiClose:
        exitapp

    ;---------------------
    #include ..\SCI.ahk
    #singleinstance force

    ; Add multiple components.

    Gui +LastFound
    hwnd:=WinExist()

    sci1 := new scintilla(hwnd, 0, 0, 590, 190) ; you can put the parameters here
    sci2 := new scintilla

    sci2.add(hwnd, 0, 200, 590, 190) ; or you can use the add function like this

    Gui, show, w600 h400
    return

    GuiClose:
        exitapp

    ;---------------------
    #include ..\SCI.ahk
    #singleinstance force

    ; Here we add a component embedded in a tab.
    ; If the variables "x,w,h" are empty the default values are used.

    Gui, add, Tab2, HWNDhwndtab x0 y0 w600 h420 gtabHandler vtabLast,one|two

    sci := new scintilla
    sci.Add(hwndtab, x, 25, w, h, a_scriptdir "\scilexer.dll")

    Gui, show, w600 h420
    return

    ; This additional code is for hiding/showing the component depending on which tab is open
    ; In this example the Tab named "one" is the one that contains the control.
    ; If you switch the words "show" and "hide" the component will be shown when the tab called "two" is active.

    tabHandler:                                 ; Tab Handler for the Scintilla Control
    Gui, submit, Nohide
    action := tabLast = "one" ? "Show" : "Hide" ; decide which action to take
    Control,%action%,,, % "ahk_id " sci.hwnd
    return

    GuiClose:
        exitapp
    (end)
*/
__Add(hParent=0, x=5, y=5, w=590, h=390, DllPath="", Styles=""){
    static WS_OVERLAPPED:=0x00000000,WS_POPUP:=0x80000000,WS_CHILD:=0x40000000,WS_MINIMIZE:=0x20000000
    ,WS_VISIBLE:=0x10000000,WS_DISABLED:=0x08000000,WS_CLIPSIBLINGS:=0x04000000,WS_CLIPCHILDREN:=0x02000000
    ,WS_MAXIMIZE:=0x01000000,WS_CAPTION:=0x00C00000,WS_BORDER:=0x00800000,WS_DLGFRAME:=0x00400000
    ,WS_VSCROLL:=0x00200000,WS_HSCROLL:=0x00100000,WS_SYSMENU:=0x00080000,WS_THICKFRAME:=0x00040000
    ,WS_GROUP:=0x00020000,WS_TABSTOP:=0x00010000,WS_MINIMIZEBOX:=0x00020000,WS_MAXIMIZEBOX:=0x00010000
    ,WS_TILED:=0x00000000,WS_ICONIC:=0x20000000,WS_SIZEBOX:=0x00040000,WS_EX_CLIENTEDGE:=0x00000200
    ,GuiID:=311210,init:=false, null:=0

    DllPath := !DllPath ? "SciLexer.dll" : inStr(DllPath, ".dll") ? DllPath : DllPath "\SciLexer.dll"
    if !init        ;  WM_NOTIFY = 0x4E
        old:=OnMessage(0x4E,"__sciNotify"),init:=true

    if !SCIModule:=DllCall("LoadLibrary", "Str", DllPath)
        return debug ? A_ThisFunc "> Could not load library: " DllPath : 1

    hStyle := WS_CHILD | (VISIBILITY := InStr(Styles, "Hidden") ? 0 : WS_VISIBLE) | WS_TABSTOP

    if Styles
        Loop, Parse, Styles, %a_tab%%a_space%, %a_tab%%a_space%
            hStyle |= %a_loopfield%+0 ? %a_loopfield% : WS_%a_loopfield% ? WS_%a_loopfield% : 0

    hSci:=DllCall("CreateWindowEx"
                 ,Uint ,WS_EX_CLIENTEDGE                ; Ex Style
                 ,Str  ,"Scintilla"                     ; Class Name
                 ,Str  ,""                              ; Window Name
                 ,UInt ,hStyle                          ; Window Styles
                 ,Int  ,x ? x : 5                       ; x
                 ,Int  ,y ? y : 5                       ; y
                 ,Int  ,w ? w : 590                     ; Width
                 ,Int  ,h ? h : 390                     ; Height
                 ,UInt ,hParent ? hParent : WinExist()  ; Parent HWND
                 ,UInt ,GuiID                           ; (HMENU)GuiID
                 ,UInt ,null                            ; hInstance
                 ,UInt ,null, "UInt")                   ; lpParam

                 ,__sendEditor(hSci)                    ; initialize sendEditor function

    return hSci
}

/*
    Function : __sendEditor
    Posts the messages used to modify the control's behaviour.

    *This is an internal function and it is not needed in normal situations. Please use the scintilla object to call all functions.
    They call this function automatically*

    Parameters:
    __sendEditor(hwnd, msg, [wParam, lParam])

    hwnd    -   The hwnd of the control that you want to operate on. Useful for when you have more than 1
                Scintilla components in the same script. The wrapper will remember the last used hwnd,
                so you can specify it once and only specify it again when you want to operate on a different
                component.
                *Note: This is converted internally by the wrapper from the object calling method. It is recommended that you dont use this function.*
    msg     -   The message to be posted, full list can be found here:
                <http://www.scintilla.org/ScintillaDoc.html>
    wParam  -   wParam for the message
    lParam  -   lParam for the message

    Returns:
    Status code of the DllCall performed.

    Examples:
    (Start Code)
    __sendEditor(hSci1, "SCI_SETMARGINWIDTHN",0,40)  ; Set the margin 0 to 40px on the first component.
    __sendEditor(0, "SCI_SETWRAPMODE",1,0)           ; Set wrap mode to true on the last used component.
    __sendEditor(hSci2, "SCI_SETMARGINWIDTHN",0,50)  ; Set the margin 0 to 50px on the second component.
    (End)
*/
__sendEditor(hwnd, msg=0, wParam=0, lParam=0){
    static

    hwnd := !hwnd ? oldhwnd : hwnd, oldhwnd := hwnd, msg := !(msg+0) ? "SCI_" msg : msg

    if !%hwnd%_df
	{
        SendMessage, SCI_GETDIRECTFUNCTION,0,0,,ahk_id %hwnd%
        %hwnd%_df := ErrorLevel
        SendMessage, SCI_GETDIRECTPOINTER,0,0,,ahk_id %hwnd%
        %hwnd%_dp := ErrorLevel
	}

    if !msg && !wParam && !lParam   ; called only with the hwnd param from SCI_Add
        return                      ; Exit because we did what we needed to do already.

    ; The fast way to control Scintilla
    return DllCall(%hwnd%_df            ; DIRECT FUNCTION
                  ,"UInt" ,%hwnd%_dp    ; DIRECT POINTER
                  ,"UInt" ,!(msg+0) ? %msg% : msg
                  ,"Int"  ,inStr(wParam, "-") ? wParam : (%wParam%+0 ? %wParam% : wParam) ; handles negative ints
                  ,"Int"  ,%lParam%+0 ? %lParam% : lParam)
}

/*
    Function : __sciNotify
    This is the default function which will be called when the WM_NOTIFY message has been received. The message is tracked as soon as you
    add a new scintilla component.


    Parameters:
    __sciNotify(wParam, lParam, msg, hwnd)

    wParam  -   wParam for the message
    lParam  -   lParam for the message
    msg     -   The message which triggered this function
    hwnd    -   The hwnd of the control which sent the message

    Returns:
    This function sets some variables on the sciObject to which the component belongs to and procedes to call your user defined notify function
    which can be set in sciObj.notify.

    It will pass wParam, lParam, msg and hwnd to that function so make sure you define it that way.
    Returns nothing.

    Examples:
*/
__sciNotify(wParam, lParam, msg, hwnd){

    ; fix int for x64 bit systems
    __sciObj                 := __SCI(NumGet(lParam + 0))               ; Returns original object
    __sciObj.idFrom          := NumGet(lParam + a_Ptrsize * 1)
    __sciObj.scnCode         := NumGet(lParam + a_Ptrsize * 2)

    __sciObj.position        := NumGet(lParam + a_Ptrsize * 3)
    __sciObj.ch              := NumGet(lParam + a_Ptrsize * 4)
    __sciObj.modifiers       := NumGet(lParam + a_Ptrsize * 5)
    __sciObj.modType         := NumGet(lParam + a_Ptrsize * 6)
    __sciObj.text            := NumGet(lParam + a_Ptrsize * 7)
    __sciObj.length          := NumGet(lParam + a_Ptrsize * 8)
    __sciObj.linesAdded      := NumGet(lParam + a_Ptrsize * 9)

    __sciObj.macMessage      := NumGet(lParam + a_Ptrsize * 10)
    __sciObj.macwParam       := NumGet(lParam + a_Ptrsize * 11)
    __sciObj.maclParam       := NumGet(lParam + a_Ptrsize * 12)

    __sciObj.line            := NumGet(lParam + a_Ptrsize * 13)
    __sciObj.foldLevelNow    := NumGet(lParam + a_Ptrsize * 14)
    __sciObj.foldLevelPrev   := NumGet(lParam + a_Ptrsize * 15)
    __sciObj.margin          := NumGet(lParam + a_Ptrsize * 16)
    __sciObj.listType        := NumGet(lParam + a_Ptrsize * 17)
    __sciObj.x               := NumGet(lParam + a_Ptrsize * 18)
    __sciObj.y               := NumGet(lParam + a_Ptrsize * 19)

    __sciObj.token           := NumGet(lParam + a_Ptrsize * 20)
    __sciObj.annotLinesAdded := NumGet(lParam + a_Ptrsize * 21)
    __sciObj.updated         := NumGet(lParam + a_Ptrsize * 22)

    __sciObj.notify(wParam, lParam, msg, hwnd, __sciObj)                ; Call user defined Notify Function and passes object to it as last parameter
    return __sciObj := ""                                               ; free object
}

__isHexColor(hex, msg){
    if (RegexMatch(hex, "^0x[0-9a-fA-F]{6}$"))
        return true
    else
        return false
}

__SCI(var, val=""){
    static

    if (RegExMatch(var,"i)[ `n-\.%,(\\\/=&^]")) ; Check if it is a valid variable name
        return

	lvar := %var%, val ? %var% := val : null
    return lvar
}

; Global scintilla variables
{
global INVALID_POSITION:=-1, unused := 0 ; Some messages dont use one of their parameters. You can use this variable for them.

; Main Scintilla Functions
{
global SCI_ADDTEXT:=2001,SCI_ADDSTYLEDTEXT:=2002,SCI_INSERTTEXT:=2003,SCI_CLEARALL:=2004,SCI_CLEARDOCUMENTSTYLE:=2005,SCI_GETLENGTH:=2006
,SCI_GETCHARAT:=2007,SCI_GETCURRENTPOS:=2008,SCI_GETANCHOR:=2009,SCI_GETSTYLEAT:=2010,SCI_REDO:=2011,SCI_SETUNDOCOLLECTION:=2012
,SCI_SELECTALL:=2013,SCI_SETSAVEPOINT:=2014,SCI_GETSTYLEDTEXT:=2015,SCI_CANREDO:=2016,SCI_MARKERLINEFROMHANDLE:=2017
,SCI_MARKERDELETEHANDLE:=2018,SCI_GETUNDOCOLLECTION:=2019,SCI_GETVIEWWS:=2020,SCI_SETVIEWWS:=2021,SCI_POSITIONFROMPOINT:=2022
,SCI_POSITIONFROMPOINTCLOSE:=2023,SCI_GOTOLINE:=2024,SCI_GOTOPOS:=2025,SCI_SETANCHOR:=2026,SCI_GETCURLINE:=2027,SCI_GETENDSTYLED:=2028
,SCI_CONVERTEOLS:=2029,SCI_GETEOLMODE:=2030,SCI_SETEOLMODE:=2031,SCI_STARTSTYLING:=2032,SCI_SETSTYLING:=2033,SCI_GETBUFFEREDDRAW:=2034
,SCI_SETBUFFEREDDRAW:=2035,SCI_SETTABWIDTH:=2036,SCI_GETTABWIDTH:=2121,SCI_SETCODEPAGE:=2037,SCI_SETUSEPALETTE:=2039,SCI_MARKERDEFINE:=2040
,SCI_MARKERSETFORE:=2041,SCI_MARKERSETBACK:=2042,SCI_MARKERADD:=2043,SCI_MARKERDELETE:=2044,SCI_MARKERDELETEALL:=2045,SCI_MARKERGET:=2046
,SCI_MARKERNEXT:=2047,SCI_MARKERPREVIOUS:=2048,SCI_MARKERDEFINEPIXMAP:=2049,SCI_MARKERADDSET:=2466,SCI_MARKERSETALPHA:=2476
,SCI_SETMARGINTYPEN:=2240,SCI_GETMARGINTYPEN:=2241,SCI_SETMARGINWIDTHN:=2242,SCI_GETMARGINWIDTHN:=2243,SCI_SETMARGINMASKN:=2244
,SCI_GETMARGINMASKN:=2245,SCI_SETMARGINSENSITIVEN:=2246,SCI_GETMARGINSENSITIVEN:=2247,SCI_STYLECLEARALL:=2050,SCI_STYLESETFORE:=2051
,SCI_STYLESETBACK:=2052,SCI_STYLESETBOLD:=2053,SCI_STYLESETITALIC:=2054,SCI_STYLESETSIZE:=2055,SCI_STYLESETFONT:=2056
,SCI_STYLESETEOLFILLED:=2057,SCI_STYLEGETFORE:=2481,SCI_STYLEGETBACK:=2482,SCI_STYLEGETBOLD:=2483,SCI_STYLEGETITALIC:=2484
,SCI_STYLEGETSIZE:=2485,SCI_STYLEGETFONT:=2486,SCI_STYLEGETEOLFILLED:=2487,SCI_STYLEGETUNDERLINE:=2488,SCI_STYLEGETCASE:=2489
,SCI_STYLEGETCHARACTERSET:=2490,SCI_STYLEGETVISIBLE:=2491,SCI_STYLEGETCHANGEABLE:=2492,SCI_STYLEGETHOTSPOT:=2493,SCI_STYLERESETDEFAULT:=2058
,SCI_STYLESETUNDERLINE:=2059,SCI_STYLESETCASE:=2060,SCI_STYLESETCHARACTERSET:=2066,SCI_STYLESETHOTSPOT:=2409,SCI_SETSELFORE:=2067
,SCI_SETSELBACK:=2068,SCI_GETSELALPHA:=2477,SCI_SETSELALPHA:=2478,SCI_SETCARETFORE:=2069,SCI_ASSIGNCMDKEY:=2070,SCI_CLEARCMDKEY:=2071
,SCI_CLEARALLCMDKEYS:=2072,SCI_SETSTYLINGEX:=2073,SCI_STYLESETVISIBLE:=2074,SCI_GETCARETPERIOD:=2075,SCI_SETCARETPERIOD:=2076
,SCI_SETWORDCHARS:=2077,SCI_BEGINUNDOACTION:=2078,SCI_ENDUNDOACTION:=2079,SCI_INDICSETSTYLE:=2080,SCI_INDICGETSTYLE:=2081
,SCI_INDICSETFORE:=2082,SCI_INDICGETFORE:=2083,SCI_SETWHITESPACEFORE:=2084,SCI_SETWHITESPACEBACK:=2085,SCI_SETSTYLEBITS:=2090
,SCI_GETSTYLEBITS:=2091,SCI_SETLINESTATE:=2092,SCI_GETLINESTATE:=2093,SCI_GETMAXLINESTATE:=2094,SCI_GETCARETLINEVISIBLE:=2095
,SCI_SETCARETLINEVISIBLE:=2096,SCI_GETCARETLINEBACK:=2097,SCI_SETCARETLINEBACK:=2098,SCI_STYLESETCHANGEABLE:=2099,SCI_AUTOCSHOW:=2100
,SCI_AUTOCCANCEL:=2101,SCI_AUTOCACTIVE:=2102,SCI_AUTOCPOSSTART:=2103,SCI_AUTOCCOMPLETE:=2104,SCI_AUTOCSTOPS:=2105
,SCI_AUTOCSETSEPARATOR:=2106,SCI_AUTOCGETSEPARATOR:=2107,SCI_AUTOCSELECT:=2108,SCI_AUTOCSETCANCELATSTART:=2110
,SCI_AUTOCGETCANCELATSTART:=2111,SCI_AUTOCSETFILLUPS:=2112,SCI_AUTOCSETCHOOSESINGLE:=2113,SCI_AUTOCGETCHOOSESINGLE:=2114
,SCI_AUTOCSETIGNORECASE:=2115,SCI_AUTOCGETIGNORECASE:=2116,SCI_USERLISTSHOW:=2117,SCI_AUTOCSETAUTOHIDE:=2118,SCI_AUTOCGETAUTOHIDE:=2119
,SCI_AUTOCSETDROPRESTOFWORD:=2270,SCI_AUTOCGETDROPRESTOFWORD:=2271,SCI_REGISTERIMAGE:=2405,SCI_CLEARREGISTEREDIMAGES:=2408
,SCI_AUTOCGETTYPESEPARATOR:=2285,SCI_AUTOCSETTYPESEPARATOR:=2286,SCI_AUTOCSETMAXWIDTH:=2208,SCI_AUTOCGETMAXWIDTH:=2209
,SCI_AUTOCSETMAXHEIGHT:=2210,SCI_AUTOCGETMAXHEIGHT:=2211,SCI_SETINDENT:=2122,SCI_GETINDENT:=2123,SCI_SETUSETABS:=2124,SCI_GETUSETABS:=2125
,SCI_SETLINEINDENTATION:=2126,SCI_GETLINEINDENTATION:=2127,SCI_GETLINEINDENTPOSITION:=2128,SCI_GETCOLUMN:=2129,SCI_SETHSCROLLBAR:=2130
,SCI_GETHSCROLLBAR:=2131,SCI_SETINDENTATIONGUIDES:=2132,SCI_GETINDENTATIONGUIDES:=2133,SCI_SETHIGHLIGHTGUIDE:=2134
,SCI_GETHIGHLIGHTGUIDE:=2135,SCI_GETLINEENDPOSITION:=2136,SCI_GETCODEPAGE:=2137,SCI_GETCARETFORE:=2138,SCI_GETUSEPALETTE:=2139
,SCI_GETREADONLY:=2140,SCI_SETCURRENTPOS:=2141,SCI_SETSELECTIONSTART:=2142,SCI_GETSELECTIONSTART:=2143,SCI_SETSELECTIONEND:=2144
,SCI_GETSELECTIONEND:=2145,SCI_SETPRINTMAGNIFICATION:=2146,SCI_GETPRINTMAGNIFICATION:=2147,SCI_SETPRINTCOLORMODE:=2148
,SCI_GETPRINTCOLORMODE:=2149,SCI_FINDTEXT:=2150,SCI_FORMATRANGE:=2151,SCI_GETFIRSTVISIBLELINE:=2152,SCI_GETLINE:=2153
,SCI_GETLINECOUNT:=2154,SCI_SETMARGINLEFT:=2155,SCI_GETMARGINLEFT:=2156,SCI_SETMARGINRIGHT:=2157,SCI_GETMARGINRIGHT:=2158
,SCI_GETMODIFY:=2159,SCI_SETSEL:=2160,SCI_GETSELTEXT:=2161,SCI_GETTEXTRANGE:=2162,SCI_HIDESELECTION:=2163,SCI_POINTXFROMPOSITION:=2164
,SCI_POINTYFROMPOSITION:=2165,SCI_LINEFROMPOSITION:=2166,SCI_POSITIONFROMLINE:=2167,SCI_LINESCROLL:=2168,SCI_SCROLLCARET:=2169
,SCI_REPLACESEL:=2170,SCI_SETREADONLY:=2171,SCI_NULL:=2172,SCI_CANPASTE:=2173,SCI_CANUNDO:=2174,SCI_EMPTYUNDOBUFFER:=2175,SCI_UNDO:=2176
,SCI_CUT:=2177,SCI_COPY:=2178,SCI_PASTE:=2179,SCI_CLEAR:=2180,SCI_SETTEXT:=2181,SCI_GETTEXT:=2182,SCI_GETTEXTLENGTH:=2183
,SCI_GETDIRECTFUNCTION:=2184,SCI_GETDIRECTPOINTER:=2185,SCI_SETOVERTYPE:=2186,SCI_GETOVERTYPE:=2187,SCI_SETCARETWIDTH:=2188
,SCI_GETCARETWIDTH:=2189,SCI_SETTARGETSTART:=2190,SCI_GETTARGETSTART:=2191,SCI_SETTARGETEND:=2192,SCI_GETTARGETEND:=2193
,SCI_REPLACETARGET:=2194,SCI_REPLACETARGETRE:=2195,SCI_SEARCHINTARGET:=2197,SCI_SETSEARCHFLAGS:=2198,SCI_GETSEARCHFLAGS:=2199
,SCI_CALLTIPSHOW:=2200,SCI_CALLTIPCANCEL:=2201,SCI_CALLTIPACTIVE:=2202,SCI_CALLTIPPOSSTART:=2203,SCI_CALLTIPSETHLT:=2204
,SCI_CALLTIPSETBACK:=2205,SCI_CALLTIPSETFORE:=2206,SCI_CALLTIPSETFOREHLT:=2207,SCI_CALLTIPUSESTYLE:=2212,SCI_VISIBLEFROMDOCLINE:=2220
,SCI_DOCLINEFROMVISIBLE:=2221,SCI_WRAPCOUNT:=2235,SCI_SETFOLDLEVEL:=2222,SCI_GETFOLDLEVEL:=2223,SCI_GETLASTCHILD:=2224
,SCI_GETFOLDPARENT:=2225,SCI_SHOWLINES:=2226,SCI_HIDELINES:=2227,SCI_GETLINEVISIBLE:=2228,SCI_SETFOLDEXPANDED:=2229
,SCI_GETFOLDEXPANDED:=2230,SCI_TOGGLEFOLD:=2231,SCI_ENSUREVISIBLE:=2232,SCI_SETFOLDFLAGS:=2233,SCI_ENSUREVISIBLEENFORCEPOLICY:=2234
,SCI_SETTABINDENTS:=2260,SCI_GETTABINDENTS:=2261,SCI_SETBACKSPACEUNINDENTS:=2262,SCI_GETBACKSPACEUNINDENTS:=2263,SCI_SETMOUSEDWELLTIME:=2264
,SCI_GETMOUSEDWELLTIME:=2265,SCI_WORDSTARTPOSITION:=2266,SCI_WORDENDPOSITION:=2267,SCI_SETWRAPMODE:=2268,SCI_GETWRAPMODE:=2269
,SCI_SETWRAPVISUALFLAGS:=2460,SCI_GETWRAPVISUALFLAGS:=2461,SCI_SETWRAPVISUALFLAGSLOCATION:=2462,SCI_GETWRAPVISUALFLAGSLOCATION:=2463
,SCI_SETWRAPSTARTINDENT:=2464,SCI_GETWRAPSTARTINDENT:=2465,SCI_SETLAYOUTCACHE:=2272,SCI_GETLAYOUTCACHE:=2273,SCI_SETSCROLLWIDTH:=2274
,SCI_GETSCROLLWIDTH:=2275,SCI_TEXTWIDTH:=2276,SCI_SETENDATLASTLINE:=2277,SCI_GETENDATLASTLINE:=2278,SCI_TEXTHEIGHT:=2279
,SCI_SETVSCROLLBAR:=2280,SCI_GETVSCROLLBAR:=2281,SCI_APPENDTEXT:=2282,SCI_GETTWOPHASEDRAW:=2283,SCI_SETTWOPHASEDRAW:=2284
,SCI_TARGETFROMSELECTION:=2287,SCI_LINESJOIN:=2288,SCI_LINESSPLIT:=2289,SCI_SETFOLDMARGINCOLOR:=2290,SCI_SETFOLDMARGINHICOLOR:=2291
,SCI_ZOOMIN:=2333,SCI_ZOOMOUT:=2334,SCI_MOVECARETINSIDEVIEW:=2401,SCI_LINELENGTH:=2350,SCI_BRACEHIGHLIGHT:=2351,SCI_BRACEBADLIGHT:=2352
,SCI_BRACEMATCH:=2353,SCI_GETVIEWEOL:=2355,SCI_SETVIEWEOL:=2356,SCI_GETDOCPOINTER:=2357,SCI_SETDOCPOINTER:=2358,SCI_SETMODEVENTMASK:=2359
,SCI_GETEDGECOLUMN:=2360,SCI_SETEDGECOLUMN:=2361,SCI_GETEDGEMODE:=2362,SCI_SETEDGEMODE:=2363,SCI_GETEDGECOLOR:=2364,SCI_SETEDGECOLOR:=2365
,SCI_SEARCHANCHOR:=2366,SCI_SEARCHNEXT:=2367,SCI_SEARCHPREV:=2368,SCI_LINESONSCREEN:=2370,SCI_USEPOPUP:=2371,SCI_SELECTIONISRECTANGLE:=2372
,SCI_SETZOOM:=2373,SCI_GETZOOM:=2374,SCI_CREATEDOCUMENT:=2375,SCI_ADDREFDOCUMENT:=2376,SCI_RELEASEDOCUMENT:=2377,SCI_GETMODEVENTMASK:=2378
,SCI_SETFOCUS:=2380,SCI_GETFOCUS:=2381,SCI_SETSTATUS:=2382,SCI_GETSTATUS:=2383,SCI_SETMOUSEDOWNCAPTURES:=2384,SCI_GETMOUSEDOWNCAPTURES:=2385
,SCI_SETCURSOR:=2386,SCI_GETCURSOR:=2387,SCI_SETCONTROLCHARSYMBOL:=2388,SCI_GETCONTROLCHARSYMBOL:=2389,SCI_SETVISIBLEPOLICY:=2394
,SCI_SETXOFFSET:=2397,SCI_GETXOFFSET:=2398,SCI_CHOOSECARETX:=2399,SCI_GRABFOCUS:=2400,SCI_SETXCARETPOLICY:=2402,SCI_SETYCARETPOLICY:=2403
,SCI_SETPRINTWRAPMODE:=2406,SCI_GETPRINTWRAPMODE:=2407,SCI_SETHOTSPOTACTIVEFORE:=2410,SCI_SETHOTSPOTACTIVEBACK:=2411
,SCI_SETHOTSPOTACTIVEUNDERLINE:=2412,SCI_SETHOTSPOTSINGLELINE:=2421,SCI_POSITIONBEFORE:=2417,SCI_POSITIONAFTER:=2418
,SCI_COPYRANGE:=2419,SCI_COPYTEXT:=2420,SCI_SETSELECTIONMODE:=2422,SCI_GETSELECTIONMODE:=2423,SCI_GETLINESELSTARTPOSITION:=2424
,SCI_GETLINESELENDPOSITION:=2425,SCI_SETWHITESPACECHARS:=2443,SCI_SETCHARSDEFAULT:=2444,SCI_AUTOCGETCURRENT:=2445,SCI_ALLOCATE:=2446
,SCI_TARGETASUTF8:=2447,SCI_SETLENGTHFORENCODE:=2448,SCI_ENCODEDFROMUTF8:=2449,SCI_FINDCOLUMN:=2456,SCI_GETCARETSTICKY:=2457
,SCI_SETCARETSTICKY:=2458,SCI_TOGGLECARETSTICKY:=2459,SCI_SETPASTECONVERTENDINGS:=2467,SCI_GETPASTECONVERTENDINGS:=2468
,SCI_SETCARETLINEBACKALPHA:=2470,SCI_GETCARETLINEBACKALPHA:=2471,SCI_STARTRECORD:=3001,SCI_STOPRECORD:=3002,SCI_SETLEXER:=4001
,SCI_GETLEXER:=4002,SCI_COLORISE:=4003,SCI_SETPROPERTY:=4004,SCI_SETKEYWORDS:=4005,SCI_SETLEXERLANGUAGE:=4006,SCI_LOADLEXERLIBRARY:=4007
,SCI_GETPROPERTY:=4008,SCI_GETPROPERTYEXPANDED:=4009,SCI_GETPROPERTYINT:=4010,SCI_GETSTYLEBITSNEEDED:=4011
}

; Styles, Markers and Indicators
{
global MARKER_MAX:=31,STYLE_DEFAULT:=32,STYLE_LINENUMBER:=33,STYLE_BRACELIGHT:=34,STYLE_BRACEBAD:=35,STYLE_CONTROLCHAR:=36
,STYLE_INDENTGUIDE:=37,STYLE_CALLTIP:=38,STYLE_LASTPREDEFINED:=39,STYLE_MAX:=127,INDIC_MAX:=7,INDIC_PLAIN:=0,INDIC_SQUIGGLE:=1,INDIC_TT:=2
,INDIC_DIAGONAL:=3,INDIC_STRIKE:=4,INDIC_HIDDEN:=5,INDIC_BOX:=6,INDIC_ROUNDBOX:=7,INDIC0_MASK:=0x20,INDIC1_MASK:=0x40,INDIC2_MASK:=0x80
,INDICS_MASK:=0xE0,SCI_START:=2000,SCI_OPTIONAL_START:=3000,SCI_LEXER_START:=4000,SCWS_INVISIBLE:=0,SCWS_VISIBLEALWAYS:=1
,SCWS_VISIBLEAFTERINDENT:=2,SC_EOL_CRLF:=0,SC_EOL_CR:=1,SC_EOL_LF:=2,SC_CP_UTF8:=65001,SC_CP_DBCS:=1,SC_MARK_CIRCLE:=0,SC_MARK_ROUNDRECT:=1
,SC_MARK_ARROW:=2,SC_MARK_SMALLRECT:=3,SC_MARK_SHORTARROW:=4,SC_MARK_EMPTY:=5,SC_MARK_ARROWDOWN:=6,SC_MARK_MINUS:=7,SC_MARK_PLUS:=8
,SC_MARK_VLINE:=9,SC_MARK_LCORNER:=10,SC_MARK_TCORNER:=11,SC_MARK_BOXPLUS:=12,SC_MARK_BOXPLUSCONNECTED:=13,SC_MARK_BOXMINUS:=14
,SC_MARK_BOXMINUSCONNECTED:=15,SC_MARK_LCORNERCURVE:=16,SC_MARK_TCORNERCURVE:=17,SC_MARK_CIRCLEPLUS:=18,SC_MARK_CIRCLEPLUSCONNECTED:=19
,SC_MARK_CIRCLEMINUS:=20,SC_MARK_CIRCLEMINUSCONNECTED:=21,SC_MARK_BACKGROUND:=22,SC_MARK_DOTDOTDOT:=23,SC_MARK_ARROWS:=24
,SC_MARK_PIXMAP:=25,SC_MARK_FULLRECT:=26,SC_MARK_CHARACTER:=10000,SC_MARKNUM_FOLDEREND:=25,SC_MARKNUM_FOLDEROPENMID:=26
,SC_MARKNUM_FOLDERMIDTAIL:=27,SC_MARKNUM_FOLDERTAIL:=28,SC_MARKNUM_FOLDERSUB:=29,SC_MARKNUM_FOLDER:=30,SC_MARKNUM_FOLDEROPEN:=31
,SC_MASK_FOLDERS:=0xFE000000,SC_MARGIN_SYMBOL:=0,SC_MARGIN_NUMBER:=1
}

; Character Sets and Printing
{
global SC_CHARSET_ANSI:=0,SC_CHARSET_DEFAULT:=1,SC_CHARSET_BALTIC:=186
,SC_CHARSET_CHINESEBIG5:=136,SC_CHARSET_EASTEUROPE:=238,SC_CHARSET_GB2312:=134,SC_CHARSET_GREEK:=161,SC_CHARSET_HANGUL:=129
,SC_CHARSET_MAC:=77,SC_CHARSET_OEM:=255,SC_CHARSET_RUSSIAN:=204,SC_CHARSET_CYRILLIC:=1251,SC_CHARSET_SHIFTJIS:=128
,SC_CHARSET_SYMBOL:=2,SC_CHARSET_TURKISH:=162,SC_CHARSET_JOHAB:=130,SC_CHARSET_HEBREW:=177,SC_CHARSET_ARABIC:=178,SC_CHARSET_VIETNAMESE:=163
,SC_CHARSET_THAI:=222,SC_CHARSET_8859_15:=1000, SC_CASE_MIXED:=0,SC_CASE_UPPER:=1,SC_CASE_LOWER:=2,SC_PRINT_NORMAL:=0,SC_PRINT_INVERTLIGHT:=1
,SC_PRINT_BLACKONWHITE:=2,SC_PRINT_COLORONWHITE:=3,SC_PRINT_COLORONWHITEDEFAULTBG:=4
}

; Search Flags
{
global SCFIND_WHOLEWORD:=2,SCFIND_MATCHCASE:=4
,SCFIND_WORDSTART:=0x00100000,SCFIND_REGEXP:=0x00200000,SCFIND_POSIX:=0x00400000
}

; Folding
{
global SC_FOLDLEVELBASE:=0x400,SC_FOLDLEVELWHITEFLAG:=0x1000
,SC_FOLDLEVELHEADERFLAG:=0x2000,SC_FOLDLEVELBOXHEADERFLAG:=0x4000,SC_FOLDLEVELBOXFOOTERFLAG:=0x8000,SC_FOLDLEVELCONTRACTED:=0x10000
,SC_FOLDLEVELUNINDENT:=0x20000,SC_FOLDLEVELNUMBERMASK:=0x0FFF,SC_FOLDFLAG_LINEBEFORE_EXPANDED:=0x0002,SC_FOLDFLAG_LINEBEFORE_CONTRACTED:=0x0004
,SC_FOLDFLAG_LINEAFTER_EXPANDED:=0x0008,SC_FOLDFLAG_LINEAFTER_CONTRACTED:=0x0010,SC_FOLDFLAG_LEVELNUMBERS:=0x0040,SC_FOLDFLAG_BOX:=0x0001
}

; Keys
{
global SCMOD_NORM:=0, SCMOD_SHIFT:=1,SCMOD_CTRL:=2,SCMOD_ALT:=4, SCK_DOWN:=300,SCK_UP:=301,SCK_LEFT:=302,SCK_RIGHT:=303,SCK_HOME:=304,SCK_END:=305
,SCK_PRIOR:=306,SCK_NEXT:=307,SCK_DELETE:=308,SCK_INSERT:=309,SCK_ESCAPE:=7,SCK_BACK:=8,SCK_TAB:=9,SCK_RETURN:=13,SCK_ADD:=310,SCK_SUBTRACT:=311
,SCK_DIVIDE:=312
}

; Lexing
{
global SCLEX_CONTAINER:=0,SCLEX_NULL:=1,SCLEX_PYTHON:=2,SCLEX_CPP:=3,SCLEX_HTML:=4,SCLEX_XML:=5,SCLEX_PERL:=6,SCLEX_SQL:=7,SCLEX_VB:=8
,SCLEX_PROPERTIES:=9,SCLEX_ERRORLIST:=10,SCLEX_MAKEFILE:=11,SCLEX_BATCH:=12,SCLEX_XCODE:=13,SCLEX_LATEX:=14,SCLEX_LUA:=15,SCLEX_DIFF:=16
,SCLEX_CONF:=17,SCLEX_PASCAL:=18,SCLEX_AVE:=19,SCLEX_ADA:=20,SCLEX_LISP:=21,SCLEX_RUBY:=22,SCLEX_EIFFEL:=23,SCLEX_EIFFELKW:=24
,SCLEX_TCL:=25,SCLEX_NNCRONTAB:=26,SCLEX_BULLANT:=27,SCLEX_VBSCRIPT:=28,SCLEX_BAAN:=31,SCLEX_MATLAB:=32,SCLEX_SCRIPTOL:=33
,SCLEX_ASM:=34,SCLEX_CPPNOCASE:=35,SCLEX_FORTRAN:=36,SCLEX_F77:=37,SCLEX_CSS:=38,SCLEX_POV:=39,SCLEX_LOUT:=40,SCLEX_ESCRIPT:=41
,SCLEX_PS:=42,SCLEX_NSIS:=43,SCLEX_MMIXAL:=44,SCLEX_CLW:=45,SCLEX_CLWNOCASE:=46,SCLEX_LOT:=47,SCLEX_YAML:=48,SCLEX_TEX:=49
,SCLEX_METAPOST:=50,SCLEX_POWERBASIC:=51,SCLEX_FORTH:=52,SCLEX_ERLANG:=53,SCLEX_OCTAVE:=54,SCLEX_MSSQL:=55,SCLEX_VERILOG:=56,SCLEX_KIX:=57
,SCLEX_GUI4CLI:=58,SCLEX_SPECMAN:=59,SCLEX_AU3:=60,SCLEX_APDL:=61,SCLEX_BASH:=62,SCLEX_ASN1:=63,SCLEX_VHDL:=64,SCLEX_CAML:=65
,SCLEX_BLITZBASIC:=66,SCLEX_PUREBASIC:=67,SCLEX_HASKELL:=68,SCLEX_PHPSCRIPT:=69,SCLEX_TADS3:=70,SCLEX_REBOL:=71,SCLEX_SMALLTALK:=72
,SCLEX_FLAGSHIP:=73,SCLEX_CSOUND:=74,SCLEX_FREEBASIC:=75,SCLEX_INNOSETUP:=76,SCLEX_OPAL:=77,SCLEX_SPICE:=78,SCLEX_D:=79,SCLEX_CMAKE:=80
,SCLEX_GAP:=81,SCLEX_PLM:=82,SCLEX_PROGRESS:=83,SCLEX_ABAQUS:=84,SCLEX_ASYMPTOTE:=85,SCLEX_R:=86,SCLEX_MAGIK:=87,SCLEX_POWERSHELL:=88
,SCLEX_MYSQL:=89,SCLEX_PO:=90,SCLEX_TAL:=91,SCLEX_COBOL:=92,SCLEX_TACL:=93,SCLEX_SORCUS:=94,SCLEX_POWERPRO:=95,SCLEX_NIMROD:=96,SCLEX_SML:=97
,SCLEX_MARKDOWN:=98,SCLEX_TXT2TAGS:=99,SCLEX_A68K:=100,SCLEX_MODULA:=101,SCLEX_COFFEESCRIPT:=102,SCLEX_TCMD:=103,SCLEX_AVS:=104,SCLEX_ECL:=105
,SCLEX_OSCRIPT:=106,SCLEX_VISUALPROLOG:=107,SCLEX_LITERATEHASKELL:=108,SCLEX_AHKL:=109
,SCE_AHKL_NEUTRAL:=0,SCE_AHKL_IDENTIFIER:=1,SCE_AHKL_COMMENTDOC:=2,SCE_AHKL_COMMENTLINE:=3,SCE_AHKL_COMMENTBLOCK:=4,SCE_AHKL_COMMENTKEYWORD:=5
,SCE_AHKL_STRING:=6,SCE_AHKL_STRINGOPTS:=7,SCE_AHKL_STRINGBLOCK:=8,SCE_AHKL_STRINGCOMMENT:=9,SCE_AHKL_LABEL:=10,SCE_AHKL_HOTKEY:=11
,SCE_AHKL_HOTSTRING:=12,SCE_AHKL_HOTSTRINGOPT:=13,SCE_AHKL_HEXNUMBER:=14,SCE_AHKL_DECNUMBER:=15,SCE_AHKL_VAR:=16,SCE_AHKL_VARREF:=17
,SCE_AHKL_OBJECT:=18,SCE_AHKL_USERFUNCTION:=19,SCE_AHKL_DIRECTIVE:=20,SCE_AHKL_COMMAND:=21,SCE_AHKL_PARAM:=22,SCE_AHKL_CONTROLFLOW:=23
,SCE_AHKL_BUILTINFUNCTION:=24,SCE_AHKL_BUILTINVAR:=25,SCE_AHKL_KEY:=26,SCE_AHKL_USERDEFINED1:=27,SCE_AHKL_USERDEFINED2:=28,SCE_AHKL_ESCAPESEQ:=30
,SCE_AHKL_ERROR:=31,AHKL_LIST_DIRECTIVES:=0,AHKL_LIST_COMMANDS:=1,AHKL_LIST_PARAMETERS:=2,AHKL_LIST_CONTROLFLOW:=3,AHKL_LIST_FUNCTIONS:=4
,AHKL_LIST_VARIABLES:=5,AHKL_LIST_KEYS:=6,AHKL_LIST_USERDEFINED1:=7,AHKL_LIST_USERDEFINED2:=8,SCLEX_AUTOMATIC=1000
}

; Notifications
{
global SCEN_CHANGE:=768,SCEN_SETFOCUS:=512,SCEN_KILLFOCUS:=256, SCN_STYLENEEDED:=2000,SCN_CHARADDED:=2001
,SCN_SAVEPOINTREACHED:=2002,SCN_SAVEPOINTLEFT:=2003,SCN_MODIFYATTEMPTRO:=2004,SCN_KEY:=2005,SCN_DOUBLECLICK:=2006,SCN_UPDATEUI:=2007
,SCN_MODIFIED:=2008,SCN_MACRORECORD:=2009,SCN_MARGINCLICK:=2010,SCN_NEEDSHOWN:=2011,SCN_PAINTED:=2013,SCN_USERLISTSELECTION:=2014
,SCN_URIDROPPED:=2015,SCN_DWELLSTART:=2016,SCN_DWELLEND:=2017,SCN_ZOOM:=2018,SCN_HOTSPOTCLICK:=2019,SCN_HOTSPOTDOUBLECLICK:=2020
,SCN_CALLTIPCLICK:=2021,SCN_AUTOCSELECTION:=2022
}

; Other
{
global SCI_LINEDOWN:=2300,SCI_LINEDOWNEXTEND:=2301,SCI_LINEDOWNRECTEXTEND:=2426
,SCI_LINESCROLLDOWN:=2342,SCI_LINEUP:=2302,SCI_LINEUPEXTEND:=2303,SCI_LINEUPRECTEXTEND:=2427,SCI_LINESCROLLUP:=2343,SCI_PARADOWN:=2413
,SCI_PARADOWNEXTEND:=2414,SCI_PARAUP:=2415,SCI_PARAUPEXTEND:=2416,SCI_CHARLEFT:=2304,SCI_CHARLEFTEXTEND:=2305,SCI_CHARLEFTRECTEXTEND:=2428
,SCI_CHARRIGHT:=2306,SCI_CHARRIGHTEXTEND:=2307,SCI_CHARRIGHTRECTEXTEND:=2429,SCI_WORDLEFT:=2308,SCI_WORDLEFTEXTEND:=2309,SCI_WORDRIGHT:=2310
,SCI_WORDRIGHTEXTEND:=2311,SCI_WORDLEFTEND:=2439,SCI_WORDLEFTENDEXTEND:=2440,SCI_WORDRIGHTEND:=2441,SCI_WORDRIGHTENDEXTEND:=2442
,SCI_WORDPARTLEFT:=2390,SCI_WORDPARTLEFTEXTEND:=2391,SCI_WORDPARTRIGHT:=2392,SCI_WORDPARTRIGHTEXTEND:=2393,SCI_HOME:=2312
,SCI_HOMEEXTEND:=2313,SCI_HOMERECTEXTEND:=2430,SCI_HOMEDISPLAY:=2345,SCI_HOMEDISPLAYEXTEND:=2346,SCI_HOMEWRAP:=2349
,SCI_HOMEWRAPEXTEND:=2450,SCI_VCHOME:=2331,SCI_VCHOMEEXTEND:=2332,SCI_VCHOMERECTEXTEND:=2431,SCI_VCHOMEWRAP:=2453,SCI_VCHOMEWRAPEXTEND:=2454
,SCI_LINEEND:=2314,SCI_LINEENDEXTEND:=2315,SCI_LINEENDRECTEXTEND:=2432,SCI_LINEENDDISPLAY:=2347,SCI_LINEENDDISPLAYEXTEND:=2348
,SCI_LINEENDWRAP:=2451,SCI_LINEENDWRAPEXTEND:=2452,SCI_DOCUMENTSTART:=2316,SCI_DOCUMENTSTARTEXTEND:=2317,SCI_DOCUMENTEND:=2318
,SCI_DOCUMENTENDEXTEND:=2319,SCI_PAGEUP:=2320,SCI_PAGEUPEXTEND:=2321,SCI_PAGEUPRECTEXTEND:=2433,SCI_PAGEDOWN:=2322,SCI_PAGEDOWNEXTEND:=2323
,SCI_PAGEDOWNRECTEXTEND:=2434,SCI_STUTTEREDPAGEUP:=2435,SCI_STUTTEREDPAGEUPEXTEND:=2436,SCI_STUTTEREDPAGEDOWN:=2437
,SCI_STUTTEREDPAGEDOWNEXTEND:=2438,SCI_DELETEBACK:=2326,SCI_DELETEBACKNOTLINE:=2344,SCI_DELWORDLEFT:=2335,SCI_DELWORDRIGHT:=2336
,SCI_DELLINELEFT:=2395,SCI_DELLINERIGHT:=2396,SCI_LINEDELETE:=2338,SCI_LINECUT:=2337,SCI_LINECOPY:=2455,SCI_LINETRANSPOSE:=2339
,SCI_LINEDUPLICATE:=2404,SCI_LOWERCASE:=2340,SCI_UPPERCASE:=2341,SCI_CANCEL:=2325,SCI_EDITTOGGLEOVERTYPE:=2324,SCI_NEWLINE:=2329
,SCI_FORMFEED:=2330,SCI_TAB:=2327,SCI_BACKTAB:=2328,SCI_SELECTIONDUPLICATE:=2469,SCI_SCROLLTOSTART:=2628,SCI_SCROLLTOEND:=2629
,SCI_DELWORDRIGHTEND:=2518,SCI_VERTICALCENTRECARET:=2619,SCI_MOVESELECTEDLINESUP:=2620,SCI_MOVESELECTEDLINESDOWN:=2621
,SC_TIME_FOREVER:=10000000,SC_WRAP_NONE:=0,SC_WRAP_WORD:=1,SC_WRAP_CHAR:=2,SC_WRAPVISUALFLAG_NONE:=0x0000,SC_WRAPVISUALFLAG_END:=0x0001
,SC_WRAPVISUALFLAG_START:=0x0002,SC_WRAPVISUALFLAG_MARGIN:=0x0004, SC_WRAPVISUALFLAGLOC_DEFAULT:=0x0000,SC_WRAPVISUALFLAGLOC_END_BY_TEXT:=0x0001
,SC_WRAPVISUALFLAGLOC_START_BY_TEXT:=0x0002,SC_CACHE_NONE:=0,SC_CACHE_CARET:=1,SC_CACHE_PAGE:=2,SC_CACHE_DOCUMENT:=3,EDGE_NONE:=0,EDGE_LINE:=1
,EDGE_BACKGROUND:=2,SC_CURSORNORMAL:=-1,SC_CURSORWAIT:=4,VISIBLE_SLOP:=0x01,VISIBLE_STRICT:=0x04,CARET_SLOP:=0x01,CARET_STRICT:=0x04
,CARET_JUMPS:=0x10,CARET_EVEN:=0x08,SC_SEL_STREAM:=0,SC_SEL_RECTANGLE:=1,SC_SEL_LINES:=2,SC_ALPHA_TRANSPARENT:=0,SC_ALPHA_OPAQUE:=255
,SC_ALPHA_NOALPHA:=256,KEYWORDSET_MAX:=8,SC_MOD_INSERTTEXT:=0x1,SC_MOD_DELETETEXT:=0x2,SC_MOD_CHANGESTYLE:=0x4,SC_MOD_CHANGEFOLD:=0x8
,SC_PERFORMED_USER:=0x10,SC_PERFORMED_UNDO:=0x20,SC_PERFORMED_REDO:=0x40,SC_MULTISTEPUNDOREDO:=0x80,SC_LASTSTEPINUNDOREDO:=0x100
,SC_MOD_CHANGEMARKER:=0x200,SC_MOD_BEFOREINSERT:=0x400,SC_MOD_BEFOREDELETE:=0x800,SC_MULTILINEUNDOREDO:=0x1000,SC_MODEVENTMASKALL:=0x1FFF
,SC_WEIGHT_NORMAL:=400, SC_WEIGHT_SEMIBOLD:=600, SC_WEIGHT_BOLD:=700
}

}

ExitApp() {
	if (attached) {
		console.writeln("")
		Process_Resume(Process_GetCurrentParentProcessID())
		DllCall("CloseHandle")
	}
	
	exitapp, % exit_code
}

ExtractInteger(ByRef pSource, pOffset = 0, pIsSigned = false, pSize = 4) ; см. описание DllCall
{
    Loop %pSize% ; собираем целое число, складывая его байты.
        result += *(&pSource + pOffset + A_Index-1) << 8*(A_Index-1)
    if (!pIsSigned OR pSize > 4 OR result < 0x80000000)
        return result ; в этих случаях не имеет значения, со знаком число или без
    return -(0xFFFFFFFF - result + 1)
}

AccessRights_EnableSeDebug() {
	hProc := DllCall( "OpenProcess", UInt,0x0400, Int,0, UInt,DllCall("GetCurrentProcessId"), "Ptr" )
	DllCall( "Advapi32.dll\OpenProcessToken", Ptr,hProc, UInt,0x0020|0x0008, PtrP,hToken )

	VarSetCapacity(LUID, 8, 0)
	DllCall( "Advapi32.dll\LookupPrivilegeValue", Ptr,0, Str,"SeDebugPrivilege", Ptr,&LUID )

	VarSetCapacity( TOKPRIV, 16, 0   )					      ; TOKEN_PRIVILEGES structure: http://goo.gl/AGXeAp.
	NumPut( 1, &TOKPRIV, 0,   "UInt" )                        ; TOKEN_PRIVILEGES > PrivilegeCount.
	NumPut( NumGet( &LUID, 0, "UInt" ), &TOKPRIV, 4, "UInt" ) ; TOKEN_PRIVILEGES > LUID_AND_ATTRIBUTES > LUID > LoPart.
	NumPut( NumGet( &LUID, 4, "UInt" ), &TOKPRIV, 8, "UInt" ) ; TOKEN_PRIVILEGES > LUID_AND_ATTRIBUTES > LUID > HiPart.
	NumPut( 2, &TOKPRIV, 12,  "UInt" )                        ; TOKEN_PRIVILEGES > LUID_AND_ATTRIBUTES > Attributes.
														      ; SE_PRIVILEGE_ENABLED = 2.

	DllCall( "Advapi32.dll\AdjustTokenPrivileges", Ptr,hToken, Int,0, Ptr,&TOKPRIV, UInt,0, Ptr,0, Ptr,0 )
    DllCall( "CloseHandle", Ptr,hToken )
    DllCall( "CloseHandle", Ptr,hProc  )
}

WM_QUERYENDSESSION(wParam, lParam)
{
    ENDSESSION_LOGOFF := 0x80000000
    if (lParam & ENDSESSION_LOGOFF)
        EventType := "Logoff"
    else
        EventType := "Shutdown"
    try
    {
		DllCall("ShutdownBlockReasonCreate", "ptr", A_ScriptHwnd, "wstr", "Подождите. Программа сейчас закроется...")
		;settimer, WARNING_shutdown, 1
        return false
    }
    catch
    {
        MsgBox, 4, % title, %EventType% in progress.  Allow it?
        IfMsgBox Yes
            return true
        else
            return false
    }
}

WTSEnumerateProcessesEx()
{
    static hWTSAPI := DllCall("LoadLibrary", "str", "wtsapi32.dll", "ptr")

    if !(DllCall("wtsapi32\WTSEnumerateProcessesEx", "ptr", 0, "uint*", 0, "uint", -2, "ptr*", buf, "uint*", TTL))
        throw Exception("WTSEnumerateProcessesEx failed", -1)
    addr := buf, WTS_PROCESS_INFO := []
    loop % TTL
    {
        WTS_PROCESS_INFO[A_Index, "SessionID"]   := NumGet(addr+0, "uint")
        WTS_PROCESS_INFO[A_Index, "ProcessID"]   := NumGet(addr+4, "uint")
        WTS_PROCESS_INFO[A_Index, "ProcessName"] := StrGet(NumGet(addr+8, "ptr"))
        WTS_PROCESS_INFO[A_Index, "UserSID"]     := NumGet(addr+8+A_PtrSize, "ptr")
        addr += 8 + (A_PtrSize * 2)
    }
    if !(DllCall("wtsapi32\WTSFreeMemoryEx", "int", 0, "ptr", buf, "uint", TTL))
        throw Exception("WTSFreeMemoryEx failed", -1)
    return WTS_PROCESS_INFO
}

FileGetInfo( lptstrFilename) {
	List := "Comments InternalName ProductName CompanyName LegalCopyright ProductVersion"
		. " FileDescription LegalTrademarks PrivateBuild FileVersion OriginalFilename SpecialBuild"
	dwLen := DllCall("Version.dll\GetFileVersionInfoSize", "Str", lptstrFilename, "Ptr", 0)
	dwLen := VarSetCapacity( lpData, dwLen + A_PtrSize)
	DllCall("Version.dll\GetFileVersionInfo", "Str", lptstrFilename, "UInt", 0, "UInt", dwLen, "Ptr", &lpData) 
	DllCall("Version.dll\VerQueryValue", "Ptr", &lpData, "Str", "\VarFileInfo\Translation", "PtrP", lplpBuffer, "PtrP", puLen )
	sLangCP := Format("{:04X}{:04X}", NumGet(lplpBuffer+0, "UShort"), NumGet(lplpBuffer+2, "UShort"))
	i := {}
	Loop, Parse, % List, %A_Space%
		DllCall("Version.dll\VerQueryValue", "Ptr", &lpData, "Str", "\StringFileInfo\" sLangCp "\" A_LoopField, "PtrP", lplpBuffer, "PtrP", puLen )
		? i[A_LoopField] := StrGet(lplpBuffer, puLen) : ""
	return i
}

GetModuleFileNameEx( p_pid ) ; by shimanov -  www.autohotkey.com/forum/viewtopic.php?t=9000
{
   if A_OSVersion in WIN_95,WIN_98,WIN_ME
   {
      MsgBox, This Windows version (%A_OSVersion%) is not supported.
      return
   }
   h_process := DllCall( "OpenProcess", "uint", 0x10|0x400, "int", false, "uint", p_pid )
   if ( ErrorLevel or h_process = 0 )
      return
   name_size = 255
   VarSetCapacity( name, name_size )
   If A_IsUnicode
      result := DllCall( "psapi.dll\GetModuleFileNameExW", "uint", h_process, "uint", 0, "str" , name, "uint", name_size )
    Else
      result := DllCall( "psapi.dll\GetModuleFileNameExA", "uint", h_process, "uint", 0, "str" , name, "uint", name_size )
   DllCall( "CloseHandle", h_process )
   return, name
}

InsertInteger(pInteger, ByRef pDest, pOffset = 0, pSize = 4)
{
    Loop %pSize% ; копируем каждый байт целого числа в структуру как сырые двоичные данные
        DllCall("RtlFillMemory", "UInt", &pDest + pOffset + A_Index-1
        , "UInt", 1, "UChar", pInteger >> 8*(A_Index-1) & 0xFF)
}

percent(num1, num2) {
	return (num1/num2)*100
}

; Конфиг

IfNotExist, % root
	warning_dir = 1

; Чтение конфига
FileCreateDir, % root
checkConfig()

addtv(p1="", p2="", p3="") {
	result := TV_Add(p1, p2, p3)
	tvs[p1] := result
	return result
}

server_api(method) {
	try whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	try whr.Open("GET", host "/api.php?method=" method, true)
	try whr.SetRequestHeader("User-Agent", "Renux Shell v" version)
	try whr.SetRequestHeader("Content-Type","application/x-www-form-urlencoded")
	try whr.Send()
	try whr.WaitForResponse()
	try response := whr.ResponseText
	catch {
		console.warning("Ошибка. Не удалось получить ответ сервера (" host ").")
		return
	}
	
	if (debug)
		console.writeln("[DEBUG] Ответ сервера RS: " response)
	
	return response
}

vk_api(method, token) {
	global
	
	err_code = 0
	StringReplace, method, method, `n, `%newline`%, All
	StringReplace, method, method, `%newline`%, `%0A, All
	StringReplace, method, method, +, `%2B, All
	StringReplace, method, method, #, `%23, All
	random, rid, 1000, 9999
	StringReplace, method, method, `%random_id`%, % rid, All
	MessagePeerRound := Round(MessagePeer)
	StringReplace, method, method, peer_id=%MessagePeer%, peer_id=%MessagePeerRound%
	MessagePeer = % MessagePeerRound
	
	api_host := proxy_vk
	
	try whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	Loop, parse, method, `&
	{
		RegExMatch(A_LoopField, "v=(.*)", loopfieldout)
		if loopfieldout
			text_api := api_host "&method=" method "&access_token=" token
		else
			text_api := api_host "&method=" method "&access_token=" token "&v=5.95"
	}
	
	try whr.Open("POST", text_api, true)
	try whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36")
	try whr.SetRequestHeader("Content-Type","application/x-www-form-urlencoded")
	try whr.Send()
	try whr.WaitForResponse()
	try response := whr.ResponseText
	catch {
		console.warning("Ошибка. Не удалось получить ответ сервера (VK API).")
		return
	}
	
	if debug
		console.writeln("[DEBUG] Ответ: " response)
	
	if (trim(response) == "") {
		console.warning("Ошибка. Ответ сервера пуст (VK API).")
		return
	}
	
	return response
}

encrypt(src, file_path, Key1, Key2 = 0)
{
	file := FileOpen(file_path, "a", UTF-8)
	
	Loop, 3
	{
		If not Key%A_Index%
			Break
		
		StringSplit, Keys, Key%A_Index%
		Dest =
		Loop, Parse, Src
		{
			Index := Mod(A_Index, Keys0) + 1
			Key := Asc(Keys%Index%)
			Code := Asc(A_LoopField)
            Dest .= Chr(Code = Key ? Code : Code ^ Key)
		}
		
		Src := Dest
	}
	
    file.write(Dest)
	file.close()
	return Dest
}

decrypt(Src, Key1, Key2 = 0)  ; Два последних ключа необязательны.
{
  Loop, 3
  {
    If not Key%A_Index%
      Break
    
    StringSplit, Keys, Key%A_Index%  ; Разбиваем фразу на отдельные ключи.
    Dest =
    Loop, Parse, Src  ; Перебор символов текста.
    {
      Index := Mod(A_Index, Keys0) + 1  ; Чтобы Index не вышел за пределы
                                        ; числа символов в ключевой фразе.
      Key := Asc(Keys%Index%)   ; Очередной ключ.
      Code := Asc(A_LoopField)  ; Код очередного символа текста.
      Dest .= Chr(Code = Key ? Code : Code ^ Key) ; Шифруем и добавляем.
    }
    Src := Dest
  }
  Return Dest
}

checkConfig() {
	global
	
	loop, 2
	{
		IniRead, start_cmd, % config, start, cmd
		if (start_cmd == "ERROR") {
			IniWrite, информация, % config, start, cmd
		}
		
		IniRead, start_transparent, % config, start, transparent
		if (start_transparent == "ERROR") {
			IniWrite, 240, % config, start, transparent
		}
		
		IniRead, proxy_vk, % config, proxy, vk
		if (proxy_vk == "ERROR") {
			IniWrite, % "https://api.vk.com/api.php?oauth=1&", % config, proxy, vk
		}
		
		IniRead, vk_token, % config, vk, token
		if (vk_token == "ERROR") {
			IniWrite, % "", % config, vk, token
		}
		
		IniRead, variables_explode_symbols, % config, variables, explode_symbols
		if (variables_explode_symbols == "ERROR") {
			IniWrite, `%, % config, variables, explode_symbols
		}
	}
}

class JSON
{
   static JS := JSON._GetJScriptObject(), true := {}, false := {}, null := {}
   
   Parse(sJson, js := false)  {
      if jsObj := this.VerifyJson(sJson)
         Return js ? jsObj : this._CreateObject(jsObj)
   }
   
   Stringify(obj, js := false, indent := "") {
      if (js && !RegExMatch(js, "\s"))
         Return this.JS.JSON.stringify(obj, "", indent)
      else {
         (RegExMatch(js, "\s") && indent := js)
         sObj := this._ObjToString(obj)
         Return this.JS.eval("JSON.stringify(" . sObj . ",'','" . indent . "')")
      }
   }
   
   GetKey(sJson, key, indent := "") {
	  if !this.VerifyJson(sJson)
         Return
		 
		 symbol = `"
      try Return StrReplace(StrReplace(StrReplace(Ltrim(RTrim(this.JS.eval("JSON.stringify((" . sJson . ")" . (SubStr(key, 1, 1) = "[" ? "" : ".") . key . ",'','" . indent . "')"), symbol), symbol), "\/", "/"), "\n", "`n"), "\" symbol, symbol)
      catch
         console.writeln("[DEBUG] Плохой ключ: " key)
   }
   
   SetKey(sJson, key, value, indent := "") {
      if !this.VerifyJson(sJson)
         Return
      if !this.VerifyJson(value, true) {
         console.warning("Плохое значение: " value)
         Return
      }
      try {
         res := this.JS.eval( "var obj = (" . sJson . ");"
                            . "obj" . (SubStr(key, 1, 1) = "[" ? "" : ".") . key . "=" . value . ";"
                            . "JSON.stringify(obj,'','" . indent . "')" )
         this.JS.eval("obj = ''")
         Return res
      }
      catch
         console.writeln("[DEBUG] Плохой ключ: " key)
   }
   
   RemoveKey(sJson, key, indent := "") {
      if !this.VerifyJson(sJson)
         Return
      
      sign := SubStr(key, 1, 1) = "[" ? "" : "."
      try {
         if !RegExMatch(key, "(.*)\[(\d+)]$", match)
            res := this.JS.eval("var obj = (" . sJson . "); delete obj" . sign . key . "; JSON.stringify(obj,'','" . indent . "')")
         else
            res := this.JS.eval( "var obj = (" . sJson . ");" 
                               . "obj" . (match1 != "" ? sign . match1 : "") . ".splice(" . match2 . ", 1);"
                               . "JSON.stringify(obj,'','" . indent . "')" )
         this.JS.eval("obj = ''")
         Return res
      }
      catch
         console.writeln("[DEBUG] Плохой ключ: " key)
   }
   
   Enum(sJson, key := "", indent := "") {
      if !this.VerifyJson(sJson)
         Return
      
      conc := key ? (SubStr(key, 1, 1) = "[" ? "" : ".") . key : ""
      try {
         jsObj := this.JS.eval("(" sJson ")" . conc)
         res := jsObj.IsArray()
         if (res = "")
            Return
         obj := {}
         if (res = -1) {
            Loop % jsObj.length
               obj[A_Index - 1] := this.JS.eval("JSON.stringify((" sJson ")" . conc . "[" . (A_Index - 1) . "],'','" . indent . "')")
         }
         else if (res = 0) {
            keys := jsObj.GetKeys()
            Loop % keys.length
               k := keys[A_Index - 1], obj[k] := this.JS.eval("JSON.stringify((" sJson ")" . conc . "['" . k . "'],'','" . indent . "')")
         }
         Return obj
      }
      catch
         console.writeln("[DEBUG] Плохой ключ: " key)
   }
   
   VerifyJson(sJson, silent := false) {
      try jsObj := this.JS.eval("(" sJson ")")
      catch {
         if !silent
            console.writeln("[DEBUG] Плохая JSON-строка: " sJson)
         Return
      }
      Return IsObject(jsObj) ? jsObj : true
   }
   
   _ObjToString(obj) {
      if IsObject( obj ) {
         for k, v in ["true", "false", "null"]
            if (obj = this[v])
               Return v
            
         isArray := true
         for key in obj {
            if IsObject(key)
               throw Exception("Invalid key")
            if !( key = A_Index || isArray := false )
               break
         }
         for k, v in obj
            str .= ( A_Index = 1 ? "" : "," ) . ( isArray ? "" : """" . k . """:" ) . this._ObjToString(v)

         Return isArray ? "[" str "]" : "{" str "}"
      }
      else if !(obj*1 = "" || RegExMatch(obj, "\s"))
         Return obj
      
      for k, v in [["\", "\\"], [A_Tab, "\t"], ["""", "\"""], ["/", "\/"], ["`n", "\n"], ["`r", "\r"], [Chr(12), "\f"], [Chr(08), "\b"]]
         obj := StrReplace( obj, v[1], v[2] )

      Return """" obj """"
   }

   _GetJScriptObject() {
      static doc
      doc := ComObjCreate("htmlfile")
      doc.write("<meta http-equiv=""X-UA-Compatible"" content=""IE=9"">")
      JS := doc.parentWindow
      JSON._AddMethods(JS)
      Return JS
   }

   _AddMethods(ByRef JS) {
      JScript =
      (
         Object.prototype.GetKeys = function () {
            var keys = []
            for (var k in this)
               if (this.hasOwnProperty(k))
                  keys.push(k)
            return keys
         }
         Object.prototype.IsArray = function () {
            var toStandardString = {}.toString
            return toStandardString.call(this) == '[object Array]'
         }
      )
      JS.eval(JScript)
   }

   _CreateObject(jsObj) {
      res := jsObj.IsArray()
      if (res = "")
         Return jsObj
      
      else if (res = -1) {
         obj := []
         Loop % jsObj.length
            obj[A_Index] := this._CreateObject(jsObj[A_Index - 1])
      }
      else if (res = 0) {
         obj := {}
         keys := jsObj.GetKeys()
         Loop % keys.length
            k := keys[A_Index - 1], obj[k] := this._CreateObject(jsObj[k])
      }
      Return obj
   }
}

getFreeName(prefix, ext)
{
    while(true)
    {
        Filename := prefix "" i "." ext
        i++
        if !FileExist(Filename)
            break
    }
    return Filename
}

FormatTime(ms) {
	if (ms < 1000) {
		return ms " мс"
	}
	
	return FormatSeconds(ms/1000)
}

parseIf(expression, cmdtodo) {
	global
	error := 0, cmdout1 := "", action := "", cmdout2 := "", cmdout3 := ""
	writing := "", brks := 0, writed := "", sc_index := "0", spaces := 0
	writing_action := 0, then_text := "", caption_cmd := 0, displayed := 0
	
	loop, parse, expression
	{
		if (A_Index < 6) {
			continue
		}
		
		if (caption_cmd) {
			cmdout3 := LTrim(cmdout3 A_LoopField)
			continue
		}

		s = `"
		if ((A_LoopField == "'") || (A_LoopField == s)) {
			if (!displayed) {
				if (!writing) {
					writing := 1, brks := brks + 1, sc_index := sc_index + 1
					continue
				} else {
					writing := 0, brks := brks - 1
					cmdout%sc_index% = % console.processVars(writed)
					writed := ""
					continue
				}
			}
		}
		
		if (A_LoopField == " ") {
			spaces+=1
			if (spaces == 1) {
				writing_action = 1
				continue
			}
			
			if (spaces == 2) {
				writing_action = 0
				continue
			}
		}
		
		if (writing) {
			writed := writed A_LoopField
		}
		
		if (writing_action == 1) {
			action := action A_LoopField
			continue
		}
		
		if (spaces > 2) {
			then_text := trim(then_text A_LoopField)
			
			if (then_text == string.down(cmdtodo)) {
				caption_cmd == 1
				continue
			}
		}
	}
}

GetMac(ByRef Line)
{
    Loop, Parse, Line
        if (A_LoopField = "-")
        {
            k:= 0, Begp:= p:= A_Index
            While (SubStr(Line, p+= 3, 1) = "-")
                k++
            if (k = 4) ; 5 in row
                return Substr(Line, Begp - 2,  17)
        }
    return ""
}

MatchStr(Str, ByRef pat){
    Loop, Parse, Str,`n,`r
    {
        if instr(A_LoopField, pat)
            NStr.= A_LoopField "`n"
    }
    return NStr
}

RunCon(CmdLine, Input, ByRef Output)
{
    static BufSizeChar := 1024, hParent := 0
    static Show := 0, Flags := 0x101  ; STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW
    static Buf, BufSizeByte, ProcessInfo, StartupInfo, PipeAttribs
    static piSize, siSize, paSize, flOffset, shOffset, ihOffset
    static inOffset, outOffset, errOffset, thrOffset
    If (!hParent) {
        BufSizeByte := A_IsUnicode ? BufSizeChar * 2 : BufSizeChar
        If (A_PtrSize = 8) {
            piSize := 24, siSize := 104, paSize = 24
            flOffset := 60, shOffset := 64, ihOffset := 16
            inOffset := 80, outOffset := 88, errOffset := 96
            thrOffset := 8
        }
        Else {
            piSize := 16, siSize := 68, paSize = 12
            flOffset := 44, shOffset := 48, ihOffset := 8
            inOffset := 56, outOffset := 60, errOffset := 64
            thrOffset := 4
        }
        VarSetCapacity(Buf, BufSizeByte, 0),    VarSetCapacity(ProcessInfo, piSize, 0)
        VarSetCapacity(StartupInfo, siSize, 0), VarSetCapacity(PipeAttribs, paSize, 0)
        NumPut(siSize, StartupInfo, 0, "uint"), NumPut(Flags, StartupInfo, flOffset, "uint")
        NumPut(Show, StartupInfo, shOffset, "ushort")
        NumPut(paSize, PipeAttribs, 0, "uint"), NumPut(1, PipeAttribs, ihOffset, "int")
        hParent := DllCall("GetCurrentProcess", "ptr")
    }
    DllCall("CreatePipe", "ptr *", hRead1_tmp, "ptr *", hWrite2
                        , "ptr", &PipeAttribs, "uint", 0)
    DllCall("CreatePipe", "ptr *", hRead2, "ptr *", hWrite1_tmp
                        , "ptr", &PipeAttribs, "uint", 0)

    NumPut(hRead2,  StartupInfo, inOffset, "ptr") 
    NumPut(hWrite2, StartupInfo, outOffset, "ptr")
    NumPut(hWrite2, StartupInfo, errOffset, "ptr")
    
    DllCall("DuplicateHandle", "ptr", hParent, "ptr", hRead1_tmp
                             , "ptr", hParent, "ptr *", hRead1
                             , "uint", 0, "uint", 0
                             , "uint", 2)    ; DUPLICATE_SAME_ACCESS
    DllCall("CloseHandle", "ptr", hRead1_tmp)
    DllCall("DuplicateHandle", "ptr", hParent, "ptr", hWrite1_tmp
                             , "ptr", hParent, "ptr *", hWrite1
                             , "uint", 0, "uint", 0
                             , "uint", 2)
    DllCall("CloseHandle", "ptr", hWrite1_tmp)
    
    DllCall("ExpandEnvironmentStrings", "str", CmdLine, "str", Buf, "uint", BufSizeChar)
    CmdLine := Buf
    Ret := DllCall("CreateProcess", "ptr", 0, "str", CmdLine, "ptr", 0, "ptr", 0
                                  , "uint", 1, "uint", 0, "ptr", 0, "ptr", 0
                                  , "ptr", &StartupInfo, "ptr", &ProcessInfo)
    If (!Ret) {
        MsgBox,, %A_ThisFunc%, Не удалось создать процесс.
        Output := ""
        Return 1
    }
    hChild := NumGet(ProcessInfo, 0, "ptr")
    DllCall("CloseHandle", "ptr", NumGet(ProcessInfo, thrOffset, "ptr"))
    DllCall("CloseHandle", "ptr", hRead2)
    DllCall("CloseHandle", "ptr", hWrite2)
    If (Input) {
        InLen := StrLen(Input) + 2
        VarSetCapacity(InBuf, InLen, 0)
        StrPut(Input . "`r`n", &InBuf, "cp1251")
        DllCall("WriteFile", "ptr", hWrite1, "ptr", &InBuf, "uint", InLen
                           , "uint *", BytesWritten, "uint", 0)
    }
    DllCall("CloseHandle", "ptr", hWrite1)
    Output := ""
    Loop {
        If not DllCall("ReadFile", "ptr", hRead1, "ptr", &Buf, "uint", BufSizeByte
                                 , "uint *", BytesRead, "uint", 0)
            Break
        NumPut(0, Buf, BytesRead, "Char")
        Output .= StrGet(&Buf, "cp1251")
    }
    DllCall("CloseHandle", "ptr", hRead1)
    DllCall("GetExitCodeProcess", "ptr", hChild, "int *", ExitCode)
    DllCall("CloseHandle", "ptr", hChild)
    Return ExitCode
}

Process_Suspend(PID_or_Name){

    PID := (InStr(PID_or_Name,".")) ? ProcExist(PID_or_Name) : PID_or_Name

    h:=DllCall("OpenProcess", "uInt", 0x1F0FFF, "Int", 0, "Int", pid)

    If !h   

        Return -1

    DllCall("ntdll.dll\NtSuspendProcess", "Int", h)

    DllCall("CloseHandle", "Int", h)

}

Process_Resume(PID_or_Name){

    PID := (InStr(PID_or_Name,".")) ? ProcExist(PID_or_Name) : PID_or_Name

    h:=DllCall("OpenProcess", "uInt", 0x1F0FFF, "Int", 0, "Int", pid)

    If !h   

        Return -1

    DllCall("ntdll.dll\NtResumeProcess", "Int", h)

    DllCall("CloseHandle", "Int", h)

}

ProcExist(PID_or_Name=""){

    Process, Exist, % (PID_or_Name="") ? DllCall("GetCurrentProcessID") : PID_or_Name

    Return Errorlevel

}

FormatSeconds(NumberOfSeconds) {
 time = 20010101 ;1/1/2001
 time += NumberOfSeconds, seconds
 FormatTime, y, %time%, y
 FormatTime, M, %time%, M
 FormatTime, d, %time%, d
 FormatTime, HHmmss, %time%, m:ss
 Return hhmmss
}

SplitCommand(InputVar, Quantity, OutputVar, processVar=1, showErrors=1) {
	global

	loop, % quantity
		%outputvar%%A_Index% =
	
	writed := ""
	if (Quantity <= 1) {
		sc_index := -1
		
		loop, parse, InputVar, % " "
		{
			sc_index+=1
			if (sc_index == 0) {
				%OutputVar% = %A_LoopField%
				continue
			}
			
			sc_index := 1
			writed := LTrim(writed " " A_LoopField)
		}
		
		if processVar
			t := console.processVars(writed)
		
		%OutputVar%%sc_index% = % t
	} else {
		sc_index := 0, brks := 0
	
		loop, parse, InputVar, % " "
		{
			%OutputVar% = %A_LoopField%
			break
		}
	
		writing := 0, writed := "", displayed := 0
		loop, parse, InputVar
		{
			if ((displayed) && (writing)) {
				writed := writed A_LoopField
				displayed := 0
				continue
			}
			
			if (A_LoopField == "``") {
				displayed := 1
				continue
			}
			
			s = `"
			if ((A_LoopField == "'") || (A_LoopField == s)) {
				if (sc_index > Quantity) {
					if showErrors
						console.error("Вы указали слишком много параметров.")
					
					return -2
				}
				
				if (writing) {
					writing := 0, symbol := symbol - 1, brks := brks - 1
					if processVar
						t := console.processVars(writed), writed := ""
					
					%OutputVar%%sc_index% = % t
				}
				else
					writing := 1, symbol := symbol + 1, sc_index := sc_index + 1, brks := brks + 1
				continue
			}
			
			if (writing) {
				writed := writed A_LoopField
				continue
			}
			
			if (brks != 0) {
				if showErrors
					console.error("Ожидался символ: '.")
				
				return -1
			}
			
			if (trim(A_LoopField) == "") {
				continue
			}
		}
		
		if (sc_index < Quantity) {
			if showErrors
				console.error("Нужно указать все параметры (указано: " sc_index "; нужно: " quantity ").")
			
			return -2
		}
	}
	
	return 1
}

ProcessArgument(name) {
	global
	
	arg_name := name
	arg_process := trim(string.up(arg_name)) ; хотел arg_to_process
	
	if (arg_process == "/HIDE") {
		if ((started) && (!shell_mode))
			MsgBox, 0, % title, % "После того, как Renux Shell выполнит команду в фоновом режиме, он закроется.", 5
		
		hide_mode = 1
		WinHide, ahk_id %mainwid%
		return 1
	}
	
	if (arg_process == "/NS") {
		no_suspend = 1
		return 1
	}
	
	if (arg_process == "/NEW") {
		if (started) {
			console.error("Вы не можете использовать этот параметр, когда программа уже запущена.")
			return 0
		}
		
		no_attach = 1
		return 1
	}
	
	if (arg_process == "/IGNORE_ERRORS") {
		ignore_errors = 1
		return 1
	}
	
	if (arg_process == "/IGNORE_WARNINGS") {
		ignore_warnings = 1
		return 1
	}
	
	if (arg_process == "/OUTPUT_MODE:MSG") {
		output_mode = msg
		return 1
	}
	
	if (arg_process == "/OUTPUT_MODE:PRINT") {
		output_mode = print
		return 1
	}
	
	if (arg_process == "/DEBUG") {
		debug = 1
		
		if (!dbgwid) {
			MsgBox, 48, % title " - Отладка",
			(
Обратите внимание: когда Renux Shell просит ввести данные для обработки, окно отладки перестает отвечать. Это особенность Windows, так что с этим ничего не поделать. Также скорость работы сценариев незначительно снижается.
			)
			
			if (mainwid) {
				WinGetPos, posx, posy, posw, posh, ahk_id %mainwid%
				xpos := (posx+posw)-posw/2
			} else {
				xpos := A_ScreenWidth/1.5, posy := A_ScreenHeight/1.5
			}
			
			Menu, DMenu1, Add, Переход к строке, debug_gotoLine
			Menu, DMenu1, Add, Выполнить команду, executeCommand
			Menu, DMenu1, Add, 
			Menu, DMenu1, Add, Пауза перед командой, debug_pause_menu
			Menu, Gui, Add, Отладка, :dmenu1
			
			gosub debug_pause_menu
			
			Gui, dbg:Default
			Gui, dbg:+AlwaysOnTop +Resize +hwnddbgwid
			Gui, dbg:Font, CDefault S8, Segoe UI
			Gui, dbg:Add, ListView, x-1 y-1 w500 h300 vDbgCtrl +Report, № строки|Текст строки|Сообщение
			Gui, dbg:Show, x%xpos% y%posy% w558 h352 NA, % title " - Отладка"
			Gui, dbg:Menu, Gui
			
			hSysMenu:=DllCall("GetSystemMenu", "Int", dbgwid, "Int", false)
			nCnt:=DllCall("GetMenuItemCount","Int",hSysMenu)
			DllCall("RemoveMenu","Int",hSysMenu,"UInt",nCnt-1,"Uint","0x400")
		}
		return 1
	}
	
	if (arg_process == "/LOG") {
		log = 1
		return 1
	}
	
	console.warning("Аргумент " arg_process " не удалось обработать.")
	return 0
}

processCmd(cmd) {
	command := "", displayed := 0
	
	loop, parse, cmd
	{
		if (!displayed) {
			if (A_LoopField == "``") {
				displayed := 1
				continue
			}
			
			if (A_LoopField == ";") {
				WinGetTitle, titlee, ahk_id %mainwid%
				
				pc_result := executeCMD(command)
				
				command := ""
				if (debug) {
					console.writeln("[DEBUG] Функция вернула: " pc_result)
				}
				continue
			}
		} else {
			s = `"
			if ((A_LoopField == "'") || (A_LoopField == s)) {
				command := command "``'", displayed := 0
				continue
			}
		
			if (string.down(A_LoopField) == "t") {
				command := command "`t", displayed := 0
				continue
			}
			
			if (string.down(A_LoopField) == "n") {
				command := command "`n", displayed := 0
				continue
			}
		}
		
		command := command A_LoopField
		displayed := 0
	}
	
	if (trim(command) != "") {
		WinGetTitle, titlee, ahk_id %mainwid%
		pc_result := executeCMD(command)
		
		if (debug) {
			console.writeln("[DEBUG] Функция вернула: " pc_result)
		}
	}
}

executeCMD(cmd) {
	global
	
	cmd_text := trim(cmd)
	cmd_process := string.getLine(string.up(cmd_text), 1)
	
	if (trim(cmd_process) == "") {
		return 0
	}
	
	; Команды с несколькими параметрами
	loop, parse, cmd_process, % A_Space
	{
		cmd_process_first := trim(A_LoopField)
		break
	}
	
	cmd_last_first := cmd_process_first
	cmd_last := cmd_process
	
	if (shell_mode) {
		for key in cmd_functions 
		{
			if (string.up(trim(key)) == string.up(trim(cmd))) {
				if debug
					console.writeln("[DEBUG] Переход на функцию " key " успешен.")
				
				script := cmd_functions[key]
				loop, parse, script, `n
				{
					pc_result := executeCMD(A_LoopField)
					if debug
						console.writeln("[DEBUG] Функция вернула: " pc_result)
				}
				
				return 1
			}
		}
	}
	
	if ((string.right(cmd_process_first, 1) == "?") && (string.len(cmd_process_first) > 2)) {
		cmd_text := "справка " string.left(cmd_process_first, string.len(cmd_process_first)-1)
		cmd_process_first := "СПРАВКА"
	}
	
	if ((cmd_process_first == "ПРОГРАММА") || (cmd_process_first == "??")) {
		gosub aboutprog
		return 1
	}
	
	if ((cmd_process_first == "СПРАВКА") || (cmd_process_first == "?")) {
		SplitCommand(cmd_text, 1, "cmdout")
		
		if (cmdout1 == ".") {
			Run, %A_ScriptFullPath% "справка" /new /ns /hide,, UseErrorLevel
			if (errorlevel) {
				console.error("Не удалось открыть справку асинхронно.")
				return 0
			}
			
			return 1
		}
		
		Gui, 1:Destroy
		Gui, 1:Default
		Gui, 1:+OwnDialogs +hwnddocswid -MinimizeBox
		Gui, 1:Color, White
		Gui, 1:Font, S9 CDefault, Segoe UI
		
		ImageListID := IL_Create(10)
		IL_Add(ImageListID, "shell32.dll", 71)
		IL_Add(ImageListID, "shell32.dll", 4)
		
		Gui, 1:Add, TreeView, x-1 y-1 w481 h364 vTV gTVClick ImageList%ImageListID% -0x1
		
		if ((trim(cmdout1) == "") && (!justgen)) {
			Gui, 1:Show, w479 h363, Руководство по работе с программой Renux Shell
		}
		
		GuiControl, 1:hide, tv
		
		tvs := "", tvs := [] ; сброс
		
		TV_START 				:= addtv("Начало работы",, "Icon2")
		TV_START_INTRO			:= addtv("Введение", TV_START)
		TV_START_SHORT_TUTORIAL	:= addtv("Краткое обучение", TV_START)
		
		TV_VAR					:= addtv("Встроенные переменные",, "Icon2")
		TV_VAR_TIME_DD			:= addtv("'.время.день'", TV_VAR)
		TV_VAR_TIME_MM			:= addtv("'.время.месяц'", TV_VAR)
		TV_VAR_TIME_YYYY		:= addtv("'.время.год'", TV_VAR)
		TV_VAR_TIME_HOUR		:= addtv("'.время.час'", TV_VAR)
		TV_VAR_TIME_MIN			:= addtv("'.время.минута'", TV_VAR)
		TV_VAR_TIME_SEC			:= addtv("'.время.секунда'", TV_VAR)
		TV_VAR_TIME_TICKCOUNT	:= addtv("'.время.счетчик'", TV_VAR)
		TV_VAR_TIME_MMM			:= addtv("'.время.месяцк'", TV_VAR)
		TV_VAR_TIME_MMMM		:= addtv("'.время.месяцс'", TV_VAR)
		TV_VAR_TIME_DDD			:= addtv("'.время.неделяк'", TV_VAR)
		TV_VAR_TIME_DDDD		:= addtv("'.время.неделяс'", TV_VAR)
		TV_VAR_CONSOLE_VERSION	:= addtv("'.консоль.версия'", TV_VAR)
		TV_VAR_CONSOLE_ADMIN	:= addtv("'.консоль.админ'", TV_VAR)
		TV_VAR_CONSOLE_RESULT	:= addtv("'.консоль.результат'", TV_VAR)
		TV_VAR_CONSOLE_FOLDER	:= addtv("'.консоль.папка'", TV_VAR)
		TV_VAR_CONSOLE_SPACE	:= addtv("'.консоль.пробел'", TV_VAR)
		TV_VAR_CONSOLE_WORKDIR	:= addtv("'.консоль.рпапка'", TV_VAR)
		TV_VAR_CONSOLE_PATH		:= addtv("'.консоль.путь'", TV_VAR)
		TV_VAR_CONSOLE_PATH_DIR	:= addtv("'.консоль.путь.папка'", TV_VAR)
		TV_VAR_CONSOLE_SCRIPT	:= addtv("'.консоль.скрипт'", TV_VAR)
		TV_VAR_CONSOLE_NAME		:= addtv("'.консоль.имя'", TV_VAR)
		TV_VAR_CONSOLE_ENV		:= addtv("'.окр.*'", TV_VAR)
		TV_VAR_SYSTEM_APPDATA	:= addtv("'.система.аппдата'", TV_VAR)
		TV_VAR_SYSTEM_CAPPDATA	:= addtv("'.система.оаппдата'", TV_VAR)
		TV_VAR_SYSTEM_DESKTOP	:= addtv("'.система.рстол'", TV_VAR)
		TV_VAR_SYSTEM_CDESKTOP	:= addtv("'.система.орстол'", TV_VAR)
		TV_VAR_SYSTEM_64BITOS	:= addtv("'.система.64бит'", TV_VAR)
		TV_VAR_SYSTEM_DOCUMENTS	:= addtv("'.система.документы'", TV_VAR)
		TV_VAR_SYSTEM_PROGFILES	:= addtv("'.система.прогфайлы'", TV_VAR)
		TV_VAR_SYSTEM_PROGRAMS	:= addtv("'.система.менюпуск'", TV_VAR)
		TV_VAR_SYSTEM_CPROGRAMS	:= addtv("'.система.оменюпуск'", TV_VAR)
		TV_VAR_SYSTEM_STARTMENU	:= addtv("'.система.стартменю'", TV_VAR)
		TV_VAR_SYSTEM_CSTARTMEN := addtv("'.система.остартменю'", TV_VAR)
		TV_VAR_SYSTEM_STARTUP	:= addtv("'.система.автозапуск'", TV_VAR)
		TV_VAR_SYSTEM_CSTARTUP	:= addtv("'.система.оавтозапуск'", TV_VAR)
		TV_VAR_SYSTEM_OSTYPE	:= addtv("'.система.тип'", TV_VAR)
		TV_VAR_SYSTEM_VERSION	:= addtv("'.система.версия'", TV_VAR)
		TV_VAR_SYSTEM_USERNAME	:= addtv("'.система.пользователь'", TV_VAR)
		TV_VAR_SYSTEM_COMPUTER	:= addtv("'.система.компьютер'", TV_VAR)
		TV_VAR_SYSTEM_CLIPBOARD	:= addtv("'.система.клипборд'", TV_VAR)
		TV_VAR_SCREEN_WIDTH		:= addtv("'.экран.ширина'", TV_VAR)
		TV_VAR_SCREEN_HEIGHT	:= addtv("'.экран.высота'", TV_VAR)
		
		TV_MAIN					:= addtv("Основное",, "Icon2")
		TV_MAIN_HOTKEYS			:= addtv("Горячие клавиши", TV_MAIN)
		TV_MAIN_MACROCOMMANDS	:= addtv("Создание макрокоманды клавиатуры и мыши", TV_MAIN)
		TV_MAIN_KEYLIST			:= addtv("Список клавиш и кнопок мыши", TV_MAIN)
		TV_MAIN_SCRIPTS			:= addtv("Пакетные файлы", TV_MAIN)
		TV_MAIN_VARIABLES		:= addtv("Переменные", TV_MAIN)
		
		TV_ADDONS				:= addtv("Аддоны",, "Icon2")
		TV_ADDONS_QUICKSTART	:= addtv("Введение", TV_ADDONS)
		TV_ADDONS_CREATING		:= addtv("Создание аддона", TV_ADDONS)
		TV_ADDONS_COMPILING		:= addtv("Сборка аддона", TV_ADDONS)
		TV_ADDONS_DELETE		:= addtv("Удаление аддона", TV_ADDONS)
		
		TV_CMDS					:= addtv("Список команд",, "Icon2")
		TV_CMDS_CONSOLE			:= addtv("Работа с консолью", TV_CMDS, "Icon2")
		TV_CMDS_CONSOLE_ADDON	:= addtv("АДДОН", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_ADZ		:= addtv("АДЗ", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_ADMIN	:= addtv("АДМИН", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_UPDLIST	:= addtv("АПДЕЙТЛИСТ", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_INPUT	:= addtv("ВВОД", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_OUTPUT	:= addtv("ВЫВОД", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_OUTPUTL	:= addtv("ВЫВОДБ", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_OUTCON	:= addtv("ВЫВОДКОНСОЛЬ || ВК", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_TITLE	:= addtv("ЗАГОЛОВОК", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_WOUTPUT	:= addtv("ЗВЫВОД", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_INFO	:= addtv("ИНФОРМАЦИЯ || ИНФО", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_CONSOLE	:= addtv("КОНСОЛЬ", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_PAUSE	:= addtv("ПАУЗА", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_TRANSP	:= addtv("ПРОЗРАЧНОСТЬ", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_DO		:= addtv("СДЕЛАТЬ", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_COMPILE	:= addtv("СОБРАТЬ", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_CMDLIST	:= addtv("СПИСОК", TV_CMDS_CONSOLE)
		TV_CMDS_CONSOLE_DOCS	:= addtv("СПРАВКА || ?", TV_CMDS_CONSOLE)	
		
		TV_CMDS_CNSTCT			:= addtv("Управляющие конструкции", TV_CMDS, "Icon2")
		TV_CMDS_CNSTCT_END		:= addtv("КОНЕЦ", TV_CMDS_CNSTCT)
		TV_CMDS_CNSTCT_LABEL	:= addtv("МЕТКА", TV_CMDS_CNSTCT)
		TV_CMDS_CNSTCT_GOTO		:= addtv("ПЕРЕЙТИ", TV_CMDS_CNSTCT)
		TV_CMDS_CNSTCT_FUNC		:= addtv("ФУНКЦИЯ", TV_CMDS_CNSTCT)
		
		TV_CMDS_KEYBOARD		:= addtv("Управление клавиатурой", TV_CMDS, "Icon2")
		TV_CMDS_KEYBOARD_INPUT	:= addtv("ВВОДК", TV_CMDS_KEYBOARD)
		TV_CMDS_KEYBOARD_HKEYS	:= addtv("ГК", TV_CMDS_KEYBOARD)
		TV_CMDS_KEYBOARD_WRITE	:= addtv("НАПЕЧАТАТЬ", TV_CMDS_KEYBOARD)
		TV_CMDS_KEYBOARD_WRITEF	:= addtv("НАПЕЧАТАТЬБ", TV_CMDS_KEYBOARD)
		
		TV_CMDS_MOUSE			:= addtv("Управление мышью", TV_CMDS, "Icon2")
		TV_CMDS_MOUSE_MOVE		:= addtv("МЫШЬ.ПЕРЕДВИНУТЬ", TV_CMDS_MOUSE)
		
		TV_CMDS_REG				:= addtv("Управление реестром", TV_CMDS, "Icon2")
		TV_CMDS_REG_WRITE		:= addtv("РЕЕСТР.ЗАПИСАТЬ", TV_CMDS_REG)
		TV_CMDS_REG_READ		:= addtv("РЕЕСТР.ПРОЧИТАТЬ", TV_CMDS_REG)
		TV_CMDS_REG_DELETE		:= addtv("РЕЕСТР.УДАЛИТЬ", TV_CMDS_REG)
		
		TV_CMDS_DIALOG			:= addtv("Диалоговые окна", TV_CMDS, "Icon2")
		TV_CMDS_DIALOG_INPUTBOX	:= addtv("ВВОД.ОКНО", TV_CMDS_DIALOG)
		TV_CMDS_DIALOG_MSGBOX	:= addtv("СООБЩЕНИЕ", TV_CMDS_DIALOG)
		
		TV_CMDS_LINES			:= addtv("Работа со строками", TV_CMDS, "Icon2")
		TV_CMDS_LINES_JSON		:= addtv("ДЖСОН", TV_CMDS_LINES)
		TV_CMDS_LINES_ARR_UNIT	:= addtv("МАССИВ.ОБЪЕДИНИТЬ", TV_CMDS_LINES)
		TV_CMDS_LINES_VAR		:= addtv("ПЕР", TV_CMDS_LINES)
		TV_CMDS_LINES_UNUNIT	:= addtv("СТРОКА.РАЗДЕЛИТЬ", TV_CMDS_LINES)
		TV_CMDS_LINES_REPLACE	:= addtv("СТРОКА.ЗАМЕНИТЬ", TV_CMDS_LINES)
		
		TV_CMDS_PROCESSES		:= addtv("Управление процессами", TV_CMDS, "Icon2")
		TV_CMDS_PROCESSES_EXIT	:= addtv("ВЫХОД", TV_CMDS_PROCESSES)
		TV_CMDS_PROCESSES_WTIME	:= addtv("ЖДАТЬ.ВРЕМЯ", TV_CMDS_PROCESSES)
		TV_CMDS_PROCESSES_WPRES	:= addtv("ЖДАТЬ.НАЖАТИЕ", TV_CMDS_PROCESSES) ;специально wpres, т.к. нет места, похуй
		TV_CMDS_PROCESSES_CMD	:= addtv("КМД", TV_CMDS_PROCESSES)
		TV_CMDS_PROCESSES_PROC	:= addtv("ПРОЦЕСС", TV_CMDS_PROCESSES)
		TV_CMDS_PROCESSES_PROCF	:= addtv("ПРОЦЕСС.ИСКАТЬ", TV_CMDS_PROCESSES)
		TV_CMDS_PROCESSES_PSH	:= addtv("ПШ", TV_CMDS_PROCESSES)
		TV_CMDS_PROCESSES_RAND	:= addtv("РАНД", TV_CMDS_PROCESSES)
		TV_CMDS_PROCESSES_RSTRT	:= addtv("РЕСТАРТ", TV_CMDS_PROCESSES)
		TV_CMDS_PROCESSES_SHUTD	:= addtv("СЕССИЯ", TV_CMDS_PROCESSES)
		
		TV_CMDS_SOUND			:= addtv("Управление звуком", TV_CMDS, "Icon2")
		TV_CMDS_SOUND_SET		:= addtv("ГРОМКОСТЬ", TV_CMDS_SOUND)
		TV_CMDS_SOUND_BEEP		:= addtv("ГУДОК", TV_CMDS_SOUND)
		TV_CMDS_SOUND_GET		:= addtv("ЗВУКИНФО", TV_CMDS_SOUND)
		TV_CMDS_SOUND_PLAY		:= addtv("ПРОИГРАТЬ", TV_CMDS_SOUND)
	
		TV_CMDS_DISPLAY			:= addtv("Работа с экраном", TV_CMDS, "Icon2")
		TV_CMDS_DISPLAY_MONITOR	:= addtv("МОНИТОР", TV_CMDS_DISPLAY)
		TV_CMDS_DISPLAY_TOOLTIP	:= addtv("ПОДСКАЗКА", TV_CMDS_DISPLAY)
		TV_CMDS_DISPLAY_SCREENS	:= addtv("СКРИНШОТ", TV_CMDS_DISPLAY)
		TV_CMDS_DISPLAY_STXTON	:= addtv("ТЕКСТ.ПОКАЗАТЬ", TV_CMDS_DISPLAY)
		TV_CMDS_DISPLAY_STXTOFF	:= addtv("ТЕКСТ.СКРЫТЬ", TV_CMDS_DISPLAY)
		TV_CMDS_DISPLAY_TRAYTIP	:= addtv("УВЕДОМЛЕНИЕ", TV_CMDS_DISPLAY)
		TV_CMDS_DISPLAY_BRIGHT	:= addtv("ЯРКОСТЬ", TV_CMDS_DISPLAY)
		
		TV_CMDS_WIN				:= addtv("Работа с окнами", TV_CMDS, "Icon2")
		TV_CMDS_WIN_ELEM		:= addtv("Работа с элементами окна", TV_CMDS_WIN, "Icon2")
		TV_CMDS_WIN_ELEM_ELEM	:= addtv("ОКНО.ЭЛЕМЕНТ", TV_CMDS_WIN_ELEM)
		TV_CMDS_WIN_ELEM_MOVE	:= addtv("ОКНО.ЭЛЕМЕНТ.ПЕРЕДВИНУТЬ", TV_CMDS_WIN_ELEM)
		TV_CMDS_WIN_ELEM_VALUE	:= addtv("ОКНО.ЭЛЕМЕНТ.ЗНАЧЕНИЕ", TV_CMDS_WIN_ELEM)
		TV_CMDS_WIN_ELEM_WRITE	:= addtv("ОКНО.ЭЛЕМЕНТ.НАПЕЧАТАТЬ", TV_CMDS_WIN_ELEM)
		TV_CMDS_WIN_WAIT		:= addtv("ЖДАТЬ.ОКНО", TV_CMDS_WIN)
		TV_CMDS_WIN_WAIT_ACTI	:= addtv("ЖДАТЬ.ОКНО.АКТИВИРОВАТЬ", TV_CMDS_WIN)
		TV_CMDS_WIN_WAIT_DEACTI	:= addtv("ЖДАТЬ.ОКНО.ДЕАКТИВИРОВАТЬ", TV_CMDS_WIN)
		TV_CMDS_WIN_WAIT_CLOSE	:= addtv("ЖДАТЬ.ОКНО.ЗАКРЫТИЕ", TV_CMDS_WIN)
		TV_CMDS_WIN_ACTIVATE	:= addtv("ОКНО.АКТИВИРОВАТЬ", TV_CMDS_WIN)
		TV_CMDS_WIN_RESTORE		:= addtv("ОКНО.ВЕРНУТЬ", TV_CMDS_WIN)
		TV_CMDS_WIN_TITLE		:= addtv("ОКНО.ЗАГОЛОВОК", TV_CMDS_WIN)
		TV_CMDS_WIN_CLOSE		:= addtv("ОКНО.ЗАКРЫТЬ", TV_CMDS_WIN)
		TV_CMDS_WIN_SHOW		:= addtv("ОКНО.ПОКАЗАТЬ", TV_CMDS_WIN)
		TV_CMDS_WIN_MAXIMIZE	:= addtv("ОКНО.РАЗВЕРНУТЬ", TV_CMDS_WIN)
		TV_CMDS_WIN_MINIMIZE	:= addtv("ОКНО.СВЕРНУТЬ", TV_CMDS_WIN)
		TV_CMDS_WIN_HIDE		:= addtv("ОКНО.СПРЯТАТЬ", TV_CMDS_WIN)
		
		TV_CMDS_DIR				:= addtv("Директивы", TV_CMDS, "Icon2")
		TV_CMDS_DIR_DOWNLOAD	:= addtv("#СКАЧИВАТЬ_БЕЗ_СПРОСА", TV_CMDS_DIR)
		
		TV_CMDS_VOICESP			:= addtv("Синтезатор речи", TV_CMDS, "Icon2")
		TV_CMDS_VOICESP_VOLUME	:= addtv("ГОЛОС.ГРОМКОСТЬ", TV_CMDS_VOICESP)
		TV_CMDS_VOICESP_SAY		:= addtv("ГОЛОС.СКАЗАТЬ", TV_CMDS_VOICESP)
		TV_CMDS_VOICESP_SPEED	:= addtv("ГОЛОС.СКОРОСТЬ", TV_CMDS_VOICESP)
		
		TV_CMDS_NETWORK			:= addtv("Сеть", TV_CMDS, "Icon2")
		TV_CMDS_NETWORK_VKAPI	:= addtv("ВКАПИ", TV_CMDS_NETWORK)
		TV_CMDS_NETWORK_REQUEST	:= addtv("ЗАПРОС", TV_CMDS_NETWORK)
		TV_CMDS_NETWORK_POST	:= addtv("ПОСТ", TV_CMDS_NETWORK)
		TV_CMDS_NETWORK_CFD		:= addtv("СОЗДАТЬДАННЫЕФОРМЫ", TV_CMDS_NETWORK)
		TV_CMDS_NETWORK_SCAN	:= addtv("СЕТЬ.СКАНИРОВАТЬ", TV_CMDS_NETWORK)

		TV_CMDS_FILE			:= addtv("Файловая система", TV_CMDS, "Icon2")
		TV_CMDS_FILE_ATTR		:= addtv("Работа с атрибутами", TV_CMDS_FILE, "Icon2")
		TV_CMDS_FILE_ATTR_GET	:= addtv("АТРИБУТЫ.ПОЛУЧИТЬ", TV_CMDS_FILE_ATTR)
		TV_CMDS_FILE_ATTR_SET	:= addtv("АТРИБУТЫ.УСТАНОВИТЬ", TV_CMDS_FILE_ATTR)
		TV_CMDS_FILE_OUTPUT		:= addtv("ВЫВОДФ", TV_CMDS_FILE)
		TV_CMDS_FILE_CD			:= addtv("СД", TV_CMDS_FILE)
		TV_CMDS_FILE_CD_DOT		:= addtv("СД. / СД.. / СД...", TV_CMDS_FILE)
		TV_CMDS_FILE_DIR		:= addtv("ДИР", TV_CMDS_FILE)
		TV_CMDS_FILE_DRIVE		:= addtv("ДИСК.ПРИВОД", TV_CMDS_FILE)
		TV_CMDS_FILE_DRIVE_GET	:= addtv("ДИСК.ПОЛУЧИТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_DRIVE_GETM	:= addtv("ДИСК.ПОЛУЧИТЬ.СПАМЯТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_INI_WRITE	:= addtv("ИНИ.ЗАПИСАТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_INI_READ	:= addtv("ИНИ.ПРОЧИТАТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_INI_DELETE	:= addtv("ИНИ.УДАЛИТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_ENC_BASE64	:= addtv("КОДИРОВАТЬ.BASE64", TV_CMDS_FILE)
		TV_CMDS_FILE_RECYCLE	:= addtv("КОРЗИНА.ПЕРЕМЕСТИТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_RECYCLE_EM	:= addtv("КОРЗИНА.ОЧИСТИТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_PROG		:= addtv("ПРОГ", TV_CMDS_FILE)
		TV_CMDS_FILE_DOWNLOAD	:= addtv("СКАЧАТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_TIME_SET	:= addtv("ФАЙЛ.ВРЕМЯ.УСТАНОВИТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_TIME_GET	:= addtv("ФАЙЛ.ВРЕМЯ.ПОЛУЧИТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_WRITE_RAW	:= addtv("ФАЙЛ.ЗАПИСАТЬ.БИНАР", TV_CMDS_FILE)
		TV_CMDS_FILE_FIND		:= addtv("ФАЙЛ.ИСКАТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_ENCODING	:= addtv("ФАЙЛ.КОДИРОВКА", TV_CMDS_FILE)
		TV_CMDS_FILE_MOVE		:= addtv("ФАЙЛ.ПЕРЕМЕСТИТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_MOVE_DIR	:= addtv("ФАЙЛ.ПЕРЕМЕСТИТЬ.ПАПКА", TV_CMDS_FILE)
		TV_CMDS_FILE_GET		:= addtv("ФАЙЛ.ПОЛУЧИТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_GET_LABEL	:= addtv("ФАЙЛ.ПОЛУЧИТЬ.ЯРЛЫК", TV_CMDS_FILE)
		TV_CMDS_FILE_READ		:= addtv("ФАЙЛ.ПРОЧИТАТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_READ_RAW	:= addtv("ФАЙЛ.ПРОЧИТАТЬ.БИНАР", TV_CMDS_FILE)
		TV_CMDS_FILE_READ_LINE	:= addtv("ФАЙЛ.ПРОЧИТАТЬ.СТРОКА", TV_CMDS_FILE)
		TV_CMDS_FILE_APPEND		:= addtv("ФАЙЛ.СОЗДАТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_CREATE_DIR	:= addtv("ФАЙЛ.СОЗДАТЬ.ПАПКА", TV_CMDS_FILE)
		TV_CMDS_FILE_DELETE		:= addtv("ФАЙЛ.УДАЛИТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_DELETE_DIR	:= addtv("ФАЙЛ.УДАЛИТЬ.ПАПКА", TV_CMDS_FILE)
		TV_CMDS_FILE_COPY		:= addtv("ФАЙЛ.КОПИРОВАТЬ", TV_CMDS_FILE)
		TV_CMDS_FILE_COPY_DIR	:= addtv("ФАЙЛ.КОПИРОВАТЬ.ПАПКА", TV_CMDS_FILE)
		TV_CMDS_FILE_SIZE		:= addtv("ФАЙЛ.РАЗМЕР", TV_CMDS_FILE)
		
		TV_CMDS_ENV				:= addtv("Управление средой", TV_CMDS, "Icon2")
		TV_CMDS_ENV_UPDATE		:= addtv("ОКРУЖЕНИЕ.ОБНОВИТЬ", TV_CMDS_ENV)
		TV_CMDS_ENV_SET			:= addtv("ОКРУЖЕНИЕ.УСТАНОВИТЬ", TV_CMDS_ENV)
		TV_CMDS_ENV_GET			:= addtv("ОКРУЖЕНИЕ.ПОЛУЧИТЬ", TV_CMDS_ENV)
		
		TV_ABOUTPROG			:= addtv("О программе",, "Icon2")
		TV_UPDATELIST			:= addtv("Список обновлений", TV_ABOUTPROG, "Icon2")
		TV_UPDATELIST_2_15		:= addtv("Версия 2.15", TV_UPDATELIST)
		TV_UPDATELIST_2_14		:= addtv("Версия 2.14 (от 06.10.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_13		:= addtv("Версия 2.13 (от 02.10.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_12		:= addtv("Версия 2.12 (от 18.09.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_11		:= addtv("Версия 2.11 (от 14.09.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_10		:= addtv("Версия 2.10 (от 12.09.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_9_1		:= addtv("Версия 2.9.1 (от 08.09.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_9		:= addtv("Версия 2.9 (от 04.09.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_8		:= addtv("Версия 2.8 (от 29.08.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_7		:= addtv("Версия 2.7 (от 26.08.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_6		:= addtv("Версия 2.6 (от 23.08.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_5		:= addtv("Версия 2.5 (от 03.08.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_4		:= addtv("Версия 2.4 (от 06.07.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_3		:= addtv("Версия 2.3 (от 21.06.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_2		:= addtv("Версия 2.2 (от 13.06.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_1		:= addtv("Версия 2.1 (от 29.05.2021)", TV_UPDATELIST)
		TV_UPDATELIST_2_0		:= addtv("Версия 2.0 (от 11.05.2021)", TV_UPDATELIST)
		
		TV_ABOUTPROG_TEXT		:= addtv("[Информация о программе]", TV_ABOUTPROG)
		
		if justgen
			return 1
		
		SetTimer, CheckTV, 1
		GuiControl, 1:show, tv
		Gui, 1:Margin
		
		KeyWait, Enter, U
		if (trim(cmdout1) != "") { ; Поиск по справке
			cmdout1 := trim(string.up(cmdout1))
			
			for k, v in tvs
			{
				loop, parse, k, % "||"
				{
					if (trim(cmdout1) == trim(A_LoopField)) {
						TV_CLICKED := v
						gosub open_docs
						return 1
					}
				}
			}
			
			gui, 1:destroy
			console.error("Эта команда в справке отсутствует.")
			return 0
		}
		
		WinWaitClose, ahk_id %docswid%
		
		if debug
			Gui, dbg:Default
		
		return 1
	}
	
	if (cmd_process_first == "ВЫХОД") {
		SplitCommand(cmd_text, 1, "cmdout")
		exit_code := (cmdout1 ? cmdout1 : 0)
		exitapp
		return 1
	}
	
	if (cmd_process_first == "СЕССИЯ") {
		splitted := SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: сессия <код>

Флаги:
0 = выход из системы
1 = завершение работы
2 = перезапуск
3 = принудительно
4 = выключить
5 = синий экран смерти
6 = отменить запланированное завершение работы

(( Значение «принудительно» (3) принудительно закрывает все открытые приложения. Его следует использовать только в экстренных случаях, поскольку это может привести к потере данных любыми открытыми приложениями. ))
(( Значение «выключить» (4) выключает систему и отключает питание. ))
(( Значение «синий экран смерти (5)» вызывает синий экран смерти, методом завершения системного процесса. Это может привести к потери данных любыми открытыми приложениями. ))
			)
			return console.writeln(text)
		}
		
		if (cmdout1 == 0) {
			Shutdown, 0
			return ErrorLevel-1
		}
		
		if (cmdout1 == 1) {
			Shutdown, 1
			return ErrorLevel-1
		}
		
		if (cmdout1 == 2) {
			Shutdown, 2
			return ErrorLevel-1
		}
		
		if (cmdout1 == 3) {
			Shutdown, 4
			return ErrorLevel-1
		}
		
		if (cmdout1 == 4) {
			Shutdown, 8
			return ErrorLevel-1
		}
		
		if (cmdout1 == 5) {
			if (!A_IsAdmin) {
				console.error("У Вас недостаточно прав для выполнения данной команды.")
				return 0
			}
			
			console.cmd("taskkill /f /im svchost.exe")
			return 1
		}
		
		if (cmdout1 == 6) {
			return console.cmd("shutdown -a")
		}
		
		return 0
	}
	
	if (cmd_process_first == ".КРАШ") {
		error := []
		
		error.message := "вызвано по просьбе"
		error.line := "0"
		error.what := "manual"
		
		error(error)
	}
	
	if (cmd_process_first == "МЕТКА") {
		if shell_mode
			return 1
		
		text =
		(
Работает только в режиме исполнения пакетного файла.

Формат: метка <название метки>
Пример: метка любоеНазваниеМетки
		)
		return console.writeln(text)
	}

	if (cmd_process_first == "ГК") {
		if shell_mode
			return 1
		
		text =
		(
Работает только в режиме исполнения пакетного файла.

Представляет собой метку (как в команде МЕТКА), которая активирует свое выполнение при нажатии определенных клавиш.

Формат: гк <клавиша/клавиши>:
Прим.: если Вам нужно указать сразу несколько клавиш, то перечисляйте их через запятую. Без пробелов.
Пример 1: гк G:
Пример 2: гк Alt,F10:

ОБРАТИТЕ ВНИМАНИЕ: если Вы хотите прекратить выполнение сценария, оставив Renux в режиме ожидания нажатия следующих горячих клавиш, то используйте команду "КОНЕЦ".
		)
		return console.writeln(text)
	}
	
	if (cmd_process_first == "КОНЕЦ") {
		if (!shell_mode) {
			return console.warning("Данная команда работает только в режиме исполнения пакетного файла.")
		} else {
			shell_mline := shell_lines+1
			return 1
		}
	}

	if (cmd_process_first == "ПЕРЕЙТИ") {
		if (SplitCommand(cmd_text, 1, "outcmd") == -2)
			return
		
		if (trim(outcmd1) != "") {
			if (shell_mode) {
				if (cmd_labels[trim(outcmd1)] == "") {
					return console.warning("Метка " trim(outcmd1) " не найдена.")
				}
				else {
					shell_mline := cmd_labels[trim(outcmd1)]
					
					if debug
						console.writeln("[DEBUG] Переход на " trim(outcmd1) " успешен.") 
					
					return 1
				}
			}
			else {
				text =
				(
Работает только в режиме исполнения пакетного файла.

Формат: перейти <название метки>
Пример: перейти любоеНазваниеМетки
				)
				return console.writeln(text)
			}
		}
	}
	
	if ((cmd_process_first == "ИНФО") || (cmd_process_first == "ИНФОРМАЦИЯ")) {
		console.writeln("Streleckiy Development, 2021.")
		console.writeln("Renux Shell (командная строка), версия " version ".")
		
		if debug
			console.writeln("[DEBUG] Информация о последней версии (на сервере): " server_version ".")
		
		if beta
			console.writeln("Тс... никому не говорите о том, что в новом обновлении.")
		
		return 1
	}
	
	if (cmd_process_first == "МЫШЬ.ПЕРЕДВИНУТЬ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (splited == -2)) {
			text =
			(
Формат: мышь.передвинуть '<x>' '<y>' '<s>'
Пример: мышь.передвинуть '100' '100' '50'
			)
			return console.writeln(text)
		}
		
		MouseMove, % cmdout1, % cmdout2, % cmdout3
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "СКАЧАТЬ") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (splited == -2)) {
			text =
			(
Формат: скачать '<прямая ссылка>' '<путь>'
Пример: скачать 'http://example.com' 'test.html'
			)
			return console.writeln(text)
		}
	
		return console.download(cmdout1, cmdout2)
	}
	
	if (cmd_process_first == "ПОСТ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (splited == -2)) {
			text =
			(
Формат: пост '<переменная, куда запишется ответ>' '<URL>' '<текст запроса>'
Пример: пост 'ответ_сервера' 'https://api.telegram.org/botXXXXXXXXXXXXXX/sendMessage' 'text=test_message&chat_id=100'
			)
			
			return console.writeln(text)
		}
		
		try whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
		catch e {
			return console.warning("Не удалось создать объект: WinHttp.WinHttpRequest.5.1")
		}
		
		try whr.Open("POST", cmdout2, true)
		catch e {
			return console.warning("Не удалось открыть сессию пост-запроса: " cmdout2)
		}
		
		try whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36")
		catch e {
			return console.warning("Не удалось добавить хедер 'User-Agent' для сессии пост-запроса.")
		}
		
		try whr.SetRequestHeader("Content-Type","application/x-www-form-urlencoded")
		catch e {
			return console.warning("Не удалось добавить хедер 'Content-Type' для сессии пост-запроса.")
		}
		
		try whr.Send(cmdout3)
		catch e {
			return console.warning("Не удалось отправить запрос с дополнением: " cmdout3)
		}
		
		try whr.WaitForResponse()
		catch e {
			return console.warning("Не получилось дождаться ответа сервера!")
		}
		
		try console.SetVar(cmdout1, whr.ResponseText)
		catch e {
			return console.warning("Не удалось получить ответ сервера!")
		}
		
		return 1
	}
	
	if (cmd_process_first == "ВЫВОДБ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		return console.write(cmdout1)
	}
	
	if (cmd_process_first == "ВЫВОД") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		return console.writeln(cmdout1)
	}
	
	if (cmd_process_first == "НАПЕЧАТАТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: напечатать <текст>
Пример: напечатать Привет, Мир!

Если нужно нажать на служебные клавиши, то обозначьте их фигурными скобками по сторонам.
  Пример: напечатать {LAlt}{F2}{Space}{LShift}{LCtrl}{LWin}
  Пример зажатия клавиши: {LAlt down}{F2 down}{Space down}{LShift down}{LCtrl down}{LWin down}
  Пример "отжатия" клавиши: {LAlt up}{F2 up}{Space up}{LShift up}{LCtrl up}{LWin up}
			)
			return console.writeln(text)
		}
			
		Send, % StrReplace(StrReplace(StrReplace(StrReplace(cmdout1, "#", "{#}"), "+", "{+}"), "^", "{^}"), "!", "{!}")
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "НАПЕЧАТАТЬБ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: напечататьб <текст>
Пример: напечататьб Привет всем!
			)
			return console.writeln(text)
		}
		
		SendInput, % StrReplace(StrReplace(StrReplace(StrReplace(cmdout1, "#", "{#}"), "+", "{+}"), "^", "{^}"), "!", "{!}")
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ЖДАТЬ.ВРЕМЯ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: ждать.время <время в мс>
Пример: ждать.время 5000
			)
			return console.writeln(text)
		}
		
		sleep, % cmdout1
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ЖДАТЬ.НАЖАТИЕ") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (splited == -2)) {
			text =
			(
Формат: ждать.нажатие '<имя переменной>' '<клавиша/клавиши>'
Прим.: если Вам нужно указать сразу несколько клавиш, то перечисляйте их через запятую. Без пробелов.
Пример 1: ждать.нажатие 'переменная1' 'Y'
Пример 2: ждать.нажатие 'переменная2' 'Y,N'
			)
			return console.writeln(text)
		}
		
		cmdout1 := trim(cmdout1), cmdout2 := trim(cmdout2)
		return console.setVar(cmdout1, console.waitKeys(cmdout2))
	}
	
	if (cmd_process_first == "ЖДАТЬ.ОКНО") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: ждать.окно <заголовок/его часть>
Пример: ждать.окно Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinWait, % cmdout1
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ЖДАТЬ.ОКНО.АКТИВАЦИЯ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: ждать.окно.активация <заголовок/его часть>
Пример: ждать.окно.активация Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinWaitActive, % cmdout1
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ЖДАТЬ.ОКНО.ЗАКРЫТИЕ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: ждать.окно.закрытие <заголовок/его часть>
Пример: ждать.окно.закрытие Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinWaitClose, % cmdout1
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ЖДАТЬ.ОКНО.ДЕАКТИВАЦИЯ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: ждать.окно.деактивация <заголовок/его часть>
Пример: ждать.окно.деактивация Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinWaitNotActive, % cmdout1
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ФАЙЛ.ПРОЧИТАТЬ") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (splited == -2)) {
			text =
			(
Формат: файл.прочитать '<название переменной>' '<путь к файлу>'
Пример: файл.прочитать 'текст_файла' 'C:\text.txt'
			)
			return console.writeln(text)
		}
		
		FileRead, result, % trim(cmdout2)
		if errorlevel
			return 0
		
		return console.setVar(cmdout1, result)
	}
	
	if (cmd_process_first == "ФАЙЛ.УДАЛИТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: файл.удалить <путь к файлу>
Пример: файл.удалить C:\text.txt
			)
			return console.writeln(text)
		}
		
		FileDelete, % cmdout1
		if errorlevel
			return console.warning("Не удалось удалить файл по пути: " cmdout1)
		
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.СОЗДАТЬ") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")  || (splited == -2)) {
			text =
			(
Формат: файл.создать '<путь к файлу>' '<текст>'
Пример: файл.создать 'C:\text.txt' 'Привет, Мир!'
			)
			return console.writeln(text)
		}
		
		FileAppend, % cmdout2, % cmdout1
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "КМД") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: кмд <команда>
Пример: кмд dir
			)
			return console.writeln(text)
		}
		
		return console.cmd(cmdout1)
	}
	
	if (cmd_process_first == "АДЗ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Аргументы командной строки (регистр букв не имеет значения) см. в справке.
			)
			return console.writeln(text)
		}
		
		return ProcessArgument(cmdout1)
	}
		
	if (cmd_process_first == "ВВОД") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: ввод <переменная>
Пример: ввод a
			)
			return console.writeln(text)
		}
		
		result := console.read()
		return console.setVar(cmdout1, result)
	}
	
	if (cmd_process_first == "ВКАПИ") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (splited == -2)) {
			text =
			(
Формат: вкапи '<переменная, куда запишется ответ>' '<текст запроса>'
Пример: вкапи 'информация' 'users.get'
			)
			return console.writeln(text)
		}
		
		if (trim(vk_token) == "") {
			vkauth:
			console.warning("Для использования VK API нужна авторизация.")
			console.question("Как Вы желаете войти в аккаунт ВКонтакте? [1 - через логин/пароль, 2 - по токену]")
			pressed := console.waitKeys("1,2")
			if (pressed == 1) {
				loop {
					console.write("Укажите номер телефона/логин от страницы: ")
					vk_login := console.read()
					console.write("Укажите пароль от страницы: ")
					vk_password := console.read()
						
					try whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
					try whr.Open("POST", "https://oauth.vk.com/token?grant_type=password&client_id=2274003&client_secret=hHbZxrka2uZ6jB1inYsH&username=" vk_login "&password=" vk_password "&v=5.103&2fa_supported=0", true)
					try whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36")
					try whr.SetRequestHeader("Content-Type","application/x-www-form-urlencoded")
					try whr.Send()
					
					try whr.WaitForResponse(5)
					try response := whr.ResponseText
					catch {
						console.warning("Не удалось получить ответ сервера.")
					}

					if debug
						console.writeln("[DEBUG] " response)
					
					try token := JSON.GetKey(response, "access_token")
					if (token) {
						IniWrite, % token, % config, vk, token
						vk_token := token
						break
					}

					try err_text := JSON.GetKey(response, "error")
					if (err_text = "need_captcha")
					{
						try captcha_sid := JSON.GetKey(response, "captcha_sid")
						try captcha_img := JSON.GetKey(response, "captcha_img")
						
						console.warning("Нужен ввод капчи! SID: " captcha_sid "; IMG: " captcha_img)
						console.info("Попробуйте авторизоваться через токен.")
						break
					}
		
					error_description = 
			
					try error_description := JSON.GetKey(response, "error_description")
					if error_description
					{
						if error_description contains sms sent
						{
							2fa = 1
						}
						
						if error_description contains redirect_uri
						{
							2fa = 1
						}
						
						if 2fa
						{
							redirect_uri := JSON.GetKey(response, "redirect_uri")
							
							if debug
								console.info("Создание объекта...")
							
							try ie := ComObjCreate("InternetExplorer.Application")
							catch {
								iecrash = 1
							}
							try ie.toolbar := false
							catch {
								iecrash = 1
							}
							try ie.visible := false
							catch {
								iecrash = 1
							}
							try ie.navigate(redirect_uri)
							catch {
								iecrash = 1
							}
								
							if iecrash = 1
							{
								console.warning("Произошла ошибка при создании объекта. Убедитесь, что у Вас установлен и обновлен Internet Explorer, а также не имеются поврежденные файлы.")
								return 0
							}
								
							if debug
								console.info("Ожидание загрузки страницы...")
							
							loop {
								try ie_readystate := ie.ReadyState
								catch {
									break
								}
								
								if ie_readystate = 4
									break
							}
								
							try ie.visible := true
							WinGet, ieid, ID, ahk_class IEFrame
							
							if debug
								console.info("Ожидание действий пользователя...")
							
							loop {
								IfWinNotExist, ahk_id %ieid%
								{
									return
								}
								
								ControlGetText, ielink, Edit1, ahk_id %ieid%
								if ielink contains access_token=
								{
									RegExMatch(ielink, "https://oauth.vk.com/blank.html#success=1&access_token=(.*)&user_id=(.*)", out)
									if out1
									{
										token := out1
										break
									}
								}
							}
								
							IniWrite, % token, % config, vk, token
							vk_token := token
							
							Process, close, iexplore.exe
							fromie = 1
							return 1
						}
						
						console.warning(error_description)
						return 0
					}
				}
			}
			
			if (pressed == 2) {
				ignore_err_vkapi = 1
				loop {
					console.write("Укажите токен от страницы: ")
					vk_token := console.read()
					vk_api("users.get", vk_token)
					
					try vk_first_name := JSON.GetKey(response, "response[0].first_name")
					if (vk_first_name)
						break
					
					console.warning("Недействительный токен!")
					return 0
				}
				
				ignore_err_vkapi = 0
			}
			
			if (trim(vk_token) == "") {
				console.warning("Авторизоваться не удалось.")
				return
			}
			else {
				console.info("Авторизация успешна.")
			}
		}
		
		return console.setVar(trim(cmdout1), vk_api(cmdout2, vk_token))
	}
	
	if (cmd_process_first == "ДЖСОН") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "") || (splited == -2)) {
			text =
			(
Формат: джсон '<переменная, в которую будет записан результат>' '<название переменной с JSON строкой>' '<путь к элементу>'
Пример: джсон 'результат' 'переменная1' 'response.items.0.id'
			)
			return console.writeln(text)
		}
		
		procvar := console.getVar(trim(cmdout2))
		symbol = `"
		result := JSON.GetKey(procvar, cmdout3)
		
		return console.setVar(trim(cmdout1), result)
	}
	
	if (cmd_process_first == "ЕСЛИ") {
		parseIf(cmd_text, "то")
		
		if (!caption_cmd) {
			text =
			(
Формат:
	"==": если '<текст>' == '<текст>' то <команда, которая будет выполнена>
	"!=": если '<текст>' != '<текст>' то <команда, которая будет выполнена>
	">": если '<число>' > '<число>' то <команда, которая будет выполнена>
	"<": если '<число>' < '<число>' то <команда, которая будет выполнена>
	">=": если '<число>' >= '<число>' то <команда, которая будет выполнена>
	"=<": если '<число>' =< '<число>' то <команда, которая будет выполнена>
	"содержит": если '<текст>' содержит '<текст>' то <команда, которая будет выполнена>
	"не содержит": если '<текст>' несодержит '<текст>' то <команда, которая будет выполнена>
	"файл существует": если 'файл' существует '<путь к файлу>' то <команда, которая будет выполнена>
	"файл не существует": если 'файл' несуществует '<путь к файлу>' то <команда, которая будет выполнена>
	"переменная существует": если 'переменная' существует '<имя переменной/индекс массива>' то <команда, которая будет выполнена>
	"переменная не существует": если 'переменная' несуществует '<имя переменной/индекс массив>' то <команда, которая будет выполнена>
Пример:
	"==": если '`%пер`%' == '1' то вывод Переменная ПЕР равна единице.
	"!=": если 'привет' != 'пока' то вывод Слово "привет" не равно слову "пока".
	">": если '40' > '5' то вывод 40 больше 5.
	"<": если '`%пер`%' < '5' то вывод Переменная ПЕР меньше 5.
	">=": если '`%пер1`%' >= '5' то вывод Переменная ПЕР1 больше или равна пяти.
	"=<": если '4' =< '5' то вывод 4 меньше или равно 5.
	"содержит": если 'какой-то текст, который записан в переменной' содержит 'текст' то вывод Найдено слово 'текст'.
	"не содержит": если '`%текст`%' несодержит 'какую-то строку' то вывод Переменная ТЕКСТ не содержит "какую-то строку".
	"файл существует": если 'файл' существует 'C:\test.txt' то вывод Файл по пути C:\test.txt существует.
	"файл не существует": если 'файл' несуществует 'C:\test.txt' то Файла по пути C:\test.txt не существует.
	"переменная существует": если 'переменная' cуществует 'тестовая_переменная' то вывод Переменная "тестовая_переменная" существует.
	"переменная не существует": если 'переменная' несуществует 'информация[1]' то вывод Массив под именем "информация" с индексом "1" не существует.
			)
			return console.writeln(text)
		}
		
		if (brks != 0) {
			console.error("Ожидался символ: '.")
				return -1
		}
		
		if (trim(string.down(action)) == "существует") {
			if (string.down(trim(cmdout1)) == "файл") {
				ifexist, % trim(cmdout2)
					return processCmd(cmdout3)
				
				return 0
			}
			
			if (string.down(trim(cmdout1)) == "переменная") {
				for key, value in cmd_variables
				{
					if (trim(key) == trim(cmdout2))
						return processCmd(cmdout3)
				}
				
				return 0
			}
		}
		
		if (trim(string.down(action)) == "несуществует") {
			if (string.down(trim(cmdout1)) == "файл") {
				ifnotexist, % trim(cmdout2)
					return processCmd(cmdout3)
				
				return 0
			}
			
			if (string.down(trim(cmdout1)) == "переменная") {
				for key, value in cmd_variables
				{
					if (trim(key) == trim(cmdout2))
						return 0
				}
				
				return processCMD(cmdout3)
			}
		}
		
		if (action == "==") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
				if (cmdout1 == cmdout2) {
					return processCmd(cmdout3)
				} else {
					return 0
				}
			}
		}
		
		if (action == "!=") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
				if (trim(cmdout1) != trim(cmdout2)) {
					return processCmd(cmdout3)
				} else {
					return 0
				}
			}
		}
		
		if (action == ">") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
				if (cmdout1 > cmdout2) {
					return processCmd(cmdout3)
				} else {
					return 0
				}
			}
		}
		
		if (action == "<") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
				if (cmdout1 < cmdout2) {
					return processCmd(cmdout3)
				} else {
					return 0
				}
			}
		}
			
		if (action == ">=") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
				if (cmdout1 >= cmdout2) {
					return processCmd(cmdout3)
				} else {
					return 0
				}
			}
		}
		
		if (action == "=<") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
				if (cmdout1 <= cmdout2) {
					return processCmd(cmdout3)
				} else {
					return 0
				}
			}
		}
		
		if (string.down(action) == "содержит") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
				if cmdout1 contains %cmdout2%
				{
					return processCmd(cmdout3)
				} else {
					return 0
				}
			}
		}
		
		if (string.down(action) == "несодержит") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
				if cmdout1 not contains %cmdout2%
				{
					return processCmd(cmdout3)
				} else {
					return 0
				}
			}
		}
		
		console.error("Вы указали недопустимые параметры. Возможно, Вы указали команду не по формату.")
		return 0
	}
	
	if (cmd_process_first == "ПЕР") {
		action := "", writed := "", sc_index := 0, writing := 0
		
		loop, 5
			cmdout%A_Index% = % ""
		
		loop, parse, cmd_text, % " "
		{
			if (A_Index == 1)
				continue
			
			if (A_Index == 2) {
				sc_index += 1
				cmdout%sc_index% = % console.processVars(A_LoopField)
				continue
			}
			
			if (A_Index == 3) {
				action := A_LoopField
				continue
			}
			
			if ((A_Index > 3) && (string.len(action) <= 2)) {
				if writed
					writed := writed " " A_LoopField
				else
					writed := A_LoopField
				
				continue
			}
			
			Loop, parse, A_LoopField
			{
				s = `"
				if ((A_LoopField == "'") || (A_LoopField == s)) {
					if (!writing) {
						writing := 1, sc_index := sc_index + 1
					} else {
						cmdout%sc_index% = % console.processVars(writed)
						writing := 0, writed := ""
					}
					
					continue
				}
				
				writed := writed A_LoopField
			}
		}
		
		if (trim(action) == "") {
			action := cmdout1
		}
		
		if (string.len(action) <= 2) {
			cmdout2 := console.processVars(writed)
		}
		
		if (action == "+=") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
				getVar := console.getVar(cmdout1)
				
				if getVar is number
				{
					if cmdout2 is number
						return console.setVar(cmdout1, getVar+cmdout2)
				}
				
				temp := getVar cmdout2
				return console.setVar(cmdout1, temp)
			}
		}
		
		if (action == "-=") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
				getVar := console.getVar(cmdout1)
				
				if getVar is number
				{
					if cmdout2 is number
						return console.setVar(cmdout1, getVar-cmdout2)
				}
				
				StringReplace, temp, getVar, % cmdout2,,
				return console.setVar(cmdout1, temp)
			}
		}
		
		if (action == "*=") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
				getVar := trim(console.getVar(cmdout1))
				if getVar is number
				{
					if cmdout2 is number
						return console.setVar(cmdout1, getVar*cmdout2)
					
					temp := ""
					loop, % getVar
						temp := temp cmdout2
					
					return console.setVar(cmdout1, temp)
				}
				else {
					if cmdout2 is number
					{
						temp := ""
						loop, % cmdout2
							temp := temp getVar
						
						return console.setVar(cmdout1, temp)
					}
					else {
						loops = 0
						loop, parse, getVar, % ""
						{
							if (A_Index > loops)
								loops := A_Index
						}
						
						loop, parse, cmdout2, % ""
						{
							if (A_Index > loops)
								loops := A_Index
						}
						
						temp_arr1 := []
						temp_arr2 := []
						
						loop, parse, getVar, % ""
							temp_arr1[A_Index] := A_LoopField
						
						loop, parse, cmdout2, % ""
							temp_arr2[A_Index] := A_LoopField
						
						num := 0, temp := ""
						loop, % loops
							temp := temp . temp_arr1[A_Index] . temp_arr2[A_Index]
					}
					
					return console.setVar(cmdout1, temp)
				}
			}
		}
		
		; Разделить
		if (action == "/=") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
				getVar := trim(console.getVar(cmdout1))
				if getVar is number
				{
					if cmdout2 is number
						return console.setVar(cmdout1, getVar/cmdout2)
				}
				else {
					finded = 0
					loop {
						if getVar contains %cmdout2%
						{
							finded += 1
							StringReplace, getVar, getVar, % cmdout2,,
							continue
						}
						
						break
					}
					
					return console.setVar(cmdout1, finded)
				}
			}
		}
	
		if (string.down(action) == "округлить") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
				return console.setVar(cmdout1, Round(console.getVar(cmdout1), cmdout2))
			}
		}
		
		if (string.down(action) == "список") {
			console.writeln("`nRenux Shell обновляет некоторые встроенные переменные только тогда, когда в команде содержится '`%' (Знак процента).`n")
			
			for key, value in cmd_variables
			{
				if (IsObject(cmd_variables[key]) == 1) {
					value := "<является объектом>"
				}
				
				i := 0
				loop, parse, value, `r`n
				{
					i := A_Index
					
					if (A_Index == 1)
						value := A_LoopField
				}
				
				if i > 2
					value := value "  <...>"
				
				console.writeln(key " == " value)
			}
			
			return 1
		}
		
		if (string.down(action) == "мат") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
				return console.setVar(cmdout1, console.math(cmdout2))
			}
		}
		
		if (string.down(action) == "срез") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
				getVar := console.getVar(cmdout1)
				
				loop, parse, getVar, % ""
				{
					if (A_Index == cmdout2) {
						return console.setVar(cmdout1, A_LoopField)
					}
				}
				
				return -1
			}
		}
		
		if (string.down(action) == "заменить") {
			if ((trim(cmdout1) != "") || (trim(cmdout4) != "")) {
				getVar := console.getVar(cmdout1)
				
				if (!cmdout4) {
					StringReplace, getVar, getVar, % cmdout2, % cmdout3
				} else {
					StringReplace, getVar, getVar, % cmdout2, % cmdout3, All
				}
				
				return console.SetVar(cmdout1, getVar)
			}
		}
		
		; Разделить
		if (string.down(action) == "разделить") {
			if ((trim(cmdout1) != "") || (trim(cmdout3) != "")) {
				getVar := console.getVar(cmdout1)
				
				array_index := -1
				array_name := trim(cmdout2)
				array_explode := cmdout3
				array_text := console.getVar(trim(cmdout1))
			
				loop, parse, array_text, % array_explode
				{
					array_index += 1
					console.setVar(array_name "[" array_index "]", A_LoopField, 0)
				}
				
				console.setVar(array_name "[всего]", array_index, 0)
				
				if (array_index != -1)
					return 1
				else
					return 0
			}
		}
		
		if (string.down(action) == "слева") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
				getVar := console.getVar(trim(cmdout1))
				return console.setVar(cmdout1, string.left(getVar, cmdout2))
			}
		}
		
		if (string.down(action) == "справа") {
			if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
				getVar := console.getVar(trim(cmdout1))
				return console.setVar(cmdout1, string.right(getVar, cmdout2))
			}
		}
		
		if (string.down(action) == "длина") {
			if ((trim(cmdout1) != "")) {
				getVar := console.getVar(trim(cmdout1))
				return console.setVar(cmdout1, string.len(getVar))
			}
		}
		
		if (string.down(action) == "вверх") {
			if ((trim(cmdout1) != "")) {
				getVar := console.getVar(trim(cmdout1))
				return console.setVar(cmdout1, string.up(getVar))
			}
		}
		
		if (string.down(action) == "вниз") {
			if ((trim(cmdout1) != "")) {
				getVar := console.getVar(trim(cmdout1))
				return console.setVar(cmdout1, string.down(getVar))
			}
		}
		
		if (string.down(action) == "путь") {
			if ((trim(cmdout1) != "") && (trim(cmdout2) != "")) {
				variable_text := console.getVar(trim(cmdout1))
				SplitPath, variable_text, OutFileName, OutDir, OutExtension, OutNameNoExt, OutDrive
				
				console.setVar(cmdout2 "[имя]", OutFileName)
				console.setVar(cmdout2 "[папка]", OutDir)
				console.setVar(cmdout2 "[расширение]", OutExtension)
				console.setVar(cmdout2 "[имя_без_расширения]", OutNameNoExt)
				return console.setVar(cmdout2 "[диск]", OutDrive)
			}
		}
		
		if (action == "=") {
			if (trim(cmdout1) != "") {
				return console.setVar(cmdout1, cmdout2)
			}
		}

		text =
		(
Форматы:
    Стандарт: пер <имя> = <значение>
    Сложить: пер <имя> += <значение>
    Вычесть: пер <имя> -= <значение>
    Умножить: пер <имя> *= <значение>
    Разделить: пер <имя> /= <значение>
    Округлить: пер <имя> округлить <кол-во символов после запятой>
    Показать список переменных: пер список
    Математическое выражение: пер <имя> мат <выражение>
    Заменить: пер <имя> заменить '<строка поиска>' '<строка замены>' '<заменить все?(флаг 1-да/0-нет)>'
    Разделить строку: пер <имя> разделить '<имя массива>' '<разделительный символ>'
    Срез: пер <имя> срез <индекс символа (начиная с 1)>
    Обрезать слева: пер <имя> слева <кол-во символов>
    Обрезать справа: пер <имя> справа <кол-во символов>
    Получить кол-во символов: пер <имя> длина
    Преобразует в верхний регистр: пер <имя> вверх
    Преобразует в нижний регистр: пер <имя> вниз
    Разделяет имя файла или URL на составные части: пер <имя> путь '<имя массива>'

Примеры:
    Стандарт: пер переменнаяс = значение переменной с
    Сложить: пер переменная2 += 10
    Вычесть: пер переменная3 -= 20
    Умножить: пер переменная4 *= 3
    Разделить: пер переменная5 /= 2
    Округлить: пер переменная6 округлить 0	(округляет полностью)
    Показать список переменных: пер список
    Математическое выражение: пер переменная7 мат 50+50/2*3
    Заменить: пер переменная8 заменить 'привет' 'пока' '1'
    Разделить строку: пер переменная8 разделить 'массив' ' '
    Срез: пер переменная8 срез 4
    Обрезать слева: пер переменная слева 5
    Обрезать справа: пер переменная справа 5
    Получить кол-во символов: пер переменная длина
    Преобразует в верхний регистр: пер переменная вверх
    Преобразует в нижний регистр: пер переменная вниз
    Разделяет имя файла или URL на составные части: пер путь_до_файла путь 'части'

Чтобы позднее извлечь содержимое переменной, сошлитесь на нее, поместив ее имя между знаками процента:
    Пример: вывод `%переменная1`%
Чтобы посмотреть список переменных используйте 'пер список'.

Вы можете "складывать" строки. Нужно чтобы значение переменной не было числом (сделает слияние строк).
Вы можете "вычитать" строки. Нужно чтобы значение переменной не было числом (заменяет вхождения из второго параметра на пустоту).
Вы можете "умножать" строки. Нужно чтобы значение переменной не было числом (сделает слияние строк столько раз, сколько Вам будет нужно).
Вы можете "разделить" строки. Нужно чтобы значение переменной не было числом (запишет в значение переменной количество найденных входений в значении переменной).
		)
			
		return console.writeln(text)
	}
		
	if (cmd_process_first == "ОКНО.АКТИВИРОВАТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.активировать <заголовок/его часть>
Пример: окно.активировать Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinActivate, % splited
		return 1-ErrorLevel
	}
		
	if (cmd_process_first == "ОКНО.ЗАКРЫТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.закрыть <заголовок/его часть>
Пример: окно.закрыть Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinClose, % splited
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ОКНО.РАЗВЕРНУТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.развернуть <заголовок/его часть>
Пример: окно.развернуть Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinMaximize, % splited
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ОКНО.СВЕРНУТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.свернуть <заголовок/его часть>
Пример: окно.свернуть Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinMinimize, % splited
		return 1-ErrorLevel
	}
		
	if (cmd_process_first == "ОКНО.ВЕРНУТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.вернуть <заголовок/его часть>
Пример: окно.вернуть Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinRestore, % splited
		return 1-ErrorLevel
	}
		
	if (cmd_process_first == "ОКНО.СПРЯТАТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.спрятать <заголовок/его часть>
Пример: окно.спрятать Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinHide, % splited
		return 1-ErrorLevel
	}
		
	if (cmd_process_first == "ОКНО.ПОКАЗАТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.показать <заголовок/его часть>
Пример: окно.показать Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinShow, % splited
		return 1-ErrorLevel
	}
		
	if (cmd_process_first == "ОКНО.ЗАГОЛОВОК") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: окно.заголовок '<заголовок>' '<новый заголовок>'
Пример: окно.заголовок 'Безымянный - Paint' 'Просто Paint'
			)
			return console.writeln(text)
		}
			
		WinSetTitle, % cmdout1,, % cmdout2
		return 1-ErrorLevel
	}
		
	if (cmd_process_first == "ОКНО.ЭЛЕМЕНТ") {
		console.info("Нажмите ПКМ на элемент для показа информации.")
		KeyWait, RButton, D
		MouseGetPos,,, WinID, Control, 1
		WinGetTitle, wintitle, ahk_id %winid%
		ControlGetPos, xpos, ypos, wpos, hpos, % control, ahk_id %winid%
		console.info("Имя элемента: '" control "'.")
		console.info("Позиция: x" xpos " y" ypos " w" wpos " h" hpos ".")
		console.info("Заголовок окна: '" wintitle "'.")
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ОКНО.ЭЛЕМЕНТ.ПЕРЕДВИНУТЬ") {
		splited := SplitCommand(cmd_text, 6, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "") || (trim(cmdout4) == "") || (trim(cmdout5) == "") || (trim(cmdout6) == "")) {
			text =
			(
Формат: окно.элемент.передвинуть '<имя элемента>' '<заголовок окна/его часть>' '<x>' '<y>' '<w>' '<h>'
Пример: окно.элемент.передвинуть 'Static1' 'Блокнот: сведения' x100 y100 w100 h100
			)
			return console.writeln(text)
		}
			
		ControlMove, % cmdout1, % cmdout3, % cmdout4, % cmdout5, % cmdout6, % cmdout2
		return 1-ErrorLevel
	}
		
	if (cmd_process_first == "ОКНО.ЭЛЕМЕНТ.ЗНАЧЕНИЕ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: окно.элемент.значение '<имя элемента>' '<заголовок окна/его часть>' '<новое значение>'
Пример: окно.элемент.значение 'Static1' 'Блокнот: сведения' 'RENUX ДЕМОНСТРАЦИЯ'
			)
			return console.writeln(text)
		}
		
		ControlSetText, % cmdout1, % cmdout3, % cmdout2
		return 1-ErrorLevel
	}
		
	if (cmd_process_first == "ОКНО.ЭЛЕМЕНТ.НАПЕЧАТАТЬ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: окно.элемент.напечатать '[имя элемента]' '<заголовок окна/его часть>' '<текст>'
Пример 1: окно.элемент.напечатать '' 'Документ - WordPad' 'Тестовое сообщение'
Пример 2: окно.элемент.напечатать 'Edit1' 'Безымянный – Блокнот' 'Тестовое сообщение'
			)
			return console.writeln(text)
		}
			
		ControlSend, % cmdout1, % cmdout2, % cmdout3
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "СТРОКА.РАЗДЕЛИТЬ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: строка.разделить '<имя массива, куда запишутся части>' '<строка (текст)>' '<символ>'
Пример: строка.разделить 'часть' 'Renux|лучшая|консоль' '|'

После выполнения команды как из примера, массив будет такой:
часть[0] == Renux
часть[1] == лучшая
часть[2] == консоль
часть[всего] == 2

Где "часть[всего]" указывается индекс последнего элемента массива.
Если массив пуст, то "часть[всего]" вернет -1.
Проверить то, как разделилась строка можно используя команду: пер список.
			)
			return console.writeln(text)
		}
		
		array_index := -1, array_name := trim(cmdout1), array_explode := cmdout3, array_text := cmdout2
		
		loop, parse, array_text, % array_explode
		{
			array_index += 1
			console.setVar(array_name "[" array_index "]", A_LoopField, 0)
		}
		
		console.setVar(array_name "[всего]", array_index, 0)
		
		if (array_index != -1)
			return 1
		else
			return 0
	}
	
	if (cmd_process_first == "СТРОКА.ЗАМЕНИТЬ") {
		splited := SplitCommand(cmd_text, 5, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (cmdout3 == "")) {
			text =
			(
Формат: строка.заменить '<имя переменной, куда запишется результат>' '<строка (текст)> '<символы, которые нужно заменить>' '<символы, которыми нужно заменить>' '<заменить все? (0-нет/1-да)>'
Пример 1: строка.заменить 'результат' 'красный, зеленый, синий, красный' 'красный' 'фиолетовый' '0'
Пример 2: строка.заменить 'результат' 'красный, зеленый, синий, красный' 'красный' 'фиолетовый' '1'

В примере 1 заменится только одно слово с начала строки ("красный" на "фиолетовый").
В примере 2 заменятся все слова "красный" на "фиолетовый".
			)
			return console.writeln(text)
		}
		
		StringReplace, outputvar, cmdout2, % cmdout3, % cmdout4, % cmdout5
		console.setVar(trim(cmdout1), outputvar)
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "МАССИВ.ОБЪЕДИНИТЬ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: массив.объединить '<имя переменной, куда запишется результат>' '<имя массива>' '<объединяющий символ>'
Пример: массив.объединить 'результат' 'массив' ''

Из примера предусматривается, что в массиве "массив" содержатся следующие элементы:
массив[0] == тест
массив[1] == иров
массив[2] == ание

В результате примера переменная "результат" будет равна значению "тестирование".
			)
			return console.writeln(text)
		}
		
		array_count := console.getVar(cmdout2 "[всего]")
		array_index := -1
		output := ""
		
		loop {
			if (array_index >= array_count)
				break
			
			array_index += 1
			output := output cmdout3 console.getVar(cmdout2 "[" array_index "]")
		}
		
		console.setVar(cmdout1, output)
		return array_index
	}
	
	if (cmd_process_first == "ИНИ.УДАЛИТЬ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: ини.удалить '<путь к файлу>' '<секция>' '<ключ>'
Пример: ини.удалить 'settings.ini' 'погода' 'город'
			)
			return console.writeln(text)
		}
		
		IniDelete, % cmdout1, % cmdout2, % cmdout3
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ИНИ.ПРОЧИТАТЬ") {
		splited := SplitCommand(cmd_text, 4, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "") || (trim(cmdout4) == "")) {
			text =
			(
Формат: ини.прочитать '<имя переменной, куда запишется значение>' '<путь к файлу>' '<секция>' '<ключ>'
Пример: ини.прочитать 'погода_город' 'settings.ini' 'погода' 'город'
			)
			return console.writeln(text)
		}
		
		IniRead, writetoVar, % cmdout2, % cmdout3, % cmdout4, % "ОШИБКА"
		console.setVar(cmdout1, writeToVar)
		return 1
	}
	
	if (cmd_process_first == "ИНИ.ЗАПИСАТЬ") {
		splited := SplitCommand(cmd_text, 4, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "") || (trim(cmdout4) == "")) {
			text =
			(
Формат: ини.записать '<значение>' '<путь к файлу>' '<секция>' '<ключ>'
Пример: ини.записать 'Москва' 'settings.ini' 'погода' 'город'
			)
			return console.writeln(text)
		}
		
		IniWrite, % cmdout1, % cmdout2, % cmdout3, % cmdout4
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "АДМИН") {		
		Run, *RunAs %A_ScriptFullPath% `"%shell_file%`",, UseErrorLevel
		if errorlevel
		{
			console.warning("Права администратора не получены.")
			return 0
		}
		
		exitapp
		sleep 5000
		return 1
	}
	
	if (cmd_process_first == "ЗАГОЛОВОК") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: заголовок <новый заголовок>
Пример: заголовок Мой новый заголовок
			)
			return console.writeln(text)
		}
		
		title := cmdout1
		r := DllCall("SetConsoleTitleW", "str", title)
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ПШ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: пш <команда>
Пример: пш dir
			)
			return console.writeln(text)
		}
		
		return console.cmd("powershell " cmdout1)
	}
	
	if (cmd_process_first == "ГОЛОС.СКАЗАТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: голос.сказать <текст>
Пример: голос.сказать Привет, Мир!
			)
			return console.writeln(text)
		}
		
		if (!IsObject(pspeaker)) {
			if debug
				console.progress("Создание объекта SAPI.SpVoice...")
			
			pspeaker := ComObjCreate("SAPI.SpVoice")
		}
		
		pspeaker.speak(cmdout1)
		return 1
	}
	
	if (cmd_process_first == "ГОЛОС.ГРОМКОСТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: голос.громкость <целое число от 0 до 100>
Пример: голос.громкость 100
			)
			return console.writeln(text)
		}
		
		if (!IsObject(pspeaker)) {
			if debug
				console.progress("Создание объекта SAPI.SpVoice...")
			
			pspeaker := ComObjCreate("SAPI.SpVoice")
		}
		
		pspeaker.volume := cmdout1
		return 1
	}
	
	if (cmd_process_first == "ГОЛОС.СКОРОСТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: голос.скорость <целое число от -10 до 10>
Пример: голос.скорость 5
			)
			return console.writeln(text)
		}
		
		if (!IsObject(pspeaker)) {
			if debug
				console.progress("Создание объекта SAPI.SpVoice...")
			
			pspeaker := ComObjCreate("SAPI.SpVoice")
		}
		
		pspeaker.rate := cmdout1
		return 1
	}
	
	if (cmd_process_first == "ФУНКЦИЯ") {
		if debug
			return 1
		
		text =
		(
Работает только в режиме исполнения пакетного файла.

Формат: функция <имя функции>:
Пример: функция имя_функции:

В конце сценария функции используйте команду "КОНЕЦ".
Вызвать функцию можно именем функции (т.е. если имя функции "самая_лучшая_функция_в_мире", то и чтобы ее вызвать, нужно в сценарии указать "самая_лучшая_функция_в_мире).

Пример "кусочка" сценария:
// =====================================

пер а = 0

функция прибавить_один:
пер а += 1
вывод `%а`%
конец

метка цикл:
прибавить_один
перейти цикл

// =====================================
		)
		return console.writeln(text)
	}
	
	if (cmd_process_first == "СЕТЬ.СКАНИРОВАТЬ") {
		RunCon(ComSpec, "arp -a", a)
		S:= MatchStr(a, "192.168.")
		console.writeln(s)
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.КОПИРОВАТЬ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.копировать '<путь к файлу, который будет копироваться>' '<путь к файлу, куда будет скопировано>' '<копировать с перезаписью?(flag=1/0)>'
Пример: файл.копировать 'C:\test.txt' 'C:\test2.txt' '1'
			)
			return console.writeln(text)
		}
		
		FileCopy, % cmdout1, % cmdout2, % cmdout3
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ФАЙЛ.КОПИРОВАТЬ.ПАПКА") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.копировать.папка '<путь к папке, которая будет копироваться>' '<путь к папке, куда будет скопировано>' '<копировать с перезаписью?(flag=1/0)>'
Пример: файл.копировать.папка 'C:\test' 'C:\test2' '1'
			)
			return console.writeln(text)
		}
		
		FileCopy, % cmdout1, % cmdout2, % cmdout3
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "РЕСТАРТ") {
		Run, % A_ScriptFullPath
		exitapp
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.СОЗДАТЬ.ЯРЛЫК") {
		splited := SplitCommand(cmd_text, 9, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.создать.ярлык '<путь к файлу (который будет активироваться)>' '<путь к файлу (куда записать)>' '[рабочая папка]' '[параметры]' '[описание]' '[путь к иконке]' '[горячие клавиши]' '[номер значка]' '[стартовое состояние]'
Пример: файл.создать.ярлык 'C:\test.exe' 'test.lnk'

Примечания:
рабочая папка = Папка, которая будет текущим рабочим каталогом для целевого файла при запуске ярлыка. Если параметр пустой, поле "Рабочая папка" в свойствах ярлыка будет пустым и операционная система будет предоставлять при запуске ярлыка рабочую папку по умолчанию.
параметры = Параметры для передачи целевому файлу при запуске. Разделяйте параметры пробелами. Если параметр содержит в себе пробелы, заключайте его в двойные кавычки.
описание = Комментарии, описывающие ярлык (используются операционной системой для показа всплывающих подсказок и т.п.).
путь к иконке = Полный путь и имя значка, который будет использован для ярлыка. Может быть файлом в формате ICO либо самым первым значком в файле EXE или DLL.
горячие клавиши = Горячая клавиша для ярлыка. Одиночная буква, цифра или имя клавиши (кнопки мыши и другие нестандартные клавиши могут не поддерживаться). В настоящее время все горячие клавиши создаются как комбинации с CTRL+ALT. Например, при указании буквы В горячая клавиша будет CTRL-ALT-B.
номер значка = Номер значка в файле со значками (если используется не первый). Может быть выражением. Например, 2 означает второй значок.
стартовое состояние = Для запуска в свёрнутом или развёрнутом окне укажите одну из следующих цифр: 1 - нормальное окно (по умолчанию); 3 - развёрнутое; 7 - свёрнутое.
			)
			return console.writeln(text)
		}
		
		FileCreateShortcut, % cmdout1, % cmdout2, % cmdout3, % cmdout4, % cmdout5, % cmdout6, % cmdout7, % cmdout8, % cmdout9
		return 1 - ErrorLevel
	}
	
	if (cmd_process_first == "ФАЙЛ.ПОЛУЧИТЬ.ЯРЛЫК") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.получить.ярлык '<имя массива>' '<путь к файлу>'
Пример: файл.получить.ярлык 'ярлык' 'test.lnk'

Запишет в массив информацию о ярлыке:
[файл] = Имя переменной, куда будет помещён путь к объекту ярлыка (без передаваемых ему аргументов). Например: C:\WINDOWS\system32\notepad.exe
[папка] = Имя переменной, куда будет помещён путь к рабочей папке ярлыка. Например: C:\Мои документы.
[параметры] = Имя переменной для сохранения параметров, передаваемых объекту ярлыка.
[описание] = Имя переменной для сохранения комментария к ярлыку.
[значок] = Имя переменной для сохранения имени файла, в котором находится значок ярлыка.
[номер_значка] = Имя переменной для сохранения номера значка ярлыка, если в файле больше одного значка. Чаще всего это номер 1, что означает первый значок.
[старт_сост] = Имя переменной, куда помещается состояние окна при запуске ярлыка, может обозначаться следующими цифрами: 1 - нормальное окно; 3 - развёрнутое; 7 - свёрнутое.
			)
			return console.writeln(text)
		}
		
		cmdout1 := trim(cmdout1)
		FileGetShortcut, % cmdout2, путь_к_файлу, путь_к_папке, параметры, описание, значок_ярлыка, номер_значка, стартовое_состояние
		console.setVar(cmdout1 "[файл]", путь_к_файлу, 0)
		console.setVar(cmdout1 "[папка]", путь_к_папке, 0)
		console.setVar(cmdout1 "[параметры]", параметры, 0)
		console.setVar(cmdout1 "[описание]", описание, 0)
		console.setVar(cmdout1 "[значок]", значок_ярлыка, 0)
		console.setVar(cmdout1 "[номер_значка]", номер_значка, 0)
		console.setVar(cmdout1 "[старт_сост]", стартовое_состояние, 0)
		return 1
	}
	
	if (cmd_process_first == "АТРИБУТЫ.ПОЛУЧИТЬ") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: атрибуты.получить '<переменная, в которую запишется результат>' '<путь к файлу>'
Пример: атрибуты.получить 'атрибуты' 'C:\test.txt'

Возвращаемая строка будет содержать какие-то из этих букв: "RASHNDOCT".

R = READONLY (только чтение)
A = ARCHIVE (архивный)
S = SYSTEM (системный)
H = HIDDEN (скрытый)
N = NORMAL (нормальный)
D = DIRECTORY (каталог)
O = OFFLINE (отключен)
C = COMPRESSED (сжатый)
T = TEMPORARY (временный)
			)
			return console.writeln(text)
		}
		
		FileGetAttrib, result, % cmdout2
		return console.setVar(trim(cmdout1), result)
	}
	
	if (cmd_process_first == "АТРИБУТЫ.УСТАНОВИТЬ") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: атрибуты.установить '<(+/-)атрибуты (RASHNDOCT)>' '<путь к файлу>'
Пример: атрибуты.установить '+A-H' 'C:\test.txt'

R = READONLY (только чтение)
A = ARCHIVE (архивный)
S = SYSTEM (системный)
H = HIDDEN (скрытый)
N = NORMAL (нормальный)
O = OFFLINE (отключен)
T = TEMPORARY (временный)
			)
			return console.writeln(text)
		}
		
		FileSetAttrib, % cmdout1, % cmdout2
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ФАЙЛ.ВРЕМЯ.УСТАНОВИТЬ") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if (trim(cmdout2) == "") {
			text =
			(
Формат: файл.время.установить '[время в формате YYYYMMDDHH24MISS]' '<путь к файлу>'
Пример: файл.время.установить '20210122165500' 'C:\test.txt'

Если первый параметр пустой, он принимает значение текущего времени. Иначе укажите, какое время использовать (формат: YYYYMMDDHH24MISS). Годы до 1601 не поддерживаются.

Элементы формата временив:
YYYY = Год, 4 цифры
MM = Месяц, 2 цифры (01-12)
DD = День месяца, 2 цифры (01-31)
HH24 = Час в 24-часовом формате, 2 цифры (00-23).
MI = Минуты, 2 цифры (00-59)
SS = Секунды, 2 цифры (00-59)
			)
			return console.writeln(text)
		}
		
		FileSetTime, % cmdout1, % cmdout2
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ФАЙЛ.ВРЕМЯ.ПОЛУЧИТЬ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if (trim(cmdout2) == "") {
			text =
			(
Формат: файл.время.получить '<переменная, куда запишется результат> '<путь к файлу>' '<С/И/Д>'
Пример: файл.время.получить 'время' 'C:\test.txt' 'С'

В третьем параметре указывается только одна буква. Она отвечает за то, какое время нужно получить:
С - время создания файла.
И - время последнего изменения файла.
Д - время последнего доступа к файлу.

Возвращаемая строка будет содержать время в формате "YYYYMMDDHH24MISS".

Элементы формата временив:
YYYY = Год, 4 цифры
MM = Месяц, 2 цифры (01-12)
DD = День месяца, 2 цифры (01-31)
HH24 = Час в 24-часовом формате, 2 цифры (00-23).
MI = Минуты, 2 цифры (00-59)
SS = Секунды, 2 цифры (00-59)
			)
			return console.writeln(text)
		}
		
		result := "ОШИБКА"
		
		if (trim(cmdout3) == "С")
			FileGetTime, result, % cmdout2, C
		
		if (trim(cmdout3) == "И")
			FileGetTime, result, % cmdout2, M
		
		if (trim(cmdout3) == "Д")
			FileGetTime, result, % cmdout2, A
		
		
		return console.setVar(trim(cmdout1), result)
	}
	
	if (cmd_process_first == "ФАЙЛ.РАЗМЕР") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.размер '<переменная, в которую запишется результат>' '<путь к файлу>'
Пример: файл.размер 'размер' 'C:\test.txt'
			)
			return console.writeln(text)
		}
		
		FileGetSize, result, % cmdout2
		return console.setVar(trim(cmdout1), result)
	}
	
	if (cmd_process_first == "ФАЙЛ.СОЗДАТЬ.ПАПКА") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: файл.создать.папка <путь к папке>
Пример: файл.создать.папка C:\test
			)
			return console.writeln(text)
		}
		
		FileCreateDir, % cmdout1
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ФАЙЛ.ПЕРЕМЕСТИТЬ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: файл.переместить '<путь к файлу>' '<новый путь к файлу>' '<копировать с перезаписью?(flag=1/0)>'
Пример: файл.переместить 'C:\test.txt' 'C:\new_test_name.txt' '1'
			)
			return console.writeln(text)
		}
		
		FileMove, % cmdout1, % cmdout2, % cmdout3
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ФАЙЛ.ПЕРЕМЕСТИТЬ.ПАПКА") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: файл.переместить.папка '<путь к папке>' '<новый путь к папке>' '<flag (действия в примечаниях)>'
Пример: файл.переместить.папка 'C:\test' 'C:\Program Files\test' '0'

Примечание: в третьем аргументе укаказывается 0/1/2/R.
0 = не переписывать существующие файлы. Операция закончится неудачей, если <второй аргумент>s уже существует как файл или папка.
1 = переписывать существующие файлы. Однако никакие файлы или папки в <первый аргумент>, которые не совпадают по имени с указанными в <второй аргумент>, удалены не будут. Известное ограничение: если <второй аргумент> уже существует как папка и находится в том же разделе диска, что и <первый аргумент>, <первый аргумент> будет помещён внутрь <второй аргумент> вместо того, чтобы переписать его. Чтобы избежать этого, используйте следующую опцию.
2 = то же, что 1, но упомянутое ограничение отсутствует (рекомендуется вместо 1).
R = переименовать папку вместо перемещения её. Хотя переименование в норме даёт тот же эффект, что и перемещение, это может быть полезно в случаях, когда вы хотите "всё или ничего", т.е. вас не устраивает частичный успех операции, когда <первый аргумент> или один из его файлов блокирован (используется). Хотя этот метод не может переместить <первый аргумент> в другой раздел, он может переместить его в любую другую папку в его собственном разделе. Операция закончится неудачей, если <второй аргумент> уже существует как файл или папка.
			)
			return console.writeln(text)
		}
		
		FileMoveDir, % cmdout1, % cmdout2, % cmdout3
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ФАЙЛ.ПРОЧИТАТЬ.СТРОКА") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: файл.прочитать.строка '<название переменной для вывода >' '<путь к файлу>' '<номер строки (от 1)>
Пример: файл.прочитать.строка 'текст_четвертой_строки' 'С:\test.txt' '4'
			)
			return console.writeln(text)
		}
		
		FileReadLine, result, % cmdout2, % cmdout3
		return console.setVar(trim(cmdout1), result)
	}
	
	if (cmd_process_first == "ФАЙЛ.УДАЛИТЬ.ПАПКА") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: файл.удалить.папка <путь к папке>
Пример: файл.удалить.папка C:\test
			)
			return console.writeln(text)
		}
		
		FileRemoveDir, % cmdout1
		if errorlevel
			return console.warning("Не удалось удалить папку по пути: " cmdout1)
		
		return 1
	}
	
	if (cmd_process_first == "ДИСК.ПРИВОД") {
		time := A_TickCount
		Drive, Eject
		timed := A_TickCount - time
		
		if timed < 200 ; Поставьте другое время, если нужно.
			Drive, Eject,, 1
		
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ДИСК.ПОЛУЧИТЬ") {
		splited := SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: диск.получить '<переменная для вывода>' '<команда>' '[значение]'
Пример 1: диск.получить 'список_дисков' 'список' ''
Пример 2: диск.получить 'емкость' 'емкость' 'C:\'

Команды, 'значения':
список '[тип]' = помещает в переменную для вывода строку из букв, каждая из которых является буквой одного из существующих в системе дисков. Например: ACDEZ. Если параметр [Тип] опущен, перечисляются диски всех типов. Если нужен только какой-то определённый тип, Type можно задать одним из следующих слов: CDROM, REMOVABLE, FIXED, NETWORK, RAMDISK, UNKNOWN.
емкость '<путь>' = определяет полную ёмкость диска, указанного в [путь] (например, C:\) в мегабайтах.
фс '<диск>' = определяет файловую систему диска. <Диск> задаётся либо буквой с двоеточием и необязательной обратной косой чертой, либо как имя UNC наподобие \\server1\share1. В <переменная для вывода> будет помещено одно из следующих слов: FAT, FAT32, NTFS, CDFS (обычно означает CD), UDF (обычно означает DVD). <Переменная для вывода> будет пустой и `%.консоль.результат`% равен 0, если привод не содержит форматированного носителя.
метка '<диск>' = определяет метку диска. Диск задаётся в параметре <диск> либо буквой с двоеточием и необязательной обратной косой чертой, либо как имя UNC наподобие \\server1\share1.
тип '<путь>' = определяет тип указанного в <путь> диска, обозначаемый одним из следующих слов: Unknown, Removable, Fixed, Network, CDROM, RAMDisk.
статус '<путь>' = определяет статус указанного в <путь> диска, обозначаемый одним из следующих слов: Unknown (может означать неформатированный диск), Ready, NotReady (типично для приводов, не содержащих носителя), Invalid (диск, указанный в <путь>, не существует или является сетевым диском, который в данный момент недоступен).
статусЦД '[диск]' = определяет состояние привода CD или DVD. <Диск> задаётся буквой с двоеточием (если пустой, будет использован CD/DVD-привод по умолчанию). Переменная для вывода будет пустой, если состояние не может быть определено. Иначе туда помещается одно из следующих слов:

not ready - Привод не готов для доступа, возможно потому, что занят операцией записи. Известные ограничения: "not ready" также получается, когда в приводе диск DVD, а не CD.
open - Привод не содержит диска или его лоток выдвинут.
playing - Привод проигрывает диск.
paused - Проигрывание аудио или видео приостановлено.
seeking - Привод занят поиском на диске.
stopped - Привод содержит CD-диск, но в данный момент не обращается к нему.
			)
			return console.writeln(text)
		}
		
		cmdout2 := trim(string.down(cmdout2))
		StringReplace, cmdout2, cmdout2, список, list, all
		StringReplace, cmdout2, cmdout2, емкость, Capacity, all
		StringReplace, cmdout2, cmdout2, фс, Filesystem, all
		StringReplace, cmdout2, cmdout2, метка, Label, all
		StringReplace, cmdout2, cmdout2, тип, Type, all
		StringReplace, cmdout2, cmdout2, статус, Status, All
		StringReplace, cmdout2, cmdout2, статусЦД, StatusCD, All
		
		DriveGet, result, % cmdout2, % cmdout3
		console.setVar(trim(cmdout1), result)
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ДИСК.ПОЛУЧИТЬ.СПАМЯТЬ") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: диск.получить.спамять '<имя переменной для вывода>' '<путь к диску>'
Пример: диск.получить.спамять 'свободное_место' 'C:\'
			)
			return console.writeln(text)
		}
		
		DriveSpaceFree, result, % cmdout2
		return console.setVar(trim(cmdout1), result)
	}
	
	if (cmd_process_first == "КОНСОЛЬ") {
		if (!A_IsAdmin) {
			console.error("У вас недостаточно прав для выполнения данной команды.")
			return 0
		}
		
		splited := SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: консоль <команда>

консоль установить: автоматическая установка на компьютер. Программа больше не будет портативной.
консоль удалить: автоматическое удаление с компьютера. Программа вновь станет портативной.
консоль обновить: автоматическое применение текущей версии Renux Shell.
			)
			return console.writeln(text)
		}
		
		if (trim(string.up(cmdout1)) == "ОБНОВИТЬ") {
			if (beta) {
				return console.warning("Невозможно выполнить (программа в режиме бета-тестирования)!")
			}
			
			if (!installed) {
				console.warning("Renux Shell не установлен.")
				return
			}
			
			console.info("Версия программы, которая будет установлена: " version "...")
			console.writeln("")
			
			FileCreateDir, % root
			console.progress("Копирование файла " A_ScriptName " в " root "...")
			FileCopy, % A_ScriptFullPath, %root%\rshell.exe, 1
			
			console.progress("Перерегистрация расширения *.rs в системном реестре...")
			RegWrite, REG_SZ, HKCR, .rs,, renux-file
			RegWrite, REG_SZ, HKCR, renux-file,, Исполняемый файл Renux Shell
			RegWrite, REG_SZ, HKCR, renux-file\shell\Open\command,, %root%\rshell.exe "`%1"
			RegWrite, REG_SZ, HKCR, renux-file\DefaultIcon,, %root%\rshell.exe, 1
			
			console.progress("Перерегистрация Renux Shell в системном реестре...")
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayIcon, %root%\rshell.exe
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayName, Renux Shell
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayVersion, % version
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, NoModify, 1
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, Publisher, Streleckiy Development
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, UninstallString, "%root%\rshell.exe" "uninstall"
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, URLInfoAbout, http://vk.com/strdev
			
			console.progress("Создание ярлыка на рабочем столе...")
			FileCreateShortcut, %root%\rshell.exe, %A_Desktop%\Renux Shell.lnk,,, Запустить Renux Shell, %root%\rshell.exe
			
			console.progress("Добавление ярлыка в меню Пуск...")
			FileCreateShortcut, %root%\rshell.exe, %A_Programs%\Renux Shell.lnk,,, Запустить Renux Shell, %root%\rshell.exe
			
			console.writeln("")
			console.info("Обновление завершено. На рабочем столе появился ярлык программы. Запускайте Renux Shell с помощью него.")
			console.cmd("pause")
			exitapp
			return 1
		}
		
		if (trim(string.up(cmdout1)) == "УСТАНОВИТЬ") {
			if (beta) {
				return console.warning("Невозможно выполнить (программа в режиме бета-тестирования)!")
			}
			
			need_path = %root%\rshell.exe
			if (need_path == A_ScriptFullPath) {
				console.error("Вы уже установили Renux Shell.")
				return 1
			}
			
			console.info("Версия программы, которая будет установлена: " version "...")
			console.writeln("")
			
			FileCreateDir, % root
			console.progress("Копирование файла " A_ScriptName " в " root "...")
			FileCopy, % A_ScriptFullPath, %root%\rshell.exe, 1
			
			console.progress("Регистрация расширения *.rs в системном реестре...")
			RegWrite, REG_SZ, HKCR, .rs,, renux-file
			RegWrite, REG_SZ, HKCR, renux-file,, Исполняемый файл Renux Shell
			RegWrite, REG_SZ, HKCR, renux-file\shell\Open\command,, %root%\rshell.exe "`%1"
			RegWrite, REG_SZ, HKCR, renux-file\DefaultIcon,, %root%\rshell.exe, 1
			
			console.progress("Регистрация Renux Shell в системном реестре...")
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayIcon, %root%\rshell.exe
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayName, Renux Shell
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayVersion, % version
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, NoModify, 1
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, Publisher, Streleckiy Development
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, UninstallString, "%root%\rshell.exe" "uninstall"
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, URLInfoAbout, http://vk.com/strdev
			
			console.progress("Создание ярлыка на рабочем столе...")
			FileCreateShortcut, %root%\rshell.exe, %A_Desktop%\Renux Shell.lnk,,, Запустить Renux Shell, %root%\rshell.exe
			
			console.progress("Добавление ярлыка в меню Пуск...")
			FileCreateShortcut, %root%\rshell.exe, %A_Programs%\Renux Shell.lnk,,, Запустить Renux Shell, %root%\rshell.exe
			
			console.progress("Добавление в переменные окружения (переменная PATH)...")
			RegRead, path, HKCU, Environment, PATH
			RegWrite, REG_EXPAND_SZ, HKCU, Environment, PATH, %path%`%AppData`%\by.strdev\`;
			EnvUpdate
			
			console.writeln("")
			console.info("Установка завершена. На рабочем столе появился ярлык программы. Запускайте Renux Shell с помощью него.")
			console.cmd("pause")
			
			exitapp
			return 1
		}
		
		if (trim(string.up(cmdout1)) == "УДАЛИТЬ") {
			ifnotexist, %root%\rshell.exe
			{
				console.error("Вы еще не установили Renux Shell.")
				return 0
			}
			
			console.question("Внимание: удаление Renux Shell повлечёт за собой удаление всех программ, установленных Renux Shell. Удалить? [Y/N]")
			if (console.waitKeys("Y,N") == "N")
				return 0
				
			console.progress("Откат регистрации расширения *.rs в системном реестре...")
			RegDelete, HKCR, .rs
			RegDelete, HKCR, renux-file
			console.progress("Откат регистрации Renux Shell в системном реестре...")
			RegDelete, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell
			RegRead, path, HKCU, Environment, PATH
			RegWrite, REG_EXPAND_SZ, HKCU, Environment, PATH, % StrReplace(path, "%AppData%\by.strdev\;")
			EnvUpdate
			
			console.progress("Удаление ярлыка в меню Пуск...")
			FileDelete, %A_Programs%\Renux Shell.lnk
			
			SetWorkingDir, %A_AppData%
			Run, %ComSpec% /c start cmd.exe /c "timeout /t 5 & rd by.strdev /s /q & chcp 1251 > nul & title Renux Shell & cls & echo Программа удалена. Спасибо за использование. & pause & exit",, Hide
			exitapp
		}
		
		console.warning("Недопустимый параметр команды.")
		return 0
	}
	
	if (cmd_process_first == "ПРОГ") {
		if debug
			console.writeln("[DEBUG] Получение информации о продуктах...")
		
		if (!installed) {
			console.error("Необходимо установить программу (консоль установить).")
			return
		}
		
		prod_list := server_api("products")
		
		if prod_list not contains output
		{
			console.error("Не удалось получить список продуктов. Попробуйте позже.")
			return 0
		}
		
		prod_count := JSON.GetKey(prod_list, "output.count")
		index := -1
		prod := []
		
		console.writeln("")
		console.writeln("Для установки доступно " prod_count " приложений:")
		
		loop, % prod_count
		{
			index+=1
			prod_is_dir := JSON.GetKey(prod_list, "output.items[" index "].is_dir")
			
			if (prod_is_dir == "true") {
				prod[index+1] := JSON.GetKey(prod_list, "output.items[" index "].name")
				console.writeln(index+1 ": " prod[index+1])
			}
		}
		
		console.writeln("")
		
		input_prod_num:
		console.write("Укажите номер приложения>")
		prod_num := trim(console.read())
		
		if (prod_num == "")
			return 0
		
		if prod_num is not integer
		{
			console.warning("Нужно указать целое число.")
			goto input_prod_num
		}
		
		if ((prod_num > (index+1)) || (prod_num < 1)) {
			console.warning("Номер приложения выходит за границы списка.")
			goto input_prod_num
		}
		
		console.writeln("")
		console.writeln("Доступные варианты действий:")
		ifexist, % root "\products\" prod[index+1]
		{
			console.writeln("1: Обновить программу`n2: Удалить программу")
			console.writeln("")
			
			loop {
				console.write("Укажите номер действия>")
				prod_action := trim(console.read())
				
				if prod_action is not integer
				{
					console.warning("Нужно указать целое число.")
					continue
				}
				
				if (prod_action == 1) {
					prod_action = update
					break
				}
				
				if (prod_action = 2) {
					prod_action = deinstall
					break
				}
			}
		}
		else {
			console.writeln("1: Установить программу")
			console.writeln("")
		
			loop {
				console.write("Укажите номер действия>")
				prod_action := trim(console.read())
				
				if prod_action is not integer
				{
					console.warning("Нужно указать целое число.")
					continue
				}
				
				if (prod_action == 1) {
					prod_action = install
					break
				}
			}
		}
		
		if (prod_action == "deinstall") {
			console.question("Вы точно желаете удалить программу? [Y/N]")
			if (console.waitKeys("Y,N") == "Y") {
				console.progress("Удаление программы " prod[prod_num] "...")
				dir := prod[prod_num]
				FileRemoveDir, %root%\products\%dir%
				console.info("Операция завершена.")
			}
		} else {
			prod_files := server_api("products&name=" prod[prod_num])
			
			if prod_files not contains output
			{
				console.error("Не удалось получить список файлов продукта. Попробуйте позже.")
				return 0
			}
			
			prod_count_files := JSON.GetKey(prod_files, "output.count")
			index := -1
			
			console.writeln("")
			console.writeln("Файлы, которые установит программа:")
			
			sizefiles = 0
			loop, % prod_count
			{
				index+=1
				file_is_dir 	:= JSON.GetKey(prod_files, "output.items[" index "].is_dir")
				
				if (file_is_dir == "false") {
					file_size 		:= JSON.GetKey(prod_files, "output.items[" index "].size")
					file_name		:= JSON.GetKey(prod_files, "output.items[" index "].name")
				}
				
				console.writeln("- " file_name " (" file_size " байт)")
				sizefiles+=%file_size%
			}
		
			console.writeln("")
			console.question("Установка займет " sizefiles " байт памяти. Установить? [Y/N]")
			if (console.waitKeys("Y,N") == "Y") {
				console.writeln("")
				
				FileCreateDir, % root "\products\" prod[prod_num]
				
				index := -1
				loop, % prod_count
				{
					index+=1
					file_is_dir 	:= JSON.GetKey(prod_files, "output.items[" index "].is_dir")
					
					if (file_is_dir == "false") {
						file_size 		:= JSON.GetKey(prod_files, "output.items[" index "].size")
						file_name		:= JSON.GetKey(prod_files, "output.items[" index "].name")
					}
					
					loop {
						console.progress("Скачивание файла '" file_name "' (" file_size " байт)...")
						FileDelete, % root "\products\" prod[prod_num] "\" file_name
						URLDownloadToFile, % host "/products/" prod[prod_num] "/" file_name, % root "\products\" prod[prod_num] "\" file_name
						
						FileGetSize, pcsize, % root "\products\" prod[prod_num] "\" file_name
						
						if (file_size == pcsize)
							break
						
						console.warning("Размер файла не совпадает с размером файла на сервере. Повторяю попытку скачивания... (#" A_Index ")")
					}
					
					sizefiles+=%file_size%
				}
				
				console.writeln("")
				console.info("Операция завершена.")
			}
		}
		return 1
	}
	
	if (cmd_process_first == "СД") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		
		if (trim(cmdout1) == "") {
			console.writeln(A_WorkingDir)
			return 0
		}
		
		outdrive =
		SplitPath, cmdout1, , , , , OutDrive
		if (trim(OutDrive) != "") {
			SetWorkingDir, % string.up(outdrive)
		}
		
		setted = 0
		loop, parse, cmdout1, `\
		{
			if (A_LoopField == "")
				continue
			
			patternlen := string.len(A_LoopField)
			Loop, files, %A_WorkingDir%\*, D
			{
				FileGetAttrib, Attribs, % A_LoopFileFullPath
				if (InStr(Attribs,"D")) {
					file_name := string.left(A_LoopFileName, patternlen)
					if (string.up(A_LoopField) == string.up(file_name)) {
						SetWorkingDir, %A_WorkingDir%\%A_LoopFileName%
						setted+=1
						break
					}
				}
			}
			
			Loop, files, %A_WorkingDir%\*, F
			{
				if (string.down(A_LoopFileExt) == "lnk") {
					file_name := string.left(A_LoopFileName, patternlen)
					if (string.up(A_LoopField) == string.up(file_name)) {
						FileGetShortcut, % A_LoopFileFullPath, target, dir
						
						loop, parse, target, `\
						{
							SetWorkingDir, % A_LoopField
							if errorlevel
								break
							
							setted+=1
							continue
						}
						
						Loop, parse, dir, `\
						{
							SetWorkingDir, % A_LoopField
							if errorlevel
								break
							
							setted+=1
							continue
						}
						
						break
					}
				}
			}
		}
		
		return setted
	}
	
	if (cmd_process_first == "ДИР") {
		cmdout1 =
		SplitCommand(cmd_text, 1, "cmdout")
		
		if (trim(cmdout1) == "")
			cmdout1 = *
		
		console.writeln("Содержание папки " A_WorkingDir ":")
		
		if (cmdout1 != "*") {
			console.writeln("Установленный фильтр поиска: " cmdout1 ".")
		}
		
		console.writeln("")
		
		files := 0, folders := 0
		
		loop, %A_WorkingDir%\%cmdout1%, 1
		{
			f := A_LoopFileFullPath, timee := ""
			
			FileGetTime, time, %f%, M
			FormatTime, time, % time, dd.MM.yyyy hh:mm:ss
			FileGetAttrib, Attribs, % f
			
			If (InStr(Attribs,"D")) {
				folders+=1
				console.writeln("`t" time " `t<ПАПКА>`t`t" A_LoopFileName)
			} else {
				SplitPath, A_LoopFileFullPath,,, Extension
				extension := trim(string.down(Extension))
				
				if (extension == "rs") {
					files+=1
					console.writeln("`t" time " `t<СКРИПТ>`t" A_LoopFileName) 
				} else {
					files+=1
					console.writeln("`t" time "`t`t`t" A_LoopFileName) 
				}
			}
		}
		
		console.writeln("")
		console.writeln("Найдено " files " файлов и " folders " папок.")
		return 1
	}
	
	if (cmd_process_first == "СД.") {
		f := A_WorkingDir
		while (true) {
			if (string.right(f, 1) == "\") {
				break
			}
			
			f := string.left(f, string.len(f)-1)
			
			if (trim(f) == "") {
				return 0
			}
		}
		
		SetWorkingDir, % f
		return 1
	}
	
	if (cmd_process_first == "СД..") {
		loop, 2
			executeCMD("сд.")
		
		return 1
	}
	
	if (cmd_process_first == "СД...") {
		loop, 3
			executeCMD("сд.")
		
		return 1
	}
	
	if (cmd_process_first == "ПРОЦЕСС") {
		splited := SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: процесс '<операция>' '<имя процесса/PID>

Возможные операции:

существует`tпомещает в переменную .консоль.результат идентификатор процесса (PID),
`t`tесли соответствующий процесс существует, иначе 0. Если второй параметр пустой,
`t`tопределяется PID самого скрипта.

завершить`tзавершает процесс(-ы). Если процесс(-ы) завершён успешно, в .консоль.результат помещается
`t`tкол-во завершенн(-ых) процесс(-ов). Так как процесс будет завершён внезапно
`t`t- возможно, с прерыванием его работы в критической точке или с потерей несохранённых
`t`tданных - этот метод должен использоваться, только если процесс не может быть закрыт
`t`tпутём применения ОКНО.ЗАКРЫТЬ к одному из его окон.

ждать`t`tожидает существования указанного процесса. При обнаружении подходящего процесса
`t`tв .консоль.результат помещается его идентификатор (PID).

ждать.закрытие`tждёт, пока не будут закрыты ВСЕ отвечающие второму параметру процессы.
`t`tЕсли все совпадающие процессы завершаются, .консоль.результат устанавливается в 0.

заморозить`tзаморозит процесс по идентификатору процесса (PID) или его имени.

разморозить`tразморозит процесс по идентификатору процесса (PID) или его имени.

список`t`tотображает список активных процессов на момент исполнения команды. Второй параметр
`t`tигнорируется.

Пример: процесс 'существует' 'explorer.exe'
			)
			return console.writeln(text)
		}
		
		if (trim(string.down(cmdout1)) == "существует") {
			Process, exist, % cmdout2
			return ErrorLevel
		}
		
		if (trim(string.down(cmdout1)) == "завершить") {
			AccessRights_EnableSeDebug()
			
			OUT_LIST := "", COUNT_NO_PATHS := 0, PROCESSES := 0
			for i, v in WTSEnumerateProcessesEx()
			{
				if (v.ProcessID == cmdout2) {
					process, close, % cmdout2
					if (ErrorLevel == cmdout2) {
						console.writeln("Процесс " (v.ProcessName ? v.ProcessName : "<без имени>") " с идентификатором " v.ProcessID " был успешно завершен.")
						PROCESSES++
						break
					} else {
						console.error("Процесс " (v.ProcessName ? v.ProcessName : "<без имени>") " с идентификатором " v.ProcessID " завершить не удалось.")
					}
				}
				
				if (string.down(v.ProcessName) == string.down(cmdout2)) {
					process, close, % v.ProcessID
					if (ErrorLevel == v.ProcessID) {
						console.writeln("Процесс " (v.ProcessName ? v.ProcessName : "<без имени>") " с идентификатором " v.ProcessID " был успешно завершен.")
						PROCESSES++
						continue
					} else {
						console.error("Процесс " (v.ProcessName ? v.ProcessName : "<без имени>") " с идентификатором " v.ProcessID " завершить не удалось.")
					}
				}
			}
			
			console.writeln("`nВсего процессов было завершено: " PROCESSES ".")
			return processes
		}
		
		if (trim(string.down(cmdout1)) == "ждать") {
			Process, Wait, % cmdout2
			return ErrorLevel
		}
		
		if (trim(string.down(cmdout1)) == "ждать.закрытие") {
			Process, WaitClose, % cmdout2
			return ErrorLevel
		}
		
		if (trim(string.down(cmdout1)) == "заморозить") {
			Process_Suspend(cmdout2)
			return 1
		}
		
		if (trim(string.down(cmdout1)) == "разморозить") {
			Process_Resume(cmdout2)
			return 1
		}
		
		if (trim(string.down(cmdout1)) == "список") {
			AccessRights_EnableSeDebug()
			
			OUT_LIST := "", COUNT_NO_PATHS := 0, PROCESSES := 0
			for i, v in WTSEnumerateProcessesEx()
			{
				
				FullEXEPath := GetModuleFileNameEx( v.ProcessID )
				PROCESSES+=1
				
				if (v.ProcessName == "")
					v.ProcessName := "[Без имени]"
				
				console.writeln("`n> " v.ProcessName ":`n  Описание: " FileGetInfo(FullEXEPath).FileDescription "`n  Идентификатор: " v.ProcessID "`n  Путь к файлу: " FullEXEPath "`n  Копирайт: " FileGetInfo( FullEXEPath ).LegalCopyright)
			}
			
			console.writeln("`nВсего процессов: " PROCESSES ".")
			return 1
		}
		
		console.error("Ошибка в синтаксисе команды.")
		return -1
	}
	
	if (cmd_process_first == "ПРОЗРАЧНОСТЬ") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: прозрачность <целое число>
Пример: прозрачность 240
			)
			return console.writeln(text)
		}
		
		if cmdout1 is not integer
		{
			console.error("Первый аргумент должен быть целым числом.")
			return 0
		}
		
		if ((cmdout1 < 100) || (cmdout1 > 255)) {
			console.error("Число из первого аргумента должно быть в диапазоне от 100 до 255.")
			return 0
		}
		
		WinSet, Transparent, % cmdout1, ahk_id %mainwid%
		IniWrite, % cmdout1, % config, start, transparent
		
		start_transparent := cmdout1
		return 1
	}
	
	if (cmd_process_first == "ГРОМКОСТЬ") {
		splited := SplitCommand(cmd_text, 4, "cmdout")
		
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: громкость '<новый параметр>' '[тип компонента]' '[вид настройки]' '[номер устройства]'

Новый параметр = Новая настройка. Число в диапазоне от -100 до 100 включительно (может быть числом с плавающей точкой). Если число указано со знаком (плюс или минус), значение настройки будет увеличено или уменьшено на указанную величину. Иначе текущее значение настройки будет заменено указанной величиной.Для настроек с двумя возможными значениями, а именно ONOFF, MUTE, MONO, LOUDNESS, STEREOENH, BASSBOOST, любое положительное число будет включать настройку, а ноль - выключать. Однако любое число с явно указанным знаком (плюс или минус) будет просто переключать настройку в противоположное состояние.
Тип компонента = Если опущен или пустой, принимает значение MASTER (общий регулятор громкости, который доступен также при одиночном щелчке по динамику в трее). Допустимые значения: MASTER (то же, что SPEAKERS), DIGITAL, LINE, MICROPHONE, SYNTH, CD, TELEPHONE, PCSPEAKER, WAVE, AUX, ANALOG. Если микшер не содержит указанного компонента, это будет отражено сообщением в переменной .КОНСОЛЬ.РЕЗУЛЬТАТ (см. справку). Компонент, обозначаемый в микшере как Auxiliary (дополнительный), иногда может быть доступен как ANALOG, а не как AUX. Если микшер имеет более одного экземпляра какого-то компонента, то обычно первый содержит настройки воспроизведения, а второй - настройки записи. Для доступа ко второму и следующим экземплярам добавляйте двоеточие и номер к имени компонента. Например, Analog:2.
Вид настройки = Если опущен или пустой, принимает значение VOLUME (громкость). Допустимые значения: VOLUME (или VOL), ONOFF, MUTE, MONO, LOUDNESS, STEREOENH, BASSBOOST, PAN, QSOUNDPAN, BASS, TREBLE, EQUALIZER. Если компонент не поддерживает указанный вид настройки, это будет отражено сообщением в переменной .КОНСОЛЬ.РЕЗУЛЬТАТ (см. справку).
Номер устройства = Может быть выражением. Номер устройства. Если опущен, принимает значение 1, что обычно соответствует системному устройству по умолчанию для записи и воспроизведения. Для доступа к другим устройствам указывайте номер больше единицы.

Примеры:
  // Общий регулятор громкости на середину.
  громкость '50' '' '' ''

  // Увеличить общую громкость на 10`%.
  громкость '+10' '' '' ''
  
  // Уменьшить общую громкость на 10`%
  громкость '-10' '' '' ''
  
  // Отключить микрофон
  громкость '1' 'Microphone' 'mute' ''
  
  // Переключить выключатель общей громкости (в противоположное состояние).
  громкость '+1' '' 'mute' ''
  
  // Поднять нижние частоты на 20`%.
  громкость '+20' 'Master' 'bass' ''
  если '`%.консоль.результат`%' != '1' то вывод Настройка нижних частот не поддерживается общим регулятором громкости.
			)
			return console.writeln(text)
		}
		
		SoundSet, % cmdout1, % cmdout2, % cmdout3, % cmdout4
		e := ErrorLevel
		if e is integer
		{
			return 1-ErrorLevel
		} else {
			return StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(ErrorLevel, "Invalid Control Type or Component Type", "Неверный вид настройки или тип компонента"), "Can't Open Specified Mixer", "Не могу открыть указанный микшер"), "Mixer Doesn't Support This Component Type", "Микшер не поддерживает указанный компонент"), "Mixer Doesn't Have That Many of That Component Type", "Количество компонентов данного типа в микшере меньше, чем указанный номер"), "Component Doesn't Support This Control Type", "Компонент не поддерживает указанную настройку"), "Can't Get Current Setting", "Не могу считать текущую настройку"), "Can't Change Setting", "Не могу изменить настройку")
		}
	}
	
	if (cmd_process_first == "СООБЩЕНИЕ") {
		splited := SplitCommand(cmd_text, 4, "cmdout")
		
		if ((trim(cmdout2) == "") ||(trim(cmdout3) == "") ||  (splited == -2)) {
			text =
			(
Формат: сообщение '<опции>' '<заголовок>' '<текст>' '[тайм-аут]'
Пример: сообщение '64' 'Привет' 'Это сообщение показывается 5 секунд' ''
			)
			console.writeln(text)
			return 0
		}
		
		if (cmdout1 == 0) {
			Msgbox, 0, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 1) {
			Msgbox, 1, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 2) {
			Msgbox, 2, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 3) {
			Msgbox, 3, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 4) {
			Msgbox, 4, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 5) {
			Msgbox, 5, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 6) {
			Msgbox, 6, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 7) {
			Msgbox, 7, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 8) {
			Msgbox, 8, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 9) {
			Msgbox, 9, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 10) {
			Msgbox, 10, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 11) {
			Msgbox, 11, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 12) {
			Msgbox, 12, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 13) {
			Msgbox, 13, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 14) {
			Msgbox, 14, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 15) {
			Msgbox, 15, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 16) {
			Msgbox, 16, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 17) {
			Msgbox, 17, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 18) {
			Msgbox, 18, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 19) {
			Msgbox, 19, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 20) {
			Msgbox, 20, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 21) {
			Msgbox, 21, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 22) {
			Msgbox, 22, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 23) {
			Msgbox, 23, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 24) {
			Msgbox, 24, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 25) {
			Msgbox, 25, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 26) {
			Msgbox, 26, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 27) {
			Msgbox, 27, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 28) {
			Msgbox, 28, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 29) {
			Msgbox, 29, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 30) {
			Msgbox, 30, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 31) {
			Msgbox, 31, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 32) {
			Msgbox, 32, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 33) {
			Msgbox, 33, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 34) {
			Msgbox, 34, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 35) {
			Msgbox, 35, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 36) {
			Msgbox, 36, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 37) {
			Msgbox, 37, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 38) {
			Msgbox, 38, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 39) {
			Msgbox, 39, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 40) {
			Msgbox, 40, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 41) {
			Msgbox, 41, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 42) {
			Msgbox, 42, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 43) {
			Msgbox, 43, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 44) {
			Msgbox, 44, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 45) {
			Msgbox, 45, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 46) {
			Msgbox, 46, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 47) {
			Msgbox, 47, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 48) {
			Msgbox, 48, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 49) {
			Msgbox, 49, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 50) {
			Msgbox, 50, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 51) {
			Msgbox, 51, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 52) {
			Msgbox, 52, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 53) {
			Msgbox, 53, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 54) {
			Msgbox, 54, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 55) {
			Msgbox, 55, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 56) {
			Msgbox, 56, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 57) {
			Msgbox, 57, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 58) {
			Msgbox, 58, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 59) {
			Msgbox, 59, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 60) {
			Msgbox, 60, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 61) {
			Msgbox, 61, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 62) {
			Msgbox, 62, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 63) {
			Msgbox, 63, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 64) {
			Msgbox, 64, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 65) {
			Msgbox, 65, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 66) {
			Msgbox, 66, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 67) {
			Msgbox, 67, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 68) {
			Msgbox, 68, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 69) {
			Msgbox, 69, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 70) {
			Msgbox, 70, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 71) {
			Msgbox, 71, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 72) {
			Msgbox, 72, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 73) {
			Msgbox, 73, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 74) {
			Msgbox, 74, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 75) {
			Msgbox, 75, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 76) {
			Msgbox, 76, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 77) {
			Msgbox, 77, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 78) {
			Msgbox, 78, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 79) {
			Msgbox, 79, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 80) {
			Msgbox, 80, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 81) {
			Msgbox, 81, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 82) {
			Msgbox, 82, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 83) {
			Msgbox, 83, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 84) {
			Msgbox, 84, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 85) {
			Msgbox, 85, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 86) {
			Msgbox, 86, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 87) {
			Msgbox, 87, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 88) {
			Msgbox, 88, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 89) {
			Msgbox, 89, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 90) {
			Msgbox, 90, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 91) {
			Msgbox, 91, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 92) {
			Msgbox, 92, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 93) {
			Msgbox, 93, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 94) {
			Msgbox, 94, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 95) {
			Msgbox, 95, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 96) {
			Msgbox, 96, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 97) {
			Msgbox, 97, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 98) {
			Msgbox, 98, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 99) {
			Msgbox, 99, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		if (cmdout1 == 100) {
			Msgbox, 100, %cmdout2%, %cmdout3%, %cmdout4%
		}
		
		IfMsgBox, Yes
			console.setVar(".сообщение.ответ", "Да", 0)
		
		IfMsgBox, No
			console.setVar(".сообщение.ответ", "Нет", 0)
		
		IfMsgBox, OK
			console.setVar(".сообщение.ответ", "ОК", 0)
		
		IfMsgBox, Cancel
			console.setVar(".сообщение.ответ", "Отмена", 0)
		
		IfMsgBox, Abort
			console.setVar(".сообщение.ответ", "Прервать", 0)
		
		IfMsgBox, Ignore
			console.setVar(".сообщение.ответ", "Игнорировать", 0)
		
		IfMsgBox, Retry
			console.setVar(".сообщение.ответ", "Повторить", 0)
		
		IfMsgBox, Timeout
			console.setVar(".сообщение.ответ", "Тайм-аут", 0)
		
		return 1
	}
	
	if (cmd_process_first == "УВЕДОМЛЕНИЕ") {
		splited := SplitCommand(cmd_text, 4, "cmdout")
		
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: уведомление '<заголовок>' '<текст>' '<тайм-аут>' '<опции>'
Пример: уведомление 'Привет' 'Это сообщение показывается 5 секунд' '5' '1'
			)
			console.writeln(text)
			return 0
		}
		
		Menu, Tray, Icon
		TrayTip, % cmdout1, % cmdout2, % cmdout3, % cmdout4
		
		if (trim(cmdout4) == "")
			cmdout4 = 10
		
		settimer, hidetrayicon, % cmdout4
		return 1
	}
	
	if (cmd_process_first == "МОНИТОР") {
		splited := SplitCommand(cmd_text, 1, "cmdout")
		
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: монитор <действие>
Пример: монитор выключить
			)
			return console.writeln(text)
		}
		
		if (string.down(trim(cmdout1)) == "выключить") {
			SendMessage, 0x112, 0xF170, 2,, Program Manager
			return 1
		}
		
		if (string.down(trim(cmdout1)) == "включить") {
			SendMessage, 0x112, 0xF170, -1,, Program Manager
			return 1
		}
		
		if (string.down(trim(cmdout1)) == "малая") {
			SendMessage, 0x112, 0xF170, 1,, Program Manager
			return 1
		}
		
		console.error("Действие не распознано.")
		return -1
	}
	
	if (cmd_process_first == ".ТЕСТ") {
		SplitCommand(cmd_text, 1, "outcmd")
		if (trim(outcmd1) == "") {
			console.writeln(">>> Формат: .тест <команда>")
			return 0
		}
		
		time := A_TickCount
		processCMD(outcmd1)
		console.writeln(">>> На выполнение команды было затрачено: " FormatTime(A_TickCount-time) ".")
		return 1
	}
	
	if (cmd_process_first == "ГУДОК") {
		SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: гудок '<частота в герцах>' '<длительность в мс>
Пример: гудок '750' '500'
			)
			return console.writeln(text)
		}
		
		SoundBeep, % cmdout1, % cmdout2
		return 1
	}
	
	if (cmd_process_first == "ЗВУКИНФО") {
		SplitCommand(cmd_text, 4, "cmdout")
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: звукинфо '<переменная для вывода>' '<тип компонента>' '<вид настройки>' '<номер устройства>'
Пример: звукинфо 'громкость' '' '' '';вывод Общий регулятор громкости сейчас на уровне `%громкость`% процентов.
			)
			return console.writeln(text)
		}
		
		SoundGet, output, % cmdout2, % cmdout3, % cmdout4
		console.setVar(cmdout1, output)
		e := ErrorLevel
		if e is integer
		{
			return 1-ErrorLevel
		} else {
			return StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(StrReplace(ErrorLevel, "Invalid Control Type or Component Type", "Неверный вид настройки или тип компонента"), "Can't Open Specified Mixer", "Не могу открыть указанный микшер"), "Mixer Doesn't Support This Component Type", "Микшер не поддерживает указанный компонент"), "Mixer Doesn't Have That Many of That Component Type", "Количество компонентов данного типа в микшере меньше, чем указанный номер"), "Component Doesn't Support This Control Type", "Компонент не поддерживает указанную настройку"), "Can't Get Current Setting", "Не могу считать текущую настройку"), "Can't Change Setting", "Не могу изменить настройку")
		}
	}
	
	if (cmd_process_first == "ПРОИГРАТЬ") {
		SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (splited == -2))
		{
			text =
			(
Формат: проиграть '<имя файла>' '[ждать? (1-да/0-нет)]>
Пример: проиграть 'tada.wav' '1'
			)
			return console.writeln(text)
		}
		
		SoundPlay, % cmdout1, % cmdout2
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "РЕЕСТР.ПРОЧИТАТЬ") {
		SplitCommand(cmd_text, 4, "cmdout")
		
		if ((splited == -2) || (trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: реестр.прочитать '<вывод переменной>' '<имя корневого размера>' '<имя подраздела>' '[имя параметра]'
Пример: реестр.прочитать 'PATH' 'HKCU' 'Environment' 'PATH'
			)
			return console.writeln(text)
		}
		
		RegRead, output, % cmdout2, % cmdout3, % cmdout4
		e := ErrorLevel
		if e
			return 1-ErrorLevel
		
		return console.setVar(cmdout1, output)
	}
	
	if (cmd_process_first == "РЕЕСТР.ЗАПИСАТЬ") {
		SplitCommand(cmd_text, 5, "cmdout")
		
		if ((splited == -2) || (trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")|| (trim(cmdout4) == "")) {
			text =
			(
Формат: реестр.записать '<тип записываемого параметра>' '<имя корневого раздела>' '<имя подраздела>' '<имя параметра реестра>' '[значение для записываемого параметра]'
Пример: реестр.записать 'REG_SZ' 'HKEY_LOCAL_MACHINE' 'SOFTWARE\TestKey' 'MyValueName' 'Test Value'
			)
			return console.writeln(text)
		}
		
		RegWrite, % cmdout1, % cmdout2, % cmdout3, % cmdout4, % cmdout5
		e := ErrorLevel
		if e
			return 1-ErrorLevel
		
		return console.setVar(cmdout1, output)
	}
	
	if (cmd_process_first == "РЕЕСТР.УДАЛИТЬ") {
		SplitCommand(cmd_text, 3, "cmdout")
		
		if ((splited == -2) || (trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")|| (trim(cmdout4) == "")) {
			text =
			(
Формат: реестр.удалить '<имя корневого раздела>' '<имя подраздела>' '[имя параметра для удаления]'
Пример: реестр.удалить 'HKEY_LOCAL_MACHINE' 'Software\SomeApplication' 'TestValue'
			)
			return console.writeln(text)
		}
		
		RegDelete, % cmdout1, % cmdout2, % cmdout3 
		e := ErrorLevel
		if e
			return 1-ErrorLevel
		
		return console.setVar(cmdout1, output)
	}
	
	if (cmd_process_first == "СКРИНШОТ") {
		SplitCommand(cmd_text, 1, "cmdout")
		
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: скриншот <имя файла>
Пример: скриншот screenshot.png
			)
			return console.writeln(text)
		}
		
		FileDelete, % cmdout1
		SaveScreenshotToFile(0, 0, A_ScreenWidth, A_ScreenHeight, cmdout1)
		ifexist, % cmdout1
			return 1
		else
			return 0
	}
	
	if (cmd_process_first == "ЯРКОСТЬ") {
		SplitCommand(cmd_text, 1, "cmdout")
		
		if ((trim(cmdout1) == "") || (splited == -2)) {
			text =
			(
Формат: яркость <[+/-]число>
Пример: яркость 30
			)
			return console.writeln(text)
		}
		
		MoveBrightness(cmdout1)
		return 1
	}
	
	if (cmd_process_first == "АДДОН") {
		console.writeln("`nДобро пожаловать в Мастер Аддонов Renux Shell.")
		console.writeln("> Выберите операцию, которая Вам нужна:")
		console.writeln("  [1] - установить аддон")
		console.writeln("  [2] - удалить аддон")
		console.writeln("  [3] - собрать аддон")
		console.writeln("  [4] - выйти")
		console.writeln("")
		action := console.waitKeys("1,2,3,4")
		
		if (action == 1) {
			console.writeln("  Устанавливайте аддоны только из надежных источников, иначе Ваша система может быть заражена вирусом.")
			loop {
				console.write("> Укажите путь к файлу: ")
				link := console.read()
				
				if (trim(link) == "")
					return 0
				
				ifnotexist, % link
				{
					console.error("Файл по указанному пути не найден.")
					continue
				}
				
				break
			}
			
			FileRead, text, % link
			return unpackRSAC(text)
		}
		
		if (action == "2") {
			console.writeln("Список аддонов:")
			loop, files, %root%\*.rsa
			{
				IniRead, описание, % A_LoopFileFullPath, addon, описание, % ""
				console.writeln("- " A_LoopFileName " (" описание ")")
			}
			
			console.writeln("")
			loop {
				console.write("Укажите имя файла аддона для удаления: ")
				filename := console.read()
				if (trim(filename) == "") {
					return 0
				}
				
				ifnotexist, %root%\%filename%
				{
					console.writeln("Аддон с таким именем не найден.")
					continue
				}
				
				IniRead, имя_пакета, %root%\%filename%, addon, имя_пакета, % " "
				FileDelete, %root%\%filename%
				FileDelete, %root%\%имя_пакета%.rs
				console.writeln("Аддон удален.")
				sleep 4000
				processCMD("рестарт")
				return 1
			}
		}
		
		if (action == "3") {
			loop {
				console.write("> Укажите путь к файлу *.rsa: ")
				file_rsa := console.read()
				
				if (trim(file_rsa) == "") {
					return 0
				}
				
				ifnotexist, % file_rsa
				{
					console.writeln("Файл не найден.")
					continue
				}
				
				break
			}
			
			loop {
				console.write("> Укажите путь к файлу *.rs: ")
				file_rs := console.read()
				
				if (trim(file_rs) == "") {
					return 0
				}
				
				ifnotexist, % file_rs
				{
					console.writeln("Файл не найден.")
					continue
				}
				
				break
			}
			
			loop {
				console.write("> Укажите путь к будущему файлу (без расширения), в который будет записан собранный аддон: ")
				file_rsac := console.read()
				
				if (trim(file_rsac) == "") {
					return 0
				}
				
				FileDelete, % file_rsac ".rsac"
				FileRead, rsa_text, % file_rsa
				FileRead, rs_text, % file_rs
				
				FileAppend, %rsa_text%`n<< СКРИПТ >>`n%rs_text%, % file_rsac ".rsac"
				if errorlevel
				{
					console.error("Не удалось записать файл: " file_rsac ".")
					return 0
				}
				
				console.writeln("Аддон собран и сохранен по пути " file_rsac)
				return 1
			}
		}
		
		if (action == "4") {
			return 1
		}
		
		return 0
	}
	
	if (cmd_process_first == "СОЗДАТЬДАННЫЕФОРМЫ") {
		SplitCommand(cmd_text, 4, "cmdout")
		
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "") || (trim(cmdout4) == "") || (splited == -2)) {
			text =
			(
Формат: создатьДанныеФормы '<тип файла>' '<путь к файлу>' '<вывод #1>''<вывод #2>'
Пример: создатьДанныеФормы 'photo' 'C:\photo.png' 'PostData' 'ContentType'

> Параметры:
  Тип файла:
    "application" - Внутренний формат прикладной программы
    "audio" - Аудио
    "image" - Изображение
    "message" - Сообщение
    "model" - Для 3D-моделей
    "multipart" - Email
    "text" - Текст
    "video" - Видео
  
  Путь к файлу:
    Указывается путь к файлу, который нужно получить.
  
  Вывод #1:
    Имя переменной, в которую запишется информация: PostData.

  Вывод #2:
    Имя переменной, в которую запишется информация: Content-Type.
			)
			return console.writeln(text)
		}
		
		objParam := {putArr(cmdout1): [cmdout2]}
		CreateFormData(PostData, hdr_ContentType, objParam)
		console.setVar(cmdout3, PostData)
		return console.setVar(cmdout4, hdr_ContentType)
	}
	
	if (cmd_process_first == "РАНД") {
		SplitCommand(cmd_text, 3, "cmdout")
		
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: ранд '<вывод>' '<минимальное число>' '<максимальное число>'
Пример: ранд 'число' '1' '100';вывод Случайное число: `%число`%.
			)
			return console.writeln(text)
		}
		
		Random, OutputVar, % cmdout2, % cmdout3
		return console.setVar(cmdout1, OutputVar)
	}
	
	if (cmd_process_first == "ЗАПРОС") {
		SplitCommand(cmd_text, 4, "cmdout")
		
		if (trim(cmdout1) == "") { ; больше не нада
			text =
			(
Формат: запрос '<метод>' '<параметр #1>' '<параметр #2>' '[параметр #3]'

> Методы:
  открыть (open) - Открывает HTTP-соединение с HTTP-ресурсом.
  отправить (send) - Отправляет HTTP-запрос на сервер HTTP.
  устХедер (SetRequestHeader) - Добавляет, изменяет или удаляет заголовок HTTP-запроса.
  таймаут (SetTimeouts) - Указывает в миллисекундах отдельные компоненты времени ожидания операции отправки и получения.
  ждатьОтвет (waitForResponse) - Указывает время ожидания для завершения асинхронного метода отправки (в секундах) с необязательным значением времени ожидания.

> Примечания:
  Во втором параметре метода "отправить" указывается имя объекта без "`%" (если загружаются данные формы).
	)
			return console.writeln(text)
		}
		
		method := trim(string.down(cmdout1))
		if (method == "открыть") {
			HTTP := ComObjCreate("WinHttp.WinHttpRequest.5.1")
			try HTTP.Open(cmdout2, cmdout3, cmdout4)
			catch
				return 0
			
			return 1
		}
		
		if (method == "отправить") {
			if (isObject(console.getVar(cmdout2)) == 1) {
				console.writeln("[DEBUG] В запросе используется объект.")
				cmdout2 := console.getVar(cmdout2)
			}
			
			try HTTP.Send(cmdout2)
			catch
				return 0
			
			return 1
		}
		
		if (method == "устхедер") {
			try HTTP.SetRequestHeader(cmdout2, cmdout3)
			catch
				return 0
			
			return 1
		}
		
		if (method == "таймаут") {
			try HTTP.SetTimeouts(cmdout2)
			catch
				return 0
			
			return 1
		}
		
		if (method == "ждатьответ") {
			try HTTP.WaitForResponse()
			catch
				return 0
			
			try response := HTTP.ResponseText
			catch
				return 0
			
			return response
		}
		
		console.error("Метод не распознан.")
		return -1
	}
	
	if (cmd_process_first == "СОБРАТЬ") {
		console.info("Добро пожаловать в мастер сборки пакетных файлов Renux Shell.")
		
		while (true) {
			console.write("`n> Укажите полный путь до пакетного файла (*.rs): ")
			script_path := console.read()
			
			if (trim(script_path) == "")
				return 0
			
			IfExist, % script_path ".rs"
				script_path := script_path ".rs"
			
			ifnotexist, % script_path
			{
				console.error("Файл по заданному пути не найден.")
				continue
			}
			
			break
		}
		
		while (true) {
			console.write("`n> Укажите полный путь до иконки (*.ico): ")
			icon_path := console.read()
			
			if (trim(icon_path) == "") {
				GetIconFromResource(A_Temp "\scriptico.ico", A_ScriptFullPath, 1)
				icon_path := A_Temp "\scriptico.ico"
				
				FileGetSize, size, % icon_path, B
				if (size > 0)
					console.info("Будет использоваться иконка программы.")
				else
					return 0
			}
			
			ifexist, % icon_path ".ico"
				icon_path := icon_path ".ico"
			
			ifnotexist, % icon_path
			{
				console.error("Файл по заданному пути не найден.")
				continue
			}
			
			break
		}
		
		console.write("`n> Укажите с какими стартовыми параметрами будет запускаться программа (например, /hide /debug и т.п.): ")
		script_param := console.read()
		
		console.writeln("")
		console.progress("Распаковка Compiler\AutoHotKeySC.bin...")
		FileInstall, Compiler\AutoHotkeySC.bin, %root%\AutoHotkeySC.bin, 1
		if (ErrorLevel) {
			console.error("Не удалось распаковать Compiler\AutoHotKeySC.bin в " root "!")
			console.writeln("  Попробуйте повысить права программы и попробовать снова.")
			return -1
		}
		
		console.progress("Распаковка Compiler\ANSI.bin...")
		FileInstall, Compiler\ANSI.bin, %root%\ANSI.bin, 1
		if (ErrorLevel) {
			console.error("Не удалось распаковать Compiler\ANSI.bin в " root "!")
			console.writeln("  Попробуйте повысить права программы и попробовать снова.")
			
			console.progress("Очистка временных файлов...")
			FileDelete, %root%\AutoHotKeySC.bin
			return -1
		}
		
		console.progress("Распаковка Compiler\Ahk2Exe.exe...")
		FileInstall, Compiler\Ahk2Exe.exe, %root%\Ahk2Exe.exe, 1
		if (ErrorLevel) {
			console.error("Не удалось распаковать Compiler\Ahk2Exe.exe в " root "!")
			console.writeln("  Попробуйте повысить права программы и попробовать снова.")
			
			console.progress("Очистка временных файлов...")
			FileDelete, %root%\AutoHotKeySC.bin
			FileDelete, %root%\ANSI.bin
			return -1
		}
		
		console.progress("Оптимизация пакетного файла...")
		
		script_exe := "", line_count := 0, line_writed := 0
		FileRead, script_text, % script_path
		
		loop, parse, script_text, `r`n
		{
			line_count += 1
			
			if (trim(A_LoopField) == "")
				continue
			
			if (string.left(A_LoopField, 2) == "//")
				continue
			
			if script_exe
				script_exe := A_LoopField
			else
				script_exe := script_exe "`n" A_LoopField
			
			line_writed += 1
		}
		
		if (trim(script_text) == "") {
			console.error("Пакетный файл пуст.")
			
			console.progress("Очистка временных файлов...")
			FileDelete, %root%\AutoHotKeySC.bin
			FileDelete, %root%\ANSI.bin
			FileDelete, %root%\Ahk2Exe.exe
			return -1
		}
		
		console.info("Оптимизировано " line_count-line_writed " строк сценария.")
		console.progress("Сохранение оптимизированного пакетного файла...")
		
		filedelete, %root%\script.rs
		fileappend, % script_exe, %root%\script.rs
		if (ErrorLevel) {
			console.error("Не удалось сохранить оптимизированный пакетный файл.")
			console.writeln("  Попробуйте повысить права программы и попробовать снова.")
			
			console.progress("Очистка временных файлов...")
			FileDelete, %root%\AutoHotKeySC.bin
			FileDelete, %root%\ANSI.bin
			FileDelete, %root%\Ahk2Exe.exe
			return -1
		}
		
		console.progress("Копирование интерпретатора в папку программы...")
		FileCopy, % A_ScriptFullPath, %root%\prog.exe, 1
		if (ErrorLevel) {
			console.error("Не удалось скопировать " A_ScriptFullPath " в " root "!")
			console.writeln("  Попробуйте повысить права программы и попробовать снова.")
			
			console.progress("Очистка временных файлов...")
			FileDelete, %root%\AutoHotKeySC.bin
			FileDelete, %root%\ANSI.bin
			FileDelete, %root%\Ahk2Exe.exe
			FileDelete, %root%\script.rs
			return -1
		}
		
		console.progress("Копирование Renux Shell в папку программы...")
		FileCopy, % A_ScriptFullPath, %root%\prog.exe, 1
		if (ErrorLevel) {
			console.error("Не удалось скопировать " A_ScriptFullPath " в " root "!")
			console.writeln("  Попробуйте повысить права программы и попробовать снова.")
			
			console.progress("Очистка временных файлов...")
			FileDelete, %root%\AutoHotKeySC.bin
			FileDelete, %root%\ANSI.bin
			FileDelete, %root%\Ahk2Exe.exe
			FileDelete, %root%\script.rs
			return -1
		
		}
		
		console.progress("Копирование иконки...")
		FileCopy, % icon_path, %root%\icon.ico, 1
		if (ErrorLevel) {
			console.error("Не удалось скопировать " icon_path " в " root "!")
			console.writeln("  Попробуйте повысить права программы и попробовать снова.")
			
			console.progress("Очистка временных файлов...")
			FileDelete, %root%\AutoHotKeySC.bin
			FileDelete, %root%\ANSI.bin
			FileDelete, %root%\Ahk2Exe.exe
			FileDelete, %root%\prog.exe
			return -1
		}
		
		console.progress("Генерация кода исполняемого файла...")
		FileDelete, %root%\executable.tmp
		FileAppend, 
		(
#SingleInstance Off
#NoEnv
#NoTrayIcon

Random, Name, 10000000000, 99999999999
FileInstall, script.rs, `%A_Temp`%\`%name`%.rs, 1
if (ErrorLevel) {
	Msgbox, 16, Renux Shell Executable File, Не удалось распаковать файл script.rs.``nПопробуйте повысить права и повторить попытку.
	exitapp
}

FileInstall, prog.exe, `%A_Temp`%\rshell.exe, 1
; Не учитываем ErrorLevel, так как мог быть запущен другой скрипт.

try Run, `%A_Temp`%\rshell.exe "`%A_Temp`%\`%name`%.rs" %script_param%
catch e {
	Msgbox, 16, Renux Shell Executable File, `% "Не удалось запустить rshell.exe. Причина:``n``n" e.Message
	exitapp
}

exitapp
		), %root%\executable.tmp
		if (ErrorLevel) {
			console.error("Не удалось создать файл executable.tmp в " root "!")
			console.writeln("  Попробуйте повысить права программы и попробовать снова.")
			
			console.progress("Очистка временных файлов...")
			FileDelete, %root%\AutoHotKeySC.bin
			FileDelete, %root%\ANSI.bin
			FileDelete, %root%\ahk2exe.exe
			FileDelete, %root%\script.rs
			FileDelete, %root%\prog.exe
			FileDelete, %root%\icon.ico
			FileDelete, %root%\executable.tmp
			return -1
		}
		
		old_wdir := A_WorkingDir
		SetWorkingDir, % root
		console.progress("Компиляция исполняемого файла...")
		RunWait, %root%\ahk2exe.exe /in "%root%\executable.tmp" /out "%root%\compiled.exe" /icon "%icon_path%" /bin "ANSI.bin", % A_WorkingDir, UseErrorLevel
		if (ErrorLevel) {
			SetWorkingDir, % old_wdir
			console.error("Не удалось скомпилировать исходный файл. Ошибка была отображена.")
			
			console.progress("Очистка временных файлов...")
			FileDelete, %root%\AutoHotKeySC.bin
			FileDelete, %root%\ANSI.bin
			FileDelete, %root%\ahk2exe.exe
			FileDelete, %root%\script.rs
			FileDelete, %root%\prog.exe
			FileDelete, %root%\icon.ico
			FileDelete, %root%\executable.tmp
			return -1
		}
		
		SetWorkingDir, % old_wdir
		SplitPath, script_path,,,, script_filename
		while (true) {
			SetWorkingDir, % root
			FileSelectFile, save_path, 16, % userdir "\" script_filename ".exe", Укажите`, куда сохранить файл, *.exe
			if ((errorlevel) || (trim(save_path) == ""))
				continue
			
			break
		}
		
		console.progress("Копирование исполняемого файла в " save_path "...")
		FileMove, %root%\compiled.exe, % save_path, 1
		if (ErrorLevel) {
			console.error("Не удалось скопировать исполняемый файл в " save_path "!")
			console.writeln("  Попробуйте повысить права программы и попробовать снова.`n")
			
			console.progress("Очистка временных файлов...")
			FileDelete, %root%\AutoHotKeySC.bin
			FileDelete, %root%\ANSI.bin
			FileDelete, %root%\ahk2exe.exe
			FileDelete, %root%\script.rs
			FileDelete, %root%\prog.exe
			FileDelete, %root%\icon.ico
			FileDelete, %root%\executable.tmp
			return -1
		}
		
		console.progress("Очистка временных файлов...")
		FileDelete, %root%\AutoHotKeySC.bin
		FileDelete, %root%\ANSI.bin
		FileDelete, %root%\ahk2exe.exe
		FileDelete, %root%\script.rs
		FileDelete, %root%\prog.exe
		FileDelete, %root%\icon.ico
		FileDelete, %root%\executable.tmp
		
		console.writeln("")
		console.info("Компиляция завершена без ошибок.")
		return 1
	}
	
	if (cmd_process_first == "ОКРУЖЕНИЕ.ОБНОВИТЬ") {
		EnvUpdate
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ОКРУЖЕНИЕ.УСТАНОВИТЬ") {
		SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: окружение.установить '<имя используемой переменной окружения, например "COMSPEC" или "PATH">' '<значение, присваиваемое переменной окружения.>'
Пример: окружение.установить 'Renux' 'Какой-либо текст для данной переменной.'
			)
			return console.writeln(text)
		}
		
		EnvSet, % cmdout1, % cmdout2
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ОКРУЖЕНИЕ.ПОЛУЧИТЬ") {
		SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: окружение.получить '<имя переменной, куда будет помещено полученое значение>' '<Имя внешней переменной, значение которой хотим получить>'
Пример: окружение.получить 'path' 'PATH'
			)
			return console.writeln(text)
		}
		
		EnvGet, output, % cmdout2
		if ErrorLevel
			return 0
		
		return console.setVar(trim(cmdout1), output, 0)
	}
	
	if (cmd_process_first == "ФАЙЛ.ИСКАТЬ") {
		SplitCommand(cmd_text, 3, "cmdout")
		
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.искать '<название массива для вывода>' '<шаблон файла>' '[режим]'

> Шаблон файла:
  Имя отдельного файла или папки или шаблон подстановки, например C:\Temp\*.Tmp.
  Предполагается, что <шаблон файла> находится в `%.консоль.рпапка`%, если не указан абсолютный путь.

> Режимы:
  Если пусто или опущено, включаются только файлы, а подкаталоги не рекурсивны. В противном случае укажите одну или несколько из следующих букв:
  Д = включать директории.
  Ф = включать файлы. Если Д и Ф опущены, файлы включаются, но не папки.
  Р = рекурсия в подкаталоги (подпапки). Если Р не указан, файлы и папки во вложенных папках не включаются.

Пример: файл.искать 'файлы' '*.lnk' 'ФДР'
			)
			return console.writeln(text)
		}
		
		array_name := cmdout1
		try {
			Loop, Files, % cmdout2, % StrReplace(StrReplace(StrReplace(cmdout3, "Д", "D"), "Ф", "F"), "Р", "R")
			{
				array_index += 1
				console.setVar(array_name "[" array_index "_имя]", A_LoopFileName, 0)
				console.setVar(array_name "[" array_index "_путь]", A_LoopFileFullPath, 0)
				
				if debug
					console.writeln("[DEBUG] " A_LoopFileFullPath)
			}
			
			console.setVar(array_name "[всего]", array_index, 0)
		} catch {
			console.error("Произошла ошибка при выполнении команды.")
		}
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.ПОЛУЧИТЬ") {
		SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.получить '<имя массива для вывода>' '<полный путь к файлу>'

> Записывает в массив следующие ключи:
CompanyName, FileDescription, FileVersion, InternalName, LegalCopyright, OriginalFileName, ProductName, ProductVersion.

Пример: файл.получить 'информация' 'C:\test.exe'
			)
			return console.writeln(text)
		}
		
		output := FileGetInfo(cmdout2)
		for key, val in output
			console.setVar(cmdout1 "[" key "]", val, 0)
		
		return 1
	}
	
	if (cmd_process_first == "ПОКА") {
		ccmd_text = % cmd_text
		loop {
			parseIf(ccmd_text, "сделать")
			
			if (!caption_cmd) {
				text =
				(
Формат:
	"==": пока '<текст>' == '<текст>' сделать <команда, которая будет выполнена>
	"!=": пока '<текст>' != '<текст>' сделать <команда, которая будет выполнена>
	">": пока '<число>' > '<число>' сделать <команда, которая будет выполнена>
	"<": пока '<число>' < '<число>' сделать <команда, которая будет выполнена>
	">=": пока '<число>' >= '<число>' сделать <команда, которая будет выполнена>
	"=<": пока '<число>' =< '<число>' сделать <команда, которая будет выполнена>
	"содержит": пока '<текст>' содержит '<текст>' сделать <команда, которая будет выполнена>
	"не содержит": пока '<текст>' несодержит '<текст>' сделать <команда, которая будет выполнена>
	"файл существует": пока 'файл' существует '<путь к файлу>' сделать <команда, которая будет выполнена>
	"файл не существует": пока 'файл' несуществует '<путь к файлу>' сделать <команда, которая будет выполнена>
	"переменная существует": пока 'переменная' существует '<имя переменной/индекс массива>' сделать <команда, которая будет выполнена>
	"переменная не существует": пока 'переменная' несуществует '<имя переменной/индекс массив>' сделать <команда, которая будет выполнена>
Пример:
	"==": пока '`%пер`%' == '1' сделать вывод Переменная ПЕР равна единице.
	"!=": пока 'привет' != 'пока' сделать вывод Слово "привет" не равно слову "пока".
	">": пока '40' > '5' сделать вывод 40 больше 5.
	"<": пока '`%пер`%' < '5' сделать вывод Переменная ПЕР меньше 5.
	">=": пока '`%пер1`%' >= '5' сделать вывод Переменная ПЕР1 больше или равна пяти.
	"=<": пока '4' =< '5' сделать вывод 4 меньше или равно 5.
	"содержит": пока 'какой-то текст, который записан в переменной' содержит 'текст' сделать вывод Найдено слово 'текст'.
	"не содержит": пока '`%текст`%' несодержит 'какую-то строку' сделать вывод Переменная ТЕКСТ не содержит "какую-то строку".
	"файл существует": пока 'файл' существует 'C:\test.txt' сделать вывод Файл по пути C:\test.txt существует.
	"файл не существует": пока 'файл' несуществует 'C:\test.txt' сделать Файла по пути C:\test.txt не существует.
	"переменная существует": пока 'переменная' cуществует 'тестовая_переменная' сделать вывод Переменная "тестовая_переменная" существует.
	"переменная не существует": пока 'переменная' несуществует 'информация[1]' сделать вывод Массив под именем "информация" с индексом "1" не существует.
				)
				return console.writeln(text)
			}
			
			if (brks != 0) {
				console.error("Ожидался символ: '.")
					return -1
			}
			
			if (trim(string.down(action)) == "существует") {
				if (string.down(trim(cmdout1)) == "файл") {
					ifexist, % trim(cmdout2)
					{
						processCmd(cmdout3)
						continue
					}
					
					return 1
				}
				
				if (string.down(trim(cmdout1)) == "переменная") {
					for key, value in cmd_variables
					{
						if (trim(key) == trim(cmdout2))
						{
							processCmd(cmdout3)
							continue
						}
					}
					
					return 1
				}
			}
			
			if (trim(string.down(action)) == "несуществует") {
				if (string.down(trim(cmdout1)) == "файл") {
					ifnotexist, % trim(cmdout2)
					{
						processCmd(cmdout3)
						continue
					}
					
					return 1
				}
				
				if (string.down(trim(cmdout1)) == "переменная") {
					for key, value in cmd_variables
					{
						if (trim(key) == trim(cmdout2))
							return 1
					}
					
					processCMD(cmdout3)
					continue
				}
			}
			
			if (action == "==") {
				if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
					if (cmdout1 == cmdout2) {
						processCmd(cmdout3)
						continue
					} else {
						return 1
					}
				}
			}
			
			if (action == "!=") {
				if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
					if (trim(cmdout1) != trim(cmdout2)) {
						processCmd(cmdout3)
						continue
					} else {
						return 1
					}
				}
			}
			
			if (action == ">") {
				if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
					if (cmdout1 > cmdout2) {
						processCmd(cmdout3)
						continue
					} else {
						return 1
					}
				}
			}
			
			if (action == "<") {
				if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
					if (cmdout1 < cmdout2) {
						processCmd(cmdout3)
						continue
					} else {
						return 1
					}
				}
			}
				
			if (action == ">=") {
				if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
					if (cmdout1 >= cmdout2) {
						processCmd(cmdout3)
						continue
					} else {
						return 1
					}
				}
			}
			
			if (action == "=<") {
				if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
					if (cmdout1 <= cmdout2) {
						processCmd(cmdout3)
						continue
					} else {
						return 1
					}
				}
			}
			
			if (string.down(action) == "содержит") {
				if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
					if cmdout1 contains %cmdout2%
					{
						processCmd(cmdout3)
						continue
					} else {
						return 1
					}
				}
			}
			
			if (string.down(action) == "несодержит") {
				if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
					if cmdout1 not contains %cmdout2%
					{
						processCmd(cmdout3)
						continue
					} else {
						return 1
					}
				}
			}
			
			console.error("Вы указали недопустимые параметры. Возможно, Вы указали команду не по формату.")
			return 0
		}
	}
	
	if (cmd_process_first == "ЦИКЛ") {
		if (trim(string.up(cmd_text)) == "ЦИКЛ") {
			text =
			(
Формат: цикл [кол-во повторов:] <команда>

> Примечание:
  Если первый параметр опущен, то цикл выполняется бесконечно.

> Пример с определенным количеством повторов:
  цикл 5: вывод Это сообщение выводится 5 раз

> Пример с бесконечным количеством повторов:
  цикл вывод Это сообщение выводится бесконечно, пока Вы не закроете это окно.
			)
			return console.writeln(text)
		}
		
		_cmd := "", cmd_text := LTrim(cmd_text)
		loop, parse, cmd_text, % " "
		{
			if (A_Index == 1)
				continue
			
			if (A_Index == 2) {
				if (string.right(A_LoopField, 1) == "`:") {
					kolvo := string.left(A_LoopField, string.len(A_LoopField)-1)
					continue
				} else {
					kolvo := ""
				}
			}
			
			_cmd := _cmd A_LoopField " "
		}
		
		if (trim(kolvo) == "") {
			loop
				processCMD(_cmd)
		} else {
			loop, % kolvo
				processCMD(_cmd)
		}
		
		return 1
	}
	
	if (cmd_process_first == "ДЛЯ") {
		if (trim(string.up(cmd_text)) == "ДЛЯ") {
			text =
			(
Формат: для <вывод ключа> <вывод значения> в <вывод массива> сделать <команда>
Пример: для ключ значение в массив сделать вывод Ключ: `%ключ`%``nЗначение: `%значение`%
			)
			return console.writeln(text)
		}
		
		output_key := "", output_value := "", output_array := "", do := "", cmd_text := LTrim(cmd_text)
		
		loop, parse, cmd_text, % " "
		{
			if (A_Index == 1)
				continue
			
			if (A_Index == 2) {
				output_key := A_LoopField
				continue
			}
			
			if (A_Index == 3) {
				output_value := A_LoopField
				continue
			}
			
			if (A_Index == 4) {
				if (string.down(A_LoopField) != "в") {
					console.error("Некорректный синтаксис команды.")
					return 0
				}
				continue
			}
			
			if (A_Index == 5) {
				output_array := A_LoopField
				continue
			}
			
			if (A_Index == 6) {
				if (string.down(A_LoopField) != "сделать") {
					console.error("Некорректный синтаксис команды.")
					return 0
				}
				continue
			}
			
			do := do A_LoopField " "
		}
		
		if ((string.CheckNorm(output_key) == 0) || (string.CheckNorm(output_value) == 0) || (trim(output_key) == "") || (trim(output_value) == "")) {
			console.error("Укажите допустимое значение переменной для вывода.")
			return 0
		}
		
		if (output_array == "") {
			console.error("Укажите допустимое значение массива.")
			return 0
		}
		
		if (trim(do) == "") {
			console.error("Укажите параметр '<команда>'.")
			return 0
		}
		
		if output_array contains `[,`]
		{
			console.error("Укажите имя массива без индекса.")
			return 0
		}
		
		output_match := string.up(output_array) "[", was := ""
		for k, v in cmd_variables
		{
			k_match := string.left(string.up(k), string.len(output_match)-1) "["
			if (output_match == k_match) {
				RegExMatch(k, "\[(.*)\]$", outk)
				
				loop, parse, was, `|
				{
					if (A_LoopField == outk1) {
						wass := 1
						break
					}
				}
				
				if (wass) {
					wass := 0
					continue
				}
				
				was := was "|" outk1
				
				console.setVar(output_key, outk1)
				console.setVar(output_value, v)
				
				processCMD(do)
				continue
			}
		}
		
		console.setVar(output_key, "")
		console.setVar(output_value, "")
		return 1
	}
	
	if (cmd_process_first == "ПАУЗА") {
		loop {
			Input, output, L1 V
			sleep 100

			IfWinActive, ahk_id %mainwid%
				break
		}
		
		ControlSend,, {backspace}, ahk_id %mainwid%
		return 1
	}
	
	if (cmd_process_first == "СПИСОК") {
		justgen = 1
		executeCMD("справка")
		justgen := 0, i := 0, t := "`n"

		for k, v in tvs
		{
			if A_index == 1
				console.writeln("")
			
			if (k == string.up(k)) {
				i++
				console.writeln("#" i "`t" k)
			}
		}
		
		return 1
	}
	
	if (cmd_process_first == "ВВОДК") {
		SplitCommand(cmd_text, 3, "cmdout")
		if ((splited == -1) || (trim(cmdout1) == "")) {
			text =
			(
Формат: вводк '<вывод>' '[опции]' '[конечные клавиши]'

> Аргументы:
  вывод = имя переменной для вывода
  опции = см. ниже
  конечные клавиши = см. ниже

> Опции (может быть пустым или содержать какие-то из следующих букв (в любом порядке, с пробелами или без):
  Все буквы на английской раскладке.
  
  B - Backspace игнорируется. По умолчанию нажатие Backspace удаляет последний введённый символ с конца строки. Замечание: если вводимый текст видим (например, в редакторе) и были использованы клавиши-стрелки или другое средство для перемещения по тексту, Backspace всё равно удалит последний символ текста, а не тот, что позади каретки (текстового курсора).
  I: Игнорировать ввод, генерируемый скриптами Renux Shell. Однако, ввод через команду НАПЕЧАТАТЬБ игнорируется всегда, независимо от данной настройки.
  L: Ограничение длины (например, L5). Максимальная разрешённая длина вводимой строки. Когда текст достигнет указанной длины, команда ВВОДК завершится. Если данный параметр не задан, ограничение по длине составляет 16383 символов, что также является абсолютным максимумом.
  T: Таймаут (например, T3). Через указанное число секунд команда ВВОДК завершится. Если ВВОДК завершается по таймауту, в "<вывод>" будет текст, который пользователь успел ввести. Можно задавать числом с плавающей точкой, например, 2.5.
  V: Видимость текста. По умолчанию ввод пользователя блокируется (прячется от системы). Используйте эту опцию, если хотите, чтобы ввод посылался в активное окно.

> Конечные клавиши:
  Может быть пустым или содержать список клавиш, при нажатии на любую из которых работа ВВОДК должна быть завершена (сами эти клавиши не попадут в "<вывод>").
  В списке "<конечные клавиши>" используется тот же формат, что и для команды НАПЕЧАТАТЬ. Например, при указании {Enter}.{Esc} ВВОДК будет завершаться по нажатию клавиш ENTER, точка (.) или ESCAPE. Чтобы сами фигурные скобки завершали ВВОДК, их нужно задать как {{} и/или {}}.
  Чтобы использовать Control, Alt или Shift в качестве завершающих, указывайте конкретно левую и/или правую клавишу из пары. Например, {LControl}{RControl}, но не {Control}
			)
			return console.writeln(text)
		}
		
		Input, res, % cmdout2, % cmdout3
		return console.setVar(cmdout1, res)
	}
	
	if (cmd_process_first == "ПРОЦЕСС.ИСКАТЬ") {
		SplitCommand(cmd_text, 2, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: процесс.искать '<имя массива для вывода>' '<имя/часть имени процесса>'

> Параметр <имя/часть имени процесса>:
  Укажите "." для записи всех процессов.

Пример: процесс.искать 'список_процессов' '.'
			)
			return console.writeln(text)
		}
		
		AccessRights_EnableSeDebug()
		
		OUT_LIST := "", COUNT_NO_PATHS := 0, PROCESSES := 0
		for i, v in WTSEnumerateProcessesEx()
		{
			pn := v.ProcessName
			if pn contains %cmdout2%
			{
				FullEXEPath := GetModuleFileNameEx( v.ProcessID )
				PROCESSES+=1
				
				console.setVar(cmdout1 "[" A_Index "_имя]", v.ProcessName, 0)
				console.setVar(cmdout1 "[" A_Index "_ид]", v.ProcessID, 0)
				continue
			}
		}
		
		return console.setVar(cmdout1 "[всего]", PROCESSES, 0)
	}
	
	if (cmd_process_first == "ЗВЫВОД") {
		SplitCommand(cmd_text, 1, "cmdout")
		
		if (trim(cmdout1) != "") {
			if (string.left(cmdout1, 1) == ":") {
				if (console.setVar(cmdout1, "") == 0)
					return 0
			} else {
				FileDelete, % cmdout1
			}
			
			allow_console_writing = 0
			console_output_to := cmdout1
			settimer, checkRSWin, 100
		} else {
			allow_console_writing = 1
			console_output_to := ""
			settimer, checkRSWin, off
		}
		
		return 1
	}
	
	if (cmd_process_first == "АПДЕЙТЛИСТ") {
		justgen = 1
		executeCMD("справка")
		justgen := 0, i := 0, prev_ver := "Версия " version

		for k, v in tvs
		{
			if k contains %prev_ver%
			{
				TV_CLICKED := v
				gosub open_docs
				return 1
			}
		}
		
		return 0
	}

	if (cmd_process_first == "ВЫВОДФ") {
		SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: выводф <путь к файлу>
Пример: выводф test.txt
			)
			return console.writeln(text)
		}
		
		loop, read, % cmdout1
			console.writeln(A_LoopReadLine)
		
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.КОДИРОВКА") {
		SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: файл.кодировка [кодировка]
Пример: файл.кодировка UTF-8
			)
			return console.writeln(text)
		}
		
		FileEncoding, % cmdout1
		return 1
	}
	
	if (cmd_process_first == "КОРЗИНА.ПЕРЕМЕСТИТЬ") {
		SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: корзина.переместить <путь к файлу>
Пример: корзина.переместить test.txt
			)
			return console.writeln(text)
		}
		
		FileRecycle, % cmdout1
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "КОРЗИНА.ОЧИСТИТЬ") {
		SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "")
			FileRecycleEmpty
		else
			FileRecycleEmpty, % cmdout1
		
		return 1-ErrorLevel
	}
	
	if (cmd_process_first == "ФАЙЛ.ПРОЧИТАТЬ.БИНАР") {
		SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: файл.прочитать.бинар '<вывод бинарных данных (имя переменной)>' '<вывод размера в байтах (имя переменной)>' '<путь к файлу>'
Пример: файл.прочитать.бинар 'бинарные_данные' 'размер' 'test.txt'
			)
			return console.writeln(text)
		}
		
		File := FileOpen(cmdout3, "r")
		
		if (!IsObject(File)) {
			return console.error("Не удалось открыть файл.")
		}
		
		File.RawRead(Data, File.Length)
		console.setVar(cmdout1, Data)
		console.setVar(cmdout2, File.Length)
		File.Close()
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.ЗАПИСАТЬ.БИНАР") {
		SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: файл.записать.бинар '<ввод бинарных данных (имя переменной)>' '<размер в байтах>' '<путь к файлу>'
Пример: файл.записать.бинар 'бинарные_данные' '`%размер`%' 'test.txt'
			)
			return console.writeln(text)
		}
		
		File := FileOpen(cmdout3, "w")
		
		if (!IsObject(File)) {
			return console.error("Не удалось открыть файл.")
		}
		
		File.RawWrite(console.getVar(cmdout1), cmdout2)
		File.Close()
		return 1
	}
	
	if (cmd_process_first == "КОДИРОВАТЬ.BASE64") {
		SplitCommand(cmd_text, 3, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: кодировать.base64 '<вывод данных>' '<ввод данных (имя переменной)>' '<размер данных в байтах>'
Пример: кодировать.base64 'формат_base64' 'данные' '`%размер`%'
			)
			return console.writeln(text)
		}
		
		Base64enc( result, console.getVar(cmdout2), cmdout3)
		return console.setVar(cmdout1, result)
	}
	
	if (cmd_process_first == "ВВОД.ОКНО") {
		SplitCommand(cmd_text, 11, "cmdout")
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: ввод.окно '<вывод (имя переменной)>' '<заголовок>' '<текст>' '[скрывать? (flag=0/1)]' '[ширина]' '[высота]' '[x]' '[y]' '[имя шрифта]' '[тайм-аут]' '[текст по-умолчанию]'
Пример: ввод.окно 'текст' 'Заголовок для окна' 'Текст для окна' '' '' '' '' '' '' '' ''
			)
			return console.writeln(text)
		}
		
		if (cmdout4)
			InputBox, result, % cmdout2, % cmdout3, HIDE, % cmdout5, % cmdout6, % cmdout7, % cmdout8, % cmdout9, % cmdout10, % cmdout11
		else
			InputBox, result, % cmdout2, % cmdout3, 0, % cmdout5, % cmdout6, % cmdout7, % cmdout8, % cmdout9, % cmdout10, % cmdout11
		
		if errorlevel
			return 1-ErrorLevel
		
		return console.setVar(cmdout1, result)
	}
	
	if (cmd_process_first == "ТЕКСТ.ПОКАЗАТЬ") {
		SplitCommand(cmd_text, 4, "cmdout", 1, 0)
		SplashTextOn, % cmdout1, % cmdout2, % cmdout3, % cmdout4
		return 1
	}
	
	if (cmd_process_first == "ТЕКСТ.СКРЫТЬ") {
		SplashTextOff
		return 1
	}
	
	if (cmd_process_first == "ПОДСКАЗКА") {
		SplitCommand(cmd_text, 4, "cmdout", 1, 0)
		ToolTip, % cmdout1, % cmdout2, % cmdout3, % cmdout4
		return 1
	}
	
	if (cmd_process_first == "СДЕЛАТЬ") {
		SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: сделать <команда>
Пример: сделать вывод Привет
			)
			return console.writeln(text)
		}
		
		executeCMD(cmdout1)
		return pc_result
	}
	
	if ((cmd_process_first == "ВК") || (cmd_process_first == "ВЫВОДКОНСОЛЬ")) {
		if (!allow_console_writing) {
			return console.error("Недопустимая операция в режиме перенаправления вывода консоли.")
		}
		
		SplitCommand(cmd_text, 1, "cmdout")
		if (trim(cmdout1) == "") {
			text =
			(
Формат: выводконсоль <команда>
Пример: выводконсоль ??
			)
			return console.writeln(text)
		}
		
		settimer, checkRSWin, 1
		executeCMD(cmdout1)
		settimer, checkRSWin, off
		return pc_result
	}

	; =======================================================
	
	addon_desc := addons[cmd_process_first][1]
	addon_syntax := addons[cmd_process_first][2]
	addon_example := addons[cmd_process_first][3]
	addon_indexp := addons[cmd_process_first][4]
	addon_array_name := addons[cmd_process_first][5]
	addon_script := addons[cmd_process_first][6]
	
	if (addon_indexp > 15) {
		console.error("Поддерживается максимум 15 параметров.")
		return -1
	}
	
	if (addon_script) {
		splited := SplitCommand(cmd_text, addon_indexp, "cmdout")
		if (splited == -2) {
			text =
			(
%addon_desc%

Формат: %addon_syntax%
Пример: %addon_example%
			)
			return console.writeln(text)
		}
		
		ifnotexist, % root "\" addon_script ".rs"
		{
			console.error("Файл " root "\" addon_script ".rs" " не найден.")
			return -1
		}
		
		loop, 15
			console.setVar(addon_array_name "[" A_Index "]", "", 0)
		
		console.setVar(addon_array_name "[1]", cmdout1, 0)
		console.setVar(addon_array_name "[2]", cmdout2, 0)
		console.setVar(addon_array_name "[3]", cmdout3, 0)
		console.setVar(addon_array_name "[4]", cmdout4, 0)
		console.setVar(addon_array_name "[5]", cmdout5, 0)
		console.setVar(addon_array_name "[6]", cmdout6, 0)
		console.setVar(addon_array_name "[7]", cmdout7, 0)
		console.setVar(addon_array_name "[8]", cmdout8, 0)
		console.setVar(addon_array_name "[9]", cmdout9, 0)
		console.setVar(addon_array_name "[10]", cmdout10, 0)
		console.setVar(addon_array_name "[11]", cmdout11, 0)
		console.setVar(addon_array_name "[12]", cmdout12, 0)
		console.setVar(addon_array_name "[13]", cmdout13, 0)
		console.setVar(addon_array_name "[14]", cmdout14, 0)
		console.setVar(addon_array_name "[15]", cmdout15, 0)
		
		shell_from := 1
		shell_file := root "\" addon_script ".rs"
		shell_mode := 1
		return 2
	}
	
	ifexist, %A_WorkingDir%\%cmd_text%.rs
	{
		FileRead, t, %A_WorkingDir%\%cmd_text%.rs
		if (trim(t) == "") {
			return 0
		}
		
		shell_from := 1
		shell_mode := 1
		shell_file := A_WorkingDir "\" cmd_text ".rs"
		return 1
	}
	
	ifexist, %root%\%cmd_text%.rs
	{
		FileRead, t, %A_WorkingDir%\%cmd_text%.rs
		if (trim(t) == "") {
			return 0
		}
		
		shell_from := 1
		shell_mode := 1
		shell_file := A_WorkingDir "\" cmd_text ".rs"
		return 1
	}
	
	process_pid =
	try RunWait, %cmd_text%,,, PROCESS_PID
	if (PROCESS_PID) {
		if debug
			console.writeln("Запущен процесс под ID: " PROCESS_PID)
		
		return 1
	}

	if (!shell_mode) {
		loop, parse, cmd_text, % " "
		{
			cmd_parsed := A_LoopField
			break
		}
		
		console.error("Не удалось определить команду '" cmd_process_first "', используйте 'СПРАВКА' или '?' для открытия справки.")
	}
	else {
		if (ignore_errors == 0) {
			if (output_mode == "print")
			{
				console.error("Команду '" cmd_text "' обработать не удалось!")
			}
			else {
				MsgBox, 16, % title,
				(
	Произошла ошибка при исполнении пакетного файла '%shell_file%':

	Команду '%cmd_text%' обработать не удалось!
				)
			}
		}
	}
	
	return -1
}

Base64enc( ByRef OutData, ByRef InData, InDataLen ) {
 DllCall( "Crypt32.dll\CryptBinaryToString" ( A_IsUnicode ? "W" : "A" )
        , UInt,&InData, UInt,InDataLen, UInt,1, UInt,0, UIntP,TChars, "CDECL Int" )
 VarSetCapacity( OutData, Req := TChars * ( A_IsUnicode ? 2 : 1 ) )
 DllCall( "Crypt32.dll\CryptBinaryToString" ( A_IsUnicode ? "W" : "A" )
        , UInt,&InData, UInt,InDataLen, UInt,1, Str,OutData, UIntP,Req, "CDECL Int" )
Return TChars
}

putArr(text) {
	return text
}

class string {
	getLine(text, line) {
		loop, parse, % text, `r`n
		{
			if (A_Index == Line) {
				return A_LoopField
			}
		}
	}
	
	checkCyrillic(text) {
		rus = 0
		characters = а,б,в,г,д,е,ё,ж,з,и,й,к,л,м,н,о,п,р,с,т,у,ф,х,ц,ч,ш,щ,ъ,ы,ь,э,ю,я,А,Б,В,Г,Д,Е,Ё,Ж,З,И,Й,К,Л,М,Н,О,П,Р,С,Т,У,Ф,Х,Ц,Ч,Ш,Щ,Ъ,Ы,Ь,Э,Ю,Я
		loop, parse, characters, `,
		{
			if text contains %A_LoopField%
			{
				rus = 1
				break
			}
		}
		return rus
	}

	checkLatin(text) {
		eng = 0
		characters = a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z,A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z
		loop, parse, characters, `,
		{
			if text contains %A_LoopField%
			{
				eng = 1
				break
			}
		}
		return eng
	}
	
	checkInteger(text) {
		int = 0
		characters = 1,2,3,4,5,6,7,8,9,0
		loop, parse, characters, `,
		{
			if text contains %A_LoopField%
			{
				int = 1
				break
			}
		}
		return int
	}
	
	checkSymbol(text) {
		symbol = 0
		characters = _
		loop, parse, characters, `,
		{
			if text contains %A_LoopField%
			{
				symbol = 1
				break
			}
		}
		return symbol
	}
	
	checkNorm(text) {
		if (RegExMatch(text, "i)[ `n-\.%,(\\\/=&^\?]")) ; Check if it is a valid variable name
			return 0
		
		return 1
	}
	
	up(text) {
		StringUpper, rtn, text
		return rtn
	}
	
	down(text) {
		StringLower, rtn, text
		return rtn
	}
	
	upT(text) {
		StringUpper, rtn, text, T
		return rtn
	}
	
	downT(text) {
		StringLower, rtn, text, T
		return rtn
	}
	
	left(text, number) {
		StringLeft, rtn, text, % number
		return rtn
	}
	
	right(text, number) {
		StringRight, rtn, text, % number
		return rtn
	}
	
	len(text) {
		StringLen, rtn, text
		return rtn
	}
}

unpackRSAC(text) {
	loop {
		random, rand, 1000000, 9999999
		ifexist, %root%\%rand%.rsa
			continue
		
		file_name := rand
		break
	}
	
	FileDelete, %root%\%file_name%.rsa
	
	write_file := 0
	loop, parse, text, `r`n
	{
		if (trim(A_LoopField) == "")
			continue
		
		if ((write_file == 0) && (A_LoopField != "<< СКРИПТ >>")) { ; запись .rsa
			fileappend, % A_LoopField "`n", % root "\" file_name ".rsa"
			if errorlevel
			{
				console.error("Не удалось записать .rsa файл по пути: " root "\" file_name ".rsa")
				console.writeln("Попробуйте запустить программу от имени администратора.")
				return 0
			}
			continue
		}
		
		if ((A_LoopField == "<< СКРИПТ >>") && (write_file == 0)) {
			IniRead, имя_пакета, %root%\%file_name%.rsa, addon, имя_пакета, % file_name
			FileDelete, %root%\%имя_пакета%.rs
			write_file := 1
			continue
		}
		
		if (write_file == 1) {
			fileappend, % A_LoopField "`n", %root%\%имя_пакета%.rs
			if errorlevel
			{
				console.error("Не удалось записать .rs файл по пути: " root "\" file_name ".rs")
				console.writeln("Попробуйте запустить программу от имени администратора.")
				return 0
			}
		}
	}
	
	console.writeln("Аддон установлен как " file_name ".rsa!")
	sleep 4000
	processCMD("рестарт")
	return 1
}

PrepareForIncomingConnection(IPAddress, Port)
; This can connect to most types of TCP servers, not just Network.
; Returns -1 (INVALID_SOCKET) upon failure or the socket ID upon success.
{
    VarSetCapacity(wsaData, 32)  ; The struct is only about 14 in size, so 32 is conservative.
    result := DllCall("Ws2_32\WSAStartup", "UShort", 0x0002, "UInt", &wsaData) ; Request Winsock 2.0 (0x0002)
    ; Since WSAStartup() will likely be the first Winsock function called by this script,
    ; check ErrorLevel to see if the OS has Winsock 2.0 available:
    if ErrorLevel
    {
        console.error("WSAStartup() не может быть вызван из-за ошибки: " ErrorLevel ". Winsock 2.0 и требуется выше.")
        return -1
    }
	
    if result  ; Non-zero, which means it failed (most Winsock functions return 0 upon success).
    {
        console.error("WSAStartup(): " DllCall("Ws2_32\WSAGetLastError") ".")
        return -1
    }

    AF_INET = 2
    SOCK_STREAM = 1
    IPPROTO_TCP = 6
    socket := DllCall("Ws2_32\socket", "Int", AF_INET, "Int", SOCK_STREAM, "Int", IPPROTO_TCP)
    if socket = -1
    {
        console.error("socket(): " . DllCall("Ws2_32\WSAGetLastError") ".")
        return -1
    }

    ; Prepare for connection:
    SizeOfSocketAddress = 16
    VarSetCapacity(SocketAddress, SizeOfSocketAddress)
    InsertInteger(2, SocketAddress, 0, AF_INET)   ; sin_family
    InsertInteger(DllCall("Ws2_32\htons", "UShort", Port), SocketAddress, 2, 2)   ; sin_port
    InsertInteger(DllCall("Ws2_32\inet_addr", "Str", IPAddress), SocketAddress, 4, 4)   ; sin_addr.s_addr

    ; Bind to socket:
    if DllCall("Ws2_32\bind", "UInt", socket, "UInt", &SocketAddress, "Int", SizeOfSocketAddress)
    {
        console.error("bind(): " . DllCall("Ws2_32\WSAGetLastError") . "?")
        return -1
    }
    if DllCall("Ws2_32\listen", "UInt", socket, "UInt", "SOMAXCONN")
    {
        console.error("LISTEN(): " . DllCall("Ws2_32\WSAGetLastError") . "?")
        return -1
    }
   
    return socket  ; Indicate success by returning a valid socket ID rather than -1. 
}

SendData(wParam,SendData, Repeat, Delay)
{
   socket := wParam
;   SendDataSize := VarSetCapacity(SendData)
;   SendDataSize += 1
   Loop % Repeat
   {
   	  SendIt := SendData
      SendDataSize := VarSetCapacity(SendIt)
      SendDataSize += 1
      
      sendret := DllCall("Ws2_32\send", "UInt", socket, "Str", SendIt, "Int", SendDatasize, "Int", 0)
      WinsockError := DllCall("Ws2_32\WSAGetLastError")
      
	  if WinsockError <> 0 ; WSAECONNRESET, which happens when Network closes via system shutdown/logoff.
	  {
		console.error("При отправке произошла ошибка №" . WinsockError ". Возможно, это связано с тем, что клиент закрыл соединение.")
		ConnectionClosed()
	  }
	  
   	  sleep,Delay
   }
;send( sockConnected,> welcome, strlen(welcome) + 1, NULL);
}

ConnectToAddress(IPAddress, Port)
; Returns -1 (INVALID_SOCKET) upon failure or the socket ID upon success.
{
    VarSetCapacity(wsaData, 32)  ; The struct is only about 14 in size, so 32 is conservative.
    result := DllCall("Ws2_32\WSAStartup", "UShort", 0x0002, "UInt", &wsaData) ; Request Winsock 2.0 (0x0002)
    ; Since WSAStartup() will likely be the first Winsock function called by this script,
    ; check ErrorLevel to see if the OS has Winsock 2.0 available:
    if ErrorLevel
    {
        console.error("WSAStartup(): не может быть вызван из-за ошибки " ErrorLevel ". Winsock 2.0 и должен быть выше.")
        return -1
    }
    if result  ; Non-zero, which means it failed (most Winsock functions return 0 upon success).
    {
        console.error("WSAStartup(): " . DllCall("Ws2_32\WSAGetLastError") ".")
        return -1
    }

    AF_INET = 2
    SOCK_STREAM = 1
    IPPROTO_TCP = 6
    socket := DllCall("Ws2_32\socket", "Int", AF_INET, "Int", SOCK_STREAM, "Int", IPPROTO_TCP)
    if socket = -1
    {
        console.error("socket(): " . DllCall("Ws2_32\WSAGetLastError") ".")
        return -1
    }

    ; Prepare for connection:
    SizeOfSocketAddress = 16
    VarSetCapacity(SocketAddress, SizeOfSocketAddress)
    InsertInteger(2, SocketAddress, 0, AF_INET)   ; sin_family
    InsertInteger(DllCall("Ws2_32\htons", "UShort", Port), SocketAddress, 2, 2)   ; sin_port
    InsertInteger(DllCall("Ws2_32\inet_addr", "Str", IPAddress), SocketAddress, 4, 4)   ; sin_addr.s_addr

    ; Attempt connection:
    if DllCall("Ws2_32\connect", "UInt", socket, "UInt", &SocketAddress, "Int", SizeOfSocketAddress)
    {
        console.error("Не удалось подключиться. (" . DllCall("Ws2_32\WSAGetLastError") . ")")
        return -1
    }
	
    return socket  ; Indicate success by returning a valid socket ID rather than -1.
}

ConnectionClosed() {
	global connection_closed
	gui, destroy
	
	DllCall("Ws2_32\WSACleanup")
	
	console.info("Соединение было оборвано.")
	connection_closed := 1
	return 0
}

ReceiveData(wParam)
{
	Critical
	
	global ShowReceived
    global MyEdit
    global LinesReceived

    socket := wParam
    ReceivedDataSize = 4096  ; Large in case a lot of data gets buffered due to delay in processing previous data.
    VarSetCapacity(ReceivedData, ReceivedDataSize, 0)  ; 0 for last param terminates string for use with recv().
    Data   := ""
    Loop  ; This loop solves the issue of the notification message being discarded due to thread-already-running.
    {
        ReceivedDataLength := DllCall("Ws2_32\recv", "UInt", socket, "Str", ReceivedData, "Int", ReceivedDataSize, "Int", 0)
        if ReceivedDataLength = 0  ; The connection was gracefully closed,
		{
			console.info("Соединение закрыто.")
			break
		}
		
		if ReceivedDataLength = -1
        {
            WinsockError := DllCall("Ws2_32\WSAGetLastError")
            if ( WinsockError = 10035 ) { ; WSAEWOULDBLOCK, which means "no more data to be read".
                break
            }
        }
        Data .= ReceivedData
    }
	
    ; Otherwise, process the data received.
    Loop, parse, Data, `n, `r
    {
		if (A_LoopField == "<RENUX> #DISCONNECTED#")
		{
			connectionClosed()
			return 1
		}
		
	    console.writeln(A_LoopField)
    }
	
    return 1  ; Tell the program that no further processing of this message is needed.
}

MoveBrightness(i, l=0) {
	if (l == 0) {
		i := (trim(i)), it := string.left(i, 1)
		
		if ((it != "-") && (it != "+")) {
			MoveBrightness(-100, 1)
		}
	}
	
	IndexMove := i
	VarSetCapacity(SupportedBrightness, 256, 0)
	VarSetCapacity(SupportedBrightnessSize, 4, 0)
	VarSetCapacity(BrightnessSize, 4, 0)
	VarSetCapacity(Brightness, 3, 0)
	
	hLCD := DllCall("CreateFile"
	, Str, "\\.\LCD"
	, UInt, 0x80000000 | 0x40000000 ;Read | Write
	, UInt, 0x1 | 0x2  ; File Read | File Write
	, UInt, 0
	, UInt, 0x3  ; open any existing file
	, UInt, 0
	  , UInt, 0)
	
	if hLCD != -1
	{
		
		DevVideo := 0x00000023, BuffMethod := 0, Fileacces := 0
		  NumPut(0x03, Brightness, 0, "UChar")   ; 0x01 = Set AC, 0x02 = Set DC, 0x03 = Set both
		  NumPut(0x00, Brightness, 1, "UChar")      ; The AC brightness level
		  NumPut(0x00, Brightness, 2, "UChar")      ; The DC brightness level
		DllCall("DeviceIoControl"
		  , UInt, hLCD
		  , UInt, (DevVideo<<16 | 0x126<<2 | BuffMethod<<14 | Fileacces) ; IOCTL_VIDEO_QUERY_DISPLAY_BRIGHTNESS
		  , UInt, 0
		  , UInt, 0
		  , UInt, &Brightness
		  , UInt, 3
		  , UInt, &BrightnessSize
		  , UInt, 0)
		
		DllCall("DeviceIoControl"
		  , UInt, hLCD
		  , UInt, (DevVideo<<16 | 0x125<<2 | BuffMethod<<14 | Fileacces) ; IOCTL_VIDEO_QUERY_SUPPORTED_BRIGHTNESS
		  , UInt, 0
		  , UInt, 0
		  , UInt, &SupportedBrightness
		  , UInt, 256
		  , UInt, &SupportedBrightnessSize
		  , UInt, 0)
		
		ACBrightness := NumGet(Brightness, 1, "UChar")
		ACIndex := 0
		DCBrightness := NumGet(Brightness, 2, "UChar")
		DCIndex := 0
		BufferSize := NumGet(SupportedBrightnessSize, 0, "UInt")
		MaxIndex := BufferSize-1

		Loop, %BufferSize%
		{
		ThisIndex := A_Index-1
		ThisBrightness := NumGet(SupportedBrightness, ThisIndex, "UChar")
		if ACBrightness = %ThisBrightness%
			ACIndex := ThisIndex
		if DCBrightness = %ThisBrightness%
			DCIndex := ThisIndex
		}
		
		if DCIndex >= %ACIndex%
		  BrightnessIndex := DCIndex
		else
		  BrightnessIndex := ACIndex

		BrightnessIndex += IndexMove
		
		if BrightnessIndex > %MaxIndex%
		   BrightnessIndex := MaxIndex
		   
		if BrightnessIndex < 0
		   BrightnessIndex := 0

		NewBrightness := NumGet(SupportedBrightness, BrightnessIndex, "UChar")
		
		NumPut(0x03, Brightness, 0, "UChar")   ; 0x01 = Set AC, 0x02 = Set DC, 0x03 = Set both
        NumPut(NewBrightness, Brightness, 1, "UChar")      ; The AC brightness level
        NumPut(NewBrightness, Brightness, 2, "UChar")      ; The DC brightness level
		
		DllCall("DeviceIoControl"
			, UInt, hLCD
			, UInt, (DevVideo<<16 | 0x127<<2 | BuffMethod<<14 | Fileacces) ; IOCTL_VIDEO_SET_DISPLAY_BRIGHTNESS
			, UInt, &Brightness
			, UInt, 3
			, UInt, 0
			, UInt, 0
			, UInt, 0
			, Uint, 0)
		
		DllCall("CloseHandle", UInt, hLCD)
		sleep 100
	}

}

class console {
	setVar(variable, value, limit=1) {
		variable := trim(variable)
		
		if (string.down(variable) == ".система.клипборд")
			limit = 0
		
		if (limit) {
			if (string.checkNorm(variable) == 0) {
				console.warning("Имя переменной содержит недопустимые символы и не может называться '" variable "'.")
				return 0
			}
		}
		
		a := 0
		loop, parse, variable
		{
			if ((A_LoopField == "[") || (A_LoopField == "]")) {
				a+=1
			}
		}

		if variable contains `[
		{
			if (a > 2) {
				console.error("Массив не может быть многомерным.")
				return 0
			}
		
			loop, parse, variable, `[
			{
				if (A_Index == 1) {
					if (string.checkNorm(A_LoopField) == 0) {
						console.error("Имя массива содержит недопустимые символы и не может называться '" variable "'.")
						return
					}
					
					break
				}
			}
		}
		
		if (string.down(variable) == ".система.клипборд")
			Clipboard := value
		
		try cmd_variables[variable] := value
		catch e {
			console.warning("Не удалось назначить переменную '" variable "' (возможно в названии используются запрещенные символы).")
			return 0
		}
		
		;if (string.left(variable, 1) != ".")
		;	MsgBox,, % "OK!", %variable%=%value%
		
		return 1
	}
	
	math(value) {
		RunWait, cmd.exe /c set /a "%value%" > math.tmp,, UseErrorLevel
		FileRead, result, math.tmp
		FileDelete, math.tmp
		return result
	}
	
	getVar(variable) {
		return cmd_variables[variable]
	}

	processVars(text) {
		global
		
		if text contains %variables_explode_symbols%
		{
			; Встроенные переменные
			console.setVar(".время.день", A_DD, 0)
			console.setVar(".время.месяц", A_MM, 0, 0)
			console.setVar(".время.год", A_YYYY, 0)
			console.setVar(".время.час", A_Hour, 0)
			console.setVar(".время.минута", A_Min, 0)
			console.setVar(".время.секунда", A_Sec, 0)
			console.setVar(".время.счетчик", A_TickCount, 0)
			console.setVar(".время.месяцк", A_MMM, 0)
			console.setVar(".время.месяцс", A_MMMM, 0)
			console.setVar(".время.неделяк", A_DDD, 0)
			console.setVar(".время.неделяс", A_DDDD, 0)
			console.setVar(".консоль.результат", pc_result, 0)
			console.setVar(".консоль.рпапка", A_WorkingDir, 0)
			console.setVar(".консоль.скрипт", shell_file, 0)
			console.setVar(".консоль.пробел", A_Space, 0)
			console.setVar(".система.клипборд", Clipboard, 0)
		}
		
		for key, value in cmd_variables
			StringReplace, text, text, `%%key%`%, % value, All
		
		return text
	}

	init() {
		global mainwid
		
		console.create()
		
		if (!attached) {
			process, exist
			WinGet, mainwid, ID, ahk_pid %ErrorLevel%
		} else {
			WinGet, mainwid, ID, % "ahk_pid " Process_GetCurrentParentProcessID()
		}
		
		WinGetTitle, titlee, ahk_id %mainwid%
		
		if (trim(titlee) == "") {
			process, exist
			WinGet, mainwid, ID, ahk_pid %ErrorLevel%
		}
		
		if (!attached)
			WinSet, Transparent, % start_transparent, ahk_id %mainwid%
		
		DllCall("SetConsoleOutputCP", "int", 1251)
		DllCall("SetConsoleCP", "int", 1251)
	}
	
	flushBuffer() {
		hStdout.Read(0)
	}
	
	create() {
		attached = 1
		
		if (no_attach) {
			DllCall("AllocConsole")
			attached = 0
		}
		else {
			if (DllCall("AttachConsole", "uInt", Process_GetCurrentParentProcessID(), "Cdecl int") != 1) {
				DllCall("AllocConsole")
				attached = 0
			}
		}
		
		hStdIn := FileOpen(DllCall("GetStdHandle", "int", -10, "ptr"), "h `n")
		hStdOut := FileOpen(DllCall("GetStdHandle", "int", -11, "ptr"), "h `n")
		
		if (attached) {
			parentProcessPath := GetModuleFileNameEx(Process_GetCurrentParentProcessID())
			
			if (string.up(string.right(parentProcessPath, 7)) != "CMD.EXE") {
				if parentProcessPath not contains %A_WinDir%
				{
					if (parentProcessPath != A_ScriptFullPath) {
						an := FileGetInfo(parentProcessPath).FileDescription
						SplitPath, parentprocesspath, an_name
						
						MsgBox, 49, % title ": Предупреждение", % "Renux Shell может работать некорректно, если в качестве командной строки не используется стандартная командная строка Windows.`n`nЭто предупреждение появилось, так как Renux Shell определил, что Вы запускаете его не напрямую из командной строки, а через: " (an ? an : an_name) " (" parentProcessPath ").`n`nНажмите на 'ОК' для продолжения запуска RS.`nНажмите на 'Отмена' для отмены запуска RS."
						IfMsgBox, Cancel
							exitapp
					}
				}
			}
			
			console.writeln("")
			
			if (!no_suspend)
				Process_Suspend(Process_GetCurrentParentProcessID())
			
			ControlSend,, {enter}, % "ahk_pid " Process_GetCurrentParentProcessID()
		}
		
		if (!attached)
			DllCall("SetConsoleTitleW", "str", (A_IsAdmin ? "Администратор" : A_UserName) ": " title)
	}
	
	cmd(cmd) {
		if (allow_console_writing)
			RunWait, cmd.exe /c %cmd%,, UseErrorLevel
		else {
			RunCon(ComSpec, "echo off & " cmd, output)
			
			toOut := ""
			loop, parse, output, `n
			{
				if (A_Index < 5)
					continue
				
				toOutput := toOutput A_LoopField "`n"
			}
			
			console.writeln(RTrim(toOutput, "`n"))
		}
	}
	
	read() {
		if (allow_console_writing) {
			result := RTrim(hStdIn.ReadLine(), "`n")
			console.flushBuffer()
		} else {
			console.writeln("[DEBUG] Ввод команды отменен, так как идет перенаправление вывода.")
			result := 0
		}
	
		if log
			fileappend, % hStdIn.ReadLine() "`n", %root%\log.txt
		
		return result
	}
	
	write(text) {
		if (string.left(text, 7) == "[DEBUG]") {
			StringReplace, text, text, % "[DEBUG]",,			
			LV_Add("", shell_mline, cmd_source[shell_mline], text)
			LV_ModifyCol()
			LV_Modify(LV_GetCount(), "Vis")
			sleep 1
			
			if debug_pause_menu
				console.cmd("pause")
			
			return 1
		}
		
		if (!allow_console_writing) {
			text := StrReplace(text, "`t", " ")
			if (string.left(console_output_to, 1) == ":") {
				varname := string.right(console_output_to, string.len(console_output_to)-1)
				console.setVar(varname, console.getVar(varname) . text)
			} else {
				fileappend, % text, % console_output_to
			}
			return
		}
		
		result := hStdOut.write(text)
		console.flushBuffer()
		
		if log
			fileappend, % text, %root%\log.txt
		
		return result
	}
	
	writeln(text) {
		if (string.left(text, 7) == "[DEBUG]") {
			StringReplace, text, text, % "[DEBUG]",,			
			LV_Add("", shell_mline, cmd_source[shell_mline], text)
			LV_ModifyCol()
			LV_Modify(LV_GetCount(), "Vis")
			sleep 1
			
			if debug_pause_menu
				console.cmd("pause")
			
			return 1
		}
		
		if (!allow_console_writing) {
			text := StrReplace(text, "`t", " ")
			
			if (trim(text) == "")
				return
			
			if (string.left(console_output_to, 1) == ":") {
				varname := string.right(console_output_to, string.len(console_output_to)-1)
				console.setVar(varname, console.getVar(varname) text . "`n")
			} else {
				fileappend, % text "`n", % console_output_to
			}
			return
		}
		
		result := hStdOut.WriteLine(text)
		console.flushBuffer()
		
		if log
			fileappend, % text "`n", %root%\log.txt 
		
		return result
	}
	
	warning(text) {
		if ignore_warnings
			return -1
		
		if (output_mode == "msg")
			MsgBox, 0, % title, % text "`n`nОкно автоматически закроется через 5 секунд.", 5
		else	
			return console.writeln(text)
	}
	
	info(text) {
		if ignore_info
			return -1
		
		if (output_mode == "msg")
			MsgBox, 0, % title, % text "`n`nОкно автоматически закроется через 5 секунд.", 5
		else	
			return console.writeln("[#] " text)
	}
	
	error(text) {
		if ignore_errors
			return -1
		
		if (output_mode == "msg") {
			MsgBox, 4, % title, % text "`n`nПродолжить выполнение сценария?"
			IfMsgBox, yes
				return -1
			
			IfMsgBox, no
				exitapp
		}
		
		return console.writeln("ОШИБКА: " text)
	}
	
	question(text) {
		return console.writeln("[?] " text)
	}
	
	progress(text) {
		result := hstdout.WriteLine("[~] " text)
		console.flushBuffer()
		return result
	}
	
	waitKeys(keys) { ; в параметр keys указываются клавиши, нажатие которых нужно ожидать. Разделяется символом ",".
		if (!allow_console_writing) {
			console.writeln("[DEBUG] Ввод команды отменен, так как идет перенаправление вывода.")
			return
		}
		
		wid := mainwid
		
		loop {
			loop, parse, keys, `,
			{
				if (GetKeyState(trim(A_LoopField), "P")) {
					KeyWait, % A_LoopField, U
					IfWinNotActive, ahk_id %wid%
						continue
					
					ControlSend,, {Backspace}, ahk_id %wid%
					return trim(A_LoopField)
				}
			}
			
			sleep 1
		}
	}
	
	download(url, to) { ; to - путь, куда сохранится файл.
		global warn_download
		
		ifexist, % to
		{
			console.warning("Файл по этому пути уже имеется. Сначала удалите его.")
			return -1
		}
		
		SplitPath, to, filename_prev
		ToolTip, Получение информации...
		netsize := GetFileSizeFromInternet(url), filename_prev := trim(filename_prev)
		ToolTip
		if netsize not contains `<
		{
			_netsize := netsize, netsize := netsize " байт"
		}
		else {
			netsize := "определить не удалось"
		}
		
		console.question("Renux Shell хочет скачать файл " filename_prev ". Размер: " netsize ". [Y/N]")
		pressed := console.waitKeys("Y,N")
		if (pressed == "Y") {
			loop {
				console.progress("Попытка загрузки файла из Сети Интернет: " url "...")
				moment_time := A_TickCount
				URLDownloadToFile, % url, % to
				dl_time := FormatTime(A_TickCount - moment_time)
				FileGetSize, filesize, % to
				
				ifnotexist, % to
				{
					console.warning("Файл " filename_prev " не удалось скачать.")
					return 0
				}
				
				if netsize not contains не
				{
					if netsize not contains Невозможно
					{
						console.info("Скачано " filesize " из " netsize " байт за " dl_time ".")
						
						if (filesize != _netsize) {
							console.warning("Нарушена целостность файла. Возможно это связано с тем, что у Вас нестабильный интернет.")
							console.question("Повторить попытку? [Y/N]")
							verdict := console.waitKeys("Y,N")
							if (verdict == "Y") {
								continue
							}
							else {
								return 0
							}
						}
					}
				} else {
					console.info("Скачано " _filesize " за " dl_time ".")
				}
				
				break
			}
			
			return 1
		}
		else {
			return 0
		}
	}
}

Process_GetCurrentProcessID(){
  Return DllCall("GetCurrentProcessId")  ; http://msdn2.microsoft.com/ms683180.aspx
}

Process_GetCurrentParentProcessID(){
  Return Process_GetParentProcessID(Process_GetCurrentProcessID())
}

Process_GetProcessName(ProcessID){
  Return Process_GetProcessInformation(ProcessID, "Str", 260, 36)  ; TCHAR szExeFile[MAX_PATH]
}

Process_GetParentProcessID(ProcessID){
  Return Process_GetProcessInformation(ProcessID, "UInt *", 4, 24)  ; DWORD th32ParentProcessID
}

Process_GetProcessThreadCount(ProcessID){
  Return Process_GetProcessInformation(ProcessID, "UInt *", 4, 20)  ; DWORD cntThreads
}

Process_GetProcessInformation(ProcessID, CallVariableType, VariableCapacity, DataOffset){
  hSnapshot := DLLCall("CreateToolhelp32Snapshot", "UInt", 2, "UInt", 0)  ; TH32CS_SNAPPROCESS = 2
  if (hSnapshot >= 0)
  {
    VarSetCapacity(PE32, 304, 0)  ; PROCESSENTRY32 structure -> http://msdn2.microsoft.com/ms684839.aspx
    DllCall("ntdll.dll\RtlFillMemoryUlong", "UInt", &PE32, "UInt", 4, "UInt", 304)  ; Set dwSize
    VarSetCapacity(th32ProcessID, 4, 0)
    if (DllCall("Process32First", "UInt", hSnapshot, "UInt", &PE32))  ; http://msdn2.microsoft.com/ms684834.aspx
      Loop
      {
        DllCall("RtlMoveMemory", "UInt *", th32ProcessID, "UInt", &PE32 + 8, "UInt", 4)  ; http://msdn2.microsoft.com/ms803004.aspx
        if (ProcessID = th32ProcessID)
        {
          VarSetCapacity(th32DataEntry, VariableCapacity, 0)
          DllCall("RtlMoveMemory", CallVariableType, th32DataEntry, "UInt", &PE32 + DataOffset, "UInt", VariableCapacity)
          DllCall("CloseHandle", "UInt", hSnapshot)  ; http://msdn2.microsoft.com/ms724211.aspx
          Return th32DataEntry  ; Process data found
        }
        if not DllCall("Process32Next", "UInt", hSnapshot, "UInt", &PE32)  ; http://msdn2.microsoft.com/ms684836.aspx
          Break
      }
    DllCall("CloseHandle", "UInt", hSnapshot)
  }
  Return  ; Cannot find process
}

Process_GetModuleFileNameEx(ProcessID)  ; modified version of shimanov's function
{
  if A_OSVersion in WIN_95, WIN_98, WIN_ME
    Return Process_GetProcessName(ProcessID)
  
  ; #define PROCESS_VM_READ           (0x0010)
  ; #define PROCESS_QUERY_INFORMATION (0x0400)
  hProcess := DllCall( "OpenProcess", "UInt", 0x10|0x400, "Int", False, "UInt", ProcessID)
  if (ErrorLevel or hProcess = 0)
    Return
  FileNameSize := 260
  VarSetCapacity(ModuleFileName, FileNameSize, 0)
  CallResult := DllCall("Psapi.dll\GetModuleFileNameExA", "UInt", hProcess, "UInt", 0, "Str", ModuleFileName, "UInt", FileNameSize)
  DllCall("CloseHandle", hProcess)
  Return ModuleFileName
}

SaveScreenshotToFile(x, y, w, h, filePath)  {
   hBitmap := GetHBitmapFromScreen(x, y, w, h)
   gdip := new GDIplus
   pBitmap := gdip.BitmapFromHBitmap(hBitmap)
   DllCall("DeleteObject", Ptr, hBitmap)
   gdip.SaveBitmapToFile(pBitmap, filePath)
   gdip.DisposeImage(pBitmap)
}

GetHBitmapFromScreen(x, y, w, h)  {
   hDC := DllCall("GetDC", Ptr, 0, Ptr)
   hBM := DllCall("CreateCompatibleBitmap", Ptr, hDC, Int, w, Int, h, Ptr)
   pDC := DllCall("CreateCompatibleDC", Ptr, hDC, Ptr)
   oBM := DllCall("SelectObject", Ptr, pDC, Ptr, hBM, Ptr)
   DllCall("BitBlt", Ptr, pDC, Int, 0, Int, 0, Int, w, Int, h, Ptr, hDC, Int, x, Int, y, UInt, 0x00CC0020)
   DllCall("SelectObject", Ptr, pDC, Ptr, oBM)
   DllCall("DeleteDC", Ptr, pDC)
   DllCall("ReleaseDC", Ptr, 0, Ptr, hDC)
   Return hBM  ; should be deleted with DllCall("DeleteObject", Ptr, hBM)
}

class GDIplus   {
   __New()  {
      if !DllCall("GetModuleHandle", Str, "gdiplus", Ptr)
         DllCall("LoadLibrary", Str, "gdiplus")
      VarSetCapacity(si, A_PtrSize = 8 ? 24 : 16, 0), si := Chr(1)
      DllCall("gdiplus\GdiplusStartup", PtrP, pToken, Ptr, &si, Ptr, 0)
      this.token := pToken
   }
   
   __Delete()  {
      DllCall("gdiplus\GdiplusShutdown", Ptr, this.token)
      if hModule := DllCall("GetModuleHandle", Str, "gdiplus", Ptr)
         DllCall("FreeLibrary", Ptr, hModule)
   }
   
   BitmapFromHBitmap(hBitmap, Palette := 0)  {
      DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", Ptr, hBitmap, Ptr, Palette, PtrP, pBitmap)
      return pBitmap  ; should be deleted with this.DisposeImage(pBitmap)
   }
   
   SaveBitmapToFile(pBitmap, sOutput, Quality=75)  {
      SplitPath, sOutput,,, Extension
      if Extension not in BMP,DIB,RLE,JPG,JPEG,JPE,JFIF,GIF,TIF,TIFF,PNG
         return -1

      DllCall("gdiplus\GdipGetImageEncodersSize", UIntP, nCount, UIntP, nSize)
      VarSetCapacity(ci, nSize)
      DllCall("gdiplus\GdipGetImageEncoders", UInt, nCount, UInt, nSize, Ptr, &ci)
      if !(nCount && nSize)
         return -2
      
      Loop, % nCount  {
         sString := StrGet(NumGet(ci, (idx := (48+7*A_PtrSize)*(A_Index-1))+32+3*A_PtrSize), "UTF-16")
         if !InStr(sString, "*." Extension)
            continue
         
         pCodec := &ci+idx
         break
      }
      
      if !pCodec
         return -3

      if RegExMatch(Extension, "i)^J(PG|PEG|PE|FIF)$") && Quality != 75  {
         DllCall("gdiplus\GdipGetEncoderParameterListSize", Ptr, pBitmap, Ptr, pCodec, UintP, nSize)
         VarSetCapacity(EncoderParameters, nSize, 0)
         DllCall("gdiplus\GdipGetEncoderParameterList", Ptr, pBitmap, Ptr, pCodec, UInt, nSize, Ptr, &EncoderParameters)
         Loop, % NumGet(EncoderParameters, "UInt")  {
            elem := (24+A_PtrSize)*(A_Index-1) + 4 + (pad := A_PtrSize = 8 ? 4 : 0)
            if (NumGet(EncoderParameters, elem+16, "UInt") = 1) && (NumGet(EncoderParameters, elem+20, "UInt") = 6)  {
               p := elem+&EncoderParameters-pad-4
               NumPut(Quality, NumGet(NumPut(4, NumPut(1, p+0)+20, "UInt")), "UInt")
               break
            }
         }      
      }
      
      if A_IsUnicode
         pOutput := &sOutput
      else  {
         VarSetCapacity(wOutput, StrPut(sOutput, "UTF-16")*2, 0)
         StrPut(sOutput, &wOutput, "UTF-16")
         pOutput := &wOutput
      }
      E := DllCall("gdiplus\GdipSaveImageToFile", Ptr, pBitmap, Ptr, pOutput, Ptr, pCodec, UInt, p ? p : 0)
      return E ? -5 : 0
   }
   
   DisposeImage(pBitmap)  {
      return DllCall("gdiplus\GdipDisposeImage", Ptr, pBitmap)
   }
}

CreateFormData(ByRef retData, ByRef retHeader, objParam) {
	New CreateFormData(retData, retHeader, objParam)
}

Class CreateFormData {

	__New(ByRef retData, ByRef retHeader, objParam) {

		Local CRLF := "`r`n", i, k, v, str, pvData
		; Create a random Boundary
		Local Boundary := this.RandomBoundary()
		Local BoundaryLine := "------------------------------" . Boundary

    this.Len := 0 ; GMEM_ZEROINIT|GMEM_FIXED = 0x40
    this.Ptr := DllCall( "GlobalAlloc", "UInt",0x40, "UInt",1, "Ptr"  )          ; allocate global memory

		; Loop input paramters
		For k, v in objParam
		{
			If IsObject(v) {
				For i, FileName in v
				{
					str := BoundaryLine . CRLF
					     . "Content-Disposition: form-data; name=""" . k . """; filename=""" . FileName . """" . CRLF
					     . "Content-Type: " . this.MimeType(FileName) . CRLF . CRLF
          this.StrPutUTF8( str )
          this.LoadFromFile( Filename )
          this.StrPutUTF8( CRLF )
				}
			} Else {
				str := BoundaryLine . CRLF
				     . "Content-Disposition: form-data; name=""" . k """" . CRLF . CRLF
				     . v . CRLF
        this.StrPutUTF8( str )
			}
		}

		this.StrPutUTF8( BoundaryLine . "--" . CRLF )

    ; Create a bytearray and copy data in to it.
    retData := ComObjArray( 0x11, this.Len ) ; Create SAFEARRAY = VT_ARRAY|VT_UI1
    pvData  := NumGet( ComObjValue( retData ) + 8 + A_PtrSize )
    DllCall( "RtlMoveMemory", "Ptr",pvData, "Ptr",this.Ptr, "Ptr",this.Len )

    this.Ptr := DllCall( "GlobalFree", "Ptr",this.Ptr, "Ptr" )                   ; free global memory 

    retHeader := "multipart/form-data; boundary=----------------------------" . Boundary
	}

  StrPutUTF8( str ) {
    Local ReqSz := StrPut( str, "utf-8" ) - 1
    this.Len += ReqSz                                  ; GMEM_ZEROINIT|GMEM_MOVEABLE = 0x42
    this.Ptr := DllCall( "GlobalReAlloc", "Ptr",this.Ptr, "UInt",this.len + 1, "UInt", 0x42 )   
    StrPut( str, this.Ptr + this.len - ReqSz, ReqSz, "utf-8" )
  }
  
  LoadFromFile( Filename ) {
    Local objFile := FileOpen( FileName, "r" )
    this.Len += objFile.Length                     ; GMEM_ZEROINIT|GMEM_MOVEABLE = 0x42 
    this.Ptr := DllCall( "GlobalReAlloc", "Ptr",this.Ptr, "UInt",this.len, "UInt", 0x42 )
    objFile.RawRead( this.Ptr + this.Len - objFile.length, objFile.length )
    objFile.Close()       
  }

	RandomBoundary() {
		str := "0|1|2|3|4|5|6|7|8|9|a|b|c|d|e|f|g|h|i|j|k|l|m|n|o|p|q|r|s|t|u|v|w|x|y|z"
		Sort, str, D| Random
		str := StrReplace(str, "|")
		Return SubStr(str, 1, 12)
	}

	MimeType(FileName) {
		n := FileOpen(FileName, "r").ReadUInt()
		Return (n        = 0x474E5089) ? "image/png"
		     : (n        = 0x38464947) ? "image/gif"
		     : (n&0xFFFF = 0x4D42    ) ? "image/bmp"
		     : (n&0xFFFF = 0xD8FF    ) ? "image/jpeg"
		     : (n&0xFFFF = 0x4949    ) ? "image/tiff"
		     : (n&0xFFFF = 0x4D4D    ) ? "image/tiff"
		     : "application/octet-stream"
	}

}

GetFileSizeFromInternet(url, ProxyName = "", ProxyBypass = "")
{
   INTERNET_OPEN_TYPE_DIRECT = 1
   INTERNET_OPEN_TYPE_PROXY = 3
   AccessType := ProxyName ? INTERNET_OPEN_TYPE_DIRECT : INTERNET_OPEN_TYPE_PROXY
   INTERNET_FLAG_RELOAD = 0x80000000
   HTTP_QUERY_CONTENT_LENGTH = 5
   coding := A_IsUnicode ? "W" : "A"
 
   hModule := DllCall("LoadLibrary", Str, "wininet.dll")
   hInternet := DllCall("wininet\InternetOpen" . coding
                  , Str, ""   
                  , UInt, INTERNET_OPEN_TYPE_DIRECT
                  , Str, ""
                  , Str, ""
                  , UInt, 0)
   if !hInternet
   {
      Error := A_LastError
      DllCall("FreeLibrary", UInt, hModule)
      Return "<Ошибка " . Error ">"
   }
 
   hFile := DllCall("wininet\InternetOpenUrl" . coding
               , UInt, hInternet
               , Str, url
               , Str, ""
               , UInt, 0
               , UInt, INTERNET_FLAG_RELOAD
               , UInt, 0)
   if !hFile
   {
      Error := A_LastError
      DllCall("wininet\InternetCloseHandle", UInt, hInternet)
      DllCall("FreeLibrary", UInt, hModule)
      Return "<Ошибка " . Error ">"
   }
 
   VarSetCapacity(buff, 64)
   VarSetCapacity(bufflen, 2)
   Loop 4
   {
      success := DllCall("wininet\HttpQueryInfo" . coding
                  , UInt, hFile
                  , UInt, HTTP_QUERY_CONTENT_LENGTH
                  , UInt, &buff
                  , UInt, &bufflen
                  , UInt, 0)
      if success
         Break
   }
   Result := success ? StrGet(&buff) : "Невозможно извлечь информацию"
 
   DllCall("wininet\InternetCloseHandle", UInt, hInternet)
   DllCall("wininet\InternetCloseHandle", UInt, hFile)
   DllCall("FreeLibrary", UInt, hModule)
 
   Return Result
}

; Чтение параметров запуска
for n, param in A_Args  ; For each parameter:
{
	if (A_Index == 1) {
		if ((beta) && (param == "fromscite")) {
			continue
		}
		
		if (param == "install") {
			start_cmd := "консоль установить"
			continue
		}
		
		if (param == "uninstall") {
			start_cmd := "консоль удалить"
			continue
		}
		
		if (param == "from_updating") {
			if (beta) {
				MsgBox, 0, % title, % "Невозможно выполнить (программа в режиме бета-тестирования)!"
				return
			}
			
			FileCreateDir, % root
			FileCopy, % A_ScriptFullPath, %root%\rshell.exe, 1
			
			RegWrite, REG_SZ, HKCR, .rs,, renux-file
			RegWrite, REG_SZ, HKCR, renux-file,, Исполняемый файл Renux Shell
			RegWrite, REG_SZ, HKCR, renux-file\shell\Open\command,, %root%\rshell.exe "`%1"
			RegWrite, REG_SZ, HKCR, renux-file\DefaultIcon,, %root%\rshell.exe, 1
			
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayIcon, %root%\rshell.exe
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayName, Renux Shell
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayVersion, % version
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, NoModify, 1
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, Publisher, Streleckiy Development
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, UninstallString, "%root%\rshell.exe" "uninstall"
			RegWrite, REG_SZ, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, URLInfoAbout, http://vk.com/strdev
			
			FileCreateShortcut, %root%\rshell.exe, %A_Desktop%\Renux Shell.lnk,,, Запустить Renux Shell, %root%\rshell.exe
			FileCreateShortcut, %root%\rshell.exe, %A_Programs%\Renux Shell.lnk,,, Запустить Renux Shell, %root%\rshell.exe
			
			from_updating = 1
			continue
		}
		
		if (param == "updating") {
			sleep 2000
			FileMove, %root%\rshell.exe, %root%\old_rshell.exe, 1
			FileMove, %root%\new_rshell.exe, %root%\rshell.exe, 1
			try Run, %root%\rshell.exe from_updating
			catch e {
				FileDelete, %root%\rshell.exe
				FileMove, %root%\old_rshell.exe, %root%\rshell.exe, 1
				MsgBox, 16, % title, Не удалось запустить новую версию программы с приказом установки.`n`nRenux Shell откатил обновление`, следовательно`, у Вас будет установлена та же версия программы`, которая была до установки этой.`n`nПопробуйте повторить попытку обновления программы позже.
				Run, %root%\rshell.exe,, UseErrorLevel
			}
			
			FileDelete, %root%\old_rshell.exe
			exitapp
		}
		
		if (param == "start") {
			start_app = %2%
			if (trim(start_app) == "") {
				MsgBox, 16, % title, Вы не указали имя программы.
				exitapp
			}
			
			ifnotexist, %root%\products\%start_app%
			{
				MsgBox, 16, % title, Программа %start_app% не найдена.
				exitapp
			}
			
			Gui, launcher:-MinimizeBox +hwndlauncherwid +OwnDialogs
			Gui, launcher:Color, White
			Gui, launcher:Font, S12 CDefault bold, Segoe UI
			Gui, launcher:Add, Text, x12 y9 w360 h20 , % start_app
			Gui, launcher:Font, S9 CDefault norm, Segoe UI
			Gui, launcher:Add, Text, x12 y39 w360 h20 vText, Инициализация запуска...
			Gui, launcher:Add, Progress, x12 y69 w360 h20 vProgress, 0
			Gui, launcher:Show, w390 h102, % title " Launcher"
			
			GuiControl, launcher:, text, Проверка наличия новых обновлений...
			
			prod_files := server_api("products&name=" start_app)
			
			if prod_files not contains output
			{
				MsgBox, 1, % title, Не удалось получить информацию с сервера.`n`nНажмите OK`, чтобы продолжить запуск программы без проверки обновлений.
				IfMsgBox, Cancel
				{
					exitapp
				}
			}
			
			prod_count := JSON.GetKey(prod_files, "output.count")
			index := -1
			
			loop, % prod_count
			{
				index+=1
				file_is_dir 	:= JSON.GetKey(prod_files, "output.items[" index "].is_dir")
				
				if (file_is_dir == "false") {
					file_size 		:= JSON.GetKey(prod_files, "output.items[" index "].size")
					file_name		:= JSON.GetKey(prod_files, "output.items[" index "].name")
				}
				
				GuiControl, launcher:, text, % "Обновление " file_name " (" index+1 "/" prod_count ")"
				FileDelete, % root "\products\" start_app "\" file_name
				loop {
					URLDownloadToFile, % host "/products/" start_app "/" file_name, % root "\products\" start_app "\" file_name
					FileGetSize, pcsize, % root "\products\" start_app "\" file_name
					if (file_size == pcsize) {
						break
					}
					
					GuiControl, launcher:, text, % "Файл поврежден (" file_size "; " pcsize ")"
					sleep 1000
					GuiControl, launcher:, text, % "Обновление " file_name " (" index+1 "/" prod_count ") (Попытка #" A_Index ")"
				}
				GuiControl, launcher:, progress, % percent(index+1, prod_count)
			}
			
			GuiControl, launcher:, text, % "Приложение запускается..."
			
			process, exist
			WinGet, mainwid, ID, ahk_pid %ErrorLevel%
			
			try Run, %root%\products\%start_app%\app.exe "%mainwid%",,, PRODUCT_PID
			catch e {
				MsgBox, 16, % title, % "Не удалось запустить файл app.exe: " e.message
			}
			
			WinWait, ahk_pid %PRODUCT_PID%,, 5
			exitapp
		}
		
		ifexist, % param
		{
			shell_mode := 1
			shell_file := param
			continue
		}
	}
	
    result := ProcessArgument(param)
	
	if ((A_Index == 1) && (result == 0)) {
		cmd_start := param
	}
}

; Инициализация консоли...

if ((!hide_mode) && (!vkcmd_mode))
	console.init()

if ((!shell_mode) && (trim(cmd_start) == "")) {
	processCmd(start_cmd)
	console.writeln("")
}

if (from_updating == 1) {
	console.info("Программа успешно обновлена.`n")
	
	if note_for_update
		console.writeln(note_for_update "`n")
}

if (debug) {
	console.info("Режим отладки активирован.")
}

if (vkcmd_mode) {
	goto START_PROGRAM
}

RegRead, rversion, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayVersion 
if (ErrorLevel) {
	installed = 0
} else {
	installed = 1
}

if ((!shell_mode) && (trim(cmd_start) == "")) {
	if (warning_dir == 1) {
		console.info("Судя по всему Вы запустили Renux Shell впервые. Программа выделила себе папку по пути: " root ".`n")
	}
	
	if (string.left(A_OSVersion, 2) != "10") {
		console.writeln("Версия Вашего ядра Windows, не совпадает с Windows 10. Возможно, Вы изменили параметры совместимости программы.")
		console.writeln("Renux Shell используются некоторые компоненты системы, существующие и работающие только в Windows 10.`n")
	}
	
	ifexist, %root%\rshell.exe
	{
		if (!beta) {
			RegRead, rversion, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayVersion 
			if (trim(version) != trim(rversion)) {
				console.writeln("Обнаружено, что Вы используете другую версию программы.")
				console.writeln("Пожалуйста, установите ее, чтобы файлы с расширением *.rs открывались с новыми функциями, которые появились в этой версии.")
				console.writeln("Используйте 'консоль обновить' с правами администратора для установки этой версии в систему Windows.")
				console.writeln("")
			}
			else {
				if (!beta) {
					need_path = %root%\rshell.exe
					if (need_path != A_ScriptFullPath) {
						console.writeln("Пожалуйста, запускайте Renux Shell через ярлык на рабочем столе.")
						console.writeln("Нажмите на Y чтобы создать новый ярлык на рабочем столе; N - не создавать.")
						verdict := console.waitKeys("Y,N")
						if (verdict == "Y") {
							FileCreateShortcut, %root%\rshell.exe, %A_Desktop%\Renux Shell.lnk,,, Запустить Renux Shell, %root%\rshell.exe
							console.info("Ярлык успешно создан.")
						}
						
						SetWorkingDir, % root
						Run, %root%\rshell.exe,, UseErrorLevel
						if (!errorlevel) {
							exitapp
						}
						
						console.error("Пожалуйста, переустановите программу. Используйте команду 'консоль установить' с правами администратора.")
					}
				}
			}
		}
	}
}

if (trim(cmd_start) != "") {
	processCMD(cmd_start)
	if debug
	{
		console.writeln("[DEBUG] Выполнение команды завершено.")
		console.cmd("pause")
	}
	
	exitapp
}

; Проверка обновлений
check_updates:
if (!beta) {
	if ((!shell_mode)) {
		if debug
			console.writeln("[DEBUG] Проверка наличия новых обновлений...")
		
		server_response := server_api("version")
		
		if server_response contains output
		{
			server_version := JSON.GetKey(server_response, "output.version")
			server_file := JSON.GetKey(server_response, "output.file")
			
			if ((trim(server_version) == "") || (trim(server_file) == "")) {
				console.error("Не удалось определить новейшую версию/ссылку Renux Shell. Работа Renux Shell продолжается...")
				console.writeln("")
			}
			else {
				if (server_version != version) {
					if (installed) {
						console.writeln("Появилась новая версия Renux Shell (" server_version "). Текущая версия - " version ".")
						console.writeln("Renux Shell умеет автоматически обновляться. Обновиться? Y - да; N - нет.`n")
						if (console.waitKeys("Y,N") == "Y") {
							FileDelete, % root "\new_rshell.exe"
							if (console.download(host "/" server_file, root "\new_rshell.exe")) {
								console.progress("Процесс: обновление...")
								Run, %root%\new_rshell.exe updating
								exitapp
							}
						}
					} else {
						console.writeln("Появилась новая версия Renux Shell (" server_version "). Текущая версия - " version ".")
						console.writeln("Для установки новой версии в автоматическом режиме необходимо установить программу.")
						console.writeln("Renux может автоматически установиться и обновиться. Установить? [Y/N]`n")
						if (console.waitKeys("Y,N") == "Y") {
							Run, *RunAs %A_ScriptFullPath% install,, UseErrorLevel
							if (!ErrorLevel) {
								exitapp
							}
						}
					}
				}
			}
		} else {
			console.error("Не удалось проверить наличие новых обновлений. Работа Renux Shell продолжается...")
			console.writeln("")
		}
	}
}

START_PROGRAM:
Menu, Tray, NoStandard
Menu, Tray, Tip, Renux Shell v%version%

addons := []

loop, files, %root%\*.rsa
{
	IniRead, команда, % A_LoopFileFullPath, addon, команда, % ""
	IniRead, описание, % A_LoopFileFullPath, addon, описание, % ""
	IniRead, синтаксис, % A_LoopFileFullPath, addon, синтаксис, % ""
	IniRead, пример, % A_LoopFileFullPath, addon, пример, % ""
	IniRead, количество_параметров, % A_LoopFileFullPath, addon, количество_параметров, % ""
	IniRead, массив_для_вывода, % A_LoopFileFullPath, addon, массив_для_вывода, % ""
	IniRead, имя_пакета, % A_LoopFileFullPath, addon, имя_пакета, % ""
	
	addons[trim(string.up(команда))] := [описание, синтаксис, пример, количество_параметров, массив_для_вывода, имя_пакета]
	console.writeln("[DEBUG] Загружен аддон: " A_LoopFileName "!")
}

; Встроенные переменные
console.setVar(".экран.ширина", A_ScreenWidth, 0)
console.setVar(".экран.высота", A_ScreenHeight, 0)
console.setVar(".консоль.версия", version, 0)
console.setVar(".консоль.админ", A_IsAdmin, 0)
console.setVar(".консоль.папка", root, 0)
console.setVar(".консоль.путь", A_ScriptFullPath, 0)
console.setVar(".консоль.имя", A_ScriptName, 0)
console.setVar(".консоль.путь.папка", A_ScriptDir, 0)
console.setVar(".система.аппдата", A_AppData, 0)
console.setVar(".система.оаппдата", A_AppDataCommon, 0)
console.setVar(".система.рстол", A_Desktop, 0)
console.setVar(".система.орстол", A_DesktopCommon, 0)
console.setVar(".система.64бит", A_Is64bitOS, 0)
console.setVar(".система.документы", A_MyDocuments, 0)
console.setVar(".система.прогфайлы", A_ProgramFiles, 0)
console.setVar(".система.менюпуск", A_Programs, 0)
console.setVar(".система.оменюпуск", A_ProgramsCommon, 0)
console.setVar(".система.стартменю", A_StartMenu, 0)
console.setVar(".система.остартменю", A_StartMenuCommon, 0)
console.setVar(".система.автозапуск", A_Startup, 0)
console.setVar(".система.оавтозапуск", A_StartupCommon, 0)
console.setVar(".система.тип", A_OSType, 0)
console.setVar(".система.версия", A_OSVersion, 0)
console.setVar(".система.пользовать", A_UserName, 0)
console.setVar(".система.компьютер", A_ComputerName, 0)

loop, HKLM, SYSTEM\CurrentControlSet\Control\Session Manager\Environment, 1, 1
{
	RegRead, value, HKLM, %A_LoopRegSubkey%, %A_LoopRegName%
	console.setVar(".окр." string.down(A_LoopRegName), value, 0)
}

loop, HKLM, SYSTEM\ControlSet001\Control\Session Manager\Environment, 1, 1
{
	RegRead, value, HKLM, %A_LoopRegSubkey%, %A_LoopRegName%
	console.setVar(".окр." string.down(A_LoopRegName), value, 0)
}

loop, HKCU, Environment, 1, 1
{
	RegRead, value, HKCU, %A_LoopRegSubKey%, %A_LoopRegName%
	console.setVar(".окр." string.down(A_LoopRegName), value, 0)
}

EnvGet, ENV_PATH, PATH

CurrentProcessPath := GetModuleFileNameEx(Process_GetCurrentProcessID())

started = 1

;if (vkcmd_mode)
;	goto vkcmd_mode

main:
;try settimer, main, off

if (!hide_mode) {
	IfWinNotExist, ahk_id %mainwid%
	{
		DllCall("FreeConsole")
		console.init()
		console.writeln("Соединение с окном консоли было потеряно. Была создана новая консоль (текущая).`n")
		goto main
	}
}

if (hide_mode)
	exitapp

if server_id == 1
	return

if (!shell_mode) {
	if (console_output_to != "")
		allow_console_writing = 1
	
	console.write("RS " A_WorkingDir "> ")
	command := console.read()
	
	if (console_output_to != "")
		allow_console_writing = 0
	
	if (trim(command) == "") {
		if (!GetKeyState("Enter", "D"))
			console.writeln("")
		
		goto main
	}
	
	res := processCmd(command)
	
	if (res == "server") {
		settimer, waitcloseconnection, 1
		server_id = 1
		return
	}
	
	console.writeln("")
	goto main
}

if debug
	console.writeln("[DEBUG] Анализ пакетного файла и запись в память...")

shell_lines := 0, crypt_test := ""
crypt_script := "", p_crypt_script := ""
displayed := "", command := "", shell_mline := 0
cmd_source := "", cmd_source := []

command := "", displayed := 0
FileRead, crypt_script, % shell_file

func_write := 0, func_name := ""
loop, parse, crypt_script, `r`n
{
	if (trim(A_LoopField) == "") {
		continue
	}
	
	if (trim(string.left(A_LoopField, 2)) == "//") {
		continue
	}
	
	if (trim(string.up(A_LoopField) == "#СКАЧИВАТЬ_БЕЗ_СПРОСА")) {
		perm_download_msg = 1
		continue
	}
	
	if (func_write == 1) {
		if (string.up(trim(A_LoopField)) == "КОНЕЦ") {
			if debug
				console.writeln("[DEBUG] Функция " func_name " зарегистрирована в памяти процесса.")
			
			func_write := 0, func_name := ""
			continue
		}
		
		banned_words := "метка,функция,гк,перейти"
		loop, parse, A_LoopField, % " "
		{
			cmdsi2_first := A_LoopField
			break
		}
		
		loop, parse, banned_words, % ","
		{
			if (string.up(A_LoopField) == string.up(cmdsi2_first)) {
				console.warning("Команда '" cmdsi2 "' не может быть выполнена (нельзя создавать метки, горячие клавиши, функции и переход к ним в функции).")
				console.cmd("pause")
				exitapp
			}
		}
		
		try cmd_functions[func_name] := cmd_functions[func_name] "`n" A_LoopField
		continue
	}
	
	loop, parse, A_LoopField, % " "
	{
		first_line := A_LoopField
		break
	}
	
	if (string.up(trim(first_line)) == "ФУНКЦИЯ") {
		RegExMatch(A_LoopField, "i)функция (.*)\:", cmdout)
		if (trim(cmdout1) != "") {
			func_write := 1, func_name := cmdout1
			
			if debug
				console.writeln("[DEBUG] Обнаружена функция " cmdout1 ".")
			
			continue
		}
	}
	
	shell_lines+=1
	cmd_source[shell_lines] := A_LoopField
}

for cmdsi1, cmdsi2 in cmd_source
{
	RegExMatch(cmdsi2, "i)метка (.*)\:", cmdout)
	if (trim(cmdout1) != "") {
		if (string.checkNorm(cmdout1) == 0) {
			console.warning("Метка с таким именем не может быть создана (#НПП).") ; НПП - не прошел проверку
			continue
		}
		
		try cmd_labels[trim(cmdout1)] := cmdsi1
		catch e {
			console.warning("Метка с таким именем не может быть создана (#" cmdsi1 ").")
			continue
		}
		
		if debug
			console.writeln("[DEBUG] Метка " cmdout1 "#" cmdsi1 " зарегистрирована в памяти процесса.")
		
		continue
	}
	
	RegExMatch(cmdsi2, "i)гк (.*)\:", cmdout)
	if (trim(cmdout1) != "") {
		cmd_hotkeys[trim(cmdout1)] := cmdsi1
		cmd_hks := cmd_hks "`n" trim(cmdout1)
		
		if debug
			console.writeln("[DEBUG] Горячая клавиша " cmdout1 "#" cmdsi1 " зарегистрирована в памяти процесса.")
		
		continue
	}
}

if (debug)
{
	console.writeln("[DEBUG] Обработано " shell_lines " строк кода.")
	prev_code := ""
	
	for key, value in cmd_source
		prev_code := prev_code key ": " value "`n"
	
	MsgBox, 0, % title, Оптимизированный код:`n`n%prev_code%
	
	for key, val in cmd_functions
		MsgBox, 0, % title, Оптимизированный код функции %key%:`n%val%
}

if (shell_mode) {
	SplitPath, shell_file, shell_prev, shell_dir
	shell_prev = title %shell_prev%
	SetWorkingDir, % shell_dir
	console.cmd(shell_prev)
}

shell_mode:
shell_mline+=1

if (shell_mline > shell_lines) {
	if (cmd_hks) {
		loop {
			loop, parse, cmd_hks, `n
			{
				cmd_hk_line := trim(A_LoopField), cmd_hk_points := 0
				loop, parse, A_LoopField, `,
				{
					cmd_hk_points_all := A_Index
					
					if (GetKeyState(A_LoopField, "P")) {
						cmd_hk_points+=1
						continue
					}
					
					sleep 1
				}
				
				if (cmd_hk_points == cmd_hk_points_all) {
					shell_mline := cmd_hotkeys[cmd_hk_line]
					
					if debug
						console.writeln("[DEBUG] Активирована горячая клавиша '" cmd_hk_line "'! Переход на строку #" shell_mline " успешен.")
					
					break
				}
			}
			
			if (shell_mline <= shell_lines) {
				break
			}
		}
	}
	else {	
		if debug
		{
			console.writeln("[DEBUG] Сценарий завершен.")
			console.cmd("pause")
		}
		
		if !shell_from
			exitapp
		else {
			shell_mode := 0, shell_file := "", shell_from := 0
			console.writeln("")
			console.cmd("title " title)
			goto main
		}
	}
}

cmd_text := cmd_source[shell_mline]
if (perm_download_msg) {
	perm_download_msg = 0
	console.question("Renux спрашивает разрешение на скачивание файлов без спроса. [Y/N]")
	pressed := console.waitKeys("Y,N")
	if (pressed == "Y") {
		perm_download := 1
	}
	else {
		if !shell_from
			exitapp
		else {
			shell_mode := 0, shell_file := "", shell_from := 0
			console.writeln("")
			console.cmd("title " title)
			goto main
		}
	}
}

processCmd(cmd_text)

goto shell_mode
return

TempGuiClose:
return

waitcloseconnection:
if connection_closed
{
	try DllCall("Ws2_32\WSACleanup")
	server_id := 1, connection_closed := 0
	settimer, waitcloseconnection, off
	goto main
}

IfWinActive, ahk_id %mainwid%
{
	if (GetKeyState("Escape", "P")) {
		connectionClosed()
		server_id := 1, connection_closed := 0
		settimer, waitcloseconnection, off
		goto main
	}
}
return

DbgGuiSize:
GuiControl, dbg:move, DbgCtrl, % "w" A_GuiWidth+2 " h" A_GuiHeight+2
return

DbgGuiClose:
return

debug_pause_menu:
if (!debug_pause_menu) {
	Menu, DMenu1, Check, Пауза перед командой
	debug_pause_menu = 1
} else {
	Menu, DMenu1, UnCheck, Пауза перед командой
	debug_pause_menu = 0
}
return

debug_gotoLine:
GuiControl, dbg:hide, dbgctrl

Gui, dbg2:Destroy
Gui, dbg2:-MinimizeBox +Parentdbg +AlwaysOnTop +hwnddbg2wid
Gui, dbg2:Font, CDefault S8, Segoe UI
Gui, dbg2:Add, Text,, Укажите номер строки в поле ниже.
Gui, dbg2:Add, Edit, number vGotoLine w100, 0
Gui, dbg2:Add, Button, gDebug_Goto_Line, Перейти
Gui, dbg2:Show, Center, Переход к строке

ControlFocus, Edit1, ahk_id %dbg2wid%
return

Debug_Goto_Line:
Gui, dbg2:Submit, NoHide
shell_mline := gotoline-1
LV_Add("", gotoLine, cmd_source[shell_mline], "Переход на строку №" gotoline " успешен.")
Gui, dbg2:Destroy
GuiControl, dbg:show, dbgctrl
return

executeCommand:
GuiControl, dbg:hide, dbgctrl

Gui, dbg2:Destroy
Gui, dbg2:-MinimizeBox +Parentdbg +AlwaysOnTop +hwnddbg2wid
Gui, dbg2:Font, CDefault S8, Segoe UI
Gui, dbg2:Add, Text,, Укажите команду для выполнения.
Gui, dbg2:Add, Edit, vCmd w100,
Gui, dbg2:Add, Button, gExecuteWritedCommand, Выполнить
Gui, dbg2:Show, Center, Переход к строке

ControlFocus, Edit1, ahk_id %dbg2wid%
return

ExecuteWritedCommand:
gui, submit, nohide
processCMD(cmd)
Gui, dbg2:Destroy
GuiControl, dbg:show, dbgctrl
return

dbg2GuiClose:
Gui, dbg2:Destroy
GuiControl, dbg:show, dbgctrl
return

LauncherGuiClose:
exitapp

GuiEscape:
Gui, 1:Destroy
return

TVClick:
if (A_GuiEvent != "DoubleClick")
	return

TV_CLICKED := TV_GetSelection()

open_docs:
Gui, 1:+OwnDialogs
KeyWait, Enter, U

if (TV_CLICKED == TV_START_INTRO) {
	MsgBox, 0, % "Начало работы > Введение", 
	(
Renux Shell - это свободная утилита под Windows с закрытым исходным кодом.
Вы сможете автоматизировать почти все процессы лишь нажатием клавиши или кликом мыши.
Начать возможно, будет даже легче, чем вы думаете. Прочитайте раздел "Краткое обучение".
	)
}

if (TV_CLICKED == TV_START_SHORT_TUTORIAL) {
	MsgBox, 1, % "Начало работы > Краткий туториал > Установка Renux Shell",
	(
Оказавшись в этом разделе, вероятно, вы собираетесь начать осваивать язык автоматизации Renux Shell.

Установка Renux Shell:
Для установки программы на компьютер, запустите программу от имени администратора и введите команду "консоль установить". Также, стоит учесть, что без этой установки некоторые команды могут не работать (вас об этом оповестит программа). Для редактирования скриптов можно использовать любой текстовый редактор, включая "Блокнот".
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Начало работы > Краткий туториал > Создание первого скрипта",
	(
После того, как среда Renux Shell установлена, можно приступать к созданию первого скрипта. Скрипты являются обычными текстовыми файлами, имеющими расширение .rs. Запускаются как любое приложение, двойным кликом мыши. Чтобы отредактировать скрипт, нажмите на нем ПКМ > Открыть с помощью > Блокнот (или другой текстовый редактор). Перед запуском скрипта необходимо поменять кодировку файла (скрипта) на ANSI. В блокноте это можно сделать нажав на пункт в меню "Файл" -> "Сохранить как". Рядом с кнопкой "Сохранить" есть выбор кодировки. Нужно установить на ANSI. Создайте скрипт со следующим кодом и запустите его. Если вы увидели в консоли приветствие - все установлено правильно и можно продолжать.
  
  вывод привет
  кмд pause
  
В момент запуска скрипта, команды начинают выполняться по очереди сверху вниз. Выполнение новой команды не будет начато до тех пор, пока не окончена предыдущая. Также, Вы можете выполнить сразу несколько команд написав их в одной строке. Помечайте границы новой команды знаком ";". Для его экранирования используйте "``;".

  вывод первая команда;вывод вторая команда;вывод третья команда
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Начало работы > Краткий туториал > Комментарии в коде и отладка",
	(
Когда нужно оставить в коде строчку с пояснением - на помощь приходит комментарий, по умолчанию он определяется двумя слэшами.
Стоит учесть, что для комментирования строк, слэши ставятся только в начале их строк. Пример кода:

  вывод Это сообщение выводится.
  // это комментарий, Renux Shell пропускает эту строку
  вывод // это сообщение все равно выводится в консоль, так как слэши должны стоять в начале строки.
  // вывод Это сообщение не выводится, так как Renux Shell считает, что это комментарий по двум слэшам в начале команды.

Для отладки кода (проверки условий, просмотра значений переменных и т.д.) проще всего использовать команду "вывод". Также в Renux Shell имеется встроенный режим отладки, активируется командой "адз /debug".
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Начало работы > Краткий туториал > Горячие клавиши",
	(
С помощью Renux Shell Вы можете создавать свои макросы. Перед двоеточием указывается "гк ", затем клавиша или сочетание клавиш через запятую, вызывающие действие

  гк Alt,1:
  вывод Вы нажали на Alt,1
  ждать.время 5000
  конец
  
После действий горячей клавиши нужно указать слово "конец", чтобы программа не продолжала выполнять сценарий дальше.
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Начало работы > Краткий туториал > Эмуляция нажатий",
	(
Для эмуляции нажатий и ввода текста используется команда "напечатать".
Она имеет несколько вариаций: напечатать, напечататьб. Подробно про их отличия можно прочитать в справке по этим командам.

  // Ввод строки по нажатию 1
  гк 1:
  напечатать Здравствуйте, чем могу вам помочь?{Enter}Текст с новой строки
  конец
  
  // Ввод строки уже по нажатию 2
  гк 2:
  напечатать Благодарим за визит!
  конец
  
  // Выполнит комбинацию Ctrl+Shift+Esc, запустив диспетчер задач
  гк 3:
  напечатать {LCtrl down}{Shift down}{Esc}{LCtrl up}{Shift up}
  конец
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Начало работы > Краткий туториал > Переменные",
	(
Для хранения и обработки информации служат переменные. Во вступительном гайде мы рассмотрим лишь два вида: числовой и текстовый. Переменные в Renux Shell динамически изменяют свой тип в зависимости от последнего присвоенного значения. Имя переменной не должно превышать 254 знаков, может состоять из букв, цифр и знаков # _ @ $ ? [ ]. Вопреки традициям других языков, в ренуксе имена переменных могут начинаться с цифр и даже содержать кириллицу. Логический (булевый) тип предназначен для хранения 1 или 0 (true или false).

Числовой тип, как не сложно догадаться, применяется для операций с числами. Поддерживается большинство арифметических операций, а так же десятичные дроби.

  пер число = 0
  // Здесь мы при нажатии 1 добавляем 10 к значению переменной
  гк 1:
  вывод число содержал значение `%число`%
  пер число += 10
  конец

Строковый тип хранит отдельные символы или фрагменты текста. Работа со строками немного отличается от цифровых и булевых переменных- для них есть целый ряд специальных строковых функций.

  пер абв = привет
  пер абв += , мыр!
  вывод `%абв`%
  пер абв заменить 'мыр' 'мир' '0'
  вывод `%абв`%
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Начало работы > Краткий туториал > Логические операции",
	(
Наверняка вы уже задумались, как выполнять действие только при соблюдении конкретного условия? На помощь приходит логический оператор "если". Так же существуют и другие команды, представляющие собой условие.
Пожалуй, самым простым применением условия является назначение двух чередующихся действий на одну и ту же горячую клавишу. В этом примере введена переменная, которая принимает противоположное значение при каждом новом вызове ГК.

  пер а = 0
  гк Alt,1:
  если '`%а`%' == '0' то вывод переменная а равна нулю;пер а = 1;конец
  если '`%a`%' == '1' то вывод переменная а равна 1; пер а = 0;конец
  конец

Еще одним примером может служить определение времени суток:

  гк Alt,1:
  если '`%.время.час`%' < '6' то вывод Сейчас ночь;конец
  если '`%.время.час`%' < '10' то вывод Сейчас утро;конец
  если '`%.время.час`%' < '17' то вывод Сейчас день;конец
  вывод Сейчас вечер;конец
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Начало работы > Краткий туториал > Циклы",
	(
Для повторения определенного участка кода несколько раз используются циклы. Циклы можно реализовать: либо через метки и переходы к ним, либо через команду "ПОКА", либо через команду "ЦИКЛ", либо через команду "ДЛЯ".

  // Пять повторений одного участка кода с помощью меток и переходов
  пер а = 0
  метка метка_для_повтора:
  пер а += 1
  если 'a' > '5' то конец
  вывод `%а`%
  перейти метка_для_повтора
  
  // Отсчет до 1000 и обратно до нуля.
  пока '`%а`%' < '1000' сделать пер а += 1```;вывод `%а`%
  пока '`%а`%' > '0' сделать пер а -= 1```;вывод `%а`%
  
  // Пять выводов одного и того же сообщения.
  цикл 5: вывод Это сообщение отображается 5 раз.
  
  // Выводит свойства системного файла svchost.exe
  файл.получить 'информация' 'C:\Windows\System32\svchost.exe'
  вывод;для тип значение в информация сделать вывод `%тип`%: `%значение`%
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Начало работы > Краткий туториал > Запуск программ, открытие ссылок",
	(
Для запуска EXE приложений, открытия окон проводника или браузера есть множество способов.

1. Используется вызов командной строки из Renux.

  // Запуск программы
  кмд start notepad.exe
  
  // Открытие ссылки.
  кмд http://vk.com/strdev

2. Используется имя файла и параметры как в командной строке. В этом случае ожидается закрытие процесса, который создал RS.
  
  // Запуск программы
  notepad.exe
  
  // Открытие ссылки
  http://vk.com/strdev
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Начало работы > Краткий туториал > Команды и функции",
	(
В Renux Shell есть две основных структуры: команды и функции. Обе предназначены для выполнения какого-либо действия, но отличаются способом записи. В данной программе функция используется как метка, но для ее вызова не используется команда "перейти", а нужно просто указать ее имя на строке. Стоит учесть, что функция не исполняется, пока ее не вызвать в коде. Пример:

  // объявляем функцию
  функция плюс_один:
  пер а += 1
  конец
  пер а = 0
  
  // бесконечный цикл
  метка цикл:
  плюс_один
  вывод %а%
  перейти цикл
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 0, % "Начало работы > Краткий туториал > Заключение", 
	(
В этом разделе приведены самые базовые возможности программы. Полный список функций можно найти на Главной странице справочника.

Рекомендуем последовательно пройти по описанию всех команд для примерного понимания их назначения перед тем, как начинать писать свой первый скрипт :)

Перед тем, как приступить к написанию кода, необходимо составить алгоритм. Распишите по шагам, что должна делать ваша программа. Так будет гораздо проще искать команды, необходимые для выполнения каждого из шагов.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_DD) {
	MsgBox, 0, % "Встроенные переменные > .время.день",
	(
Применение: `%.время.день`%
Описание: Текущий день месяца (2 цифры) от 01 до 31.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_MM) {
	MsgBox, 0, % "Встроенные переменные > .время.месяц",
	(
Применение: `%.время.месяц`%
Описание: Текущий месяц (2 цифры) от 01 до 12.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_YYYY) {
	MsgBox, 0, % "Встроенные переменные > .время.год",
	(
Применение: `%.время.год`%
Описание: Текущий год (4 цифры). Например: 2004.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_HOUR) {
	MsgBox, 0, % "Встроенные переменные > .время.час",
	(
Применение: `%.время.час`%
Описание: Текущий час (2 цифры) от 00 до 23. Например: 17 - это 5 часов вечера.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_MIN) {
	MsgBox, 0, % "Встроенные переменные > .время.минута",
	(
Применение: `%.время.минута`%
Описание: Текущая минута (2 цифры) от 00 до 59.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_SEC) {
	MsgBox, 0, % "Встроенные переменные > .время.секунда",
	(
Применение: `%.время.секунда`%
Описание: Текущая секунда (2 цифры) от 00 до 59.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_TICKCOUNT) {
	MsgBox, 0, % "Встроенные переменные > .время.счетчик",
	(
Применение: `%.время.счетчик`%
Описание: Количество миллисекунд, прошедшее со времени перезагрузки компьютера. Сохранив значение .время.счетчик в переменной, можно позднее измерить общее время работы. Для этого необходимо вычесть значение этой переменной из последнего значения .время.счетчик. Например:

  пер время = `%.время.счетчик`%
  ждать.время 1000
  пер прошло_времени = `%.время.счетчик`%
  пер прошло_времени -= `%время`%
  вывод прошло `%.прошло_времени`% миллисекунд.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_MMM) {
	MsgBox, 0, % "Встроенные переменные > .время.месяцк",
	(
Применение: `%.время.месяцк`%
Описание: Аббревиатура текущего месяца на языке пользователя. Например: Июл.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_MMMM) {
	MsgBox, 0, % "Встроенные переменные > .время.месяцс",
	(
Применение: `%.время.месяцс`%
Описание: Полное название текущего месяца на языке пользователя. Например: Июль.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_DDD) {
	MsgBox, 0, % "Встроенные переменные > .время.неделяк",
	(
Применение: `%.время.неделяк`%
Описание: Аббревиатура из трех букв текущего дня недели на языке пользователя. Например: Вск.
	)
	return
}

if (TV_CLICKED == TV_VAR_TIME_DDDD) {
	MsgBox, 0, % "Встроенные переменные > .время.неделяк",
	(
Применение: `%.время.неделяс`%
Описание: Полное название текущего дня недели на языке пользователя. Например: Воскресенье.
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_VERSION) {
	MsgBox, 0, % "Встроенные переменные > .консоль.версия",
	(
Применение: `%.консоль.версия`%
Описание: Переменная содержит номер той версии Renux Shell, которая исполняет команды (например: 2.6). 
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_ADMIN) {
	MsgBox, 0, % "Встроенные переменные > .консоль.админ",
	(
Применение: `%.консоль.админ`%
Описание: Если у текущего пользователя есть права администратора, переменная содержит значение 1. Иначе - 0.
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_RESULT) {
	MsgBox, 0, % "Встроенные переменные > .консоль.результат",
	(
Применение: `%.консоль.результат`%
Описание: Это встроенная переменная, призванная отображать успешность или неуспешность выполнения каких-либо команд (однако, не все команды поддерживают работу с .консоль.результат). Значение .консоль.результат, равное единице, обычно свидетельствует об удачном завершении процесса. В .консоль.результат помещается ответ внутренней функции Renux, которая отвечает за выполнение предыдущей указанной Вами команды.
Примечание: учитывая то, что некоторые команды выдают значение .консоль.результат большее, чем 1, наилучшим способом будет: проверка имеет ли переменная .консоль.результат значение, отличное от единицы.
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_FOLDER) {
	MsgBox, 0, % "Встроенные переменные > .консоль.папка",
	(
Применение: `%.консоль.папка`%
Описание: Выводит путь к папке, которую выделил Renux Shell для хранения конфига и установки.
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_WORKDIR) {
	MsgBox, 0, % "Встроенные переменные > .консоль.рпапка",
	(
Применение: `%.консоль.рпапка`%
Описание: Текущий рабочий каталог консоли, в котором файлы доступны по умолчанию. Конечный обратный слеш нужен только в случае, если это корневой каталог. Два примера: C:\ и C:\Мои документы. Чтобы изменить рабочий каталог, используйте команду "СД".
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_PATH) {
	MsgBox, 0, % "Встроенные переменные > .консоль.путь",
	(
Применение: `%.консоль.путь`%
Описание: Комбинация двух переменных, приведенных выше. Определяет полную спецификацию файла консоли, например: C:\My Documents\renux.exe.
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_PATH_DIR) {
	MsgBox, 0, % "Встроенные переменные > .консоль.путь.папка",
	(
Применение: `%.консоль.путь.папка`%
Описание: Полный путь к каталогу, где находится консоль.
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_SCRIPT) {
	MsgBox, 0, % "Встроенные переменные > .консоль.скрипт",
	(
Применение: `%.консоль.скрипт`%
Описание: Полный путь к исполняемому пакетному файлу.
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_FOLDER) {
	MsgBox, 0, % "Встроенные переменные > .консоль.путь",
	(
Применение: `%.консоль.путь`%
Описание: Выводит путь к исполняемому файлу Renux Shell (путь к самому себе).
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_NAME) {
	MsgBox, 0, % "Встроенные переменные > .консоль.имя",
	(
Применение: `%.консоль.имя`%
Описание: Выводит имя исполняемого файла Renux Shell (свое имя файла с расширением).
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_ENV) {
	MsgBox, 0, % "Встроенные переменные > .окр.*",
	(
Синтаксис: `%.окр.<имя переменной окружения>`%
Описание: Выводит содержание определенной переменной окружения.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_APPDATA) {
	MsgBox, 0, % "Встроенные переменные > .система.аппдата",
	(
Синтаксис: `%.система.аппдата`%
Описание: Полный путь и имя папки, содержащей данные приложения текущего пользователя.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_CAPPDATA) {
	MsgBox, 0, % "Встроенные переменные > .система.оаппдата",
	(
Синтаксис: `%.система.оаппдата`%
Описание: Полный путь и имя папки, содержащей данные для всех пользователей приложения.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_DESKTOP) {
	MsgBox, 0, % "Встроенные переменные > .система.рстол",
	(
Синтаксис: `%.система.рстол`%
Описание: Полный путь и имя папки, содержащей файлы рабочего стола текущего пользователя.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_CDESKTOP) {
	MsgBox, 0, % "Встроенные переменные > .система.орстол",
	(
Синтаксис: `%.система.орстол`%
Описание: Полный путь и имя папки, содержащей файлы рабочего стола всех пользователей.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_64BITOS) {
	MsgBox, 0, % "Встроенные переменные > .система.64бит",
	(
Синтаксис: `%.система.64бит`%
Описание: Содержит 1 (истина), если ОС 64-разрядная, или 0 (ложь), если она 32-разрядная.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_DOCUMENTS) {
	MsgBox, 0, % "Встроенные переменные > .система.документы",
	(
Синтаксис: `%.система.документы`%
Описание: Полный путь и имя папки "Мои документы" текущего пользователя.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_PROGFILES) {
	MsgBox, 0, % "Встроенные переменные > .система.прогфайлы",
	(
Синтаксис: `%.система.прогфайлы`%
Описание: Каталог Program Files (например, C:\Program Files или C:\Program Files (x86)).
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_PROGRAMS) {
	MsgBox, 0, % "Встроенные переменные > .система.менюпуск",
	(
Синтаксис: `%.система.менюпуск`%
Описание: Полный путь и имя папки "Программы" в меню "Пуск" текущего пользователя.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_CPROGRAMS) {
	MsgBox, 0, % "Встроенные переменные > .система.оменюпуск",
	(
Синтаксис: `%.система.оменюпуск`%
Описание: Полный путь и имя папки "Программы" в меню "Пуск" для всех пользователей.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_STARTMENU) {
	MsgBox, 0, % "Встроенные переменные > .система.стартменю",
	(
Синтаксис: `%.система.стартменю`%
Описание: Полный путь и имя папки меню "Пуск" текущего пользователя.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_CSTARTMEN) {
	MsgBox, 0, % "Встроенные переменные > .система.остартменю",
	(
Синтаксис: `%.система.остартменю`%
Описание: Полный путь и имя папки меню «Пуск» для всех пользователей.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_STARTUP) {
	MsgBox, 0, % "Встроенные переменные > .система.автозапуск",
	(
Синтаксис: `%.система.автозапуск`%
Описание: Полный путь и имя папки «Автозагрузка» в меню «Пуск» текущего пользователя.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_CSTARTUP) {
	MsgBox, 0, % "Встроенные переменные > .система.оавтозапуск",
	(
Синтаксис: `%.система.оавтозапуск`%
Описание: Полный путь и имя папки «Автозагрузка» в меню «Пуск» для всех пользователей.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_OSTYPE) {
	MsgBox, 0, % "Встроенные переменные > .система.тип",
	(
Применение: `%.система.тип`%
Описание: Тип запущенной операционной системы. Или WIN32_WINDOWS (т.е. Win95/98/ME), или WIN32_NT (т.е. WinNT, Win2k, WinXP и, возможно, более поздние).
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_VERSION) {
	MsgBox, 0, % "Встроенные переменные > .система.версия",
	(
Применение: `%.система.версия`%
Описание: Одна из следующих строк: WIN_2003, WIN_XP, WIN_2000, WIN_NT4, WIN_95, WIN_98, WIN_ME.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_USERNAME) {
	MsgBox, 0, % "Встроенные переменные > .система.пользователь",
	(
Применение: `%.система.пользователь`%
Описание: Имя текущего пользователя, под которым он вошел в систему.
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_COMPUTER) {
	MsgBox, 0, % "Встроенные переменные > .система.компьютер",
	(
Применение: `%.система.компьютер`%
Описание: Сетевое имя компьютера. 
	)
	return
}

if (TV_CLICKED == TV_VAR_SYSTEM_CLIPBOARD) {
	MsgBox, 0, % "Встроенные переменные > .система.клипборд",
	(
Применение: `%.система.клипборд`%
Описание: Содержимое буфера обмена операционной системы, доступное для чтения и записи. 
	)
	return
}

if (TV_CLICKED == TV_VAR_SCREEN_WIDTH) {
	MsgBox, 0, % "Встроенные переменые > .экран.ширина",
	(
Применение: `%.экран.ширина`%
Описание: Ширина основного монитора в пикселях (например, 1024).
	)
	return
}

if (TV_CLICKED == TV_VAR_SCREEN_HEIGHT) {
	MsgBox, 0, % "Встроенные переменые > .экран.высота",
	(
Применение: `%.экран.высота`%
Описание: Высота основного монитора в пикселях (например, 768).
	)
	return
}

if (TV_CLICKED == TV_MAIN_HOTKEYS) {
	MsgBox, 1, % "Основное > Горячие клавиши",
	(
Предупреждение: работает только в режиме исполнения пакетного файла.

Горячие клавиши иногда называют "быстрыми клавишами" из-за их способности без труда активировать операции (например, запускать программу или клавиатурную макрокоманду). В примере, приведенном ниже, горячая клавиша Alt+N настроена на то, чтобы запускать Блокнот (Notepad):

  гк Alt,N:
  кмд start notepad
  конец

В последней строке команда "конец" служит для того, чтобы завершить работу горячей клавиши. Вы можете использовать много (до бесконечности) клавиш для активации макрокоманд. Их перечисляют через запятую. В примере ниже при нажатии Ctrl+Alt+T будет напечатано сообщение "Hello World":

  гк Ctrl,Alt,T:
  // На следующей строке эмуляция нажатия клавиш относится к активному окну
  напечатать Hello World
  конец
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 0, % "Основное > Горячие клавиши",
	(
Метки горячих клавиш можно использовать как обычные метки: вы можете использовать команду "перейти" и задать несколько меток горячих клавиш, чтобы выполнить одну и ту же процедуру. Например:

  гк Alt,1:
  гк Alt,2:
  вывод Вы нажали Alt+1 или Alt+2.
  конец

Вы можете привязать ко клавише любые доступные команды Renux Shell. Например, при нажатии на правый Ctrl активное окно откроется во весь экран:

  гк RCtrl:
  окно.развернуть A
  конец
	)
	return
}

if (TV_CLICKED == TV_MAIN_MACROCOMMANDS) {
	MsgBox, 0, % "Основное > Создание макрокоманды клавиатуры и мыши",
	(
Макрокоманда - это последовательность скриптовых действий, которая "воспроизводится" по требованию. Самым общим видом деятельности макрокоманды является эмуляция нажатий клавиш и кликов мышью в одно или несколько окон. Такие окна реагируют на каждое нажатие клавиши и клик мыши так, как будто это действие выполнено вручную, что позволяет автоматизировать повторяющиеся задачи с высокой скоростью и надежностью.
Для того, чтобы сейчас же начать создание своих собственных макрокоманд и горячих клавиш, обратитесь к разделу в справке "Начало работы > Краткое обучение".
	)
	return
}

if (TV_CLICKED == TV_MAIN_KEYLIST) {
	MsgBox, 1, % "Основное > Список клавиш и кнопок мыши",
	(
Мышь:
> LButton - левая кнопка мыши
> RButton - правая кнопка мыши
> MButton - средняя кнопка мыши (или колесо)
> WheelDown - поворот колеса мыши "вниз"
> WheelUp - поворот колеса мыши "вверх"
> XButton1 - четвертая кнопка мыши, боковая
> XButton2 - пятая кнопка мыши, боковая

Клавиатура:
(( Примечание: названия буквенных и цифровых клавиш точно такие же, как и сами символы этих клавиш. То есть, клавиша "b" записывается как b, а клавиша "5" как 5. ))
> Space - пробел
> Tab
> Enter (или Return)
> Escape (или Esc)
> Backspace (или BS)
> Delete (или Del)
> Insert (или Ins)
> Home
> End
> PgUp
> PgDn
> Up
> Down
> Left
> Right
> ScrollLock
> CapsLock
> NumLock
> NumpadDiv - слэш "/"
> NumpadMult - звездочка "*"
> NumpadAdd - плюс "+"
> NumpadSub - минус "-"
> NumpadEnter - клавиша "Numpad-Enter"
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Основное > Список клавиш и кнопок мыши",
	(
Следующие названия клавиш используются, когда Numlock выключен:
> NumpadDel
> NumpadIns
> NumpadClear - та же кнопка, что и Numpad5 на клавиатуре
> NumpadUp
> NumpadDown
> NumpadLeft
> NumpadRight
> NumpadHome
> NumpadEnd
> NumpadPgUp
> NumpadPgDn

Эти названия клавиш используются при включенном Numlock'e:
> Numpad0
> Numpad1
> Numpad2
> Numpad3
> Numpad4
> Numpad5
> Numpad6
> Numpad7
> Numpad8
> Numpad9
> NumpadDot - "Numpad-точка"
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "Основное > Список клавиш и кнопок мыши",
	(
С F1 по F24 - двенадцать или более функциональных клавиш, на большинстве клавиатур представлены в самом верхнем ряду.

> AppsKey - клавиша, вызывающая контекстное меню файла/программы, как при правом клике мышкой.
> LWin - левая клавиша "Windows"
> RWin - правая клавиша "Windows"
> Control (или Ctrl)
> Alt
> Shift
> LControl (или LCtrl) - левый "Сontrol"
> RControl (или RCtrl) - правый "Сontrol"
> LShift
> RShift
> LAlt - левый "Alt"
> RAlt - правый "Alt". Примечание: если на вашей клавиатуре вместо клавиши RAlt сделана клавиша AltGr, вы можете использовать следующую запись данной клавиши: <^>! Также заметим, что клавишу AltGr можно записать как сочетание клавиш "LControl & RAlt::".
> PrintScreen
> CtrlBreak
> Pause
> Break
> Help - довольно редкая клавиша, присутствует далеко не на всех клавиатурах. И работает совсем не как F1.
> Sleep - предупреждаем, что клавиша "Sleep" на некоторых клавиатурах не работает под этой записью.
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 0, % "Основное > Список клавиш и кнопок мыши",
	(
Клавиши расширенных функций Мультимедийных и Интернет-клавиатур:
> Browser_Back
> Browser_Forward
> Browser_Refresh
> Browser_Stop
> Browser_Search
> Browser_Favorites
> Browser_Home
> Volume_Mute
> Volume_Down
> Volume_Up
> Media_Next
> Media_Prev
> Media_Stop
> Media_Play_Pause
> Launch_Mail
> Launch_Media
> Launch_App1
> Launch_App2

Запись вида SCnnn, где nnn - это сканкод клавиши, позволяет нам работать с остальными клавишами, не упоминавшимися выше.
Возможна запись VKnn, где nn является шестнадцатиричным виртуальным кодом клавиши.
	)
	return
}

if (TV_CLICKED == TV_MAIN_SCRIPTS) {
	MsgBox, 1, % "Основное > Пакетные файлы",
	(
Каждый пакетный файл представляет собой простой текстовый файл, содержащий команды, которые затем будет исполнять программа (rshell.exe). Пакетный файл также может содержать горячие клавиши, и даже полностью состоять из них. Однако, в отсутствие горячих клавиш, после запуска скрипта его команды исполняются последовательно друг за другом сверху донизу. При запуске пакетные файлы оптимизируются, но не проверяются. При создании нового пакетного файла (создание текстового файла), нужно установить кодировку ANSI, иначе пакетный файл может не запуститься на вашем/другом компьютере.

Секция автовыполнения:
Программа, строка за строкой, загружает скрипт в память (каждая строка может содержать до 16 383 символов). После загрузки программа исполняет скрипт до тех пор, пока не дойдет до команд конец, выход, метки горячей клавиши, или конца скрипта (в зависимости от того, что стоит первым). Эта верхняя часть скрипта называется секцией авто-выполнения.
Не завершающий работу автоматически и не содержащий горячие клавиши скрипт заканчивает свою работу после окончания секции авто-выполнения. Иначе, он будет работать в состоянии ожидания, реагируя на такие события, как запуск горячих клавиш и т.п.

Escape-последовательности:
В Renux Shell escape-символом по умолчанию является знак акцента (``), находящийся в верхнем левом углу большинства английских клавиатур. Использование этого символа вместо обратного слеша устраняет необходимость в двойном обратном слеше в пути и имени файла.
Также с помощью escape-последовательности задаются специальные символы. Чаще всего это ``t (табуляция), ``n (перевод строки) и ``r (возврат каретки).
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 0, % "Основное > Пакетные файлы",
	(
Комментарии:
В скрипте можно добавлять комментарии в начале строки после двух слэшей. Например:

  // Вся эта строка является комментарием.

Мобильность rshell.exe:
Все, что необходимо для запуска любого .rs-скрипта - это файл rshell.exe.
	)
	return
}

if (TV_CLICKED == TV_MAIN_VARIABLES) {
	MsgBox, 1, % "Основное > Переменные",
	(
Введение в переменные:
Переменными являются участки памяти, где хранятся значения. Значение (или строка, как его иногда называют) может представлять собой любую последовательность символов или цифр. Хотя между текстом и числами не делается никаких различий (и то и другое хранится в виде строк), в некоторых контекстах трактовка строки, полностью состоящей из чисел, отличается от трактовки других строк. Например, если в выражении InputString > BookmarkString обе переменные будут иметь числовые значения, они будут сравниваться как числа. Иначе, сравнение будет производиться в соответствии с алфавитным порядком.
В примере, приведенном ниже, показано, как присвоить переменной значение:

  пер моя_переменная = 123абв

Чтобы позднее извлечь содержимое этой переменной, сошлитесь на нее, поместив ее имя между знаками процента:
  
  вывод Значение переменной моя_переменная - `%моя_переменная`%

Однако параметры некоторых команд явно определены как входные или выходные переменные. В этих случаях нет необходимости помещать переменную между знаками процента.
	)
	IfMsgBox, cancel
		return
	
	MsgBox, 1, % "Основное > Переменные",
	(
Замечания по поводу возможностей переменных и использования памяти:
> Каждая переменная может содержать до 256 MB текста.
> Когда переменной присваивается строка длиннее, чем ее текущее содержимое, дополнительная системная память выделяется автоматически.
> Память, занятую большой переменной, можно освободить, присвоив переменной пустое значение, например: пер моя_переменная =
> Команды, функции и выражения, принимающие числовые входные данные, обычно поддерживают степень точности 15 цифр после запятой (для значений с плавающей запятой). Для целых чисел поддерживаются 64-разрядные значения со знаком в пределах от -9223372036854775808 (-0x8000000000000000) до 9223372036854775807 (0x7FFFFFFFFFFFFFFF). Любая целочисленная константа, не входящая в этот диапазон, будет установлена на ближайшее целое число, принадлежащее диапазону. В отличие от этого, при арифметических операциях с целыми числами, при переполнении число циклически обращается (например, 0x7FFFFFFFFFFFFFFF + 1 = -0x8000000000000000).
	)
	IfMsgBox, cancel
		return
	
	MsgBox, 0, % "Основное > Переменные",
	(
Встроенные переменные:
Также в скриптах можно использовать встроенные переменные. Большинство из них является "зарезервированными" (reserved), что означает, что скрипт не может непосредственно изменять их содержимое. Подробнее о них можете увидеть в разделе справки "Встроенные переменные".
	)
}

if (TV_CLICKED == TV_CMDS_CONSOLE_ADZ) {
	MsgBox, 0, % "АДЗ",
	(
Синтаксис: АДЗ <параметр>

> Так как программа (Renux Shell) принимает аргументы (параметры) при старте программы, то команда АДЗ (аббр. "Аргумент До Запуска") позволяет вводить их после запуска программы.
Пример того, как Вы можете запустить режим отладки в программе, указав параметр запуска:

  1. Откройте командную строку в папке программы.
  2. Укажите команду: rshell.exe /debug
  3. Нажмите клавишу Enter.

Чтобы не открывать командную строку и т.п., Вы можете указать параметр запуска после команды "АДЗ".
Тот же режим отладки можно вызвать, указав команду в Renux'e:
  адз /debug

> Список параметров запуска:
  /hide - выполняться полностью в фоновом режиме. Работает только в режиме исполнения пакетного файла.
  /ignore_errors - игнорировать ошибки (работает только для режима исполнения файла).
  /ignore_warnings - игнорировать предупреждения (работает только для режима исполнения файла).
  /output_mode:<msg/print> - изменить режим вывода сообщений об ошибках/предупреждениях/информации (msg - в диалоговое окно, print - в консоль).
  /debug - режим отладки, показывает дополнительную информацию.
  /log - записывать в файл лог содержимое консоли.
  /new - открыть RS в новом окне.
  /ns - не замораживать дочерний процесс при подключении RS к консоли процесса.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1".

> Пример:
  адз /debug
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_ADMIN) {
	MsgBox, 0, % "АДМИН",
	(
Синтаксис: админ

Перезапускает Renux Shell от имени администратора.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  админ
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_INPUT) {
	MsgBox, 0, % "ВВОД",
	(
Синтаксис: ввод <имя переменной>

Ожидает ввод данных пользователя и записывает введенные данные в переменную.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  ввод а
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_OUTPUT) {
	MsgBox, 0, % "ВЫВОД",
	(
Синтаксис: вывод <текст>

Выводит указанный текст в консоль (с новой строки).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Переменная изменяет свое значение на ответ внутренней функции Renux Shell, отвечающей за вывод текста (обычно кол-во символов для вывода + 2).

> Пример:
  вывод Привет, Мир!
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_TITLE) {
	MsgBox, 0, % "ЗАГОЛОВОК",
	(
Синтаксис: заголовок <текст>

Изменяет заголовок главного окна Renux Shell.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  заголовок Новый заголовок
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_INFO) {
	MsgBox, 0, % "ИНФОРМАЦИЯ или ИНФО",
	(
1-й синтаксис: информация
2-й синтаксис: инфо

Выводит информацию о Renux Shell.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Переменная изменяет свое значение на "1" (единицу) в любом случае.

> Пример:
  информация
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_CONSOLE) {
	MsgBox, 0, % "КОНСОЛЬ",
	(
Синтаксис: консоль <команда>

Установщик Renux Shell, позволяющий установить/удалить Renux Shell.

Команда требует повышения прав.

> Список параметров запуска:
  установить - установит Renux Shell на Ваш ПК.
  удалить - удалит Renux Shell с Вашего ПК.
  обновить - автоматическое применение текущей версии Renux Shell.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Примеры:
  консоль установить
  консоль удалить
  консоль обновить
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_DOCS) {
	MsgBox, 0, % "СПРАВКА или ?",
	(
1-й синтаксис: справка [имя команды]
2-й синтаксис: ? [имя команды]

Если параметр опускается, то открывает руководство по работе с программой Renux Shell в виде окна с графическим пользовательским интерфейсом.
Если параметр указан, то производит поиск справки по указанной команде.
Если в параметре указано "." (точка), то открывает справку асинхронно.

> Примечание:
  Для сокращения команды, Вы можете использовать вместо слова "СПРАВКА" - знак "?".
  Также Вы можете указать в конце команды вопросительный знак, чтобы открыть справку про нее.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Примеры:
  справка
  ?
  справка адз
  ? адз
  адз?
  мышь.передвинуть?
  вывод?
	)
	return
}

if (TV_CLICKED == TV_CMDS_CNSTCT_END) {
	MsgBox, 0, % "КОНЕЦ",
	(
Синтаксис: конец

Останавливает исполнение макрокоманды.

Работает только в режиме исполнения пакетного файла.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  гк Alt,1:
  вывод нажата горячая клавиша Alt+1
  конец
  вывод Эта строка не выводится.
	)
	return
}

if (TV_CLICKED == TV_CMDS_CNSTCT_LABEL) {
	MsgBox, 0, % "МЕТКА",
	(
Синтаксис: метка <имя>:

Символьное имя, на которое обычно должен осуществляться переход.

Работает только в режиме исполнения пакетного файла.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  // Для отсчета кол-ва раз активации
  пер а = 1
  
  // Объявление метки под именем "лучшая_метка_в_мире".
  метка лучшая_метка_в_мире:
  
  // Выводим текст о том, что активировалась метка
  вывод Активация метки под именем "лучшая_метка_в_мире" (№`%а`%)
  
  // Добавляем переменной "а" единицу.
  пер а += 1
  
  // Выполняем переход к метке "лучшая_метка_в_мире"
  перейти лучшая_метка_в_мире
	)
	return
}

if (TV_CLICKED == TV_CMDS_CNSTCT_GOTO) {
	MsgBox, 0, % "ПЕРЕЙТИ",
	(
Синтаксис: перейти <имя метки>

Безусловный переход к определенной точке сценария, обозначенной меткой.

Работает только в режиме исполнения пакетного файла.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  // Для отсчета кол-ва раз активации
  пер а = 1
  
  // Объявление метки под именем "лучшая_метка_в_мире".
  метка лучшая_метка_в_мире:
  
  // Выводим текст о том, что активировалась метка
  вывод Активация метки под именем "лучшая_метка_в_мире" (№`%а`%)
  
  // Добавляем переменной "а" единицу.
  пер а += 1
  
  // Выполняем переход к метке "лучшая_метка_в_мире"
  перейти лучшая_метка_в_мире
	)
}

if (TV_CLICKED == TV_CMDS_CNSTCT_FUNC) {
	MsgBox, 0, % "ФУНКЦИЯ",
	(
Синтаксис: функция <имя>:

Исполняет макрокоманду, указанную после имени функции и продолжает выполнение, пока не сталкивается с "КОНЕЦ".

Работает только в режиме исполнения пакетного файла.

> Примечание: функция выполняется только тогда, когда ее вызывают по имени.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  // Объявление функции под именем "плюс_один", которая будет добавлять к переменной "а" единицу.
  функция плюс_один:
  пер а+=1
  конец
  
  метка цикл:
  // Вызваем функцию "плюс_один" просто указав ее имя.
  плюс_один
  перейти цикл
	)
}

if (TV_CLICKED == TV_CMDS_KEYBOARD_HKEYS) {
	MsgBox, 0, % "ГК",
	(
Синтаксис: гк <клавиши>:

С помощью Renux Shell Вы можете создавать свои макросы. Перед двоеточием указывается "гк ", затем клавиша или сочетание клавиш через запятую, вызывающие действие. После действий горячей клавиши нужно указать слово "конец", чтобы программа не продолжала выполнять сценарий дальше.

Работает только в режиме исполнения пакетного файла.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Команда не изменяет значение переменной.
  
> Пример:
  гк Alt,1:
  вывод Вы нажали на Alt,1
  ждать.время 5000
  конец
	)
}

if (TV_CLICKED == TV_CMDS_KEYBOARD_WRITE) {
	MsgBox, 0, % "НАПЕЧАТАТЬ",
	(
Синтаксис: напечатать <текст>

Посылает нажатия клавиш и щелчки мыши в активное окно.

Подробнее в справке: Начало работы > Краткий туториал > Эмуляция нажатий

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  напечатать Привет, Мир!
	)
}

if (TV_CLICKED == TV_CMDS_KEYBOARD_WRITEF) {
	MsgBox, 0, % "НАПЕЧАТАТЬБ",
	(
Синтаксис: напечататьб <текст>

Максимально быстро посылает нажатия клавиш и щелчки мыши в активное окно.

Подробнее в справке: Начало работы > Краткий туториал > Эмуляция нажатий

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  напечататьб Привет, Мир!
	)
}

if (TV_CLICKED == TV_CMDS_MOUSE_MOVE) {
	MsgBox, 0, % "МЫШЬ.ПЕРЕДВИНУТЬ",
	(
Синтаксис: мышь.передвинуть '<x>' '<y>' '<s>'

Двигает курсор мыши.

Максимальная скорость (третий аргумент): 100

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  мышь.передвинуть '100' '100' '1'
	)
}

if (TV_CLICKED == TV_CMDS_LINES_JSON) {
	MsgBox, 0, % "ДЖСОН",
	(
Синтаксис: джсон '<переменная, в которую будет записан результат>' '<название переменной с JSON строкой>' '<путь к элементу>'

Извлекает строку из строки JSON формата.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  джсон 'результат' 'переменная1' 'response.items.0.id'
	)
}

if (TV_CLICKED == TV_CMDS_LINES_ARR_UNIT) {
	MsgBox, 0, % "ДЖСОН",
	(
Синтаксис: массив.объединить '<имя переменной, куда запишется результат>' '<имя массива>' '<объединяющий символ>'

Объединяет массив с индексами в одну строку.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
	Из примера предусматривается, что в массиве "массив" содержатся следующие элементы:
	массив[0] == тест
	массив[1] == иров
	массив[2] == ание

	В результате примера переменная "результат" будет равна значению "тестирование".
	)
}

if (TV_CLICKED == TV_CMDS_LINES_VAR) {
	MsgBox, 1, % "ПЕР",
	(
Синтаксис: пер <имя переменной> <операция> <новое значение>

> Форматы:
  Стандарт: пер <имя> = <значение>
  Сложить: пер <имя> += <значение>
  Вычесть: пер <имя> -= <значение>
  Умножить: пер <имя> *= <значение>
  Разделить: пер <имя> /= <значение>
  Округлить: пер <имя> округлить <кол-во символов после запятой>
  Показать список переменных: пер список
  Математическое выражение: пер <имя> мат <выражение>
  Заменить: пер <имя> заменить '<строка поиска>' '<строка замены>' '<заменить все?(флаг 1-да/0-нет)>'
  Разделить строку: пер <имя> разделить '<имя массива>' '<разделительный символ>'
  Срез: пер <имя> срез <индекс символа (начиная с 1)>
  Обрезать слева: пер <имя> слева <кол-во символов>
  Обрезать справа: пер <имя> справа <кол-во символов>
  Получить кол-во символов: пер <имя> длина
  Преобразует в верхний регистр: пер <имя> вверх
  Преобразует в нижний регистр: пер <имя> вниз
  Разделяет имя файла или URL на составные части: пер <имя> путь '<имя массива>'

Вы можете "складывать" строки. Нужно чтобы значение переменной не было числом (сделает слияние строк).
Вы можете "вычитать" строки. Нужно чтобы значение переменной не было числом (заменяет вхождения из второго параметра на пустоту).
Вы можете "умножать" строки. Нужно чтобы значение переменной не было числом (сделает слияние строк столько раз, сколько Вам будет нужно).
Вы можете "разделить" строки. Нужно чтобы значение переменной не было числом (запишет в значение переменной количество найденных входений в значении переменной).
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 0, % "ПЕР",
	(
> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
  
> Примеры:
  Стандарт: пер переменнаяс = значение переменной с
  Сложить: пер переменная2 += 10
  Вычесть: пер переменная3 -= 20
  Умножить: пер переменная4 *= 3
  Разделить: пер переменная5 /= 2
  Округлить: пер переменная6 округлить 0	(округляет полностью)
  Показать список переменных: пер список
  Математическое выражение: пер переменная7 мат 50+50/2*3
  Заменить: пер переменная8 заменить 'привет' 'пока' '1'
  Разделить строку: пер переменная8 разделить 'массив' ' '
  Срез: пер переменная8 срез 4
  Обрезать слева: пер переменная слева 5
  Обрезать справа: пер переменная справа 5
  Получить кол-во символов: пер переменная длина
  Преобразует в верхний регистр: пер переменная вверх
  Преобразует в нижний регистр: пер переменная вниз
  Разделяет имя файла или URL на составные части: пер путь_до_файла путь 'части'
	)
	return
}

if (TV_CLICKED == TV_CMDS_LINES_UNUNIT) {
	MsgBox, 0, % "СТРОКА.РАЗДЕЛИТЬ",
	(
Синтаксис: строка.разделить '<имя массива, куда запишутся части>' '<строка (текст)>' '<символ>'

Разделяет строку на подстроки (массив).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  строка.разделить 'часть' 'Renux|лучшая|консоль' '|'
	)
	return
}

if (TV_CLICKED == TV_CMDS_LINES_REPLACE) {
	MsgBox, 0, % "СТРОКА.ЗАМЕНИТЬ",
	(
Синтаксис: строка.заменить '<имя переменной, куда запишется результат>' '<строка (текст)> '<символы, которые нужно заменить>' '<символы, которыми нужно заменить>' '<заменить все? (0-нет/1-да)>'

Заменяет вхождения строки поиска на строку замены.

> Пример 1:
  строка.заменить 'результат' 'красный, зеленый, синий, красный' 'красный' 'фиолетовый' '0'
  // В этом примере заменится только одно слово с начала строки ("красный" на "фиолетовый").

> Пример 2:
  строка.заменить 'результат' 'красный, зеленый, синий, красный' 'красный' 'фиолетовый' '1'
  // В этом примере заменятся все слова "красный" на "фиолетовый".
	)
	return
}

if (TV_CLICKED == TV_CMDS_PROCESSES_EXIT) {
	MsgBox, 0, % "ВЫХОД",
	(
Синтаксис: выход [код]

Закрытие процесса Renux Shell (с кодом выхода).

> Примечание:
  Если параметр [код] опущен, то закрывается с нулевым кодом выхода.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу)
	)
	return
}

if (TV_CLICKED == TV_CMDS_PROCESSES_SHUTD) {
	MsgBox, 0, % "СЕССИЯ",
	(
Синтаксис: сессия <код>

Завершит работу/выйдет из системы и т.п.

Флаги (код):
0 = выход из системы
1 = завершение работы
2 = перезапуск
3 = принудительно
4 = выключить
5 = синий экран смерти
6 = отменить запланированное завершение работы

> Примечание:
  Значение «принудительно» (3) принудительно закрывает все открытые приложения. Его следует использовать только в экстренных случаях, поскольку это может привести к потере данных любыми открытыми приложениями.
  Значение «выключить» (4) выключает систему и отключает питание.
  Значение «синий экран смерти (5)» вызывает синий экран смерти, методом завершения системного процесса. Это может привести к потери данных любыми открытыми приложениями.

> Сессия:
  выход 1
	)
	return
}

if (TV_CLICKED == TV_CMDS_PROCESSES_WTIME) {
	MsgBox, 0, % "ЖДАТЬ.ВРЕМЯ",
	(
Синтаксис: ждать.время <время ожидания в миллисекундах>

Ждёт заданное количество времени, прежде чем продолжить.

Время ожидания в миллисекундах в диапазоне от 0 до 2147483647 (24 дня).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  // Ждет 3 секунды
  ждать.время 3000
	)
	return
}

if (TV_CLICKED == TV_CMDS_PROCESSES_WPRES) {
	MsgBox, 0, "ЖДАТЬ.НАЖАТИЕ",
	(
Синтаксис: ждать.нажатие '<имя переменной>' '<клавиша/клавиши>'

Ждет нажатие заданных какой либо из клавиш/клавиши, прежде чем продолжить.

После нажатия одной из клавиш, в переменную, указанную в первом аргументе будет записано имя клавиши, которая была нажата.

> Примечание:
  Если Вам нужно указать сразу несколько клавиш, то перечисляйте их через запятую. Без пробелов.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример 1 (ожидается нажатие на Y):
  ждать.нажатие 'переменная1' 'Y'

> Пример 2 (ожидается нажатие на Y или N):
  ждать.нажатие 'переменная2' 'Y,N'
	)
	return
}

if (TV_CLICKED == TV_CMDS_PROCESSES_CMD) {
	MsgBox, 0, % "КМД",
	(
Синтаксис: кмд <команда>

Выполнит команду в командной строке.

> Если в режиме перенаправления вывода (команда ЗВЫВОД):
  Создает процесс командной строки, в котором вписывает команду. Дожидается выполнения команды, копирует лог и закрывает процесс. После этого записывает весь лог в вывод.

> Если не в режиме перенаправаления вывода (по-умолчанию):
  Открывает командную строку с приказом выполнить команду.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  кмд dir
	)
	return
}

if (TV_CLICKED == TV_CMDS_PROCESSES_PROC) {
	MsgBox, 0, % "ПРОЦЕСС",
	(
Синтаксис: процесс '<операция>' '<имя процесса/PID>'

> Возможные операции:
  существует - помещает в переменную .консоль.результат идентификатор процесса (PID), если соответствующий процесс существует, иначе 0. Если второй параметр пустой, определяется PID самого скрипта.

  завершить - завершает процесс(-ы). Если процесс(-ы) завершен(-ы) успешно, в .консоль.результат помещается кол-во завершенных процессов. Так как процесс будет завершён внезапно - возможно, с прерыванием его работы в критической точке или с потерей несохранённых данных - этот метод должен использоваться, только если процесс не может быть закрыт путём применения ОКНО.ЗАКРЫТЬ к одному из его окон.
  ждать - ожидает существования указанного процесса. При обнаружении подходящего процесса в .консоль.результат помещается его идентификатор (PID).
  ждать.закрытие - ждёт, пока не будут закрыты ВСЕ отвечающие второму параметру процессы. Если все совпадающие процессы завершаются, .консоль.результат устанавливается в 0.
  заморозить - заморозит процесс по идентификатору процесса (PID) или его имени.
  разморозить - разморозит процесс по идентификатору процесса (PID) или его имени.
  список - отображает список активных процессов на момент исполнения команды. Второй параметр игнорируется.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу) (искл. операция "существует").

> Пример:
  процесс 'существует' 'explorer.exe'
	)
	return
}

if (TV_CLICKED == TV_CMDS_PROCESSES_PSH) {
	MsgBox, 0, % "ПШ",
	(
Синтаксис: пш <команда>

Выполнит команду в PowerShell.

> Если в режиме перенаправления вывода (команда ЗВЫВОД):
  Создает процесс командной строки, в котором вписывает команду. Дожидается выполнения команды, копирует лог и закрывает процесс. После этого записывает весь лог в вывод.

> Если не в режиме перенаправаления вывода (по-умолчанию):
  Открывает командную строку с приказом выполнить команду.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  пш dir
	)
	return
}

if (TV_CLICKED == TV_CMDS_PROCESSES_RSTRT) {
	MsgBox, 0, % "РЕСТАРТ",
	(
Синтаксис: рестарт

Перезапустит Renux Shell.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_ELEM_ELEM) {
	MsgBox, 0, % "ОКНО.ЭЛЕМЕНТ",
	(
Синтаксис: окно.элемент

Получить информацию о элементе окна.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Переменная изменяет свое значение на "1" (единицу) в любом случае.
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_ELEM_MOVE) {
	MsgBox, 0, % "ОКНО.ЭЛЕМЕНТ.ПЕРЕДВИНУТЬ",
	(
Синтаксис: окно.элемент.передвинуть '<имя элемента>' '<заголовок окна/его часть>' '<x>' '<y>' '<w>' '<h>'

Изменит положение элемента окна с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окно.элемент.передвинуть 'Static1' 'Блокнот: сведения' '100' '100' '100' '100'
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_ELEM_VALUE) {
	MsgBox, 0, % "ОКНО.ЭЛЕМЕНТ.ЗНАЧЕНИЕ",
	(
Синтаксис: окно.элемент.значение '<имя элемента>' '<заголовок окна/его часть>' '<новое значение>'

Изменит значение элемента окна с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
  
> Пример:
  окно.элемент.значение 'Static1' 'Блокнот: сведения' 'RENUX ДЕМОНСТРАЦИЯ'
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_ELEM_WRITE) {
	MsgBox, 0, % "ОКНО.ЭЛЕМЕНТ.НАПЕЧАТАТЬ",
	(
Синтаксис: окно.элемент.напечатать '[имя элемента]' '<заголовок окна/его часть>' '<текст>'

Имитирует нажатия клавиш в окно или его элемент.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример 1:
  окно.элемент.напечатать '' 'Документ - WordPad' 'Тестовое сообщение'

> Пример 2:
  окно.элемент.напечатать 'Edit1' 'Безымянный – Блокнот' 'Тестовое сообщение'
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_WAIT) {
	MsgBox, 0, % "ЖДАТЬ.ОКНО",
	(
Синтаксис: ждать.окно <заголовок/его часть>

Ожидает создание окна с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  ждать.окно Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_WAIT_ACTI) {
	MsgBox, 0, % "ЖДАТЬ.ОКНО.АКТИВИРОВАТЬ",
	(
Синтаксис: ждать.окно.активировать <заголовок/его часть>

Ожидает активацию окна с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  ждать.окно.активировать Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_WAIT_DEACTI) {
	MsgBox, 0, % "ЖДАТЬ.ОКНО.ДЕАКТИВИРОВАТЬ",
	(
Синтаксис: ждать.окно.деактивировать <заголовок/его часть>

Ожидает деактивацию окна с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  ждать.окно.деактивировать Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_WAIT_CLOSE) {
	MsgBox, 0, % "ЖДАТЬ.ОКНО.ЗАКРЫТИЕ",
	(
Синтаксис: ждать.окно.закрытие <заголовок/его часть>

Ожидает закрытию окна с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  ждать.окно.закрытие Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_ACTIVATE) {
	MsgBox, 0, % "ОКНО.АКТИВИРОВАТЬ",
	(
Синтаксис: окно.активировать <заголовок/его часть>

Активирует окно с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окно.активировать Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_RESTORE) {
	MsgBox, 0, % "ОКНО.ВЕРНУТЬ",
	(
Синтаксис: окно.вернуть <заголовок/его часть>

Восстанавливает прежние размеры свёрнутого или развёрнутого окна.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окно.вернуть Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_TITLE) {
	MsgBox, 0, % "ОКНО.ЗАГОЛОВОК",
	(
Синтаксис: окно.заголовок '<заголовок>' '<новый заголовок>'

Изменяет заголовок окна на указанный Вами.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окно.заголовок 'Безымянный - Paint' 'Просто Paint'
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_CLOSE) {
	MsgBox, 0, % "ОКНО.ЗАКРЫТЬ",
	(
Синтаксис: окно.закрыть <заголовок/его часть>

Закроет окно с указанным Вами заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окно.закрыть Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_SHOW) {
	MsgBox, 0, % "ОКНО.ПОКАЗАТЬ",
	(
Синтаксис: окно.показать <заголовок/его часть>

Покажет скрытое окно с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окно.показать Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_MAXIMIZE) {
	MsgBox, 0, % "ОКНО.РАЗВЕРНУТЬ",
	(
Синтаксис: окно.развернуть <заголовок/его часть>

Развернет окно с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окно.развернуть Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_MINIMIZE) {
	MsgBox, 0, % "ОКНО.СВЕРНУТЬ",
	(
Синтаксис: окно.свернуть <заголовок/его часть>

Свернет окно с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окно.свернуть Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_WIN_HIDE) {
	MsgBox, 0, % "ОКНО.СПРЯТАТЬ",
	(
Синтаксис: окно.спрятать <заголовок/его часть>

Скроет окно с указанным заголовком.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окно.спрятать Безымянный - Paint
	)
	return
}

if (TV_CLICKED == TV_CMDS_DIR_DOWNLOAD) {
	MsgBox, 0, % "#СКАЧИВАТЬ_БЕЗ_СПРОСА",
	(
Синтаксис: #СКАЧИВАТЬ_БЕЗ_СПРОСА

Получить разрешение от пользователя для скачивания файлов из интернета без спроса (команда "скачать" всегда отображает сколько весит файл и скачать ли его, с этим разрешением Renux Shell сможет скачивать файлы в фоновом режиме).

Работает только в режиме исполнения пакетного файла.
	)
	return
}

if (TV_CLICKED == TV_CMDS_VOICESP_VOLUME) {
	MsgBox, 0, % "ГОЛОС.ГРОМКОСТЬ",
	(
Синтаксис: голос.громкость <громкость (целое число в диапазоне от 0 до 100)>

Установит параметр громкости для преобразования текста в речь (Text-To-Speech).

По-умолчанию громкость 100.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  голос.громкость 100
	)
	return
}

if (TV_CLICKED == TV_CMDS_VOICESP_SAY) {
	MsgBox, 0, % "ГОЛОС.СКАЗАТЬ",
	(
Синтаксис: голос.сказать <текст>

Преобразует текст в речь (Text-To-Speech).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  голос.сказать Привет, Мир!
	)
	return
}

if (TV_CLICKED == TV_CMDS_VOICESP_SPEED) {
	MsgBox, 0, % "ГОЛОС.СКОРОСТЬ",
	(
Синтаксис: голос.скорость <скорость (целое число в диапазоне от -10 до 10)>

Установит параметр скорости речи для преобразования текста в речь (Text-To-Speech).

По-умолчанию скорость 0.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  голос.скорость 0
	)
	return
}

if (TV_CLICKED == TV_CMDS_NETWORK_SCAN) {
	MsgBox, 0, % "СЕТЬ.СКАНИРОВАТЬ",
	(
Синтаксис: сеть.сканировать

Отображает текущие ARP записи, опрашивая текущие данные.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_CMDS_NETWORK_VKAPI) {
	MsgBox, 0, % "ВКАПИ",
	(
Синтаксис: вкапи '<переменная, куда запишется ответ>' '<текст запроса>'

Отправить запрос на сервер VK и записать ответ в переменную.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  вкапи 'информация' 'users.get'
	)
	return
}

if (TV_CLICKED == TV_CMDS_NETWORK_POST) {
	MsgBox, 0, % "ПОСТ",
	(
Синтаксис: пост '<переменная, куда запишется ответ>' '<URL>' '<текст запроса>'

Отправляет POST-запрос на указанный Вами сервер.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  пост 'ответ_сервера' 'https://api.telegram.org/botXXXXXXXXXXXXXX/sendMessage' 'text=test_message&chat_id=100'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_ATTR_GET) {
	MsgBox, 0, % "АТРИБУТЫ.ПОЛУЧИТЬ",
	(
Синтаксис: атрибуты.получить '<переменная, в которую запишется результат>' '<путь к файлу>'

Получает атрибуты файла или папки.

Возвращаемая строка будет содержать какие-то из этих букв: "RASHNDOCT".
R = READONLY (только чтение)
A = ARCHIVE (архивный)
S = SYSTEM (системный)
H = HIDDEN (скрытый)
N = NORMAL (нормальный)
D = DIRECTORY (каталог)
O = OFFLINE (отключен)
C = COMPRESSED (сжатый)
T = TEMPORARY (временный)

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  атрибуты.получить 'атрибуты' 'C:\test.txt'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_ATTR_SET) {
	MsgBox, 0, % "АТРИБУТЫ.УСТАНОВИТЬ",
	(
Синтаксис: атрибуты.установить '<(+/-)атрибуты (RASHNDOCT)>' '<путь к файлу>'

Изменяет атрибуты файла или папки.

R = READONLY (только чтение)
A = ARCHIVE (архивный)
S = SYSTEM (системный)
H = HIDDEN (скрытый)
N = NORMAL (нормальный)
O = OFFLINE (отключен)
T = TEMPORARY (временный)

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  атрибуты.установить '+A-H' 'C:\test.txt'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_CD) {
	MsgBox, 0, % "СД", 
	(
Синтаксис: сд <путь к директории/часть имени директории/имя ярлыка/часть имени ярлыка>

Смена текущей директории.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  сд C:\
  сд Windows
  сд System32
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_CD_DOT) {
	MsgBox, 0, % "СД. / СД.. / СД...", 
	(
Синтаксис 1: сд.
Синтаксис 2: сд..
Синтаксис 3: сд...

Переход в родительский каталог (на один/два/три уровень вверх).

Примеч.:
  СД. - переход на один уровень вверх.
  СД.. - переход на два уровня вверх.
  Сд... - переход на три уровня вверх.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_DIR) {
	MsgBox, 0, % "ДИР",
	(
Синтаксис: дир [шаблон названия файла]

Отобразит содержимое текущей директории.

Если указан параметр "шаблон названия файла", то будет выполняться поиск по шаблону. Пример команды с использованием по шаблону: дир *.txt

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_DRIVE) {
	MsgBox, 0, % "ДИСК.ПРИВОД",
	(
Синтаксис: диск.привод

Выдвигает/втягивает лоток CD- или DVD-привода.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_DRIVE_GET) {
	MsgBox, 0, % "ДИСК.ПОЛУЧИТЬ",
	(
Синтаксис: диск.получить '<переменная для вывода>' '<команда>' '[значение]'

Предоставляет разного рода информацию о дисках компьютера.

Команды, 'значения':
список '[тип]' = помещает в переменную для вывода строку из букв, каждая из которых является буквой одного из существующих в системе дисков. Например: ACDEZ. Если параметр [Тип] опущен, перечисляются диски всех типов. Если нужен только какой-то определённый тип, Type можно задать одним из следующих слов: CDROM, REMOVABLE, FIXED, NETWORK, RAMDISK, UNKNOWN.
емкость '<путь>' = определяет полную ёмкость диска, указанного в [путь] (например, C:\) в мегабайтах.
фс '<диск>' = определяет файловую систему диска. <Диск> задаётся либо буквой с двоеточием и необязательной обратной косой чертой, либо как имя UNC наподобие \\server1\share1. В <переменная для вывода> будет помещено одно из следующих слов: FAT, FAT32, NTFS, CDFS (обычно означает CD), UDF (обычно означает DVD). <Переменная для вывода> будет пустой и `%.консоль.результат`% равен 0, если привод не содержит форматированного носителя.
метка '<диск>' = определяет метку диска. Диск задаётся в параметре <диск> либо буквой с двоеточием и необязательной обратной косой чертой, либо как имя UNC наподобие \\server1\share1.
тип '<путь>' = определяет тип указанного в <путь> диска, обозначаемый одним из следующих слов: Unknown, Removable, Fixed, Network, CDROM, RAMDisk.
статус '<путь>' = определяет статус указанного в <путь> диска, обозначаемый одним из следующих слов: Unknown (может означать неформатированный диск), Ready, NotReady (типично для приводов, не содержащих носителя), Invalid (диск, указанный в <путь>, не существует или является сетевым диском, который в данный момент недоступен).
статусЦД '[диск]' = определяет состояние привода CD или DVD. <Диск> задаётся буквой с двоеточием (если пустой, будет использован CD/DVD-привод по умолчанию). Переменная для вывода будет пустой, если состояние не может быть определено. Иначе туда помещается одно из следующих слов:

not ready - Привод не готов для доступа, возможно потому, что занят операцией записи. Известные ограничения: "not ready" также получается, когда в приводе диск DVD, а не CD.
open - Привод не содержит диска или его лоток выдвинут.
playing - Привод проигрывает диск.
paused - Проигрывание аудио или видео приостановлено.
seeking - Привод занят поиском на диске.
stopped - Привод содержит CD-диск, но в данный момент не обращается к нему.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример 1:
  диск.получить 'емкость' 'емкость' 'C:\'

> Пример 2:
  диск.получить 'список_дисков' 'список' ''
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_DRIVE_GETM) {
	MsgBox, 0, % "ДИСК.ПОЛУЧИТЬ.СПАМЯТЬ",
	(
Синтаксис: диск.получить.спамять '<имя переменной для вывода>' '<путь к диску>'

Определяет объём свободного места на диске, в мегабайтах.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  диск.получить.спамять 'свободное_место' 'C:\'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_INI_WRITE) {
	MsgBox, 0, % "ИНИ.ЗАПИСАТЬ",
	(
Синтаксис: ини.записать '<значение>' '<путь к файлу>' '<секция>' '<ключ>'

Пишет параметр в INI-файл стандартного формата.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  ини.записать 'Москва' 'settings.ini' 'погода' 'город'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_INI_READ) {
	MsgBox, 0, % "ИНИ.ПРОЧИТАТЬ",
	(
Синтаксис: ини.прочитать '<имя переменной, куда запишется значение>' '<путь к файлу>' '<секция>' '<ключ>'

Читает значение параметра из INI-файла стандартного формата.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда выполнена с ошибкой, то это будет в записано в переменной, которая указана в первом аргументе.
  Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ меняет свое значение на "1" (единицу) в любом случае.

> Пример:
  ини.прочитать 'погода_город' 'settings.ini' 'погода' 'город'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_INI_DELETE) {
	MsgBox, 0, % "ИНИ.УДАЛИТЬ",
	(
Синтаксис: ини.удалить '<путь к файлу>' '<секция>' '<ключ>'

Удаляет параметр из INI-файла стандартного формата.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  ини.удалить 'settings.ini' 'погода' 'город'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_PROG) {
	MsgBox, 0, % "ПРОГ",
	(
Синтаксис: прог

Взаимодействует с программами от Streleckiy Development.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_DOWNLOAD) {
	MsgBox, 0, % "СКАЧАТЬ",
	(
Синтаксис: скачать '<прямая ссылка>' '<путь>'

Скачать файл из Сети Интернет.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  скачать 'http://example.com' 'test.html'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_TIME_SET) {
	MsgBox, 0, % "ФАЙЛ.ВРЕМЯ.УСТАНОВИТЬ",
	(
Синтаксис: файл.время.установить '[время в формате YYYYMMDDHH24MISS]' '<путь к файлу>'

Изменяет отметку даты и времени файла или папки.

Если первый параметр пустой, он принимает значение текущего времени. Иначе укажите, какое время использовать (формат: YYYYMMDDHH24MISS). Годы до 1601 не поддерживаются.

Элементы формата времени:
YYYY = Год, 4 цифры
MM = Месяц, 2 цифры (01-12)
DD = День месяца, 2 цифры (01-31)	
HH24 = Час в 24-часовом формате, 2 цифры (00-23)
MI = Минуты, 2 цифры (00-59)
SS = Секунды, 2 цифры (00-59)

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
  
> Пример:
  файл.время.установить '20210122165500' 'C:\test.txt'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_TIME_GET) {
	MsgBox, 0, % "ФАЙЛ.ВРЕМЯ.ПОЛУЧИТЬ",
	(
Синтаксис: файл.время.получить '<переменная, куда запишется результат> '<путь к файлу>' '<С/И/Д>'

В третьем параметре указывается только одна буква. Она отвечает за то, какое время нужно получить:
С - время создания файла.
И - время последнего изменения файла.
Д - время последнего доступа к файлу.

Возвращаемая строка будет содержать время в формате "YYYYMMDDHH24MISS".

Элементы формата временив:
YYYY = Год, 4 цифры
MM = Месяц, 2 цифры (01-12)
DD = День месяца, 2 цифры (01-31)
HH24 = Час в 24-часовом формате, 2 цифры (00-23).
MI = Минуты, 2 цифры (00-59)
SS = Секунды, 2 цифры (00-59)

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.время.получить 'время' 'C:\test.txt' 'С'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_MOVE) {
	MsgBox, 0, % "ФАЙЛ.ПЕРЕМЕСТИТЬ",
	(
Синтаксис: файл.переместить '<путь к файлу>' '<новый путь к файлу>' '<копировать с перезаписью?(flag=1/0)>'

Перемещает файл по указанному Вами пути.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.переместить 'C:\test.txt' 'C:\new_test_name.txt' '1'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_MOVE_DIR) {
	MsgBox, 0, % "ФАЙЛ.ПЕРЕМЕСТИТЬ.ПАПКА",
	(
Синтаксис: файл.переместить.папка '<путь к папке>' '<новый путь к папке>' '<flag (действия в примечаниях)>'

Перемещает/переименовывает папку вместе со всеми её подпапками и - файлами.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

Примечание: в третьем аргументе укаказывается 0/1/2/R.
0 = не переписывать существующие файлы. Операция закончится неудачей, если <второй аргумент>s уже существует как файл или папка.
1 = переписывать существующие файлы. Однако никакие файлы или папки в <первый аргумент>, которые не совпадают по имени с указанными в <второй аргумент>, удалены не будут. Известное ограничение: если <второй аргумент> уже существует как папка и находится в том же разделе диска, что и <первый аргумент>, <первый аргумент> будет помещён внутрь <второй аргумент> вместо того, чтобы переписать его. Чтобы избежать этого, используйте следующую опцию.
2 = то же, что 1, но упомянутое ограничение отсутствует (рекомендуется вместо 1).
R = переименовать папку вместо перемещения её. Хотя переименование в норме даёт тот же эффект, что и перемещение, это может быть полезно в случаях, когда вы хотите "всё или ничего", т.е. вас не устраивает частичный успех операции, когда <первый аргумент> или один из его файлов блокирован (используется). Хотя этот метод не может переместить <первый аргумент> в другой раздел, он может переместить его в любую другую папку в его собственном разделе. Операция закончится неудачей, если <второй аргумент> уже существует как файл или папка.

> Пример:
  файл.переместить.папка 'C:\test' 'C:\Program Files\test' '0'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_GET_LABEL) {
	MsgBox, 0, % "ФАЙЛ.ПОЛУЧИТЬ.ЯРЛЫК",
	(
Синтаксис: файл.получить.ярлык '<имя массива>' '<путь к файлу>'

Возвращает свойства ярлыка в виде массива.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.получить.ярлык 'ярлык' 'test.lnk'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_READ) {
	MsgBox, 0, % "ФАЙЛ.ПРОЧИТАТЬ",
	(
Синтаксис: файл.прочитать '<название переменной>' '<путь к файлу>'

Renux запишет содержание файла в переменную.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.прочитать 'текст_файла' 'C:\text.txt'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_READ_LINE) {
	MsgBox, 0, % "ФАЙЛ.ПРОЧИТАТЬ.СТРОКА",
	(
Синтаксис: файл.прочитать.строка '<название переменной для вывода >' '<путь к файлу>' '<номер строки (от 1)>

Читает определённую строку в файле и помещает текст в переменную.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.прочитать.строка 'текст_четвертой_строки' 'С:\test.txt' '4'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_APPEND) {
	MsgBox, 0, % "ФАЙЛ.СОЗДАТЬ",
	(
Синтаксис: файл.создать '<путь к файлу>' '<текст>'

Renux создаст/дополнит файл текстом по указанному Вами пути.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.создать 'C:\text.txt' 'Привет, Мир!'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_CREATE_DIR) {
	MsgBox, 0, % "ФАЙЛ.СОЗДАТЬ.ПАПКА",
	(
Синтаксис: файл.создать.папка <путь к папке>

Создаст папку по указанному Вами пути.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.создать.папка C:\test
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_CREATE_DIR) {
	MsgBox, 0, % "ФАЙЛ.СОЗДАТЬ.ПАПКА",
	(
Синтаксис: файл.создать.папка <путь к папке>

Создаст папку по указанному Вами пути.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.создать.папка C:\test
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_DELETE) {
	MsgBox, 0, % "ФАЙЛ.УДАЛИТЬ",
	(
Синтаксис: файл.удалить <путь к файлу>

Удалит файл по указанному Вами пути.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.удалить C:\text.txt
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_DELETE_DIR) {
	MsgBox, 0, % "ФАЙЛ.УДАЛИТЬ.ПАПКА",
	(
Синтаксис: файл.удалить.папка <путь к файлу>

Удаляет папку по указанному Вами пути.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.удалить.папка C:\test
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_COPY) {
	MsgBox, 0, % "ФАЙЛ.КОПИРОВАТЬ",
	(
Синтаксис: файл.копировать '<путь к файлу, который будет копироваться>' '<путь к файлу, куда будет скопировано>' '<копировать с перезаписью?(flag=1/0)>'

Копирует содержимое файла в другой файл.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.копировать 'C:\test.txt' 'C:\test2.txt' '1'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_COPY_DIR) {
	MsgBox, 0, % "ФАЙЛ.КОПИРОВАТЬ.ПАПКА",
	(
Синтаксис: файл.копировать.папка '<путь к папке, которая будет копироваться>' '<путь к папке, куда будет скопировано>' '<копировать с перезаписью?(flag=1/0)>'

Копирует папку вместе с содержимым в другое место.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.копировать.папка 'C:\test' 'C:\test2' '1'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_SIZE) {
	MsgBox, 0, % "ФАЙЛ.РАЗМЕР",
	(
Синтаксис: файл.размер '<переменная, в которую запишется результат>' '<путь к файлу>'

Определяет размер файла в байтах.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.размер 'размер' 'C:\test.txt'
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_TRANSP) {
	MsgBox, 0, % "ПРОЗРАЧНОСТЬ",
	(
Синтаксис: прозрачность <целое число>

Изменяет прозрачность окна командной строки Renux Shell.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  прозрачность 240
	)
	return
}

if (TV_CLICKED == TV_CMDS_SOUND_SET) {
	MsgBox, 1, % "ГРОМКОСТЬ",
	(
Синтаксис: громкость '<новый параметр>' '[тип компонента]' '[вид настройки]' '[номер устройства]'

Изменяет настройки звукового устройства (микшера). Окно с этими настройками открывается, например, при двойном щелчке по динамику в трее.

Новый параметр = Новая настройка. Число в диапазоне от -100 до 100 включительно (может быть числом с плавающей точкой). Если число указано со знаком (плюс или минус), значение настройки будет увеличено или уменьшено на указанную величину. Иначе текущее значение настройки будет заменено указанной величиной.Для настроек с двумя возможными значениями, а именно ONOFF, MUTE, MONO, LOUDNESS, STEREOENH, BASSBOOST, любое положительное число будет включать настройку, а ноль - выключать. Однако любое число с явно указанным знаком (плюс или минус) будет просто переключать настройку в противоположное состояние.
Тип компонента = Если опущен или пустой, принимает значение MASTER (общий регулятор громкости, который доступен также при одиночном щелчке по динамику в трее). Допустимые значения: MASTER (то же, что SPEAKERS), DIGITAL, LINE, MICROPHONE, SYNTH, CD, TELEPHONE, PCSPEAKER, WAVE, AUX, ANALOG. Если микшер не содержит указанного компонента, это будет отражено сообщением в переменной .КОНСОЛЬ.РЕЗУЛЬТАТ (см. справку). Компонент, обозначаемый в микшере как Auxiliary (дополнительный), иногда может быть доступен как ANALOG, а не как AUX. Если микшер имеет более одного экземпляра какого-то компонента, то обычно первый содержит настройки воспроизведения, а второй - настройки записи. Для доступа ко второму и следующим экземплярам добавляйте двоеточие и номер к имени компонента. Например, Analog:2.
Вид настройки = Если опущен или пустой, принимает значение VOLUME (громкость). Допустимые значения: VOLUME (или VOL), ONOFF, MUTE, MONO, LOUDNESS, STEREOENH, BASSBOOST, PAN, QSOUNDPAN, BASS, TREBLE, EQUALIZER. Если компонент не поддерживает указанный вид настройки, это будет отражено сообщением в переменной .КОНСОЛЬ.РЕЗУЛЬТАТ (см. справку).
Номер устройства = Может быть выражением. Номер устройства. Если опущен, принимает значение 1, что обычно соответствует системному устройству по умолчанию для записи и воспроизведения. Для доступа к другим устройствам указывайте номер больше единицы.
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 0, % "ГРОМКОСТЬ",
	(
> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
  
  Возможный текст ошибок:
  - Неверный вид настройки или тип компонента
  - Не могу открыть указанный микшер
  - Микшер не поддерживает указанный компонент
  - Количество компонентов данного типа в микшере меньше, чем указанный номер
  - Компонент не поддерживает указанную настройку
  - Не могу считать текущую настройку
  - Не могу изменить настройку

Примеры:
  // Общий регулятор громкости на середину.
  громкость '50' '' '' ''

  // Увеличить общую громкость на 10`%.
  громкость '+10' '' '' ''
  
  // Уменьшить общую громкость на 10`%
  громкость '-10' '' '' ''
  
  // Отключить микрофон
  громкость '1' 'Microphone' 'mute' ''
  
  // Переключить выключатель общей громкости (в противоположное состояние).
  громкость '+1' '' 'mute' ''
  
  // Поднять нижние частоты на 20`%.
  громкость '+20' 'Master' 'bass' ''
  если '`%.консоль.результат`%' != '1' то вывод Настройка нижних частот не поддерживается общим регулятором громкости.
	)
	return
}

if (TV_CLICKED == TV_CMDS_DIALOG_MSGBOX) {
	MsgBox, 1, % "СООБЩЕНИЕ",
	(
Синтаксис: сообщение '<опции>' '<заголовок>' '<текст>' '[тайм-аут]'

Отображает на экране диалоговое окно с кнопками (например: да/нет).

Опции = Устанавливает тип окна (обычное, информационное, ошибка, предупреждение), а также комбинации кнопок. Если опущен, то по умолчанию принимает значение 0 (обычное окно с кнопкой Ок).
Заголовок = Заголовок окна сообщение. По умолчанию содержит имя файла Renux.
Текст = Если все параметры опущены, СООБЩЕНИЕ отображает текст "Нажмите ОК для продолжения". В противном случае, этот параметр отвечает за текст, который будет отображаться в диалоговом окне. Можно использовать также управляющие последовательности, такие как ``n -перевод строки, ``t -табуляция и т.д. Если текст длинный его рекомендуется разбить на несколько строк для улучшения читаемости.
Тайм-аут = (необязательный параметр): Задает время в секундах, до автоматического закрытия диалогового окна. После истечения времени окно будет закрыто, а переменная .сообщение.результат примет значение "Тайм-Аут". Может быть дробным числом, не превышающим 2147483 (24,8 дней).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Переменная изменяет свое значение на "1" (единицу) в любом случае.
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 1, % "СООБЩЕНИЕ",
	(
> Опции:
  Можно использовать одновременно несколько опций, для этого их значение нужно сложить,
  Например: Нам нужны кнопки Прервать/Повторить/Игнорировать и информационное окно, тогда складываем 2+64, параметр ОПЦИИ в этом случае должен содержать 66!

  Функция - Числовое значение:
  ОК - 0
  ОК/Отмена - 1
  Прервать/Повторить/Пропустить - 2
  Да/Нет/Отмена - 3
  Да/Нет - 4
  Повторить/Отмена - 5
  Отмена/Повторить/Продолжить - 6
  
  Тип окна: Ошибка - 16
  Тип окна: Вопрос - 32
  Тип окна: Предупреждение - 48
  Тип окна: Информация - 64
  
  Максимальное значение: 100.

> Дополнение:
  Для определения кнопки, выбраной пользователем используется переменная .СООБЩЕНИЕ.ОТВЕТ:
  
  сообщение '4' 'Выбор' 'Вы хотите продолжить? (Нажмите Да или Нет)'
  если '`%сообщение.ответ`%' == 'Да' то вывод Вы нажали "Да"
  если '`%сообщение.ответ`%' == 'Нет' то вывод Вы нажали "Нет"

> Совет:
  Нажатие Ctrl+C во время показа Msgbox (команда СООБЩЕНИЕ) копирует его текст в буфер обмена. Это относится ко всем диалоговым окнам, в том числе не созданых Renux Shell.
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 0, % "СООБЩЕНИЕ",
	(
> Кнопка закрыть:
  Если окно имеет только один вариант выбора (ОК), кнопка X будет работать идентично кнопке ОК.
  Если окно имеет вид Да/Нет, то кнопка X будет соответствовать отрицательному выбору.

> Пример:
  сообщение '0' '' 'Привет' ''

  сообщение '4' '' 'Хотите продолжить?' ''
  если '`%.сообщение.ответ`%' == 'Нет' то выход

  сообщение '4' '' 'Этот пример с использованием таймаута 5 секунд.  Продолжить?' '5'
  если '`%.сообщение.ответ`%' == 'Тайм-аут' то сообщение '' '' 'Вы не отреагировали в течении 5 секунд' '';выход
  если '`%.сообщение.ответ`%' == 'Нет' то выход
  сообщение '0' '' 'Это конец =(' ''
	)
	return
}

if (TV_CLICKED == TV_CMDS_DISPLAY_TRAYTIP) {
	MsgBox, 0, % "УВЕДОМЛЕНИЕ",
	(
Синтаксис: уведомление '<заголовок>' '<текст>' '<тайм-аут>' '<опции>'

Создает всплывающее окно с сообщением рядом со значком в трее. В Windows 10 вместо этого может отображаться всплывающее уведомление.

> Опции:
  Параметр может быть комбинацией (суммой) нуля или более следующих значений:
  - Значок информации - 1,
  - Значок предупреждения - 2,
  - Значок ошибки - 3,
  - не воспроизводить звук уведомления - 16,
  - использовать большую версию значка - 32.
  
  По умолчанию параметр равен 0. Значок не отображается, если отсутствует заголовок (это не относится к всплывающим уведомлениям Windows 10).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Переменная изменяет свое значение на "1" (единицу) в любом случае.

> Примечание:
  Windows 10 по умолчанию заменяет все всплывающие окна всплывающими уведомлениями (это можно переопределить с помощью групповой политики). Многократный вызов "УВЕДОМЛЕНИЕ" обычно приводит к тому, что несколько уведомлений помещаются в «очередь», а не каждое уведомление заменяет последнее. Чтобы скрыть уведомление, временное удаление иконки в трее может быть эффективным.
  
  "УВЕДОМЛЕНИЕ" не действует, если следующее значение REG_DWORD существует и имеет значение 0:
    HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced >> EnableBalloonTips

> Пример:
  уведомление 'Привет' 'Это сообщение показывается 5 секунд' '5' '1'
	)
	return
}

if (TV_CLICKED == TV_CMDS_DISPLAY_MONITOR) {
	MsgBox, 0, % "МОНИТОР",
	(
Синтаксис: монитор <действие>

Выключает/включает монитор.

> Действия:
  включить - включает монитор
  выключить - выключает монитор
  малая - режим малой мощности монитора

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Примеры:
  монитор выключить
  ждать.время 5000
  монитор.включить
	)
	return
}

if (TV_CLICKED == TV_CMDS_SOUND_BEEP) {
	MsgBox, 0, % "ГУДОК",
	(
Синтаксис: гудок '<частота в герцах>' '<длительность в мс>

Издаёт звук через динамик системного блока.

> Примечание:
  Программа ждёт окончания звука, чтобы продолжить свою работу. Кроме того отзывчивость (responsiveness) системы в целом может на это время снижаться.

> Пример:
  гудок '750' '500'
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_0) {
	MsgBox, 0, % "Версия 2.0",
	(
- Самая первая версия программы.
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_1) {
	MsgBox, 0, % "Версия 2.1",
	(
- Исправлена работа команды "окно.элемент.напечатать".
- Исправлены мелкие ошибки в программном коде.
- Новый аргумент командной строки "/log" (записывает в файл лог содержимое консоли).
- Новая команда "ждать.нажатие" (Ожидает нажатие на клавишу(-и), указанную Вами).
- Переработан алгоритм показа значений переменных.
- Новая команда "СОБРАТЬ" ("Скомпилирует" пакетный файл Renux Shell в .exe формат).
- Шифрование алгоритма пакетных файлов двумя ключами шифрования (доступно в команде "СОБРАТЬ").
- При нажатии Shift и Enter одновременно, появится еще одна строка для ввода. Все указанные команды (с новой строки) будут последовательно обработаны (альтернатива "&" в командной строке Windows).
- Новая команда "ПОСТ" (отправляет POST-запрос на указанный Вами сервер).
- Теперь Renux не открывает новую сессию при просьбе пользователя открыть пакетный файл Renux Shell.
- Новое поведение программы при фатальной ошибке.
- Теперь в именах переменных можно использовать только английские/русские буквы, цифры, символ "_".
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_2) {
	MsgBox, 0, % "Версия 2.2",
	(
- Оптимизирован алгоритм отображения значений переменных.
- Новая встроенная переменная ".консоль.результат", которая будет содержать ответ предыдущей внутренней функции Renux, которая отвечает за выполнение указанной Вами команды.
- Новая команда "СТРОКА.РАЗДЕЛИТЬ" (разделяет строку на подстроки, в зависимости от заданного разделителя).
- Новая команда "СТРОКА.ЗАМЕНИТЬ" (заменяет вхождения строки поиска на строку замены).
- Новая команда "МАССИВ.ОБЪЕДИНИТЬ" (сливает один массив и записывает в указанную Вами переменную).
- Изменен синтаксис команды "ВКАПИ".
- В команде "ФАЙЛ.ПРОЧИТАТЬ", теперь вместо записи текста файла в переменую, записывается в массив по строке.
- Теперь в именах меток можно использовать только английские/русские буквы, цифры, символ "_".
- Новая команда "ГК" (активирует по нажатию клавиш(-и) участок сценария).
- Новая команда "ИНИ.УДАЛИТЬ" (удаляет параметр из INI-файла стандартного формата).
- Новая команда "ИНИ.ПРОЧИТАТЬ" (читает значение параметра из INI-файла стандартного формата).
- Новая команда "ИНИ.ЗАПИСАТЬ" (пишет параметр в INI-файл стандартного формата).
- Новая команда "АДМИН" (запросит права администратора и перезапустит сценарий (если он запущен)).
- Теперь Вы можете "складывать" строки через команду "ПЕР" (нужно чтобы значение переменной не было числом) (сделает слияние строк).
- Теперь Вы можете "уменьшать" строки через команду "ПЕР" (нужно чтобы значение переменной не было числом) (заменяет вхождения из второго параметра на пустоту).
- Теперь Вы можете "умножать" строки через команду "ПЕР" (нужно чтобы значение переменной не было числом) (сделает слияние строк столько раз, сколько Вам будет нужно) [ВО ВТОРОМ ПАРАМЕТРЕ ДОЛЖНО БЫТЬ ЧИСЛО].
- Теперь Вы можете "разделить" строки через команду "ПЕР" (нужно чтобы значение переменной не было числом) (запишет в значение переменной количество найденных входений в значении переменной).
- Новая команда "СЕТЬ.ВВОД" (передает сообщения по локальной сети).
- Новая команда "СЕТЬ.ВЫВОД" (получает сообщения по локальной сети).
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_3) {
	MsgBox, 0, % "Версия 2.3",
	(
- Новая команда "ПШ" (выполнит команду в PowerShell).
- Новая команда "ГОЛОС.СКАЗАТЬ" (преобразует текст в речь (Text-To-Speech)).
- Новая команда "ГОЛОС.ГРОМКОСТЬ" (установит параметр громкости для преобразования текста в речь (Text-To-Speech)).
- Новая команда "ГОЛОС.СКОРОСТЬ" (установит параметр скорости речи для преобразования текста в речь (Text-To-Speech)).
- Мелкие правки в справке.
- Новая команда "ФУНКЦИЯ" (метка, к которой можно обратиться из другого места сценария).
- Новая команда "СЕТЬ.СКАНИРОВАТЬ" (отображает текущие ARP записи, опрашивая текущие данные).
- Новая операция в команде "ПЕР" под именем "ЗАМЕНИТЬ" (работает также, как и команда СТРОКА.ЗАМЕНИТЬ).
- Новая операция в команде "ПЕР" под именем "РАЗДЕЛИТЬ" (работает также, как и команда СТРОКА.РАЗДЕЛИТЬ).
- Новая операция в команде "ПЕР" под именем "слева" (запишет в переменную указанное число символов строки слева).
- Новая операция в команде "ПЕР" под именем "справа" (запишет в переменную указанное число символов строки справа).
- Новая операция в команде "ПЕР" под именем "длина" (запишет в переменную количество символов строки).
- Новая операция в команде "ПЕР" под именем "вверх" (преобразует строку в верхний регистр и запишет в переменную).
- Новая операция в команде "ПЕР" под именем "вниз" (преобразует строку в нижний регистр и запишет в переменную).
- Переход на 64-разрядное приложение.
- Новая команда "СЕТЬ.СООБЩЕНИЕ" (отправит сообщение по локальной сети и дождется его чтения).
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_4) {
	MsgBox, 0, % "Версия 2.4",
	(
- Добавлено предупреждение о компонентах, работающих только в Windows 10 (если версия ядра ОС не совпадает с Windows 10).
- Исправлены программные ошибки в команде "ПЕР".
- Теперь режим отладки вызывает GUI, в котором отображаются все события.
- Новая команда "ФАЙЛ.КОПИРОВАТЬ" (копирует содержимое файла в другой файл).
- Новая команда "РЕСТАРТ" (перезапустит Renux Shell).
- Новая команда "ФАЙЛ.КОПИРОВАТЬ.ПАПКА" (копирует папку вместе с содержимым в другое место).
- Новая команда "ФАЙЛ.СОЗДАТЬ.ПАПКА" (создаст папку по указанному Вами пути).
- Новая команда "ФАЙЛ.СОЗДАТЬ.ЯРЛЫК" (создаст ярлык, который будет активировать указанный Вами файл).
- Новая команда "АТРИБУТЫ.ПОЛУЧИТЬ" (читает атрибуты файла или папки).
- Новая команда "АТРИБУТЫ.УСТАНОВИТЬ" (изменяет атрибуты файла или папки).
- Новая команда "ФАЙЛ.ВРЕМЯ.УСТАНОВИТЬ" (изменяет отметку даты и времени файла или папки).
- Новая команда "ФАЙЛ.ВРЕМЯ.ПОЛУЧИТЬ" (возвращает отметку даты и времени файла или папки).
- Новая команда "ФАЙЛ.РАЗМЕР" (определяет размер файла в байтах).
- Новая команда "ФАЙЛ.ПЕРЕМЕСТИТЬ.ПАПКА (перемещает/переименовывает папку вместе со всеми её подпапками и файлами).
- Изменен синтаксис команды "ЖДАТЬ.НАЖАТИЕ" на более привычный для Renux Shell.
- Новая команда "ФАЙЛ.ПОЛУЧИТЬ.ЯРЛЫК" (возвращает свойства ярлыка в виде массива).
- Новая команда "ФАЙЛ.ПРОЧИТАТЬ.СТРОКА" (читает определённую строку в файле и помещает текст в переменную).
- Новая команда "ФАЙЛ.УДАЛИТЬ.ПАПКА" (удаляет папку по указанному Вами пути).
- Новая команда "ДИСК.ПРИВОД" (выдвигает/втягивает лоток CD- или DVD-привода).
- Новая команда "ДИСК.ПОЛУЧИТЬ" (предоставляет разного рода информацию о дисках компьютера).
- Новая команда "ДИСК.ПОЛУЧИТЬ.СПАМЯТЬ (определяет объём свободного места на диске, в мегабайтах).
- Изменен синтаксис команды "СЕТЬ.СООБЩЕНИЕ": второй аргумент обязателен.
- Новая команда "КОНСОЛЬ" (установщик Renux Shell).
- Новый параметр запуска "install" (установит Renux Shell в систему).
- Новый параметр запуска "deinstall" (удалит Renux Shell с Вашего ПК).
- Новая переменная ".система.компьютер" (отобразит системное имя ПК).
- Новая переменная ".система.пользователь" (отобразит системное имя ПК).
- Новая команда "ПРОГ" (взаимодействует с программами от Streleckiy Development).
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_5) {
	MsgBox, 0, % "Версия 2.5",
	(
- Фикс установщика при использовании команды "ПРОГ".
- Доработана система автоматического обновления.
- Команда "ФАЙЛ.ПРОЧИТАТЬ" вновь записывает содержание файла в переменную.
- Теперь команды для выполнения разделяются не новой строкой, а знаком ";" (но ничего не мешает использовать новую строку).
- Команды "СЕТЬ.ВВОД" временно вырезаны.
- Команда "СЕТЬ.ВЫВОД" временно вырезана.
- Добавлены последовательности символов (подр. в команде "СПРАВКА").
- Переработан алгоритм распознавания команд.
- Изменен синтаксис команды "МЫШЬ.ПЕРЕДВИНУТЬ".
- Изменен синтаксис команды "ФАЙЛ.УДАЛИТЬ".
- Переработан алгоритм условий, но синтаксис не изменен (команда "ЕСЛИ").
- Переработан алгоритм работы с переменными, но синтаксис не изменен (команда "ПЕР").
- Изменен синтаксис команды "ОКНО.ЭЛЕМЕНТ.ПЕРЕДВИНУТЬ".
- Изменен формат справки для быстрой навигации по ней.
- Команда "СОБРАТЬ" временно вырезана.
- Новая команда "ВЫЙТИ" (завершит работу/выйдет из системы и т.п).
- Новая команда "ДИР" (отобразит содержимое текущей директории).
- Новая команда "СД" (смена текущей директории).
- Новая команда "СД." (аналогично СД.., СД...) (переход в родительский каталог (на один уровень вверх)).
- Новая команда "ПРОЦЕСС" (выполняет операции над процессом).
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_6) {
	MsgBox, 0, % "Версия 2.6",
	(
- Изменены флаги команды "выйти".
- Новая переменная ".система.буферобмена" (выводит/изменяет буфер обмена). 
- Новая справка в виде отдельных окон с графическим пользовательским интерфейсом (замена команде "СПРАВКА").
- Фикс обновления Renux Shell.
- Мелкие фиксы команд.
- Новая команда "ПРОЗРАЧНОСТЬ" (изменяет прозрачность окна командной строки Renux Shell).
- Фикс экранизации символов.
- Новый флаг для команды "ВЫЙТИ" (отменить запланированное завершение работы).
- Новая команда "ГРОМКОСТЬ" (изменяет настройки звукового устройства (микшера)).
- Новая команда "СООБЩЕНИЕ" (отображает на экране диалоговое окно с кнопками (например: да/нет))
- Новая команда "УВЕДОМЛЕНИЕ" (создает всплывающее окно с сообщением рядом со значком в трее. В Windows 10 вместо этого может отображаться всплывающее уведомление).
- Новая команда "МОНИТОР" (выключает/включает монитор).
- Новая команда "АСИНХ" (выполнит команду асинхронно).
- Новая команда "ГУДОК" (издаёт звук через динамик системного блока).
- Новая команда "ЗВУКИНФО" (считывает текущие настройки звукового устройства (микшера)).
- Теперь список обновлений доступен в справке: в разделе "Список обновлений".
- Новая команда "ПРОИГРАТЬ" (проигрывает аудио- и видеофайлы, или файлы другого поддерживаемого формата).
- Новая команда "РЕЕСТР.ЗАПИСАТЬ" (записывает параметр в реестр).
- Новая команда "РЕЕСТР.ПРОЧИТАТЬ" (читает параметр из реестра).
- Новая команда "РЕЕСТР.УДАЛИТЬ" (удаляет раздел или параметр реестра).
- Новая встроенная переменная ".ЭКРАН.ШИРИНА" (ширина основного монитора в пикселях).
- Новая встроенная переменная ".ЭКРАН.ВЫСОТА" (высота основного монитора в пикселях).
- Новая команда "ЯРКОСТЬ" (изменяет яркость экрана).
- Теперь после исполнения пакетного файла программа не закроется (искл. через "Открыть с помощью").
- Новая команда "АДДОН" (устанавливает/удаляет/собирает аддоны).
- Новые действия в команде "ЕСЛИ" (если (файл/переменая) (существует/не существует)).
	)
	return
}

if (TV_CLICKED == TV_CMDS_SOUND_GET) {
	MsgBox, 1, % "ЗВУКИНФО",
	(
Синтаксис: звукинфо '<переменная для вывода>' '[тип компонента]' '[вид настройки]' '[номер устройства]'

Считывает текущие настройки звукового устройства (микшера). Окно с этими настройками открывается, например, при двойном щелчке по динамику в трее.

> Параметры:
  переменная для вывода = Имя выходной переменной. В зависимости от вида считываемой настройки возвращаемое в переменную значение может быть числом (с плавающей точкой) в диапазоне от 0 до 100 (включительно), либо словом ON или OFF (для настроек ONOFF, MUTE, MONO, LOUDNESS, STEREOENH, BASSBOOST). Если считать настройку не удалось, переменная будет пустой.
  тип компонента = Тип компонента (соотносится с одним из регуляторов в окне настроек микшера). Если опущен или пустой, принимает значение MASTER (общий регулятор громкости, который доступен также при одиночном щелчке по динамику в трее). Допустимые значения: MASTER (то же, что SPEAKERS), DIGITAL, LINE, MICROPHONE, SYNTH, CD, TELEPHONE, PCSPEAKER, WAVE, AUX, ANALOG. Если микшер не содержит указанного компонента, это будет отражено сообщением в переменной .консоль.результат (см. список ниже). Компонент, обозначаемый в микшере как Auxiliary (дополнительный), иногда может быть доступен как ANALOG, а не как AUX. Если микшер имеет более одного экземпляра какого-то компонента, то обычно первый содержит настройки воспроизведения, а второй - настройки записи. Для доступа ко второму и следующим экземплярам добавляйте двоеточие и номер к имени компонента. Например, Analog:2.
  вид настройки = Если опущен или пустой, принимает значение VOLUME (громкость). Допустимые значения: VOLUME (или VOL), ONOFF, MUTE, MONO, LOUDNESS, STEREOENH, BASSBOOST, PAN, QSOUNDPAN, BASS, TREBLE, EQUALIZER. Если компонент не поддерживает указанный вид настройки, это будет отражено сообщением в переменной .консоль.результат (см. список ниже).
  номер устройства = Если опущен, принимает значение 1, что обычно соответствует системному устройству по умолчанию для записи и воспроизведения. Для доступа к другим устройствам указывайте номер больше единицы.
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 0, % "ЗВУКИНФО",
	(
> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
  
  Возможный текст ошибок:
  - Неверный вид настройки или тип компонента
  - Не могу открыть указанный микшер
  - Микшер не поддерживает указанный компонент
  - Количество компонентов данного типа в микшере меньше, чем указанный номер
  - Компонент не поддерживает указанную настройку
  - Не могу считать текущую настройку

> Примечание:
  Для изменения настроек используйте команду ГРОМКОСТЬ.

> Примеры:
  звукинфо 'громкость' '' '' ''
  вывод Общий регулятор громкости сейчас на уровне `%громкость`% процентов.
  
  звукинфо 'master_mute' '' 'mute' ''
  вывод Выключатель общего регулятора громкости сейчас в положении `%master_mute`%.
	)
	return
}

if (TV_CLICKED == TV_CMDS_SOUND_PLAY) {
	MsgBox, 0, % "ПРОИГРАТЬ",
	(
Синтаксис: проиграть '<имя файла>' '[ждать? (1-да/0-нет)]>

Проигрывает аудио- и видеофайлы, или файлы другого поддерживаемого формата.

> Параметры:
  имя файла = Если не задан полный путь, файл ищется в рабочей папке.
  Для воспроизведения стандартных системных звуков задайте этот параметр в виде звёздочки с числом, как показано ниже. Заметьте, что параметр "ждать" в этом случае не действует.
  *-1 Простой звук. Если звуковая карта недоступна, этот звук будет воспроизведён через динамик системного блока.
  *16 Стоп/Ошибка
  *32 Вопрос
  *48 Восклицание
  *64 Звёздочка (информация)
  Какие файлы будут в этих случаях проигрываться, определяется настройкой системной звуковой схемы в диалоге "Звуки и аудиоустройства".
  ждать? = Если опущен, выполнение следующих команд из текущего потока скрипта продолжается, в то время как файл проигрывается. Чтобы заставить поток ждать окончания проигрывания файла, присвойте параметру значение 1.
  Известные ограничения: если параметр ЖДАТЬ опущен, операционная система иногда может воспринимать проигрываемый файл как занятый до тех пор, пока скрипт не будет закрыт или пока не будет проигран другой файл (даже несуществующий).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Примечания:
  Все операционные системы Windows могут проигрывать wav-файлы. Однако файлы других форматов (mp3, avi и т.д.) могут требовать установки соответствующих кодеков. Если скрипт, воспроизводящий файл, начнёт проигрывать другой файл, воспроизведение первого файла будет остановлено. На некоторых системах файлы определённых форматов могут останавливаться, даже если проигрывание второго файла начато не тем же самым, а другим скриптом. Чтобы остановить проигрывание файла, используйте команду ПРОИГРАТЬ с несуществующим файлом в качестве параметра. Если работа скрипта завершается, воспроизведение любого файла, запущенное этим скриптом, останавливается.

> Пример:
  проиграть 'tada.wav' '1'
	)
	return
}

if (TV_CLICKED == TV_CMDS_REG_WRITE) {
	MsgBox, 0, % "РЕЕСТР.ЗАПИСАТЬ",
	(
Синтаксис: реестр.записать '<тип записываемого параметра>' '<имя корневого раздела>' '<имя подраздела>' '<имя параметра реестра>' '[значение для записываемого параметра]'

Записывает параметр в реестр.

> Параметры:
  Тип записываемого параметра = Возможные значения: REG_SZ, REG_EXPAND_SZ, REG_MULTI_SZ, REG_DWORD, REG_BINARY.
  Имя корневого раздела = Возможные значения: HKEY_LOCAL_MACHINE (или HKLM), HKEY_USERS (или HKU), HKEY_CURRENT_USER (или HKCU), HKEY_CLASSES_ROOT (или HKCR), HKEY_CURRENT_CONFIG (или HKCC). Для доступа к удалённому реестру укажите вначале имя компьютера с двоеточием на конце, как в этом примере: \\workstation01:HKEY_LOCAL_MACHINE
  Имя подраздела = (например, Software\SomeApplication). Если раздел не существует, он будет создан (вместе со своими родительскими разделами, если необходимо). Если SubKey оставлен пустым, запись произойдёт прямо в корневой раздел (хотя некоторые операционные системы могут отказаться писать в HKEY_CURRENT_USER).
  Имя параметра реестра = (который будет записан). Если опущен или пустой, будет записан параметр, который в редакторе реестра отображается под именем "(По умолчанию)".
  Значение для записываемого параметра = Если опущено, считается пустой строкой либо нулём, в зависимости от типа параметра.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Примечания:
  Значение параметров типа REG_DWORD должно лежать между -2147483648 и 4294967295 (0xFFFFFFFF).
  Параметры REG_BINARY и REG_MULTI_SZ допускают запись до 64 Кб данных, остальные не имеют ограничений. Когда это ограничение действует, данные, находящиеся после 64 Кб, не будут записаны. Другими словами, только первые 64 Кб очень длинной строки будут сохранены в реестре.
  При записи параметра REG_BINARY используйте строку из шестнадцатеричных цифр. Например, значение REG_BINARY 01,a9,ff,77 может быть записано при указании в команде строки 01A9FF77.
  При записи REG_MULTI_SZ вы должны отделять каждый компонент от следующего символом перевода строки (``n). Последний компонент также можно (но необязательно) завершить переводом строки. Пустые компоненты не допускаются. Другими словами, не указывайте два перевода строки подряд (``n``n), поскольку результатом будет запись в реестр значения более короткого, чем ожидалось.

> Примеры:
  реестр.записать 'REG_SZ' 'HKEY_LOCAL_MACHINE' 'SOFTWARE\TestKey' 'MyValueName' 'Test Value'
  реестр.записать 'REG_BINARY' 'HKEY_CURRENT_USER' 'Software\TEST_APP' 'TEST_NAME' '01A9FF77'
  реестр.записать 'REG_MULTI_SZ' 'HKEY_CURRENT_USER' 'Software\TEST_APP' 'TEST_NAME' 'Строка1``nСтрока2'
	)
}

if (TV_CLICKED == TV_CMDS_REG_READ) {
	MsgBox, 0, % "РЕЕСТР.ПРОЧИТАТЬ",
	(
Синтаксис: реестр.прочитать '<вывод переменной>' '<имя корневого размера>' '<имя подраздела>' '[имя параметра]'

Читает параметр из реестра.

> Параметры:
  вывод переменной = Если значение не может быть считано, переменная будет пустой и .КОНСОЛЬ.РЕЗУЛЬТАТ будет установлен в 1.
  имя корневого раздела = Возможные значения: HKEY_LOCAL_MACHINE (или HKLM), HKEY_USERS (или HKU), HKEY_CURRENT_USER (или HKCU), HKEY_CLASSES_ROOT (или HKCR), HKEY_CURRENT_CONFIG (или HKCC). Для доступа к удалённому реестру укажите вначале имя компьютера с двоеточием на конце, как в этом примере: \\workstation01:HKEY_LOCAL_MACHINE
  Имя подраздела = (например, Software\SomeApplication).
  Имя параметра = (чьё значение нужно прочитать). Если опущен или пустой, будет считан параметр, который в редакторе реестра отображается под именем "(По умолчанию)". Если ему не присвоено никакого значения, выходная переменная будет пустой и .КОНСОЛЬ.РЕЗУЛЬТАТ равен 1.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Примечания:
  В настоящее время поддерживаются только следующие типы параметров: REG_SZ, REG_EXPAND_SZ, REG_MULTI_SZ, REG_DWORD, REG_BINARY.
  Параметры REG_DWORD всегда выражаются в виде положительных десятичных чисел.
  Из параметров типа REG_BINARY может быть считано не более 64 Кб данных, остальные не имеют таких ограничений.
  При чтении REG_BINARY результатом будет строка шестнадцатеричных цифр. Например: REG_BINARY со значением 01,a9,ff,77 будет считан как 01A9FF77.
  При чтении REG_MULTI_SZ все его компоненты оканчиваются переводом строки (`n). Если компонентов нет, выходная переменная будет пустой.

> Пример:
  реестр.прочитать 'PATH' 'HKCU' 'Environment' 'PATH'
	)
}

if (TV_CLICKED == TV_CMDS_REG_DELETE) {
	MsgBox, 0, % "РЕЕСТР.УДАЛИТЬ",
	(
Синтаксис: реестр.удалить '<имя корневого раздела>' '<имя подраздела>' '[имя параметра для удаления]'

Удаляет раздел или параметр реестра.

> Параметры:
  имя корневого раздела = Возможные значения: HKEY_LOCAL_MACHINE (или HKLM), HKEY_USERS (или HKU), HKEY_CURRENT_USER (или HKCU), HKEY_CLASSES_ROOT (или HKCR), HKEY_CURRENT_CONFIG (или HKCC). Для доступа к удалённому реестру укажите вначале имя компьютера с двоеточием на конце, как в этом примере: \\workstation01:HKEY_LOCAL_MACHINE
  имя подраздела = (например, Software\SomeApplication).
  имя параметра для удаления = Если опущено, будет удалён весь раздел, указанный в SubKey. Чтобы удалить параметр, который отображается в редакторе реестра как параметр "(По умолчанию)".

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Примечание:
  Удаление из реестра потенциально опасно - пожалуйста, будьте осторожны!

> Пример:
  реестр.удалить 'HKEY_LOCAL_MACHINE' 'Software\SomeApplication' 'TestValue'
	)
}

if (TV_CLICKED == TV_CMDS_DISPLAY_SCREENS) {
	MsgBox, 0, % "СКРИНШОТ",
	(
Синтаксис: скриншот <имя файла>

Сохраняет снимок экрана в файл.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  скриншот screenshot.png
	)
	return
}

if (TV_CLICKED == TV_CMDS_DISPLAY_BRIGHT) {
	MsgBox, 0, % "ЯРКОСТЬ",
	(
Синтаксис: яркость <[+/-]число>

Изменяет яркость экрана.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Переменная изменяет свое значение на "1" (единицу) в любом случае.

> Примечание:
  Рекомендуется использовать "-" или "+" перед значением для максимального быстродействия.

> Примеры:
  // Устанавливает текущую яркость на 10
  яркость 10
  
  // Добавляет к текущей яркости +10
  яркость +10
  
  // Убавляет с текущей яркости -10
  яркость -10
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_ADDON) {
	MsgBox, 0, % "АДДОН",
	(
Синтаксис: аддон

Устанавливает/удаляет/собирает аддоны.

Подробнее в справке: в разделе Аддоны.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_ADDONS_QUICKSTART) {
	MsgBox, 0, % "Аддоны > Введение",
	(
Аддоны позволяют создавать свои команды со своим алгоритмом выполнения на языке Renux Shell.
Если имеются установленные аддоны, то Renux Shell загружает их в память.

Аддоны состоят из двух файлов.
*.rs - пакетный файл (алгоритм аддона).
*.rsa - файл, который регистрирует команду аддона.
	)
	return
}

if (TV_CLICKED == TV_ADDONS_CREATING) {
	MsgBox, 1, % "Аддоны > Создание аддона",
	(
Файл, который отвечает за регистрацию аддонов, имеет расширение *.rsa (например, аддон.rsa).
В этом файле указывается информация о синтаксисе команд и др.

Стоит учесть, что для аддонов используется стандартный парсер аргументов RS, так что каждый аргумент записывается в " ' " (одинарные кавычки). Исключение: когда используется один аргумент, кавычки не требуются

Пример записи файла:
[addon]
команда=проверка
описание=Тестирование аддона в Renux Shell
синтаксис=проверка '<текст для вывода 1>' '<текст для вывода 2>'
пример=проверка 'раз два три' 'четыре пять шесть'
количество_параметров=2
массив_для_вывода=текст
имя_пакета=алгоритм_проверки

Строка "[addon]" должна быть указана!
Где "команда", указывается название команды, которая будет активировать аддон.
Где "описание", указывается описание команды, если указаны не все аргументы.
Где "синтаксис", указывается формат команды в виде текста, если указаны не все аргументы.
Где "пример", указывается пример команды в виде текста, если указаны не все аргументы.
Где "количество_параметров", указывается количество аргументов, которая должна принимать команда.
Где "массив_для_вывода", указывается имя массива, в который будут записаны аргументы, которые указал пользователь.
Где "имя_пакета", указывается файл без расширения *.rs, который будет выполняться, когда все аргументы будут указаны.
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 0, % "Аддоны > Создание аддона",
	(
После того, как пользователь укажет все принимаемые аргументы для команды, все аргументы записываются в массив, указанный в параметре "массив_для_вывода" в *.rsa файле.

Пример, на котором выводятся значения двух аргументов, указанные пользователем:
  вывод В первом аргументе было указано: `%текст[1]`%
  вывод Во втором аргументе было указано: `%текст[2]`%

После того, как исполнение пакетного файла будет завершено, Renux вернется в обычный режим.
	)
	return
}

if (TV_CLICKED == TV_ADDONS_COMPILING) {
	MsgBox, 0, % "Аддоны > Сборка аддона",
	(
Когда Вы создадите *.rs и *.rsa файлы, Вы сможете их объединить в один файл (расширение *.rsac) и установить через команду "АДДОН" в Renux Shell. Собрать же сможете также через команду "АДДОН".
	)
	return
}

if (TV_CLICKED == TV_ADDONS_DELETE) {
	MsgBox, 0, % "Аддоны > Удаление аддона",
	(
Если Вам нужно удалить установленный аддон, то используйте команду "АДДОН".
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_7) {
	MsgBox, 0, % "Версия 2.7",
	(
- Фиксы и улучшения.
- Новая команда "СОЗДАТЬДАННЫЕФОРМЫ" (создает из файла объект, который можно отправить на сервер, командой "ЗАПРОС").
- Новая команда "РАНД" (генерирует случайное число и записывает его в переменную).
- Новая команда "ЗАПРОС" (вызывает объект "WinHttpRequest.5.1", через который Вы сможете отправить "кастомный" запрос).
- Вырезана функция расшифровки зашифрованных сценариев Renux Shell.
- Исправлены баги при выполнении пакетных файлов.
- Теперь Renux Shell вновь запустится на 32-разрядной системе.
- Вырезана команда "СЕТЬ.СООБЩЕНИЕ".
	)
	return
}

if (TV_CLICKED == TV_CMDS_NETWORK_CFD) {
	MsgBox, 0, % "СОЗДАТЬДАННЫЕФОРМЫ",
	(
Синтаксис: создатьДанныеФормы '<тип файла>' '<путь к файлу>' '<вывод #1>''<вывод #2>'

Создает из файла объект, который можно отправить на сервер, командой "ЗАПРОС"

> Параметры:
  Тип файла:
    "application" - Внутренний формат прикладной программы
    "audio" - Аудио
    "image" - Изображение
    "message" - Сообщение
    "model" - Для 3D-моделей
    "multipart" - Email
    "text" - Текст
    "video" - Видео
  
  Путь к файлу:
    Указывается путь к файлу, который нужно получить.
  
  Вывод #1:
    Имя переменной, в которую запишется информация: PostData.

  Вывод #2:
    Имя переменной, в которую запишется информация: Content-Type.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  создатьДанныеФормы 'photo' 'C:\photo.png' 'PostData' 'ContentType'
	)
	return
}

if (TV_CLICKED == TV_CMDS_PROCESSES_RAND) {
	MsgBox, 0, % "РАНД",
	(
Синтаксис: ранд '<имя переменной, куда запишется результат>' '<минимальное число>' '<максимальное число>'

Генерирует случайное число и записывает его в переменную

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  ранд 'число' '1' '100'
  вывод Случайное число: `%число`%.
	)
	return
}

if (TV_CLICKED == TV_CMDS_NETWORK_REQUEST) {
	MsgBox, 0, % "ЗАПРОС",
	(
Синтаксис: запрос '<метод>' '<параметр #1>' '<параметр #2>' '[параметр #3]'

Вызывается объект WinHttpRequest, подробнее см.: https://docs.microsoft.com/en-us/windows/win32/winhttp/winhttprequest

> Методы:
  открыть (open) - Открывает HTTP-соединение с HTTP-ресурсом.
  отправить (send) - Отправляет HTTP-запрос на сервер HTTP.
  устХедер (SetRequestHeader) - Добавляет, изменяет или удаляет заголовок HTTP-запроса.
  таймаут (SetTimeouts) - Указывает в миллисекундах отдельные компоненты времени ожидания операции отправки и получения.
  ждатьОтвет (waitForResponse) - Указывает время ожидания для завершения асинхронного метода отправки (в секундах) с необязательным значением времени ожидания.

> Примечания:
  Во втором параметре метода "отправить" указывается имя объекта без "`%" (если загружаются данные формы).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример отправки скриншота на сервер ВКонтакте:
  скриншот C:\temp.png
  создатьДанныеФормы 'photo' 'C:\temp.png' 'PostData' 'ContentType'
  ини.прочитать 'токен_вк' '`%.консоль.папка`%\rshell_config.ini' 'vk' 'token'
  вкапи 'джсон' 'photos.getMessagesUploadServer&version=5.130'
  джсон 'джсон_сервер' 'джсон' 'response.upload_url'
  запрос 'открыть' 'POST' '`%джсон_сервер`%' '1'
  запрос 'устХедер' 'Content-Type' '`%ContentType`%' ''
  запрос 'отправить' 'PostData' '' ''
  запрос 'ждатьОтвет' '' '' ''
  пер джсон_инфо = `%.консоль.результат`%
  джсон 'сервер' 'джсон_инфо' 'server'
  джсон 'фото' 'джсон_инфо' 'photo'
  джсон 'хеш' 'джсон_инфо' 'hash'
  пер фото заменить '\"' '"' '1'
  вкапи 'джсон' 'photos.saveMessagesPhoto&server=`%сервер`%&photo=`%фото`%&hash=`%хеш`%&v=5.103'
  джсон 'owner_id' 'джсон' 'response[0].owner_id'
  джсон 'id' 'джсон' 'response[0].id'
  ранд 'рандом' '1000' '9999'
  вкапи 'джсон' 'messages.send&random_id=`%рандом`%&peer_id=`%owner_id`%&attachment=photo`%owner_id`%_`%id`%'
  вывод Фотография в личных сообщениях.
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_8) {
	MsgBox, 0, % "Версия 2.8",
	(
- Новый параметр команды "КОНСОЛЬ" под именем "ОБНОВИТЬ".
- Новая команда "СОБРАТЬ" (конвертирует пакетный файл Renux Shell в исполняемый файл (*.exe)).
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_COMPILE) {
	MsgBox, 0, % "СОБРАТЬ",
	(
Синтаксис: собрать

Конвертирует пакетный файл Renux Shell в исполняемый файл (*.exe).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_9) {
	MsgBox, 0, % "Версия 2.9",
	(
- Новая переменная `%.консоль.имя`% (выводит имя исполняемого файла Renux Shell (свое имя файла с расширением)).
- Новая переменная `%.консоль.путь`% (выводит путь к исполняемому файлу Renux Shell (путь к самому себе)).
- Новая переменная `%.консоль.папка`% (выводит путь к папке, которую выделил Renux Shell для хранения конфига и установки).
- Изменен порядок пунктов в списке обновлений в справке (теперь вверху самые актуальные версии).
- Теперь в пунктах списка обновлений указывается дата, когда была выпущена версия.
- Новые переменные с префиксом "`%.окр" (например, `%.окр.comspec`% выводит содержимое системной переменной ComSpec).
- Новая команда "ОКРУЖЕНИЕ.ОБНОВИТЬ" (уведомляет операционную систему и все текущие приложения о том, что переменные среды изменились).
- Новая команда "ОКРУЖЕНИЕ.ПОЛУЧИТЬ" (получает значение переменной окружения).
- Новая команда "ОКРУЖЕНИЕ.УСТАНОВИТЬ" (задаёт значение переменной окружения).
- Новая переменная '.консоль.рпапка' (текущий рабочий каталог консоли, в котором файлы доступны по умолчанию).
- Новая переменная '.консоль.путь' (определяет полную спецификацию файла консоли, например: C:\My Documents\renux.exe).
- Новая переменная '.консоль.путь.папка' (полный путь к каталогу, где находится консоль).
- Новая переменная '.консоль.скрипт' (полный путь к исполняемому пакетному файлу).
- Новая переменная '.система.аппдата' (полный путь и имя папки, содержащей данные приложения текущего пользователя).
- Новая переменная '.система.оаппдата' (полный путь и имя папки, содержащей данные для всех пользователей приложения).
- Новая переменная '.система.рстол' (полный путь и имя папки, содержащей файлы рабочего стола текущего пользователя).
- Новая переменная '.система.орстол' (полный путь и имя папки, содержащей файлы рабочего стола всех пользователей).
- Новая переменная '.система.64бит' (содержит 1 (истина), если ОС 64-разрядная, или 0 (ложь), если она 32-битная).
- Новая переменная '.система.документы' (полный путь и имя папки "Мои документы" текущего пользователя).
- Новая переменная '.система.прогфайлы' (каталог Program Files (например, C:\Program Files или C:\Program Files (x86))).
- Новая переменная '.система.менюпуск' (полный путь и имя папки "Программы" в меню "Пуск" текущего пользователя).
- Новая переменная '.система.оменюзапуск' (полный путь и имя папки "Программы" в меню "Пуск" для всех пользователей).
- Новая переменная '.система.стартменю' (полный путь и имя папки меню "Пуск" текущего пользователя).
- Новая переменная '.система.остартменю' (полный путь и имя папки меню «Пуск» для всех пользователей).
- Новая переменная '.система.автозапуск' (полный путь и имя папки «Автозагрузка» в меню «Пуск» текущего пользователя).
- Новая переменная '.система.оавтозапуск' (полный путь и имя папки «Автозагрузка» в меню «Пуск» для всех пользователей).
	)
	return
}

if (TV_CLICKED == TV_CMDS_ENV_UPDATE) {
	MsgBox, 0, % "ОКРУЖЕНИЕ.ОБНОВИТЬ",
	(
Синтаксис: окружение.обновить

Уведомляет операционную систему и все текущие приложения о том, что переменные среды изменились.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_CMDS_ENV_GET) {
	MsgBox, 0, % "ОКРУЖЕНИЕ.ПОЛУЧИТЬ",
	(
Синтаксис: окружение.получить '<имя переменной, куда будет помещено полученое значение>' '<Имя внешней переменной, значение которой хотим получить>'

Получает значение переменной окружения.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окружение.получить 'path' 'PATH'
	)
	return
}

if (TV_CLICKED == TV_CMDS_ENV_SET) {
	MsgBox, 0, % "ОКРУЖЕНИЕ.УСТАНОВИТЬ",
	(
Синтаксис: окружение.установить '<имя используемой переменной окружения, например "COMSPEC" или "PATH".>' '<Значение, присваиваемое переменной окружения.>'

Задаёт значение переменной окружения.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  окружение.установить 'Renux' 'Текст'
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_9_1) {
	MsgBox, 0, % "Версия 2.9.1",
	(
- Оптимизирована система обновления переменных (программа работает быстрее).
- Оптимизировано время инициализирования программы (программа запускается быстрее).
- Теперь Renux Shell может открывать файлы. Вам нужно указать вместо команды путь к файлу и нужные параметры (как в cmd.exe).
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_10) {
	MsgBox, 0, % "Версия 2.10",
	(
- Команда "джсон" больше не показывает ошибки. Ошибки указываются в окне отладки.
- Теперь при обновлении/установке программы создается ярлык в меню Пуск (дополнительное удобство).
- Теперь команды "СД.." и "СД..." работают по другому алгоритму, отличаюищийся от "СД." (подр. в справке по этим командам).
- Теперь при указании директории можно использовать часть названия (команда "СД").
- Новая команда "ФАЙЛ.ИСКАТЬ" (производит поиск по хранилищу с целью поиска файлов/папок по указанному шаблону).
- Новая команда "ФАЙЛ.ПОЛУЧИТЬ" (записывает в массив свойства файла (обычно для .EXE, .DLL файлов)).
- Теперь команда "ДИР" может искать файлы по шаблону.
- Теперь команда "СД" может обрабатывать ярлыки и переключаться к их папкам (подр. в справке, см. синтаксис).
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_FIND) {
	MsgBox, 0, % "ФАЙЛ.ИСКАТЬ",
	(
Синтаксис: файл.искать '<название массива для вывода>' '<шаблон файла>' '[режим]'

Производит поиск по хранилищу с целью поиска файлов/папок по указанному шаблону.

> Шаблон файла:
  Имя отдельного файла или папки или шаблон подстановки, например C:\Temp\*.Tmp.
  Предполагается, что <шаблон файла> находится в `%.консоль.рпапка`%, если не указан абсолютный путь.

> Режимы:
  Если пусто или опущено, включаются только файлы, а подкаталоги не рекурсивны. В противном случае укажите одну или несколько из следующих букв:
  Д = включать директории.
  Ф = включать файлы. Если Д и Ф опущены, файлы включаются, но не папки.
  Р = рекурсия в подкаталоги (подпапки). Если Р не указан, файлы и папки во вложенных папках не включаются.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

Пример: файл.искать 'файлы' '*.lnk' 'ФДР'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_GET) {
	MsgBox, 0, % "ФАЙЛ.ПОЛУЧИТЬ",
	(
Синтаксис: файл.получить '<имя массива для вывода>' '<полный путь к файлу>'

Записывает в массив свойства файла (обычно для .EXE, .DLL файлов).

> Записывает в массив следующие ключи:
CompanyName, FileDescription, FileVersion, InternalName, LegalCopyright, OriginalFileName, ProductName, ProductVersion.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Переменная изменяет свое значение на "1" (единицу) в любом случае.

Пример: файл.получить 'информация' 'C:\test.exe'
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_11) {
	MsgBox, 0, % "Версия 2.11",
	(
- Теперь в заголовке окна указывается от чьего имени запущена программы.
- Важные фиксы в команде "ЕСЛИ" (ранее была некорректная работа условия ">").
- Новая команда "ПОКА" (выполняет команду несколько раз, пока указанное выражение не станет ложным).
- Новая команда "ЦИКЛ" (выполняет команду несколько раз).
- Новая команда "ДЛЯ" (один раз повторяет серию команд для каждой пары "ключ-значение" в объекте).
- Дополнено "Краткое обучение".
- Новые ограничения для названия массивов.
	)
	return
}

if (TV_CLICKED == TV_ABOUTPROG_TEXT) {
	gosub aboutprog
}

if (TV_CLICKED == TV_UPDATELIST_2_12) {
	MsgBox, 0, % "Версия 2.12",
	(
- Мелкие фиксы и улучшения.
- Немного изменен порядок разделов в справке.
- Новая команда "ПРОГРАММА" или "??" (открывает информацию о программе, не путать со справкой).
- Теперь команда "КОНЕЦ" завершает работу пакетного файла, если он не ожидает нажатие горячих клавиш.
- Новая команда "ПАУЗА" (ожидает нажатие клавиши), альтернатива команды "КМД PAUSE".
- Теперь программа запускается как консольно-интерфейсное приложение (Renux Shell подключается к консоли, из которой его вызывают).
- Изменено поведение программы во время ошибки.
- Новая команда "СПИСОК" (выводит список всех команд программы в консоль).
- Программа больше не имеет заголовок окна по-умолчанию.
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_PAUSE) {
	MsgBox, 0, % "ПАУЗА",
	(
Синтаксис: пауза

Ожидает нажатие буквы/цифры на клавиатуре.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Переменная изменяет свое значение на "1" (единицу) в любом случае.
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_CMDLIST) {
	MsgBox, 0, % "СПИСОК",
	(
Синтаксис: список

Выводит список всех команд программы в консоль.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Использовать не целесообразно.
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_13) {
	MsgBox, 0, % "Версия 2.13",
	(
- Новая команда "ВВОДК" (ждёт, пока пользователь напечатает строку).
- Новая переменная ".КОНСОЛЬ.ПРОБЕЛ" (содержит пробел).
- Теперь программа предупреждает о возможных ошибках, если его вызывают не через командную строку.
- Программа меняет заголовок своей консоли, если она не вызвана из командных строк.
- Новая команда "ПРОЦЕСС.ИСКАТЬ" (записывает в массив список процессов с их идентификаторами).
- Поправки в синтаксисе RS: теперь программа распознает символ «"» аналогично символу «'». Другими словами, команду «мышь.передвинуть '100' '100' '50'» можно записать так - «мышь.передвинуть "100" "100" "50"». Можно использовать одинарные и двойные кавычки для обозначения границ в одной команде, например - «мышь.передвинуть "100' '100" '50"». Ошибок при этом не возникнет. 
- Новая команда "ЗВЫВОД" (изменяет режим вывода сообщений Renux).
	)
	return
}

if (TV_CLICKED == TV_CMDS_KEYBOARD_INPUT) {
	MsgBox, 0, % "ВВОДК",
	(
Синтаксис: вводк '<вывод>' '[опции]' '[конечные клавиши]'

Ждёт, пока пользователь напечатает строку.

> Аргументы:
  вывод = имя переменной для вывода
  опции = см. ниже
  конечные клавиши = см. ниже

> Опции (может быть пустым или содержать какие-то из следующих букв (в любом порядке, с пробелами или без):
  Все буквы на английской раскладке.
  
  B - Backspace игнорируется. По умолчанию нажатие Backspace удаляет последний введённый символ с конца строки. Замечание: если вводимый текст видим (например, в редакторе) и были использованы клавиши-стрелки или другое средство для перемещения по тексту, Backspace всё равно удалит последний символ текста, а не тот, что позади каретки (текстового курсора).
  I: Игнорировать ввод, генерируемый скриптами Renux Shell. Однако, ввод через команду НАПЕЧАТАТЬБ игнорируется всегда, независимо от данной настройки.
  L: Ограничение длины (например, L5). Максимальная разрешённая длина вводимой строки. Когда текст достигнет указанной длины, команда ВВОДК завершится. Если данный параметр не задан, ограничение по длине составляет 16383 символов, что также является абсолютным максимумом.
  T: Таймаут (например, T3). Через указанное число секунд команда ВВОДК завершится. Если ВВОДК завершается по таймауту, в "<вывод>" будет текст, который пользователь успел ввести. Можно задавать числом с плавающей точкой, например, 2.5.
  V: Видимость текста. По умолчанию ввод пользователя блокируется (прячется от системы). Используйте эту опцию, если хотите, чтобы ввод посылался в активное окно.

> Конечные клавиши:
  Может быть пустым или содержать список клавиш, при нажатии на любую из которых работа ВВОДК должна быть завершена (сами эти клавиши не попадут в "<вывод>").
  В списке "<конечные клавиши>" используется тот же формат, что и для команды НАПЕЧАТАТЬ. Например, при указании {Enter}.{Esc} ВВОДК будет завершаться по нажатию клавиш ENTER, точка (.) или ESCAPE. Чтобы сами фигурные скобки завершали ВВОДК, их нужно задать как {{} и/или {}}.
  Чтобы использовать Control, Alt или Shift в качестве завершающих, указывайте конкретно левую и/или правую клавишу из пары. Например, {LControl}{RControl}, но не {Control}

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  // Изменяет слово "КУ" на "Здравствуйте"
  цикл вводк 'текст' 'V' '{Space}{Enter}'`;пер текст вниз`;если '%текст%' == 'ку' то напечататьб {BackSpace 3}Здравствуйте,`%.консоль.пробел`%
	)
	return
}

if (TV_CLICKED == TV_VAR_CONSOLE_SPACE) {
	MsgBox, 0, % "Встроенные переменные > .консоль.пробел",
	(
Применение: `%.консоль.пробел`%
Описание: Переменная равная пробелу.
	)
	return
}

if (TV_CLICKED == TV_CMDS_PROCESSES_PROCF) {
	MsgBox, 0, % "ПРОЦЕСС.ИСКАТЬ",
	(
Синтаксис: процесс.искать '<имя массива для вывода>' '<полное/часть имени процесса>'

Записывает в массив список процессов с их идентификаторами.

> Параметр <имя/часть имени процесса>:
  Укажите "." для записи всех процессов.

> Пример:
  процесс.искать 'список_процессов' '.'
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_WOUTPUT) {
	MsgBox, 0, % "ЗВЫВОД",
	(
Синтаксис: звывод [параметр вывода]

Изменяет режим вывода сообщений Renux.

> Параметр вывода:
  Если опустить параметр, то вывод будет перенаправлен в консоль (по-умолчанию).
  Если первым символом с левой стороны является ":", то вывод будет перенаправлен в переменную, чье имя указано после ":").*
  Если параметр указан без первого символа (как в пункте со звездочкой) и не опущен, то вывод будет перенаправлен в файл, чей путь Вы укажете в этом аргументе.

> Примечания:
  Данная команда перенаправляет сообщения только от этой программы! Другие консольные приложения, запущенные из Renux Shell перенаправляться не будут!
  Если Вы объявляете в [параметр вывода] путь к файлу, то сначала он будет удален, после уже начнется процесс перенаправления вывода в этот файл.
  Пустые строки в вывод не записываются!
  Быстродействие программы может снизиться, пока вывод перенаправляется!
  Renux Shell будет отменять ожидание какого-либо ввода пользователя, пока перенаправление активно!
  Программа будет читать содержимое дополнительных окон RS, записывать их содержимое в вывод и закрывать эти окна.
  Если Вам нужно перенаправить вывод из консольных приложений, то воспользуйтесь встроенной командой "КМД".

> Пример с перенаправлением вывода в переменную:
  звывод :запись_вывода_команды_дир
  дир
  звывод
  вывод `%запись_вывода_команды_дир`%

> Пример с перенаправлением вывода в файл:
  звывод log.txt
  дир
  звывод
  log.txt
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_14) {
	MsgBox, 0, % "Версия 2.14",
	(
- Много изменений в команде "СПРАВКА". Подробнее в справке.
- Теперь команда "СПИСОК" работает по другой технологии.
- При нажатии в справке "О программе -> [Информация о программе]" теперь отображается кол-во команд.
- Команда "АСИНХ" временно вырезана.
- Теперь в справке указываются другие вариации команды (если имеется).
- Новая команда "ВЫВОДБ" (выводит сообщение в консоль с без перехода на новую строку).
- Новый параметр запуска "/new" (открывает RS в новом окне).
- Новый параметр запуска "/ns" (не замораживать дочерний процесс при подключении RS к консоли процесса).
- Теперь параметр запуска "/hide" работает и при не включенном режиме исполнения пакетного файла.
- Новая команда "АПДЕЙТЛИСТ" (отображает список обновлений текущей версии).
- Теперь после закрытия хоста консоли окна RS, программа будет предупреждать об этом и перезагружаться (по желанию).
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_OUTPUTL) {
	MsgBox, 0, % "ВЫВОДБ",
	(
Синтаксис: выводб <текст>

Выводит указанный текст в консоль (без новой строки).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Не имеет значения.

> Пример:
  выводб Привет, Мир!
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_UPDLIST) {
	MsgBox, 0, % "АПДЕЙТЛИСТ",
	(
Синтаксис: апдейтлист

Отображает список обновлений текущей версии.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_UPDATELIST_2_15) {
	MsgBox, 0, % "Версия 2.15",
	(
- Исправлены баги с командой "ПЕР".
- Команда "ВЫЙТИ" переименована в "СЕССИЯ" (чтобы не было путаницы в названиях команд).
- Команда "ВЫХОД" теперь имеет необязательный аргумент, который отвечает за код выхода.
- Новая команда "ВЫВОДФ" (выводит содержимое файла в консоль).
- Новая команда "ФАЙЛ.КОДИРОВКА" (устанавливает кодировку по умолчанию).
- Новая команда "КОРЗИНА.ПЕРЕМЕСТИТЬ" (отправляет файл или папку в Корзину, если это возможно).
- Новая команда "КОРЗИНА.ОЧИСТИТЬ" (очищает Корзину).
- Новая операция в команде "ПЕР" под именем "ПУТЬ" (разделяет имя файла или URL на составные части).
- Повышен лимит использования возможной памяти до 512 МБ.
- Теперь при перенаправлении вывода через команду "ЗВЫВОД" программа пропускает ввод пользователя.
- Теперь при перенаправлении вывода через команду "ЗВЫВОД" программа также захватывает содержимое почти любых окон RS.
- Теперь при перенаправлении вывода через команду "ЗВЫВОД" программа сможет перехватить вывод консольных приложений, если открыть их через команду "КМД" или "ПШ".
- Новая команда "ФАЙЛ.ПРОЧИТАТЬ.БИНАР" (читает файл в бинарном режиме).
- Новая команда "ФАЙЛ.ЗАПИСАТЬ.БИНАР" (записывает файл в бинарном режиме).
- Новая команда "КОДИРОВАТЬ.BASE64" (кодирует данные в base64).
- Новая команда "ВВОД.ОКНО" (отображает поле ввода, чтобы попросить пользователя ввести строку).
- Новая команда "ТЕКСТ.ПОКАЗАТЬ" (создает настраиваемое текстовое всплывающее окно).
- Новая команда "ТЕКСТ.СКРЫТЬ" (удаляет существующую окно-заставку, созданную через ТЕКСТ.ПОКАЗАТЬ).
- Новая команда "СДЕЛАТЬ" (выполняет команду).
- Новая команда "ВЫВОДКОНСОЛЬ" или "ВК" (выполняет команду избегая графические интерфейсы RS).
- Теперь команда "СОБРАТЬ" оптимизирует пакетный файл перед его сборкой.
- Теперь если не указывать путь к иконке в команде "СОБРАТЬ", то будет использоваться иконка программы.
- Теперь можно открыть справку асинхронно, подр. в справке по команде "СПРАВКА".
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_OUTPUT) {
	MsgBox, 0, % "ВЫВОДФ",
	(
Синтаксис: выводф <путь к файлу>

Выводит содержимое файла в консоль.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Не имеет значения.

> Пример:
  выводф test.txt
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_ENCODING) {
	MsgBox, 0, % "ФАЙЛ.КОДИРОВКА",
	(
Синтаксис: файл.кодировка [кодировка]

Устанавливает кодировку по умолчанию для команд: файл.прочитать, файл.прочитать.строка, файл.создать, а также для внутренних функций Renux Shell.

> Параметр [кодировка]:
  Если одно из следующих условий будет опущено, по умолчанию будет установлена кодировка ANSI:
  UTF-8: Unicode UTF-8, эквивалентный CP65001.
  UTF-8-RAW: Аналогично выше, но при создании нового файла не записывается порядок байтов.
  UTF-16: Unicode UTF-16 с прямым порядком байтов, эквивалентно CP1200.
  UTF-16-RAW: Аналогично выше, но при создании нового файла не записывается порядок байтов.
  CPnnn: Код страницы с нумеровкой типа nnn. См. Идентификаторы кодовой страницы.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Не имеет значения.

> Пример:
  файл.кодировка UTF-8
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_RECYCLE) {
	MsgBox, 0, % "КОРЗИНА.ПЕРЕМЕСТИТЬ",
	(
Синтаксис: корзина.переместить <путь к файлу>

Отправляет файл или папку в Корзину, если это возможно.

> Примечание:
  Чтобы отправить в Корзину папку, укажите её имя без обратной косой черты на конце.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  корзина.переместить test.txt
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_RECYCLE_EM) {
	MsgBox, 0, % "КОРЗИНА.ОЧИСТИТЬ",
	(
Синтаксис: корзина.очистить [буква диска]

Очищает Корзину.

> Параметр [буква диска]:
  Буква диска, например: C:\. Если параметр опущен, Корзина очищается для всех дисков.

> Примечание:
  Эта команда требует, чтобы был установлен Internet Explorer 4 или более поздний.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  корзина.очистить C:\
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_READ_RAW) {
	MsgBox, 0, % "ФАЙЛ.ПРОЧИТАТЬ.БИНАР",
	(
Синтаксис: файл.прочитать.бинар '<вывод бинарных данных (имя переменной)>' '<вывод размера в байтах (имя переменной)>' '<путь к файлу>'

Читает файл в бинарном режиме и записывает его содержимое в переменную.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
  
> Пример:
  файл.прочитать.бинар 'бинарные_данные' 'размер' 'test.txt'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_WRITE_RAW) {
	MsgBox, 0, % "ФАЙЛ.ЗАПИСАТЬ.БИНАР",
	(
Синтаксис: файл.записать.бинар '<ввод бинарных данных (имя переменной)>' '<размер в байтах>' '<путь к файлу>'

Записывает в файл содержимое переменной в бинарном режиме.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  файл.записать.бинар 'бинарные_данные' '`%размер`%' 'test.txt'
	)
	return
}

if (TV_CLICKED == TV_CMDS_FILE_ENC_BASE64) {
	MsgBox, 0, % "КОДИРОВАТЬ.BASE64",
	(
Синтаксис: кодировать.base64 '<вывод данных (имя переменной)>' '<ввод данных (имя переменной)>' '<размер данных в байтах>'

Кодирует данные в Base64.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  кодировать.base64 'формат_base64' 'данные' '`%размер`%'
	)
	return
}

if (TV_CLICKED == TV_CMDS_DIALOG_INPUTBOX) {
	MsgBox, 1, % "ВВОД.ОКНО",
	(
Синтаксис: ввод.окно '<вывод (имя переменной)>' '<заголовок>' '<текст>' '[скрывать? (flag=0/1)]' '[ширина]' '[высота]' '[x]' '[y]' '[имя шрифта]' '[тайм-аут]' '[текст по-умолчанию]'

Отображает поле ввода, чтобы попросить пользователя ввести строку.

> Параметры:
  <вывод> = Имя переменной, в которую будет помещена введенная пользователем строка.
  <заголовок> = Заголовок окна скрипта.
  <текст> = Поясняющий текст, отображаемый в окне. Может подсказывать пользователю, что от него требуется. Если текст длинный- его можно разбить при помощи секции переноса ``n.
  [скрывать?] = Если указать "1" - ввод будет замаскирован. Обычно используется для ввода паролей.
  [ширина] = Ширина окна в пикселях, может быть выражением. Если опущена, будет равна 375.
  [высота] = Высота окна в пикселях, может быть выражением. Если опущена, будет равна 189.
  [x] и [y] = Координаты окна от верхнего левого угла (0,0). Могут быть отрицательными. Если параметр опущен - окно будет выравнено по середине. Например если X опущен, а Y равен 0, окно будет находиться вверху в центре экрана.
  [имя шрифта] = Пока не реализовано (оставьте пустым).
  [тайм-аут] = Таймаут в секундах, может содержать десятичную точку. Если больше 2147483 (24,8 дней), то будет установлен в 2147483. По истечению времени окно будет закрыто, а `%.консоль.результат`% установлен как -1. При этом то что пользователь успел ввести будет помещено в <вывод>.
  [текст по-умолчанию] = Текст поля ввода по умолчанию, появляющийся вместе с окном. Пользователь может его стереть или изменить.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	IfMsgBox, Cancel
		return
	
	MsgBox, 0, % "ВВОД.ОКНО",
	(
> Дополнение:
  Диалоговое окно содержит поле ввода и две кнопки: Ок и Отмена;
  Пользователь может изменять размеры окна, перетаскивая границы;
  Если пользователь нажал Отмена, то <вывод> будет пустой, а `%.консоль.результат`% установлен как 0. Если нажата клавиша Ок- `%.консоль.результат`% содержит 1.

> Пример:
  ввод.окно 'телефон' 'Номер телефона' 'Введите Ваш номер телефона' '' '' '' '' '' '' '' '+7'
  ввод.окно 'пароль' 'Ввод пароля' 'Введите Ваш пароль (он будет скрыт)' '1' '640' '480' '' '' '' '' ''
  если '`%.консоль.результат`%' == '0' то вывод Кнопка ОТМЕНА была нажата.
  если '`%.консоль.результат`%' == '1' то вывод Вы указали...``nНомер телефона: `%телефон`%`nПароль: `%пароль`%
	)
	return
}

if (TV_CLICKED == TV_CMDS_DISPLAY_STXTON) {
	MsgBox, 0, % "ТЕКСТ.ПОКАЗАТЬ",
	(
Синтаксис: текст.показать '[ширина]' '[высота]' '[заголовок]' '[текст]'

Создает настраиваемое текстовое всплывающее окно.

> Параметры:
  <ширина> = Ширина в пикселях окна. По умолчанию 200.
  <высота> = Высота в пикселях окна (не включая строку заголовка). По умолчанию 0 (то есть будет показана только строка заголовка).
  <заголовок> = Название окна. По умолчанию пусто.
  <текст> = Текст окна. По умолчанию пусто. Если текст длинный, его можно разбить на несколько более коротких строк с помощью продолжения, что может улучшить читаемость и удобство обслуживания.

> Примечание:
  Чтобы максимально изменять макет и имя/цвет/размер шрифта, используйте команду ТЕКСТ.ПОКАЗАТЬ с опцией zh0, которая пропускает панель и отображает только текст. Например: ТЕКСТ.ПОКАЗАТЬ 'zh0 fs18' 'Шрифт (18 пунктов)' '' ''.
  Используйте команду ТЕКСТ.СКРЫТЬ, чтобы удалить существующее окно-заставку.
  Всплывающее окно "всегда сверху", что означает, что оно остается над всеми другими обычными окнами.
  Для этой команды возможно только одно окно в одну сессию Renux Shell.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Примеры:
  текст.показать '' '' 'Отображает только строку заголовка.' ''
  ждать.время 3000
  текст.показать '' '' 'Буфер обмена' '`%.система.клипборд`%'
  ждать.время 3000
  текст.скрыть
	)
	return
}

if (TV_CLICKED == TV_CMDS_DISPLAY_STXTON) {
	MsgBox, 0, % "ТЕКСТ.СКРЫТЬ",
	(
Синтаксис: текст.скрыть

Удаляет существующую окно-заставку, созданную через ТЕКСТ.ПОКАЗАТЬ.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).
	)
	return
}

if (TV_CLICKED == TV_CMDS_DISPLAY_TOOLTIP) {
	MsgBox, 0, % "ПОДСКАЗКА",
	(
Синтаксис: подсказка '[текст]' '[x]' '[y]' '[id]'

Создаёт окно, которое всегда будет поверх всех окон.

> Параметры:
  [текст] = Если поле пустое или пропущено, существующая подсказка (если есть) будет скрыта. В противном случае этот параметр является текстом, отображаемым во всплывающей подсказке.
  [x] и [y] = Положение X и Y всплывающей подсказки относительно экрана. Если координаты опущены, всплывающая подсказка будет показана рядом с курсором мыши.
  [id] = Опустите этот параметр, если вам не нужно, чтобы несколько всплывающих подсказок появлялись одновременно. В противном случае это число от 1 до 20, указывающее, над каким окном всплывающей подсказки работать. Если не указано, то это число 1 (первое).

> Примечание:
  Если координаты X и Y приведут к тому, что всплывающая подсказка исчезнет с экрана, она будет полностью видна.
  Подсказка отображается, пока не произойдет одно из следующих действий:
  - Сценарий заканчивается.
  - Команда ПОДСКАЗКА выполняется снова с пустым параметром [текст].
  - Пользователь нажимает на всплывающую подсказку (это может зависеть от версии операционной системы).

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Если команда исполнена без ошибок, то переменная изменяет свое значение на "1" (единицу).

> Пример:
  подсказка 'Подсказка с текстом отображается рядом с мышью'
  ждать.время 5000
  подсказка 'Подсказка с текстом отображается по координатам X и Y (100, 100)' '100' '100'
  ждать.время 5000
  подсказка 'Подсказка №1' '100' '100' '1'
  подсказка 'Подсказка №2' '100' '150' '2'
  подсказка 'Подсказка №3' '100' '200' '3'
  подсказка '' '' '' '1'; подсказка '' '' '' '2'; подсказка '' '' '' '3';
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_DO) {
	MsgBox, 0, % "СДЕЛАТЬ",
	(
Синтаксис: сделать <команда>

Выполняет команду.

> Параметры:
  <команда> - указывается команда, которую нужно выполнить.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Принимает значение переменной после выполнения команды.

> Пример:
  сделать вывод Привет
	)
	return
}

if (TV_CLICKED == TV_CMDS_CONSOLE_OUTCON) {
	MsgBox, 0, "ВЫВОДКОНСОЛЬ или ВК",
	(
Синтаксис: выводконсоль <команда>

Выполняет команду избегая графические интерфейсы RS.

> Параметры:
  <команда> - указывается команда, которую нужно выполнить.

> Переменная .КОНСОЛЬ.РЕЗУЛЬТАТ:
  Принимает значение переменной после выполнения команды.

> Пример:
  выводконсоль ??
	)
}
return

CheckTV:
IfWinNotExist, ahk_id %docswid%
{
	settimer, CheckTV, Off
	return
}

IfWinNotActive, ahk_id %docswid%
	return

if (GetKeyState("Enter", "D")) {
	Send, {Right}
	TV_CLICKED := TV_GetSelection()
	gosub open_docs
	KeyWait, Enter, U
}
return

hidetrayicon:
Menu, Tray, NoIcon
try settimer, hidetrayicon, off
return

aboutprog:
justgen = 1
executeCMD("справка")
justgen := 0, i := 0

for k, v in tvs
{
	if (k == string.up(k))
		i++
}

Gui, about:Destroy
Gui, about:Color, White
Gui, about:-MinimizeBox +hwndaboutwid +AlwaysOnTop

Gui, about:Font, C4169E1 S13 bold, Segoe UI
Gui, about:Add, Text, x12 w500 +Center, Renux Shell
Gui, about:Font, CDefault S10 norm, Segoe UI
Gui, about:Add, Link, x12 w500,
(
Командная строка Renux Shell.
Версия %version%.
Разработано <a href="http://vk.com/strdev">Streleckiy Development</a>.

Многофункциональная командная строка на русском языке "Renux Shell", позволяет автоматизировать почти любые действия в одно нажатие.
Имеет функционал, разработанный специально для пакетных файлов.
В этой версии доступно %i% команд, не учитывая скрытых.

Программа распространяется бесплатно.
)

Gui, about:Add, Button, x12 gAboutGuiEscape, Закрыть
Gui, about:Show,, % "Renux Shell: сведения"
WinWaitClose, ahk_id %aboutwid%

aboutguiescape:
Gui, about:destroy
return

checkRSWin:
WinGet, WinList, List

loop, % WinList
{
	rswin_window_id := WinList%A_Index%
	WinGet, rswin_ProcessPath, ProcessPath, ahk_id %rswin_window_id%
	if ((CurrentProcessPath == rswin_ProcessPath) && (rswin_window_id != mainwid) && (rswin_window_id != dbgwid)) {
		WinGetText, result, ahk_id %rswin_window_id%
		WinKill, ahk_id %rswin_window_id%
		
		loop, parse, result, `r`n
		{
			if (trim(A_LoopField) == "ОК") {
				result := string.right(result, string.len(result)-3)
				break
			}
		}
		
		if (trim(result) != "")
			console.writeln(trim(trim(result, "`n")))
	}
}
return