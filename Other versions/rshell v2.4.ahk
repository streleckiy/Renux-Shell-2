#SingleInstance off
#NoEnv
#NoTrayIcon

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
global cnsl_stdin, cnsl_stdout
global version := "2.4"
global root := A_AppData "\by.strdev"
global config := A_AppData "\by.strdev\rshell_config.ini"
global host := "https://streleck1y.info/renux"
global title := "Renux Shell"

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

; Для ProcessCMD()
global cmd_help, procvar, api, whr, response, ignore_err_vkapi, log, mainwid, perm_download, cmd_hks, shell_mline, shell_lines, debug_pause_menu, installed
global cmd_variables := []
global cmd_labels := []
global cmd_source := []
global cmd_hotkeys := []
global cmd_functions := []
global crypt_info := []

OnError("error")

error(e) {
	global
	console.cmd("cls & color 4F")
	
	err_message := Trim(e.Message), err_line := Trim(e.Line)
	msg := str.up(StrReplace(StrReplace(err_message, " ", "_"), ".") "_" err_line)
	what := str.up(e.what)
	
	loop, 3
		console.writeln("")
	
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
	
	pause
	exitapp
	sleep 30000
}

percent(num1, num2) {
	return (num1/num2)*100
}

; Конфиг

cmd_help =
(

[Пакетные файлы]
Вы можете комментировать строки, обозначив их двумя слэшами в начале.
Вы можете записать команды в текстовый файл. Renux его выполнит построчно. Нужно открыть файл с помощью Renux.
Вы можете переименовать свой пакетный файл, добавив в окончание ".rs". Переместить свой пакетный файл в папку Apps, которая находится в папке программы. Таким способом, Вы можете активировать пакетный файл, указав только название без ".rs" (пример названия: демо.rs; активируется командой в Renux: демо).
Если Вы хотите выполнить сразу несколько команд без пакетных файлов, то используйте Shift+Enter. Новая строка - новая команда.

[Директивы для пакетных файлов]
'#СКАЧИВАТЬ_БЕЗ_СПРОСА' - Renux сможет скачивать файлы без предупреждения пользователя.

[Примечание]
В командах с началом 'окно' в названии, в параметре 'заголовок окна' можно указать английскую букву 'A'. Это указатель на активное окно.
Укажите имя команды без параметров для просмотра справки о том, как ей воспользоваться.

[Список команд]
адз`t`t`t`tОбработать аргумент командной строки.
админ`t`t`t`tЗапросит права администратора и перезапустит сценарий (если он запущен).
атрибуты.получить`t`tЧитает атрибуты файла или папки.
атрибуты.установить`t`tИзменяет атрибуты файла или папки.
ввод`t`t`t`tЗапишет текст, который указал пользователь, в переменную.
вкапи`t`t`t`tОтправить запрос на сервер VK и записать ответ в переменную.
вывод`t`t`t`tВывести сообщение в консоль.
выход`t`t`t`tВыход из Renux.
гк`t`t`t`tАктивирует по нажатию клавиш(-и) участок сценария.
голос.громкость`t`t`tУстановит параметр громкости для преобразования текста в речь (Text-To-Speech).
голос.сказать`t`t`tПреобразует текст в речь (Text-To-Speech).
голос.скорость`t`t`tУстановит параметр скорости речи для преобразования текста в речь (Text-To-Speech).
джсон`t`t`t`tRenux обработает JSON-строку и извлечет из него то указанный Вами элемент.
диск.привод`t`t`tВыдвигает/втягивает лоток CD- или DVD-привода.
диск.получить`t`t`tПредоставляет разного рода информацию о дисках компьютера.
диск.получить.спамять`t`tОпределяет объём свободного места на диске, в мегабайтах.
если`t`t`t`tВыполнение команды при условии истинности логического выражения.
ждать.время`t`t`tОжидает указанное Вами время в мс.
ждать.нажатие`t`t`tОжидает нажатие на клавишу(-и), указанную Вами.
ждать.окно`t`t`tОжидает создание окна с указанным заголовком.
ждать.окно.активация`t`tОжидает активацию окна с указанным заголовком.
ждать.окно.деактивация`t`tОжидает деактивацию окна с указанным заголовком.
ждать.окно.закрытие`t`tОжидает закрытие окна с укаказанным заголовком.
заголовок`t`t`tИзмененит заголовок окна Renux Shell.
ини.записать`t`t`tПишет параметр в INI-файл стандартного формата.
ини.прочитать`t`t`tЧитает значение параметра из INI-файла стандартного формата.
ини.удалить`t`t`tУдаляет параметр из INI-файла стандартного формата.
информация`t`t`tИнформация о Renux Shell.
кмд`t`t`t`tВыполнит команду в командной строке.
конец`t`t`t`tПрекратит выполнение сценария и будет ждать нажатия горячих клавиш.
консоль`t`t`t`tУстановщик Renux Shell.
массив.объединить`t`tСливает один массив и записывает в указанную Вами переменную.
метка`t`t`t`tСимвольное имя, на которое обычно должен осуществляться переход.
мышь.передвинуть`t`tИмитирует передвижение мыши на определенные координаты.
напечатать`t`t`tИмитировать нажатие клавиш.
напечататьб`t`t`tИмитировать максимально быстрое нажатие клавиш.
окно.активировать`t`tАктивирует окно с указанным заголовком.
окно.вернуть`t`t`tВосстанавливает прежние размеры свёрнутого или развёрнутого окна.
окно.заголовок`t`t`tИзменит заголовок окна на указанный Вами.
окно.закрыть`t`t`tЗакроет окно с указанным Вами заголовком.
окно.показать`t`t`tПокажет скрытое окно с указанным заголовком.
окно.развернуть`t`t`tРазвернет окно с указанным заголовку.
окно.свернуть`t`t`tСвернет окно с указанным заголовком.
окно.спрятать`t`t`tСпрячет окно с указанным заголовком.
окно.элемент`t`t`tПолучить информацию о элементе окна.
окно.элемент.передвинуть`tИзменит положение элемента окна с указанным заголовком.
окно.элемент.значение`t`tИзменит значение элемента окна с указанным заголовком.
окно.элемент.напечатать`t`tИмитирует нажатия клавиш в окно или его элемент.
пер`t`t`t`tОбъявить/изменить значение переменной.
перейти`t`t`t`tБезусловный переход к определенной точке сценария, обозначенной меткой.
пост`t`t`t`tОтправляет POST-запрос на указанный Вами сервер.
пш`t`t`t`tВыполнит команду в PowerShell.
прог`t`t`t`tВзаимодействует с программами от Streleckiy Development.
рестарт`t`t`t`tПерезапустит Renux Shell.
сеть.ввод`t`t`tПередает сообщения по локальной сети.
сеть.вывод`t`t`tПолучает сообщения по локальной сети.
сеть.сканировать`t`tОтображает текущие ARP записи, опрашивая текущие данные.
сеть.сообщение`t`t`tОтправит сообщение по локальной сети и дождется его чтения.
собрать`t`t`t`t"Скомпилирует" пакетный файл Renux Shell в .exe формат.
скачать`t`t`t`tСкачать файл из Сети Интернет.
справка`t`t`t`tПолучить справку о командах.
строка.разделить`t`tРазделяет строку на подстроки, в зависимости от заданного разделителя.
строка.заменить`t`t`tЗаменяет вхождения строки поиска на строку замены.
файл.время.установить`t`tИзменяет отметку даты и времени файла или папки.
файл.время.получить`t`tВозвращает отметку даты и времени файла или папки.
файл.переместить`t`tПеремещает файл по указанному Вами пути.
файл.переместить.папка`t`tПеремещает/переименовывает папку вместе со всеми её подпапками и файлами.
файл.получить.ярлык`t`tВозвращает свойства ярлыка в виде массива.
файл.прочитать`t`t`tRenux запишет содержание файла в массив.
файл.прочитать.строка`t`tЧитает определённую строку в файле и помещает текст в переменную.
файл.создать`t`t`tRenux создаст/дополнит файл текстом по указанному Вами пути.
файл.создать.папка`t`tСоздаст папку по указанному Вами пути.
файл.создать.ярлык`t`tСоздаст ярлык, который будет активировать указанный Вами файл.
файл.удалить`t`t`tRenux удалит файл по указанному Вами пути.
файл.удалить.папка`t`tУдаляет папку по указанному Вами пути.
файл.копировать`t`t`tКопирует содержимое файла в другой файл.
файл.копировать.папка`t`tКопирует папку вместе с содержимым в другое место.
файл.размер`t`t`tОпределяет размер файла в байтах.
функция`t`t`t`tМетка, к которой можно обратиться из другого места сценария.
)

IfNotExist, % root
	warning_dir = 1

; Чтение конфига
FileCreateDir, % root
checkConfig()

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
      try Return StrReplace(StrReplace(Ltrim(RTrim(this.JS.eval("JSON.stringify((" . sJson . ")" . (SubStr(key, 1, 1) = "[" ? "" : ".") . key . ",'','" . indent . "')"), symbol), symbol), "\/", "/"), "\n", "`n")
      catch
         console.warning("Плохой ключ: " key)
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
         console.warning("Плохой ключ: " key)
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
         console.warning("Плохой ключ: " key)
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
         console.warning("Плохой ключ: " key)
   }
   
   VerifyJson(sJson, silent := false) {
      try jsObj := this.JS.eval("(" sJson ")")
      catch {
         if !silent
            console.warning("Плохая JSON-строка: " sJson)
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
        StrPut(Input . "`r`n", &InBuf, "cp866")
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
        Output .= StrGet(&Buf, "cp866")
    }
    DllCall("CloseHandle", "ptr", hRead1)
    DllCall("GetExitCodeProcess", "ptr", hChild, "int *", ExitCode)
    DllCall("CloseHandle", "ptr", hChild)
    Return ExitCode
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

ProcessArgument(name) {
	global
	
	arg_name := name
	arg_process := trim(str.up(arg_name)) ; хотел arg_to_process

	if (arg_process == "/HIDE") {
		hide_mode = 1
		WinHide, ahk_id %mainwid%
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
			Menu, DMenu1, Add, 
			Menu, DMenu1, Add, Пауза перед командой, debug_pause_menu
			Menu, Gui, Add, Отладка, :dmenu1
			
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
	global
	
	if (shell_mode) {
		if ((GetKeyState("Ctrl", "P")) && (GetKeyState("C", "P"))) {
			exitapp
		}
		
		for key in cmd_functions 
		{
			if (str.up(trim(key)) == str.up(trim(cmd))) {
				if debug
					console.writeln("[DEBUG] Переход на функцию " key " успешен.")
				
				script := cmd_functions[key]
				loop, parse, script, `n
				{
					pc_result := _processCMD(A_LoopField)
					if debug
						console.writeln("[DEBUG] Функция вернула: " pc_result)
				}
				
				return 1
			}
		}
		
		pc_result := _processCMD(cmd)
		
		if debug
			console.writeln("[DEBUG] Функция вернула: " pc_result)
	}
	else {
		Loop, parse, cmd, `r`n
		{
			pc_result := _processCMD(A_LoopField)
			if debug
				console.writeln("[DEBUG] Функция вернула: " pc_result)
		}
	}
	
	return pc_result
}

_processCMD(cmd) {
	global
	
	cmd := console.processVars(trim(cmd))
	cmd_text := trim(trim(cmd))
	cmd_process := str.getLine(str.up(cmd_text), 1)
	
	if (trim(cmd_process) == "") {
		return 0
	}
	
	if cmd contains %variables_explode_symbols%
	{
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
		console.setVar(".консоль.версия", version, 0)
		console.setVar(".консоль.админ", A_IsAdmin, 0)
		console.setVar(".консоль.результат", pc_result, 0)
		console.setVar(".система.тип", A_OSType, 0)
		console.setVar(".система.версия", A_OSVersion, 0)
		console.setVar(".система.пользовать", A_UserName, 0)
		console.setVar(".система.компьютер", A_ComputerName, 0)
	}
	
	for key, value in cmd_variables
		StringReplace, cmd_text, cmd_text, `%%key%`%, % value, all

	; Команды с несколькими параметрами
	loop, parse, cmd_process, % A_Space
	{
		cmd_process_first := trim(A_LoopField)
		break
	}
	
	cmd_last_first := cmd_process_first
	cmd_last := cmd_process

	ifexist, Apps\%cmd_text%.rs
	{
		shell_mode := 1
		shell_file := "Apps\" cmd_text ".rs"
		return 1
	}
	
	if ((cmd_process_first == "СПРАВКА") || (cmd_process_first == "?")) {
		return console.writeln(cmd_help)
	}
	
	if (cmd_process_first == "ВЫХОД") {
		exitapp
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
			return console.warning("Данная команда работает только в режиме исполнения пакетного файла, когда в сценарии участвует команда 'ГК'.")
		} else {
			if (!cmd_hks) {
				return console.error("В сценарии отсутствует команда 'ГК' для выполнения команды 'КОНЕЦ'.")
			}
			
			shell_mline := shell_lines+1
			return 1
		}
	}

	if (str.up(str.left(trim(cmd_text), 8)) == "ПЕРЕЙТИ ") {
		RegExMatch(cmd_text, "i)перейти (.*)", outcmd)
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
	
	if (cmd_process_first == "ИНФОРМАЦИЯ") {
		console.writeln("Streleckiy Development, 2021.")
		console.writeln("Renux Shell (командная строка), версия " version ".")
		console.writeln("")
		return 1
	}
		
	if (cmd_process_first == "МЫШЬ.ПЕРЕДВИНУТЬ") {
		RegExMatch(cmd_text, "i)мышь.передвинуть x(.*) y(.*) s(.*)", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: мышь.передвинуть x<x> y<y> s<s>
Пример: мышь.передвинуть x100 y100 s50
			)
			return console.writeln(text)
		}
		
		MouseMove, % cmdout1, % cmdout2, % cmdout3
		return 1
	}
	
	if (cmd_process_first == "СКАЧАТЬ") {
		RegExMatch(cmd_text, "i)скачать '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
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
		RegExMatch(cmd_text, "i)пост '(.*)' '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
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
	
	if (cmd_process_first == "ВЫВОД") {
		RegExMatch(cmd_text, "i)вывод (.*)", cmdout)
		return console.writeln(cmdout1)
	}
	
	if (cmd_process_first == "НАПЕЧАТАТЬ") {
		RegExMatch(cmd_text, "i)напечатать (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
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
		return 1
	}
	
	if (cmd_process_first == "НАПЕЧАТАТЬБ") {
		RegExMatch(cmd_text, "i)напечататьб (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: напечататьб <текст>
Пример: напечататьб Привет всем!
			)
			return console.writeln(text)
		}
		
		SendInput, % StrReplace(StrReplace(StrReplace(StrReplace(cmdout1, "#", "{#}"), "+", "{+}"), "^", "{^}"), "!", "{!}")
		return 1
	}
	
	if (cmd_process_first == "ЖДАТЬ.ВРЕМЯ") {
		RegExMatch(cmd_text, "i)ждать.время (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: ждать.время <время в мс>
Пример: ждать.время 5000
			)
			return console.writeln(text)
		}
		
		sleep, % cmdout1
		return 1
	}
	
	if (cmd_process_first == "ЖДАТЬ.НАЖАТИЕ") {
		RegExMatch(cmd_text, "i)ждать.нажатие '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
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
		RegExMatch(cmd_text, "i)ждать.окно (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: ждать.окно <заголовок/его часть>
Пример: ждать.окно Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinWait, % cmdout1
		return 1
	}
	
	if (cmd_process_first == "ЖДАТЬ.ОКНО.АКТИВАЦИЯ") {
		RegExMatch(cmd_text, "i)ждать.окно.активация (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: ждать.окно.активация <заголовок/его часть>
Пример: ждать.окно.активация Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinWaitActive, % cmdout1
		return 1
	}
	
	if (cmd_process_first == "ЖДАТЬ.ОКНО.ЗАКРЫТИЕ") {
		RegExMatch(cmd_text, "i)ждать.окно.закрытие (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: ждать.окно.закрытие <заголовок/его часть>
Пример: ждать.окно.закрытие Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinWaitClose, % cmdout1
		return 1
	}
	
	if (cmd_process_first == "ЖДАТЬ.ОКНО.ДЕАКТИВАЦИЯ") {
		RegExMatch(cmd_text, "i)ждать.окно.деактивация (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: ждать.окно.деактивация <заголовок/его часть>
Пример: ждать.окно.деактивация Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinWaitNotActive, % cmdout1
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.ПРОЧИТАТЬ") {
		RegExMatch(cmd_text, "i)файл.прочитать '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.прочитать '<название массива>' '<путь к файлу>'
Пример: файл.прочитать 'текст_файла' 'C:\text.txt'
			)
			return console.writeln(text)
		}
		
		FileRead, result, % cmdout2
		array_text := result, array_explode := "`r`n", array_index := -1, array_name := trim(cmdout1)
		
		loop, parse, array_text, % array_explode
		{
			array_index += 1
			console.setVar(array_name "[" array_index "]", A_LoopField, 0)
		}
		
		console.setVar(array_name "[всего]", array_index, 0)
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.УДАЛИТЬ") {
		RegExMatch(cmd_text, "i)файл.удалить '(.*)'", cmdout)
		if (trim(cmdout1) == "") {
			text =
			(
Формат: файл.удалить '<путь к файлу>'
Пример: файл.удалить 'C:\text.txt'
			)
			return console.writeln(text)
		}
		
		FileDelete, % cmdout1
		ifnotexist, % cmdout1
			return 1
		
		return console.warning("Не удалось удалить файл по пути: " cmdout1)
	}
	
	if (cmd_process_first == "ФАЙЛ.СОЗДАТЬ") {
		RegExMatch(cmd_text, "i)файл.создать '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.создать '<путь к файлу>' '<текст>'
Пример: файл.создать 'C:\text.txt' 'Привет, Мир!'
Прим.: поддерживаются символы \t, \n, \r.
			)
			return console.writeln(text)
		}
		
		FileAppend, % trim(StrReplace(StrReplace(StrReplace(cmdout2, "\n", "`n"), "\t", "`t"), "\r", "`r")), % cmdout1
		return 1
	}
	
	if (cmd_process_first == "КМД") {
		RegExMatch(cmd_text, "i)кмд (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: кмд <команда>
Пример: кмд dir
			)
			return console.writeln(text)
		}
		
		console.cmd(cmdout1)
		return 1
	}
	
	if (cmd_process_first == "АДЗ") {
		RegExMatch(cmd_text, "i)адз (.*)", cmdout)
		if (trim(cmdout1) == "") {
			text =
			(
Аргументы командной строки (регистр букв не имеет значения):
  [первый аргумент] - в первый аргумент указывается путь к файлу или другой параметр. Если будет указан путь к файлу, то Renux автоматически выполнит все команды, которые содержатся в файле. [Режим исполнения пакетного файла]
  [первый аргумент] - в первый аргумент может указываться команда, которую должен будет выполнить Renux Shell. После выполнения команды программа закроется.
  /hide - выполняться полностью в фоновом режиме. Работает только в режиме исполнения пакетного файла.
  /ignore_errors - игнорировать ошибки (работает только для режима исполнения файла).
  /ignore_warnings - игнорировать предупреждения (работает только для режима исполнения файла).
  /output_mode:<msg/print> - изменить режим вывода сообщений об ошибках/предупреждениях/информации (msg - в диалоговое окно, print - в консоль).
  /debug - режим отладки, показывает дополнительную информацию.
  /log - записывать в файл лог содержимое консоли.
			)
			return console.writeln(text)
		}
		
		return ProcessArgument(cmdout1)
	}
		
	if (cmd_process_first == "ВВОД") {
		RegExMatch(cmd_text, "i)ввод (.*)", cmdout)
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
		RegExMatch(cmd_text, "i)вкапи '(.*)' '(.*)'", cmdout)
		if (trim(cmdout1) == "") {
			text =
			(
Формат: вкапи '<переменная, куда запишется ответ>' '<текст запроса>'
Пример: вкапи 'информация' 'users.get'
			)
			return console.writeln(text)
		}
	
		if (trim(vk_token) == "") {
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
					try whr.Open("POST", "https://oauth.vk.com/token?grant_type=password&client_id=3697615&client_secret=AlVXZFMUqyrnABp8ncuU&username=" vk_login "&password=" vk_password "&v=5.103&2fa_supported=0", true)
					try whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/59.0.3071.115 Safari/537.36")
					try whr.SetRequestHeader("Content-Type","application/x-www-form-urlencoded")
					try whr.Send()
					try whr.WaitForResponse()
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
		RegExMatch(cmd_text, "i)джсон '(.*)' '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
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
		; ==
		RegExMatch(cmd_text, "i)если '(.*)' \=\= '(.*)' то (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
			if (cmdout1 == cmdout2) {
				return processCmd(cmdout3)
			} else {
				return 0
			}
		}
		
		; !=
		RegExMatch(cmd_text, "i)если '(.*)' \!\= '(.*)' то (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
			if (trim(cmdout1) != trim(cmdout2)) {
				return processCmd(cmdout3)
			} else {
				return 0
			}
		}
		
		; >
		RegExMatch(cmd_text, "i)если '(.*)' \> '(.*)' то (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
			if (cmdout1 > cmdout2) {
				return processCmd(cmdout3)
			} else {
				return 0
			}
		}
			
		; <
		RegExMatch(cmd_text, "i)если '(.*)' \< '(.*)' то (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
			if (cmdout1 > cmdout2) {
				return processCmd(cmdout3)
			} else {
				return 0
			}
		}
			
		; >=
		RegExMatch(cmd_text, "i)если '(.*)' \>\= '(.*)' то (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
			if (cmdout1 >= cmdout2) {
				return processCmd(cmdout3)
			} else {
				return 0
			}
		}
		
		; =<
		RegExMatch(cmd_text, "i)если '(.*)' \=\< '(.*)' то (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
			if (cmdout1 <= cmdout2) {
				return processCmd(cmdout3)
			} else {
				return 0
			}
		}
		
		; содержит
		RegExMatch(cmd_text, "i)если '(.*)' содержит '(.*)' то (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
			if cmdout1 contains %cmdout2%
			{
				return processCmd(cmdout3)
			} else {
				return 0
			}
		}
		
		; не содержит
		RegExMatch(cmd_text, "i)если '(.*)' не содержит '(.*)' то (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "") || (trim(cmdout3) != "")) {
			if cmdout1 not contains %cmdout2%
			{
				return processCmd(cmdout3)
			} else {
				return 0
			}
		}
			
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
    "не содержит": если '<текст>' не содержит '<текст>' то <команда, которая будет выполнена>
Пример:
    "==": если '`%пер`%' == '1' то вывод Переменная ПЕР равна единице.
    "!=": если 'привет' != 'пока' то вывод Слово "привет" не равно слову "пока".
    ">": если '40' > '5' то вывод 40 больше 5.
    "<": если '`%пер`%' < '5' то вывод Переменная ПЕР меньше 5.
    ">=": если '`%пер1`%' >= '5' то вывод Переменная ПЕР1 больше или равна пяти.
    "=<": если '4' =< '5' то вывод 4 меньше или равно 5.
    "содержит": если 'какой-то текст, который записан в переменной' содержит 'текст' то вывод Найдено слово 'текст'.
    "не содержит": если '`%текст`%' не содержит 'какую-то строку' то вывод Переменная ТЕКСТ не содержит "какую-то строку".
		)
		
		return console.writeln(text)
	}
		
	if (cmd_process_first == "ПЕР") {
		; Прибавить
		RegExMatch(cmd_text, "i)пер (.*) \+\= (.*)", cmdout)
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
		
		; Убавить
		RegExMatch(cmd_text, "i)пер (.*) \-\= (.*)", cmdout)
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
		
		; Умножение
		RegExMatch(cmd_text, "i)пер (.*) \*\= (.*)", cmdout)
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
		
		; Разделить
		RegExMatch(cmd_text, "i)пер (.*) \/\= (.*)", cmdout)
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
	
		; Округлить
		RegExMatch(cmd_text, "i)пер (.*) округлить (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
			return console.setVar(cmdout1, Round(console.getVar(cmdout1), cmdout2))
		}
			
		; Список
		RegExMatch(cmd_text, "i)пер (.*)", cmdout)
		if (trim(str.up(cmdout1)) == "СПИСОК") {
			for key, value in cmd_variables
				console.writeln(key " == " value)
			
			return 1
		}
		
		; Математика
		RegExMatch(cmd_text, "i)пер (.*) мат (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
			return console.setVar(cmdout1, console.math(cmdout2))
		}
		
		; Срез
		RegExMatch(cmd_text, "i)пер (.*) срез (.*)", cmdout)
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
		
		; Заменить
		RegExMatch(cmd_text, "i)пер (.*) заменить '(.*)' '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout4) != "")) {
			getVar := console.getVar(cmdout1)
			
			if (cmdout4 == 0) {
				StringReplace, getVar, getVar, % cmdout2, % cmdout3
			} else {
				StringReplace, getVar, getVar, % cmdout2, % cmdout3, All
			}
			
			return console.SetVar(cmdout1, getVar)
		}
		
		; Разделить
		RegExMatch(cmd_text, "i)пер (.*) разделить '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout4) != "")) {
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
		
		; Слева
		RegExMatch(cmd_text, "i)пер (.*) слева (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
			getVar := console.getVar(trim(cmdout1))
			return console.setVar(cmdout1, str.left(getVar, cmdout2))
		}
		
		; Справа
		RegExMatch(cmd_text, "i)пер (.*) справа (.*)", cmdout)
		if ((trim(cmdout1) != "") || (trim(cmdout2) != "")) {
			getVar := console.getVar(trim(cmdout1))
			return console.setVar(cmdout1, str.right(getVar, cmdout2))
		}
		
		; Длина
		RegExMatch(cmd_text, "i)пер (.*) длина", cmdout)
		if ((trim(cmdout1) != "")) {
			getVar := console.getVar(trim(cmdout1))
			return console.setVar(cmdout1, str.len(getVar))
		}
		
		; Вверх
		RegExMatch(cmd_text, "i)пер (.*) вверх")
		if ((trim(cmdout1) != "")) {
			getVar := console.getVar(trim(cmdout1))
			return console.setVar(cmdout1, str.up(getVar))
		}
		
		; Вниз
		RegExMatch(cmd_text, "i)пер (.*) вниз")
		if ((trim(cmdout1) != "")) {
			getVar := console.getVar(trim(cmdout1))
			return console.setVar(cmdout1, str.down(getVar))
		}
		
		; Строгий стандарт
		RegExMatch(cmd_text, "i)пер (.*) \= '(.*)'", cmdout)
		if (trim(cmdout1) != "") {
			return console.setVar(cmdout1, cmdout2)
		}

		text =
		(
Форматы:
    Стандарт: пер <имя> = '<значение>'
    Сложить: пер <имя> += <значение>
    Уменьшить: пер <имя> -= <значение>
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

Примеры:
    Стандарт: пер переменнаяс = 'значение переменной с'
    Сложить: пер переменная2 += 10
    Уменьшить: пер переменная3 -= 20
    Умножить: пер переменная4 *= 3
    Разделить: пер переменная5 /= 2
    Округлить: пер переменная6 округлить 0	(округляет полностью)
    Показать список переменных: пер список
    Математическое выражение: пер переменная7 мат 50+50/2*3
    Заменить: пер переменная8 заменить 'привет' 'пока' '1'
    Разделить строку: пер переменная8 разделить 'массив' ' '
    Срез: пер перемемнная8 срез 4
    Обрезать слева: пер переменная слева 5
    Обрезать справа: пер переменная справа 5
	Получить кол-во символов: пер переменная длина
    Преобразует в верхний регистр: пер переменная вверх
    Преобразует в нижний регистр: пер переменная вниз

Чтобы позднее извлечь содержимое переменной, сошлитесь на нее, поместив ее имя между знаками процента:
    Пример: вывод `%переменная1`%
Чтобы посмотреть список переменных используйте 'пер список'.

Вы можете "складывать" строки. Нужно чтобы значение переменной не было числом (сделает слияние строк).
Вы можете "уменьшать" строки. Нужно чтобы значение переменной не было числом (заменяет вхождения из второго параметра на пустоту).
Вы можете "умножать" строки. Нужно чтобы значение переменной не было числом (сделает слияние строк столько раз, сколько Вам будет нужно).
Вы можете "разделить" строки. Нужно чтобы значение переменной не было числом (запишет в значение переменной количество найденных входений в значении переменной).
		)
			
		return console.writeln(text)
	}
		
	if (cmd_process_first == "ОКНО.АКТИВИРОВАТЬ") {
		RegExMatch(cmd_text, "i)окно.активировать (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.активировать <заголовок/его часть>
Пример: окно.активировать Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinActivate, % cmdout1
		return 1
	}
		
	if (cmd_process_first == "ОКНО.ЗАКРЫТЬ") {
		RegExMatch(cmd_text, "i)окно.закрыть (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.закрыть <заголовок/его часть>
Пример: окно.закрыть Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinClose, % cmdout1
		return 1
	}
	
	if (cmd_process_first == "ОКНО.РАЗВЕРНУТЬ") {
		RegExMatch(cmd_text, "i)окно.развернуть (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.развернуть <заголовок/его часть>
Пример: окно.развернуть Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinMaximize, % cmdout1
		return 1
	}
	
	if (cmd_process_first == "ОКНО.СВЕРНУТЬ") {
		RegExMatch(cmd_text, "i)окно.свернуть (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.свернуть <заголовок/его часть>
Пример: окно.свернуть Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinMinimize, % cmdout1
		return 1
	}
		
	if (cmd_process_first == "ОКНО.ВЕРНУТЬ") {
		RegExMatch(cmd_text, "i)окно.вернуть (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.вернуть <заголовок/его часть>
Пример: окно.вернуть Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinRestore, % cmdout1
		return 1
	}
		
	if (cmd_process_first == "ОКНО.СПРЯТАТЬ") {
		RegExMatch(cmd_text, "i)окно.спрятать (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.спрятать <заголовок/его часть>
Пример: окно.спрятать Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinHide, % cmdout1
		return 1
	}
		
	if (cmd_process_first == "ОКНО.ПОКАЗАТЬ") {
		RegExMatch(cmd_text, "i)окно.показать (.*)", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: окно.показать <заголовок/его часть>
Пример: окно.показать Безымянный - Paint
			)
			return console.writeln(text)
		}
		
		WinShow, % cmdout1
		return 1
	}
		
	if (cmd_process_first == "ОКНО.ЗАГОЛОВОК") {
		RegExMatch(cmd_text, "i)окно.заголовок '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: окно.заголовок '<заголовок>' '<новый заголовок>'
Пример: окно.заголовок 'Безымянный - Paint' 'Просто Paint'
			)
			return console.writeln(text)
		}
			
		WinSetTitle, % cmdout1,, % cmdout2
		return 1
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
		return 1
	}
	
	if (cmd_process_first == "ОКНО.ЭЛЕМЕНТ.ПЕРЕДВИНУТЬ") {
		RegExMatch(cmd_text, "i)окно.элемент.передвинуть '(.*)' '(.*)' x(.*) y(.*) w(.*) h(.*)", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "") || (trim(cmdout4) == "") || (trim(cmdout5) == "") || (trim(cmdout6) == "")) {
			text =
			(
Формат: окно.элемент.передвинуть '<имя элемента>' '<заголовок окна/его часть>' x<x> y<y> w<w> h<h>
Пример: окно.элемент.передвинуть 'Static1' 'Блокнот: сведения' x100 y100 w100 h100
			)
			return console.writeln(text)
		}
			
		ControlMove, % cmdout1, % cmdout3, % cmdout4, % cmdout5, % cmdout6, % cmdout2
		return 1
	}
		
	if (cmd_process_first == "ОКНО.ЭЛЕМЕНТ.ЗНАЧЕНИЕ") {
		RegExMatch(cmd_text, "i)окно.элемент.значение '(.*)' '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: окно.элемент.значение '<имя элемента>' '<заголовок окна/его часть>' '<новое значение>'
Пример: окно.элемент.значение 'Static1' 'Блокнот: сведения' 'RENUX ДЕМОНСТРАЦИЯ'
			)
			return console.writeln(text)
		}
		
		ControlSetText, % cmdout1, % cmdout3, % cmdout2
		return 1
	}
		
	if (cmd_process_first == "ОКНО.ЭЛЕМЕНТ.НАПЕЧАТАТЬ") {
		RegExMatch(cmd_text, "i)окно.элемент.напечатать '(.*)' '(.*)' '(.*)'", cmdout)
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
		return 1
	}
		
	if (cmd_process_first == "СОБРАТЬ") {
		if (!A_IsCompiled) {
			return console.warning("Невозможно выполнить (не скомпилирован)!")
		}
			
		console.cmd("cls")
		console.writeln("Сборка в .exe файл будет реализована через Ahk2Exe.exe.")
		console.writeln("Будет сгенерирован скрипт на языке программирования AutoHotKey и переведен в .exe формат.")
		console.writeln("После запуска сгенерированного файла, он распакует Renux Shell и Ваш сценарий.")
		console.writeln("Затем сгенерированный скрипт запустит Renux Shell в режиме обработки пакетного файла с указанными Вами параметрами.")
		console.writeln("")
		console.writeln("Нажмите '1' чтобы продолжить, '0' для выхода.")
		verdict := console.waitKeys("1,0")
		
		if (verdict == 0) {
			return 0
		}
		
		compile_path:
		console.write("Укажите путь к файлу: ")
		compile_path := console.read()
		symbol = `"
	
		ifnotexist, % StrReplace(compile_path, symbol)
		{
			console.writeln("Файл по этому пути не найден!")
			goto compile_path
		}
			
		compile_icon:
		console.write("Укажите путь к иконке (*.ico): ")
		compile_icon := console.read()
		
		ifnotexist, % compile_icon
		{
			console.writeln("Файл по этому пути не найден!")
			goto compile_icon
		}
			
		console.writeln("Выполняться в скрытом режиме? [1-да/0-нет]")
		compile_hide := console.waitKeys("1,0")
		
		console.writeln("Отображать ошибки? [0-да/1-нет]")
		compile_ignore_errors := console.waitKeys("1,0")
		
		console.writeln("Отображать предупреждения? [0-да/1-нет]")
		compile_ignore_warnings := console.waitKeys("1,0")
			
		console.writeln("Режим вывода сообщений Renux? [1-в консоль, 0-диалоговое окно]")
		compile_output_mode := console.waitKeys("1,0")
		
		console.writeln("Шифрование кода? (Люди, имеющие ключи дешифровки смогут посмотреть/запустить алгоритм) [1-да/0-нет]")
		compile_encrypt_state := console.waitKeys("1,0")
		if (compile_encrypt_state) {
			console.write("Укажите ключ дешифровки №1: ")
			compile_encrypt_key1 := console.read()
			console.write("Укажите ключ дешифровки №2: ")
			compile_encrypt_key2 := console.read()
		}
		
		if (compile_output_mode == 1) {
			compile_output_mode := "print"
		} else {
			compile_output_mode := "msg"
		}
			
		console.writeln("Сжать *.exe файл? [0-не сжимать/1-сжать с помощью UPX]")
		compile_press := console.waitKeys("1,0")
		
		console.cmd("cls")
		console.writeln("[~] Процесс сборки сценария Renux в .exe файл...")
		console.writeln("")
		console.writeln("> Путь к сценарию: " compile_path)
		console.writeln("> Путь к иконке: " compile_icon)
		
		if compile_hide
			console.writeln("> Скрытый режим: Да")
		else
			console.writeln("> Скрытый режим: Нет")
		
		if compile_ignore_errors
			console.writeln("> Отображать ошибки: Нет")
		else
			console.writeln("> Отображать ошибки: Да")
			
		if compile_ignore_warnings
			console.writeln("> Отображать предупреждения: Нет")
		else
			console.writeln("> Отображать предупреждения: Да")
		
		if (compile_output_mode == "print")
			console.writeln("> Режим вывод сообщений: В консоль")
		else
			console.writeln("> Режим вывод сообщений: В диалоговое окно")
			
		
		if (compile_encrypt_state == 1) {
			console.writeln("> Шифрование алгоритма: Да")
			console.writeln("> Ключ дешифровки №1: " compile_encrypt_key1)
			console.writeln("> Ключ дешифровки №2: " compile_encrypt_key2)
		} else {
			console.writeln("> Шифрование алгоритма: Нет")
		}
			
		console.writeln("")
		console.writeln("- Проверка наличия необходимых файлов для компиляции...")
		ifnotexist, %A_ScriptDir%\Compiler\ahk2exe.exe
		{
			console.warning("Не найден файл по пути: " A_WorkingDir "\Compiler\ahk2exe.exe")
			return -1
		}
		
		ifnotexist, %A_ScriptDir%\Compiler\ansi.bin
		{
			console.warning("Не найден файл по пути: " A_WorkingDir "\Compiler\ansi.bin")
			return -1
		}
		
		ifnotexist, %A_ScriptDir%\Compiler\AutoHotkeySC.bin
		{
			console.warning("Не найден файл по пути: " A_WorkingDir "\Compiler\AutoHotkeySC.bin")
			return -1
		}
		
		ifnotexist, %A_ScriptDir%\Compiler\upx.exe
		{
			console.warning("Не найден файл по пути: " A_WorkingDir "\Compiler\upx.exe")
			return -1
		}
		
		console.writeln("- Копирование файлов...")
		
		FileCopy, % compile_path, %A_ScriptDir%\Compiler\script.rs
		FileCopy, % compile_icon, %A_ScriptDir%\Compiler\icon.ico
		FileCopy, % A_ScriptFullPath, %A_ScriptDir%\Compiler\rshell.exe
		
		console.writeln("- Оптимизация сценария...")
		FileRead, scripttext, %A_ScriptDir%\Compiler\script.rs
		scriptopt =
		scriptopt_count = 0
		
		loop, parse, scripttext, `r`n
		{
			scripttext_count := A_Index
			
			if (str.left(A_LoopField, 2) == "//") {
				continue
			}
			
			if (trim(A_LoopField) == "") {
				continue
			}
			
			scriptopt_count+=1
			
			if scriptopt
				scriptopt := scriptopt "`n" A_LoopField
			else
				scriptopt := scriptopt A_LoopField
		}
		
		console.writeln("- Оптимизировано. Из кода убрано лишних строк: " scripttext_count-scriptopt_count ".")
		FileDelete, %A_ScriptDir%\Compiler\script.rs
		
		if (compile_encrypt_state == 1) {
			console.writeln("- Шифрование алгоритма ключами дешифровки...")
			fileappend, ШИФР`n, % A_ScriptDir "\Compiler\script.rs"
			encrypt(scriptopt, A_ScriptDir "\Compiler\script.rs", compile_encrypt_key1, compile_encrypt_key2)
		}
		else {
			FileAppend, % scriptopt, %A_ScriptDir%\Compiler\script.rs
		}
	
		console.writeln("- Генерация кода для компиляции...")
		
		if compile_hide
			start_params := "/hide "
		
		if compile_ignore_errors
			start_params := start_params "/ignore_errors "
		
		if compile_ignore_warnings
			start_params := start_params "/ignore_warnings "
		
		start_params := start_params "/output_mode:" compile_output_mode
		
		FileDelete, %A_ScriptDir%\Compiler\temp.tmp
		FileAppend, 
		(
#SingleInstance off
#NoTrayIcon
SetBatchLines, -1

name = `%A_Hour`%`%A_Min`%`%A_Sec`%.rs

FileInstall, script.rs, `% name, 1
ifnotexist, `% name
{
	Msgbox, 16, Renux Shell Executor, Не удалось извлечь сценарий.
	exitapp
}

FileInstall, rshell.exe, `%A_Temp`%\rshell.exe, 1
ifnotexist, `%A_Temp`%\rshell.exe
{
	Msgbox, 16, Renux Shell Executor, Не удалось извлечь rshell.exe.
	exitapp
}

try Run, `%A_Temp`%\rshell.exe "`%A_ScriptDir`%\`%name`%" %start_params%
catch e {
	MsgBox, 16, Renux Shell Executor, `% "Не удалось запустить файл rshell.exe. Причина: " e.Message
	exitapp
}

sleep 5000
FileDelete, `% name

exitapp
		), %A_ScriptDir%\Compiler\temp.tmp
		
		console.writeln("- Комплиция сгенерированного кода...")
		RunWait, %A_ScriptDir%\Compiler\Ahk2Exe.exe /in "%A_ScriptDir%\Compiler\temp.tmp" /out "%A_ScriptDir%\Compiler\compiled.exe" /icon "%A_ScriptDir%\Compiler\icon.ico" /bin "%A_ScriptDir%\Compiler\ANSI.bin" /cp 1251, UseErrorLevel
		if (errorlevel) {
			console.warning("Не удалось выполнить: " A_ScriptDir "\Compiler\Ahk2Exe.exe")
			console.writeln("- Очистка временных файлов...")
			FileDelete, %A_ScriptDir%\Compiler\temp.tmp
			FileDelete, %A_ScriptDir%\Compiler\script.rs
			FileDelete, %A_ScriptDir%\Compiler\rshell.exe
			FileDelete, %A_ScriptDir%\Compiler\icon.ico
			return -2
		}
		
		ifnotexist, %A_ScriptDir%\Compiler\compiled.exe
		{
			console.warning("Произошла ошибка при компиляции.")
			console.writeln("- Очистка временных файлов...")
			FileDelete, %A_ScriptDir%\Compiler\temp.tmp
			FileDelete, %A_ScriptDir%\Compiler\script.rs
			FileDelete, %A_ScriptDir%\Compiler\rshell.exe
			FileDelete, %A_ScriptDir%\Compiler\icon.ico
			return -2
		}
		
		console.writeln("- Компиляция файла завершена.")
			
		if (compile_press == 1) {
			console.writeln("- Процесс сжатия скомпилированного файла...")
			RunWait, %A_ScriptDir%\Compiler\upx.exe -9 -q -o "%A_ScriptDir%\Compiler\compiled_pressed.exe" "%A_ScriptDir%\Compiler\compiled.exe",, UseErrorLevel
			if (ErrorLevel) {
				console.warning("Не удалось выполнить: " A_ScriptDir "\Compiler\upx.exe")
				console.writeln("- Очистка временных файлов...")
				FileDelete, %A_ScriptDir%\Compiler\temp.tmp
				FileDelete, %A_ScriptDir%\Compiler\script.rs
				FileDelete, %A_ScriptDir%\Compiler\rshell.exe
				FileDelete, %A_ScriptDir%\Compiler\icon.ico
				return -3
			}
			
			FileDelete, %A_ScriptDir%\Compiler\compiled.exe
			FileMove, %A_ScriptDir%\Compiler\compiled_pressed.exe, %A_ScriptDir%\Compiler\compiled.exe, 1
			console.writeln("- Сжатие файла завершено.")
		}
		
		compile_select_dir:
		SplitPath, compile_path, , , , outnamenoext
		FileSelectFile, path_to_save_compiled_file, S, %outnamenoext%.exe, Куда сохранить файл?
		if ((path_to_save_compiled_file == "ERROR") || (trim(path_to_save_compiled_file) == "")) {
			goto compile_select_dir
		}
		
		FileCopy, %A_ScriptDir%\Compiler\compiled.exe, % path_to_save_compiled_file, 1
	
		ifnotexist, % path_to_save_compiled_file
		{
			console.warning("Не удалось сохранить файл! Попробуйте указать другой путь!")
			goto compile_select_dir
		}
	
		console.writeln("- Очистка временных файлов...")
		FileDelete, %A_ScriptDir%\Compiler\temp.tmp
		FileDelete, %A_ScriptDir%\Compiler\script.rs
		FileDelete, %A_ScriptDir%\Compiler\rshell.exe
		FileDelete, %A_ScriptDir%\Compiler\icon.ico
		FileDelete, %A_ScriptDir%\Compiler\compiled.exe
		
		console.writeln("")
		console.info("Файл успешно сохранен по пути: " path_to_save_compiled_file ".")
		return 1
	}
	
	if (cmd_process_first == "СТРОКА.РАЗДЕЛИТЬ") {
		RegExMatch(cmd_text, "i)строка.разделить '(.*)' '(.*)' '(.*)'", cmdout)
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
		RegExMatch(cmd_text, "i)строка.заменить '(.*)' '(.*)' '(.*)' '(.*)' '(.*)'", cmdout)
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
		return 1
	}
	
	if (cmd_process_first == "МАССИВ.ОБЪЕДИНИТЬ") {
		RegExMatch(cmd_text, "i)массив.объединить '(.*)' '(.*)' '(.*)'", cmdout)
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
	
	if (cmd_process_first == "ИНИ.УДАЛИТЬ") { ; IniDelete, filename, section, key
		RegExMatch(cmd_text, "i)ини.удалить '(.*)' '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: ини.удалить '<путь к файлу>' '<секция>' '<ключ>'
Пример: ини.удалить 'settings.ini' 'погода' 'город'
			)
			return console.writeln(text)
		}
		
		IniDelete, % cmdout1, % cmdout2, % cmdout3
		return 1
	}
	
	if (cmd_process_first == "ИНИ.ПРОЧИТАТЬ") { ; IniRead, outputvar, filename, section, key
		RegExMatch(cmd_text, "i)ини.прочитать '(.*)' '(.*)' '(.*)' '(.*)'", cmdout)
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
	
	if (cmd_process_first == "ИНИ.ЗАПИСАТЬ") { ; IniWrite, Value, Filename, Section, Key
		RegExMatch(cmd_text, "i)ини.записать '(.*)' '(.*)' '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "") || (trim(cmdout4) == "")) {
			text =
			(
Формат: ини.записать '<значение>' '<путь к файлу>' '<секция>' '<ключ>'
Пример: ини.записать 'Москва' 'settings.ini' 'погода' 'город'
			)
			return console.writeln(text)
		}
		
		IniWrite, % cmdout1, % cmdout2, % cmdout3, % cmdout4
		return 1
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
		RegExMatch(cmd_text, "i)заголовок '(.*)'", cmdout)
		if ((trim(cmdout1) == "")) {
			text =
			(
Формат: заголовок '<новый заголовок>'
Пример: заголовок 'Мой новый заголовок'
			)
			return console.writeln(text)
		}
		
		console.cmd("title " StrReplace(cmdout1, "&"))
		return 1
	}
	
	if (cmd_process_first == "СЕТЬ.ВВОД") { ; server
		RegExMatch(cmd_text, "i)сеть.ввод (.*)\:(.*)", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: сеть.ввод <ip>:<порт>
Пример: сеть.ввод 127.0.0.1:8765
			) 
			return console.writeln(text)
		}
		
		if cmdout2 is not integer
		{
			console.warning("Порт должен быть целым числом.")
			return 0
		}
		
		network_address := cmdout1
		network_port := cmdout2
		
		console.progress("Инициализация серверных параметров...")
		socket := PrepareForIncomingConnection(Network_Address, Network_Port)
		if (socket == -1) {  ; Connection failed (it already displayed the reason).
			console.error("Операция не удалась!")
			return -1
		}
		
		Process, Exist  ; This sets ErrorLevel to this script's PID (it's done this way to support compiled scripts).
		DetectHiddenWindows On
		ScriptMainWindowId := WinExist("ahk_class ConsoleWindowClass ahk_pid " . ErrorLevel)
		DetectHiddenWindows Off
		
		; Set up the connection to notify this script via message whenever new data has arrived.
		; This avoids the need to poll the connection and thus cuts down on resource usage.
		FD_READ = 1     ; Received when data is available to be read.
		;FD_WRITE = 
		FD_CLOSE = 32   ; Received when connection has been closed.
		FD_CONNECT = 20 ; Received when connection has been made.
		if DllCall("Ws2_32\WSAAsyncSelect", "UInt", socket, "UInt", ScriptMainWindowId, "UInt", NotificationMsg, "Int", FD_CLOSE|FD_CONNECT)
		{
			console.error("Не удалось выполнить операцию. (" . DllCall("Ws2_32\WSAGetLastError") ")")
			return 1
		}
	
		console.progress("Ожидание подключения клиента (сеть.вывод)...")
		Loop ; Wait for incomming connections
		{
		; accept requests that are in the pipeline of the socket   
		   conectioncheck := DllCall("Ws2_32\accept", "UInt", socket, "UInt", &SocketAddress, "Int", SizeOfSocketAddress)
		; Ws2_22/accept returns the new Connection-Socket if a connection request was in the pipeline
		; on failure it returns an negative value
			if conectioncheck > 1
			{
			   console.info("Соединение успешно. Используйте Escape+Enter для выхода из режима.")
			   break 
		   }
			sleep 500 ; wait half 1 second then accept again
		}
		
		connection_closed := 0
		
		loop {
			console.write("# NET-" A_UserName ">")
			sendText := console.read(), repeat := 1, delay := 1
			SendData(conectioncheck,SendText,Repeat,Delay)
			SentText =
			
			if (connection_closed) {
				DllCall("Ws2_32\WSACleanup")
				return 1
			}
			
			IfWinActive, ahk_id %mainwid%
			{
				if (GetKeyState("Escape", "P")) {
					SendData(conectioncheck, "<RENUX> #DISCONNECTED#", Repeat, Delay)
					console.info("Вы отключились от " network_address ":" network_port ".")
					return 1
				}
			}
		}
	}
	
	if (cmd_process_first == "СЕТЬ.ВЫВОД") { ; client
		RegExMatch(cmd_text, "i)сеть.вывод (.*)\:(.*)", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: сеть.вывод <ip>:<порт>
Пример: сеть.вывод 127.0.0.1:8765
			)
			return console.writeln(text)
		}
		
		if cmdout2 is not integer
		{
			console.warning("Порт должен быть целым числом.")
			return 0
		}
		
		network_address := cmdout1
		network_port := cmdout2
		
		console.progress("Инициализация клиентских параметров...")
		socket := ConnectToAddress(Network_Address, Network_Port)
		if socket = -1  ; Connection failed (it already displayed the reason).
			return 0
		
		Gui, -Caption +hwndtmpwid
		Gui, Show, x-10000 y-10000, % " "
		
		Process, Exist  ; This sets ErrorLevel to this script's PID (it's done this way to support compiled scripts).
		DetectHiddenWindows On
		ScriptMainWindowId := WinExist("ahk_id " tmpwid " ahk_pid " . ErrorLevel)
		DetectHiddenWindows Off
		
		NotificationMsg = 0x5555  ; An arbitrary message number, but should be greater than 0x1000.
		OnMessage(NotificationMsg, "ReceiveData")
		
		connection_closed := 0
		
		FD_READ = 1     ; Received when data is available to be read.
		FD_CLOSE = 32   ; Received when connection has been closed.
		
		if DllCall("Ws2_32\WSAAsyncSelect", "UInt", socket, "UInt", ScriptMainWindowId, "UInt", NotificationMsg, "Int", FD_READ|FD_CLOSE)
		{
			console.error("Подключиться не удалось! (" DllCall("Ws2_32\WSAGetLastError") ")")
			return 0
		}
		
		console.info("Соединение успешно. Используйте Escape для выхода из режима.")
		return "server"
	}
	
	if (cmd_process_first == "ПШ") {
		RegExMatch(cmd_text, "i)пш (.*)", cmdout)
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
		RegExMatch(cmd_text, "i)голос.сказать (.*)", cmdout)
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
		RegExMatch(cmd_text, "i)голос.громкость (.*)", cmdout)
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
		RegExMatch(cmd_text, "i)голос.скорость (.*)", cmdout)
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
	
	if (cmd_process_first == "СЕТЬ.СООБЩЕНИЕ") {
		RegExMatch(cmd_text, "i)сеть.сообщение '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: сеть.сообщение '<IP сервера>' '<текст сообщения>'
Пример: сеть.сообщение '127.0.0.1' 'Привет, Мир!'
			)
			return console.writeln(text)
		}
		
		RunWait, msg * "/server:%cmdout1%" /w "%cmdout2%"
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.КОПИРОВАТЬ") {
		RegExMatch(cmd_text, "i)файл.копировать '(.*)' '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.копировать '<путь к файлу, который будет копироваться>' '<путь к файлу, куда будет скопировано>' '<копировать с перезаписью?(flag=1/0)>'
Пример: файл.копировать 'C:\test.txt' 'C:\test2.txt' '1'
			)
			return console.writeln(text)
		}
		
		FileCopy, % cmdout1, % cmdout2, % cmdout3
		ifexist, % cmdout2
			return 1
		else
			return 0
	}
	
	if (cmd_process_first == "ФАЙЛ.КОПИРОВАТЬ.ПАПКА") {
		RegExMatch(cmd_text, "i)файл.копировать.папка '(.*)' '(.*)' '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "")) {
			text =
			(
Формат: файл.копировать.папка '<путь к папке, которая будет копироваться>' '<путь к папке, куда будет скопировано>' '<копировать с перезаписью?(flag=1/0)>'
Пример: файл.копировать.папка 'C:\test' 'C:\test2' '1'
			)
			return console.writeln(text)
		}
		
		FileCopy, % cmdout1, % cmdout2, % cmdout3
		ifexist, % cmdout2
			return 1
		else
			return 0
	}
	
	if (cmd_process_first == "РЕСТАРТ") {
		Run, % A_ScriptFullPath
		exitapp
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.СОЗДАТЬ.ЯРЛЫК") {
		RegExMatch(cmd_text, "i)файл.создать.ярлык '(.*)' '(.*)' '(.*)' '(.*)' '(.*)' '(.*)' '(.*)' '(.*)' '(.*)'", cmdout)
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
		RegExMatch(cmd_text, "i)файл.получить.ярлык '(.*)' '(.*)'", cmdout)
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
		RegExMatch(cmd_text, "i)атрибуты.получить '(.*)' '(.*)'", cmdout)
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
		RegExMatch(cmd_text, "i)атрибуты.установить '(.*)' '(.*)'", cmdout)
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
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.ВРЕМЯ.УСТАНОВИТЬ") {
		RegExMatch(cmd_text, "i)файл.время.установить '(.*)' '(.*)'")
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
		return 1
	}
	
	if (cmd_process_first == "ФАЙЛ.ВРЕМЯ.ПОЛУЧИТЬ") {
		RegExMatch(cmd_text, "i)файл.время.получить '(.*)' '(.*)' '(.*)'")
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
		RegExMatch(cmd_text, "i)файл.размер '(.*)' '(.*)'", cmdout)
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
		RegExMatch(cmd_text, "i)файл.создать.папка '(.*)'", cmdout)
		if (trim(cmdout1) == "") {
			text =
			(
Формат: файл.создать.папка '<путь к папке>'
Пример: файл.создать.папка 'C:\test'
			)
			return console.writeln(text)
		}
		
		FileCreateDir, % cmdout1
		ifexist, % cmdout1
			return 1
		else
			return 0
	}
	
	if (cmd_process_first == "ФАЙЛ.ПЕРЕМЕСТИТЬ") {
		RegExMatch(cmd_text, "i)файл.переместить '(.*)' '(.*) '(.*)'", cmdout)
		if ((trim(cmdout1) == "") || (trim(cmdout2) == "") || (trim(cmdout3) == "")) {
			text =
			(
Формат: файл.переместить '<путь к файлу>' '<новый путь к файлу>' '<копировать с перезаписью?(flag=1/0)>'
Пример: файл.переместить 'C:\test.txt' 'C:\new_test_name.txt' '1'
			)
			return console.writeln(text)
		}
		
		FileMove, % cmdout1, % cmdout2, % cmdout3
		ifexist, % cmdout2
			return 1
		else
			return 0
	}
	
	if (cmd_process_first == "ФАЙЛ.ПЕРЕМЕСТИТЬ.ПАПКА") {
		RegExMatch(cmd_text, "i)файл.переместить.папка '(.*)' '(.*)' '(.*)'", cmdout)
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
		RegExMatch(cmd_text, "i)файл.прочитать.строка '(.*)' '(.*)' '(.*)'", cmdout)
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
		RegExMatch(cmd_text, "i)файл.удалить.папка '(.*)'", cmdout)
		if (trim(cmdout1) == "") {
			text =
			(
Формат: файл.удалить.папка '<путь к папке>'
Пример: файл.удалить.папка 'C:\test'
			)
			return console.writeln(text)
		}
		
		FileRemoveDir, % cmdout1
		ifnotexist, % cmdout1
			return 1
		
		return console.warning("Не удалось удалить папку по пути: " cmdout1)
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
		RegExMatch(cmd_text, "i)диск.получить '(.*)' '(.*)' '(.*)'", cmdout)
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
		
		cmdout2 := trim(str.down(cmdout2))
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
		RegExMatch(cmd_text, "i)диск.получить.спамять '(.*)' '(.*)'", cmdout)
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
		
		RegExMatch(cmd_text, "i)консоль (.*)", cmdout)
		if (trim(cmdout1) == "") {
			text =
			(
Формат: консоль <команда>

консоль установить: автоматическая установка на компьютер. Программа больше не будет портативной.
консоль удалить: автоматическое удаление с компьютера. Программа вновь станет портативной.
			)
			return console.writeln(text)
		}
		
		if (trim(str.up(cmdout1)) == "УСТАНОВИТЬ") {
			if (!A_IsCompiled) {
				return console.warning("Невозможно выполнить (не скомпилирован)!")
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
			
			console.progress("Копирование папки Apps в " root "...")
			FileCopyDir, Apps, %root%\Apps, 1
			
			console.progress("Копирование папки Compiler в " root "...")
			FileCopyDir, Compiler, %root%\Compiler
			
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
			
			console.writeln("")
			console.info("Установка завершена. На рабочем столе появился ярлык программы. Запускайте Renux Shell с помощью него.")
			return 1
		}
		
		if (trim(str.up(cmdout1)) == "УДАЛИТЬ") {
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
			
			SetWorkingDir, %A_AppData%
			Run, cmd.exe /c start cmd.exe /c "timeout /t 5 & rd by.strdev /s /q & chcp 1251 & title Renux Shell & cls & echo Программа удалена. Спасибо за использование. & pause & exit",, Hide
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
		if prod_num is not integer
		{
			console.warning("Нужно указать целое число.")
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
				RunWait, cmd.exe /c rd "%root%\products\%dir%" /s /q
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
					
					console.progress("Скачивание файла '" file_name "' (" file_size " байт)...")
					FileDelete, % root "\products\" prod[prod_num] "\" file_name
					URLDownloadToFile, % host "/products/" file_name, % root "\products\" prod[prod_num] "\" file_name
					sizefiles+=%file_size%
				}
				
				console.info("Операция завершена.")
			}
		}
		return 1
	}
	
	; =================================================================
	
	StringReplace, cmd_text, cmd_text, `",, All
	ifexist, % cmd_text
	{
		shell_mode := 1
		shell_file := cmd_text
		return 1
	}

	if (!shell_mode) {
		console.warning("Renux не распознал указанную Вами команду. Используйте 'СПРАВКА' для просмотра списка команд.")
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

class str {
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
		loop, parse, text, % ""
		{
			if (str.checkCyrillic(A_LoopField) == 0) {
				if (str.checkLatin(A_LoopField) == 0) {
					if (str.checkInteger(A_LoopField) == 0) {
						if (str.checkSymbol(A_LoopField) == 0) {
							return 0
						}
					}
				}
			}
		}
		
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

InsertInteger(pInteger, ByRef pDest, pOffset = 0, pSize = 4)
; The caller must ensure that pDest has sufficient capacity.  To preserve any existing contents in pDest,
; only pSize number of bytes starting at pOffset are altered in it.
{
    Loop %pSize%  ; Copy each byte in the integer into the structure as raw binary data.
        DllCall("RtlFillMemory", "UInt", &pDest + pOffset + A_Index-1, "UInt", 1, "UChar", pInteger >> 8*(A_Index-1) & 0xFF)
}

class console {
	setVar(variable, value, limit=1) {
		variable := trim(variable), value := trim(value)
		
		if (limit) {
			if (str.checkNorm(variable) == 0) {
				console.warning("Имя переменной содержит недопустимые символы и не может называться '" variable "'.")
				return 0
			}
		}
		
		try cmd_variables[variable] := value
		catch e {
			console.warning("Не удалось назначить переменную '" variable "' (возможно в названии используются запрещенные символы).")
			return 0
		}
		
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
		for key, value in cmd_variables
			StringReplace, text, text, `%%key%`%, % value, All
		
		return text
	}

	init() {
		console.create()
		process, exist
		WinGet, mainwid, ID, ahk_pid %ErrorLevel%
		RunWait, cmd.exe /c chcp 1251 > nul & title %title% & break off > nul,, UseErrorLevel
	}
	
	flushBuffer() {
		cnsl_stdout.Read(0)
	}
	
	create() {
		if (!hide_mode)
			DllCall("AllocConsole")
		
		cnsl_stdin := FileOpen(DllCall("GetStdHandle", "int", -10, "ptr"), "h `n")
		cnsl_stdout := FileOpen(DllCall("GetStdHandle", "int", -11, "ptr"), "h `n")
	}
	
	cmd(cmd) {
		RunWait, cmd.exe /c %cmd%,, UseErrorLevel
	}
	
	read() {
		result := RTrim(cnsl_stdin.ReadLine(), "`n")
		console.flushBuffer()
		
		if (!shell_mode) {
			loop
			{
				if (GetKeyState("Shift", "P")) {
					result := result "`n" RTrim(cnsl_stdin.ReadLine(), "`n")
					continue
				}
				
				break
			}
		}
		
		if log
			fileappend, % cnsl_stdin.ReadLine() "`n", log.txt
		
		return result
	}
	
	write(text) {
		if (str.left(text, 7) == "[DEBUG]") {
			StringReplace, text, text, % "[DEBUG]",,			
			LV_Add("", shell_mline, cmd_source[shell_mline], text)
			LV_ModifyCol()
			LV_Modify(LV_GetCount(), "Vis")
			sleep 1
			
			if debug_pause_menu
				console.cmd("pause")
			
			return 1
		}
		
		result := cnsl_stdout.write(text)
		console.flushBuffer()
		
		if log
			fileappend, % text, log.txt
		
		return result
	}
	
	writeln(text) {
		if (str.left(text, 7) == "[DEBUG]") {
			StringReplace, text, text, % "[DEBUG]",,			
			LV_Add("", shell_mline, cmd_source[shell_mline], text)
			LV_ModifyCol()
			LV_Modify(LV_GetCount(), "Vis")
			sleep 1
			
			if debug_pause_menu
				console.cmd("pause")
			
			return 1
		}
		
		result := cnsl_stdout.WriteLine(text)
		console.flushBuffer()
		
		if log
			fileappend, % text "`n", log.txt 
		
		return result
	}
	
	warning(text) {
		if ignore_warnings
			return -1
		
		if (output_mode == "msg")
			MsgBox, 0, % title, % text "`n`nОкно автоматически закроется через 5 секунд.", 5
		else	
			return console.writeln("[!] " text)
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
		result := cnsl_stdout.WriteLine("[~] " text)
		console.flushBuffer()
		return result
	}
	
	waitKeys(keys) { ; в параметр keys указываются клавиши, нажатие которых нужно ожидать. Разделяется символом ",".
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
		if ((!A_IsCompiled) && (param == "fromscite")) {
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

if ((hide_mode) && (!shell_mode)) {
	hide_mode = 0
	warning_hide = 1
}

if (!hide_mode)
	console.init()

if (!shell_mode) {
	processCmd(start_cmd)
}

if (warning_hide == 1) {
	console.warning("Аргумент /hide не учитывается, если Renux не находится в режиме исполнения пакетного файла.")
	warning_hide = 0
}

if (debug) {
	console.info("Режим отладки активирован.")
}

RegRead, rversion, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayVersion 
if (ErrorLevel) {
	installed = 0
} else {
	installed = 1
}

if (!shell_mode) {
	if (warning_dir == 1) {
		console.info("Судя по всему Вы запустили Renux Shell впервые. Программа выделила себе папку по пути: " root ".")
	}
	
	if (str.left(A_OSVersion, 2) != "10") {
		console.writeln("Версия Вашего ядра Windows, не совпадает с Windows 10. Возможно, Вы изменили параметры совместимости программы.")
		console.writeln("Renux Shell используются некоторые компоненты системы, существующие и работающие только в Windows 10.`n")
	}
	
	ifexist, %root%\rshell.exe
	{
		RegRead, rversion, HKLM, SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Renux Shell, DisplayVersion 
		if (trim(version) != trim(rversion)) {
			console.writeln("Обнаружено, что Вы используете другую версию программы.")
			console.writeln("Пожалуйста, установите ее, чтобы файлы с расширением *.rs открывались с новыми функциями, которые появились в этой версии.")
			console.writeln("Используйте 'консоль установить' с правами администратора для установки этой версии в систему Windows.")
			console.writeln("")
		}
		else {
			if (A_IsCompiled) {
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
				console.writeln("Сервер сообщил, что появилась новая версия Renux Shell (v" server_version "). Сейчас версия - v" version ".")
				console.writeln("Renux Shell автоматичекси обновится. Обновиться? Y - да; N - нет.")
				if (console.waitKeys("Y,N") == "Y") {
					Run, *RunAs %A_ScriptFullPath%,, UseErrorLevel
					if (errorlevel) {
						console.warning("Не удалось получить права администратора.")
						console.cmd("pause")
						goto check_updates
					}
					
					result := console.download(host "/" server_file, A_Temp "\new_rshell.exe")
					
					console.progress("Процесс: перемещение файлов...")
					FileMove, %root%\rshell.exe, %root%\rshell_old.exe, 1
					FileMove, %A_Temp%\new_rshell.exe, %root%\rshell.exe, 1
					console.progress("Процесс: обновление...")
					RunWait, %root%\rshell.exe install /hide,, UseErrorLevel
					Run, %root%\rshell.exe
					exitapp
				}
			}
		}
	} else {
		console.error("Не удалось проверить наличие новых обновлений. Работа Renux Shell продолжается...")
		console.writeln("")
	}
}

main:
;try settimer, main, off

if server_id == 1
	return

if (!shell_mode) {
	console.write("# RS-" A_UserName ">")
	command := console.read()
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
	
	goto main
}

if debug
	console.writeln("[DEBUG] Анализ пакетного файла и запись в память процесса...")

shell_lines := 0

crypt_info["status"] := 0
FileReadLine, crypt_test, % shell_file, 1
if (crypt_test == "ШИФР") {
	FileRead, crypt_script, % shell_file
	crypt_info["status"] := 1
	
	console.writeln("")
	console.writeln("== Пакетный файл зашифрован! ==")
	console.write("> Укажите ключ дешифровки №1: ")
	crypt_info["key1"] := console.read()
	console.write("> Укажите ключ дешифровки №2: ")
	crypt_info["key2"] := console.read()
	console.cmd("cls")
	
	StringReplace, crypt_script, crypt_script, % "ШИФР`r`n", % ""
	crypt_script := decrypt(crypt_script, crypt_info["key2"], crypt_info["key1"])
	
	loop, parse, crypt_script, `r`n
	{
		if (trim(A_LoopField) == "") {
			continue
		}
		
		if (trim(str.left(A_LoopField, 2)) == "//") {
			continue
		}
		
		if (trim(str.up(A_LoopField) == "#СКАЧИВАТЬ_БЕЗ_СПРОСА")) {
			perm_download_msg = 1
			continue
		}
		
		shell_lines+=1
		cmd_source[shell_lines] := A_LoopField
	}
}
else {
	func_write := 0, func_name := ""
	loop, read, % shell_file
	{
		if (trim(A_LoopReadLine) == "") {
			continue
		}
		
		if (trim(str.left(A_LoopReadLine, 2)) == "//") {
			continue
		}
		
		if (trim(str.up(A_LoopReadLine) == "#СКАЧИВАТЬ_БЕЗ_СПРОСА")) {
			perm_download_msg = 1
			continue
		}
		
		if (func_write == 1) {
			if (str.up(trim(A_LoopReadLine)) == "КОНЕЦ") {
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
				if (str.up(A_LoopField) == str.up(cmdsi2_first)) {
					console.warning("Команда '" cmdsi2 "' не может быть выполнена (нельзя создавать метки, горячие клавиши, функции и переход к ним в функции).")
					console.cmd("pause")
					exitapp
				}
			}
			
			try cmd_functions[func_name] := cmd_functions[func_name] "`n" A_LoopReadLine
			continue
		}
		
		loop, parse, A_LoopReadLine, % " "
		{
			first_line := A_LoopField
			break
		}
		
		if (str.up(trim(first_line)) == "ФУНКЦИЯ") {
			RegExMatch(A_LoopReadLine, "i)функция (.*)\:", cmdout)
			if (trim(cmdout1) != "") {
				func_write := 1, func_name := cmdout1
				
				if debug
					console.writeln("[DEBUG] Обнаружена функция " cmdout1 ".")
				
				continue
			}
		}
		
		shell_lines+=1
		cmd_source[shell_lines] := A_LoopReadLine
	}
}

for cmdsi1, cmdsi2 in cmd_source
{
	RegExMatch(cmdsi2, "i)метка (.*)\:", cmdout)
	if (trim(cmdout1) != "") {
		try cmd_labels[trim(cmdout1)] := cmdsi1
		catch e {
			console.warning("Метка с таким именем не может быть создана (#" cmdsi1 ").")
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
		
		exitapp
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
		exitapp
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

dbg2GuiClose:
Gui, dbg2:Destroy
GuiControl, dbg:show, dbgctrl
return

LauncherGuiClose:
exitapp