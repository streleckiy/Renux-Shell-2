# Renux Shell 2
Многофункциональная командная строка на русском языке с поддержкой исполнения пакетных файлов.

## О проекте.
> Один из первых моих крупных проектов, в который было вложено много времени и сил.
> Последнее официальное обновление было **8 января 2022 года**.
> После этого обновления планировалось создать проект «**Renux Shell 3**» на платформе .NET, написанный на C#, но эта затея тоже вскоре отменилась.
> Теперь планируется создание «**Renux Lang**» на C++.

## О компиляции.
> Разрабатывалось и тестировалось на платформе AutoHotkey (**версия 1.1.35.00**).
> Рекомендуется производить компиляцию именно на этой версии.
> После компиляции программа обрабатывалась через VMProtect с целью сокрытия исходного кода.

## О том, что полезного содержится в исходном коде.
> Используйте поиск по коду (**Ctrl+F**), чтобы находить описываемые ниже вещи проще.
> * Содержится класс «**Console**», который содержит самые основные методы для работы с консолью Windows (при разработке его сильно не хватало).
> * Содержится функция «**getGeoLang**», которая определяет язык пользователя.
> * Содержится класс «**JSON**», который парсит JSON-строки.
> * Содержится функция «**RunCon**», которая запускает любое **консольное** приложение и записывает его вывод в переменную.
> * Содержатся функции «**Process_Suspend**», «**Process_Resume**», «**Process_GetProcessThreadCount**», «**Process_GetProcessName**», «**Process_GetCurrentProcessID**» для работы с процессами.
> * Содержится код для авторизации в **VK** даже с поддержкой OAuth (когда требуется двухфакторная авторизация).
> * Содержится код для регистрации программы в «**Программы и компоненты**» (как установленное приложение Windows).
> * Содержится код для **самостоятельного** удаления программы. 
> * Содержится код для работы с **API Renux Shell** (некоторые функции уже не работают, **вскоре будет отключено**).
> * Содержится код для «**сборки**» пакетного файла в исполняемый файл.
> * Содержится функция «**Process_GetProcessInformation**» для получения информации о процессе.
> * Содержится функция «**Process_GetParentProcessID**» для получения информации о родительском процессе.
> * Содержится функция «**Base64Enc**», которая кодирует данные в Base64.
> * Содержится класс «**string**», который нужен тому, кому нужно больше ООП при работе со строками.
> * Содержится функция «**MoveBrightness**», которая изменяет яркость экрана (**если это возможно**).
> * Содержится функция «**SaveScreenshotToFile**», которая сохраняет снимок экрана в файл.
> * Содержится класс «**CreateFormData**», который генерирует formdata для запросов в сеть Интернет.
> * Содерится функция «**GetFileSizeFromInternet**», которая возвращает размер файла из сети Интернет.
>
> Возможно, Вы найдете что-то полезное для себя **самостоятельно**.

## О среде разработки Renux Shell 2.
> Вопрос о создании **IDE** для более упрощенной разработки пакетных файлов для Renux Shell 2 решил **HACK1EXE**, который присутствует в команде **Streleckiy Development**.
> Он разработал **IDE** на платформе **.NET** на языке программирования **C#**.
> Нажмите [сюда](https://github.com/HACK1EXE/Renux-Shell-2-IDE), чтобы перейти в репозиторий **Renux Shell 2 IDE**.

## О система версий.
> Так как ранее исходные коды и другие файлы **не загружались** на **GitHub**, после релиза все версии копировались и подписывались в директории «**Other versions**».
> Как раз-таки в этой директории и хранились все (**не утерянные**) версии исходного кода **Renux Shell 2**, включая последнюю.

## О Renux Shell API.
> Для того, чтобы работало автоматическое обновление **Renux Shell 2**, было разработано **API** на языке программирования PHP (**в этом репозитории нет серверной части Renux Shell**).
> Это также позволило реализовать **установку других программ** по **Вашему желанию** через команду «**ПРОГ**».
> Ну и не стоит забывать об автоматической отправке **анонимных** отчетов о краше программы на сервер **Renux Shell 2**.
> API Renux Shell 2 будет **работать** еще некоторое время, но **вскоре может быть отключено**.

## О известных проблемах Renux Shell 2.
> * Не сможет выходить в Интернет на Windows XP (из-за особенностей объекта WinHttpRequest).
> * Виснет GUI, пока ожидается ввод пользователя.
> * Может крашнуться, если получит необратываемое исключение при работе с исключением WinHttpRequest.

## О том, как компилировать Renux Shell 2.
> 1. Из директории «**Other versions**» выберите файл, в названии которого указана **интересующая Вас версия**.
> 2. Скачайте выбранный Вами файл на Ваше устройство.
> 3. Установите AutoHotkey последней версии (**1.\***), но рекомендуется использовать версию «**1.1.35.00**».
> 4. Откройте «**ahk2exe.exe**» через меню «**Выполнить**» (**Win + R**).
> 5. В поле «**Source (script file)**» укажите путь к скачанному Вами файлу.
> 6. В поле «**Base file (.bin, .exe)**» выберите вариант содержащий слово «**ANSI**» (**в разных версиях по-разному**).
> 7. Затем нажмите «**Convert**» или «**Compile**» (**в разных версиях по-разному**).
> 8. **Готово**. Ваш скомпилированный файл расположен в той же директории, где и хранится скачанный Вами файл (**если Вы не изменяли поле «Destination (.exe file)»**).
