
#Requires AutoHotkey v2.0
#SingleInstance Force

global GDLTimers := Map()
global GDLTimerGui := 0
global GDLTimerText := 0
global GDLAlarmGui := 0
global GDLAlarmText := 0
global GDLAlarmEndTick := 0
global LastExplorerPath := ""
global LastExplorerTick := 0
global LastSelectedFileNames := []

global IniFile := A_ScriptDir "\snippets.ini"
global Snippets := Map()
global Actions := Map()
global ManagerGui := 0
global SnippetList := 0

global SuggestionInput := 0

global SuggestionMode := ""

global SuggestionQuery := ""

global IgnoreSuggestionInput := false


Hotstring(
    "EndChars",
    " `n"
)

LoadSnippets()

RegisterBuiltInActions()
RegisterHelpCommands()
RegisterTextTransformCommands()
StartLiveSuggestionWatcher()
RegisterGDLTimers()
RegisterGDLClockAlarms()
Hotstring(":?Z:;cancela", CancelGDLTimers)
Hotstring(":?Z:;sair", ExitAndCleanupGDL)
CreateGDLTimerDisplay()
CreateGDLAlarmDisplay()
SetTimer(UpdateGDLTimerDisplay, 250)
SetTimer(CaptureExplorerSelection, 300)
SetTimer(CaptureExplorerSelectionNames, 250)
Hotstring(":?Z:;caminho", InsertSelectedPath)
Hotstring(":?Z:;nomes", CopyCachedSelectedFileNames)
Hotstring(":?Z:;backup", OpenAdminPowerShellBackup)
Hotstring(":?Z:;restore", OpenAdminPowerShellRestore)
Hotstring(":?Z:;xml", OpenSelectedXmlViewer)
Hotstring(":?Z:;kdxml", FindNfceXmlByClipboardKey)
Hotstring(":?Z:;copiatxt", CopySelectedTextFile)

^!t::ShowManager()


StartLiveSuggestionWatcher()
{
    global SuggestionInput

    if IsObject(SuggestionInput)
    {
        try
        {
            if SuggestionInput.InProgress
                return
        }
    }

    SuggestionInput := InputHook(
        "VL0"
    )

    SuggestionInput.KeyOpt(
        "{Backspace}{Escape}{Enter}{Tab}",
        "N"
    )

    SuggestionInput.OnChar := LiveSuggestionOnChar

    SuggestionInput.OnKeyDown := LiveSuggestionOnKeyDown

    SuggestionInput.OnEnd := LiveSuggestionWatcherEnded

    SuggestionInput.Start()

    SetTimer(
        EnsureLiveSuggestionWatcher,
        5000
    )
}


LiveSuggestionWatcherEnded(inputHook)
{
    SetTimer(
        RestartLiveSuggestionWatcher,
        -100
    )
}


RestartLiveSuggestionWatcher(*)
{
    StartLiveSuggestionWatcher()
}


EnsureLiveSuggestionWatcher(*)
{
    global SuggestionInput

    if !IsObject(SuggestionInput)
    {
        StartLiveSuggestionWatcher()
        return
    }

    try
    {
        if !SuggestionInput.InProgress
        {
            StartLiveSuggestionWatcher()
        }
    }
    catch
    {
        SuggestionInput := 0
        StartLiveSuggestionWatcher()
    }
}


LiveSuggestionOnChar(inputHook, char)
{
    global SuggestionMode

    global SuggestionQuery

    global IgnoreSuggestionInput

    if IgnoreSuggestionInput
        return

    SetTimer(
        ResetInvalidSuggestion,
        0
    )

    if char = ";"
    {
        SuggestionMode := ";"

        SuggestionQuery := ""

        UpdateLiveSuggestionTooltip()

        return
    }
if SuggestionMode = ""
        return

    if char = " "
    {
        if SuggestionMode = ";"
        {
            if IsSpecialDateShortcut(
                SuggestionQuery
            )
            {
                if ReplaceDateShortcutText(
                    SuggestionQuery
                )
                {
                    StopLiveSuggestions()
                    Hotstring "Reset"
                    return
                }
            }

            if TryExecuteDateShortcut(
                SuggestionQuery
            )
            {
                dateCommand := SuggestionQuery

                IgnoreSuggestionInput := true

                try
                {
                    SendEvent(
                        "{Backspace " . (StrLen(dateCommand) + 2) . "}"
                    )

                    Sleep(100)

                    TypeDateText(
                        BuildDateShortcut(
                            dateCommand
                        )
                    )
                }
                finally
                {
                    IgnoreSuggestionInput := false
                }

                StopLiveSuggestions()
                Hotstring "Reset"
                return
            }
        }

        StopLiveSuggestions()
        return
    }

    if char = "`n" || char = "`r" || char = "`t"
    {
        StopLiveSuggestions()
        return
    }


    SuggestionQuery .= char

    UpdateLiveSuggestionTooltip()
}


LiveSuggestionOnKeyDown(inputHook, vk, sc)
{
    global SuggestionMode

    global SuggestionQuery

    global IgnoreSuggestionInput

    if IgnoreSuggestionInput
        return

    SetTimer(
        ResetInvalidSuggestion,
        0
    )

    if SuggestionMode = ""
        return

    if vk = 0x08
    {
        if StrLen(SuggestionQuery) > 0
        {
            SuggestionQuery := SubStr(
                SuggestionQuery,
                1,
                StrLen(SuggestionQuery) - 1
            )

            UpdateLiveSuggestionTooltip()

            return
        }

        StopLiveSuggestions()
        return
    }

    if vk = 0x0D
    {
        StopLiveSuggestions()
        return
    }

    if vk = 0x1B
    {
        StopLiveSuggestions()
        return
    }

    if vk = 0x09
    {
        StopLiveSuggestions()
        return
    }
}


UpdateLiveSuggestionTooltip()
{
    global Snippets

    global Actions

    global SuggestionMode

    global SuggestionQuery

    if SuggestionMode = ""
    {
        HideLiveSuggestionTooltip()
        return
    }

    queryLower := StrLower(
        SuggestionQuery
    )

    tooltipText := ""

    matchCount := 0

    if SuggestionMode = ";"
    {
        tooltipText := "COMANDOS" . "  " . ";"

        keys := GetSortedMapKeys(
            Snippets
        )

        for key in keys
        {
            if queryLower != ""
            {
                if SubStr(
                    StrLower(key),
                    1,
                    StrLen(queryLower)
                ) != queryLower
                {
                    continue
                }
            }

            matchCount += 1

            description := GetSnippetSuggestionDescription(
                key
            )

            tooltipText .= "`n;" . key

            if description != ""
            {
                tooltipText .= "  →  " . description
            }
        }

        if queryLower = ""
            || SubStr("help", 1, StrLen(queryLower)) = queryLower
        {
            matchCount += 1
            tooltipText .= "`n;help  →  Mostrar lista completa"
        }

        specialTextCommands := Map(
            "backup", "Backup Firebird do FDB selecionado",
            "caminho", "Inserir caminho do arquivo ou pasta selecionado",
            "copiatxt", "Copiar conteudo do arquivo textual selecionado",
            "kdxml", "Localizar XML NFC-e pela chave copiada",
            "nomes", "Copiar nomes dos arquivos selecionados",
            "cancela", "Cancelar temporizadores e alarmes",
            "mai", "Texto copiado em MAIÚSCULAS",
            "min", "Texto copiado em minúsculas",
            "primai", "Iniciais Das Palavras Em Maiúsculas",
            "restore", "Restaurar FBK selecionado em nova base",
            "xml", "Analisar XML NF-e selecionado",
            "sair", "Encerrar o GDL Macro"
        )

        for specialKey, specialDescription in specialTextCommands
        {
            if queryLower != ""
            {
                if SubStr(
                    specialKey,
                    1,
                    StrLen(queryLower)
                ) != queryLower
                {
                    continue
                }
            }

            matchCount += 1
            tooltipText .= "`n;" . specialKey . "  →  " . specialDescription
        }

        actionKeys := GetSortedMapKeys(
            Actions
        )

        for key in actionKeys
        {
            if queryLower != ""
            {
                if SubStr(
                    StrLower(key),
                    1,
                    StrLen(queryLower)
                ) != queryLower
                {
                    continue
                }
            }

            matchCount += 1

            action := Actions[key]
            description := action.Description

            if Trim(description) = ""
            {
                if action.Type = "macro"
                    description := "Executar macro"
                else
                    description := action.Target
            }

            description := CompactSuggestionText(
                description
            )

            tooltipText .= "`n;" . key

            if description != ""
            {
                tooltipText .= "  →  " . description
            }
        }


        AppendSpecialDateSuggestions(
            SuggestionQuery,
            &tooltipText,
            &matchCount
        )

        if IsDateShortcutCandidate(
            SuggestionQuery
        )
        {
            matchCount += 1

            if TryExecuteDateShortcut(
                SuggestionQuery
            )
            {
                tooltipText .= "`n;"
                    . SuggestionQuery
                    . "  →  "
                    . BuildDateShortcut(
                        SuggestionQuery
                    )
            }
            else
            {
                tooltipText .= "`n;"
                    . SuggestionQuery
                    . "  →  completar data"
            }
        }
    }


    if matchCount = 0
    {
        tooltipText .= "`n"

        tooltipText .= "`n" . SuggestionMode . SuggestionQuery

        tooltipText .= "  →  nenhum comando"
    }
    else
    {
        tooltipText .= "`n"

        if matchCount = 1
        {
            tooltipText .= "`n1 opção"
        }
        else
        {
            tooltipText .= "`n" . matchCount . " opções"
        }
    }

    ShowLiveSuggestionTooltip(
        tooltipText
    )

    SetTimer(
        StopLiveSuggestions,
        0
    )

    SetTimer(
        ResetInvalidSuggestion,
        0
    )

    if matchCount = 0
    {
        SetTimer(
            ResetInvalidSuggestion,
            0
        )

        return
    }

    SetTimer(
        StopLiveSuggestions,
        0
    )
}


GetSnippetSuggestionDescription(key)
{
    global Snippets

    if key = "olá"
    {
        return "Saudação inteligente"
    }

    if !Snippets.Has(key)
        return ""

    description := Snippets[key]

    description := ParseSnippetEscapes(
        description
    )

    description := StrReplace(
        description,
        "`t",
        " ⇥ "
    )

    return CompactSuggestionText(
        description
    )
}


CompactSuggestionText(value)
{
    value := StrReplace(
        value,
        "`r",
        " "
    )

    value := StrReplace(
        value,
        "`n",
        " "
    )

    value := Trim(
        value
    )

    if StrLen(value) > 52
    {
        value := SubStr(
            value,
            1,
            49
        ) . "..."
    }

    return value
}


ShowLiveSuggestionTooltip(text)
{
    try
    {
        if CaretGetPos(
            &caretX,
            &caretY
        )
        {
            ToolTip(
                text,
                caretX + 8,
                caretY + 24
            )

            return
        }
    }
    catch
    {
    }

    ToolTip(
        text
    )
}


ResetInvalidSuggestion(*)
{
    SetTimer(
        ResetInvalidSuggestion,
        0
    )

    Hotstring "Reset"

    StopLiveSuggestions()
}


StopLiveSuggestions(*)
{
    global SuggestionMode

    global SuggestionQuery

    SetTimer(
        StopLiveSuggestions,
        0
    )

    SetTimer(
        ResetInvalidSuggestion,
        0
    )

    SuggestionMode := ""

    SuggestionQuery := ""

    HideLiveSuggestionTooltip()
}


HideLiveSuggestionTooltip()
{
    ToolTip()
}


RegisterHelpCommands()
{
    try
    {
        Hotstring(
            ":?Z:;help",
            (*) => ShowHelpTooltip()
        )
    }
    catch
    {
    }
}


RegisterTextTransformCommands()
{
    commands := ["mai", "min", "primai"]

    for command in commands
    {
        currentCommand := command

        try
        {
            Hotstring(
                ":?Z:;" . currentCommand,
                ExecuteClipboardTextTransform.Bind(currentCommand)
            )
        }
        catch
        {
        }
    }
}


ExecuteClipboardTextTransform(mode, *)
{
    global IgnoreSuggestionInput

    StopLiveSuggestions()

    if !ClipWait(1)
    {
        MsgBox(
            "A área de transferência está vazia ou ainda não foi sincronizada.",
            "GDLtext"
        )
        return
    }

    sourceText := A_Clipboard

    if sourceText = ""
    {
        MsgBox(
            "Não existe texto copiado para transformar.",
            "GDLtext"
        )
        return
    }

    normalizedMode := StrLower(Trim(mode))

    if normalizedMode = "mai"
    {
        transformedText := StrUpper(sourceText)
    }
    else if normalizedMode = "min"
    {
        transformedText := StrLower(sourceText)
    }
    else if normalizedMode = "primai"
    {
        transformedText := StrTitle(
            StrLower(sourceText)
        )
    }
    else
    {
        return
    }

    IgnoreSuggestionInput := true

    try
    {
        PasteMacroText(
            transformedText,
            300
        )
    }
    catch as error
    {
        MsgBox(
            "Não foi possível transformar/colar o texto.`n`nErro: "
            . error.Message,
            "GDLtext"
        )
    }
    finally
    {
        IgnoreSuggestionInput := false
    }
}


ShowHelpTooltip()
{
    global Snippets

    global Actions

    helpText := "COMANDOS DISPONÍVEIS"

    helpText .= "`n--------------------------------"


    helpText .= "`n`nTEXTOS  (;)"

    snippetKeys := GetSortedMapKeys(
        Snippets
    )

    for key in snippetKeys
    {
        if key = "olá"
        {
            description := "Saudação inteligente conforme o horário"
        }
        else
        {
            description := Snippets[key]

            description := StrReplace(
                description,
                "`r",
                " "
            )

            description := StrReplace(
                description,
                "`n",
                " "
            )

            if StrLen(description) > 58
            {
                description := SubStr(
                    description,
                    1,
                    55
                ) . "..."
            }
        }

        helpText .= "`n;" . key . "  →  " . description
    }

    helpText .= "`n;backup  →  Backup Firebird do FDB selecionado"
    helpText .= "`n;caminho  →  Inserir caminho do arquivo ou pasta selecionado"
    helpText .= "`n;copiatxt  →  Copiar conteudo do arquivo textual selecionado"
    helpText .= "`n;kdxml  →  Localizar XML NFC-e pela chave copiada"
    helpText .= "`n;cancela  →  Cancelar temporizadores e alarmes"
    helpText .= "`n;mai  →  Texto copiado em MAIÚSCULAS"
    helpText .= "`n;min  →  Texto copiado em minúsculas"
    helpText .= "`n;primai  →  Inicial de cada palavra em maiúscula"
    helpText .= "`n;restore  →  Restaurar FBK selecionado em nova base"
    helpText .= "`n;xml  →  Analisar XML NF-e selecionado"
    helpText .= "`n;sair  →  Encerrar o GDL Macro"

    helpText .= "`n;help  →  Mostrar todos os comandos"


    helpText .= "`n`nAÇÕES  (;)"

    actionKeys := GetSortedMapKeys(
        Actions
    )

    for key in actionKeys
    {
        action := Actions[key]

        description := action.Description

        if Trim(description) = ""
        {
            description := action.Target
        }

        if StrLen(description) > 58
        {
            description := SubStr(
                description,
                1,
                55
            ) . "..."
        }

        helpText .= "`n;" . key . "  →  " . description
    }


    totalCommands := Snippets.Count + Actions.Count + 11

    helpText .= "`n`n--------------------------------"
    helpText .= "`nTOTAL: " . totalCommands . " comandos"

    helpText .= "`nA ajuda fecha automaticamente."

    ToolTip(
        helpText
    )

    SetTimer(
        HideHelpTooltip,
        0
    )

    SetTimer(
        HideHelpTooltip,
        -15000
    )
}


HideHelpTooltip(*)
{
    ToolTip()
}


GetSortedMapKeys(mapObject)
{
    keysText := ""

    for key, value in mapObject
    {
        keysText .= key . "`n"
    }

    keysText := RTrim(
        keysText,
        "`n"
    )

    sortedKeys := []

    if keysText = ""
        return sortedKeys

    keysText := Sort(
        keysText
    )

    for key in StrSplit(
        keysText,
        "`n",
        "`r"
    )
    {
        sortedKeys.Push(
            key
        )
    }

    return sortedKeys
}


LoadSnippets()
{
    global IniFile
    global Snippets

    Snippets := Map()

    if !FileExist(IniFile)
    {
        CreateDefaultIni()
    }

    file := FileOpen(
        IniFile,
        "r",
        "UTF-8"
    )

    if !file
    {
        MsgBox(
            "Não foi possível abrir o arquivo snippets.ini.",
            "Text Expander"
        )

        return
    }

    content := file.Read()

    file.Close()

    currentSection := ""

    lines := StrSplit(
        content,
        "`n",
        "`r"
    )

    for line in lines
    {
        line := Trim(line)

        if line = ""
            continue

        if SubStr(line, 1, 1) = "["
        {
            if SubStr(line, -1) = "]"
            {
                currentSection := SubStr(
                    line,
                    2,
                    StrLen(line) - 2
                )

                currentSection := Trim(
                    currentSection
                )
            }

            continue
        }

        if currentSection != ""
        {
            if SubStr(line, 1, 5) = "Text="
            {
                text := SubStr(
                    line,
                    6
                )

                Snippets[currentSection] := text

                RegisterSnippet(
                    currentSection
                )
            }
        }
    }


    if !Snippets.Has("olá")
    {
        Snippets["olá"] := ""
        RegisterSnippet("olá")
    }
}


RegisterBuiltInActions()
{
    global Actions

    Actions["rust"] := {
        Type: "macro",
        Description: "Preencher acesso RustDesk",
        Delay: 250,
        Steps: [
            "177.37.167.22",
            "KEY:TAB",
            "177.37.167.22:21117",
            "KEY:TAB",
            "KEY:TAB",
            "hbQxwewnF9QjVuvny6UMa0F0xHumiSKJFEdtJzKwUFg="
        ]
    }

    RegisterSemicolonAction("rust")

    Actions["sonum"] := {
        Type: "macro",
        Description: "Colar somente números",
        Delay: 150,
        Steps: [
            "CLIP:DIGITS"
        ]
    }

    RegisterSemicolonAction("sonum")

}


ExecuteMacroAction(action)
{
    defaultDelay := action.Delay

    if defaultDelay < 0
        defaultDelay := 0

    for step in action.Steps
    {
        step := Trim(step)

        if step = ""
            continue

        if RegExMatch(
            step,
            "i)^(WAIT|SLEEP)\s*:\s*(\d+)$",
            &waitMatch
        )
        {
            Sleep(
                Integer(waitMatch[2])
            )
            continue
        }

        if RegExMatch(
            step,
            "i)^KEY\s*:\s*(.+)$",
            &keyMatch
        )
        {
            SendMacroKey(
                Trim(keyMatch[1])
            )

            if defaultDelay > 0
                Sleep(defaultDelay)

            continue
        }

        if RegExMatch(
            step,
            "i)^CLIP\s*:\s*(DIGITS|NUMBERS|NUMEROS)$"
        )
        {
            PasteClipboardDigits(
                defaultDelay
            )

            continue
        }

        if RegExMatch(
            step,
            "i)^TEXT\s*:\s*(.*)$",
            &textMatch
        )
        {
            PasteMacroText(
                ExpandEnvironmentVariables(textMatch[1]),
                defaultDelay
            )

            continue
        }

        if RegExMatch(
            step,
            "^\{.+\}$"
        )
        {
            Send(step)

            if defaultDelay > 0
                Sleep(defaultDelay)

            continue
        }

        PasteMacroText(
            ExpandEnvironmentVariables(step),
            defaultDelay
        )
    }
}


PasteClipboardDigits(postDelay := 180)
{
    if !ClipWait(1)
    {
        throw Error(
            "A área de transferência está vazia ou ainda não foi sincronizada."
        )
    }

    sourceText := A_Clipboard

    digitsOnly := RegExReplace(
        sourceText,
        "\D",
        ""
    )

    if digitsOnly = ""
    {
        throw Error(
            "O conteúdo copiado não possui números."
        )
    }

    PasteMacroText(
        digitsOnly,
        postDelay
    )
}


PasteMacroText(value, postDelay := 180)
{
    savedClipboard := ClipboardAll()

    A_Clipboard := ""

    A_Clipboard := value

    if !ClipWait(1)
    {
        A_Clipboard := savedClipboard

        throw Error(
            "Não foi possível preparar o texto na área de transferência."
        )
    }

    Sleep(180)

    SendEvent(
        "{Ctrl down}v{Ctrl up}"
    )

    if postDelay < 180
        postDelay := 180

    Sleep(
        postDelay
    )

    A_Clipboard := savedClipboard

    Sleep(80)
}


SendMacroKey(keyName)
{
    normalized := StrUpper(
        Trim(keyName)
    )

    if normalized = "TAB"
    {
        Send("{Tab}")
        return
    }

    if normalized = "ENTER"
    {
        Send("{Enter}")
        return
    }

    if normalized = "SHIFTTAB" || normalized = "SHIFT+TAB"
    {
        Send("+{Tab}")
        return
    }

    if normalized = "ESC" || normalized = "ESCAPE"
    {
        Send("{Escape}")
        return
    }

    if normalized = "UP"
    {
        Send("{Up}")
        return
    }

    if normalized = "DOWN"
    {
        Send("{Down}")
        return
    }

    if normalized = "LEFT"
    {
        Send("{Left}")
        return
    }

    if normalized = "RIGHT"
    {
        Send("{Right}")
        return
    }

    if normalized = "HOME"
    {
        Send("{Home}")
        return
    }

    if normalized = "END"
    {
        Send("{End}")
        return
    }

    if normalized = "BACKSPACE" || normalized = "BKSP"
    {
        Send("{Backspace}")
        return
    }

    if normalized = "DELETE" || normalized = "DEL"
    {
        Send("{Delete}")
        return
    }

    if normalized = "SPACE"
    {
        Send("{Space}")
        return
    }

    Send("{" . keyName . "}")
}


RegisterSemicolonAction(key)
{

    trigger := ":?Z:;" . key

    callback := (*) => ExecuteAction(
        key
    )

    try
    {
        Hotstring(
            trigger,
            callback
        )
    }
    catch
    {
    }
}


ExecuteAction(key)
{
    global Actions

    global IgnoreSuggestionInput

    if !Actions.Has(key)
        return

    action := Actions[key]

    if action.Type = "macro"
    {
        StopLiveSuggestions()

        IgnoreSuggestionInput := true

        try
        {
            ExecuteMacroAction(
                action
            )
        }
        catch as error
        {
            mensagemErro := "Não foi possível executar a macro: " . key . ".`n`nErro: " . error.Message
            MsgBox(mensagemErro, "GDLtext")
        }
        finally
        {
            IgnoreSuggestionInput := false
        }

        return
    }

    target := ExpandEnvironmentVariables(
        action.Target
    )

    try
    {
        Run(
            target
        )
    }
    catch as error
    {
        mensagemErro := "Não foi possível executar o comando: " . key . ".`n`nDestino: " . target . "`n`nErro: " . error.Message
        MsgBox(mensagemErro, "GDLtext")
    }
}


ExpandEnvironmentVariables(value)
{
    result := value

    while RegExMatch(
        result,
        "%([^%]+)%",
        &match
    )
    {
        variableName := match[1]

        variableValue := EnvGet(
            variableName
        )

        if variableValue = ""
            break

        result := StrReplace(
            result,
            match[0],
            variableValue
        )
    }

    return result
}


RegisterSnippet(key)
{

    trigger := ":?Z:" . ";" . key

    callback := (*) => ExecuteSnippet(
        key
    )

    try
    {
        Hotstring(
            trigger,
            callback
        )
    }
    catch
    {
    }
}


ParseSnippetEscapes(value)
{
    slash := Chr(
        92
    )

    placeholder := Chr(
        0xE000
    )

    value := StrReplace(
        value,
        slash . slash,
        placeholder
    )

    value := StrReplace(
        value,
        slash . "n",
        "`r`n"
    )

    value := StrReplace(
        value,
        slash . "t",
        "`t"
    )

    value := StrReplace(
        value,
        placeholder,
        slash
    )

    return value
}


TypeDateText(value)
{
    Loop Parse, value
    {
        SendEvent(
            A_LoopField
        )
    }
}


ReplaceDateShortcutText(command)
{
    global IgnoreSuggestionInput

    result := BuildSpecialDateShortcut(
        command
    )

    if result = ""
        return false

    IgnoreSuggestionInput := true

    try
    {
        SendEvent(
            "{Backspace " . (StrLen(command) + 2) . "}"
        )

        Sleep(150)

        TypeDateText(
            result
        )
    }
    finally
    {
        IgnoreSuggestionInput := false
    }

    return true
}


IsSpecialDateShortcut(value)
{
    return BuildSpecialDateShortcut(
        value
    ) != ""
}


BuildSpecialDateShortcut(value)
{
    command := StrLower(
        Trim(value)
    )

    today := A_Now

    currentMonthStart := FormatTime(
        today,
        "yyyyMM"
    ) . "01"

    if command = "h"
    {
        return FormatTime(
            today,
            "ddMMyyyy"
        )
    }

    if command = "a"
    {
        return FormatTime(
            DateAdd(today, 1, "Days"),
            "ddMMyyyy"
        )
    }

    if command = "o"
    {
        return FormatTime(
            DateAdd(today, -1, "Days"),
            "ddMMyyyy"
        )
    }

    if command = "im"
    {
        return FormatTime(
            currentMonthStart,
            "ddMMyyyy"
        )
    }

    if command = "fm"
    {
        currentYear := Integer(
            FormatTime(today, "yyyy")
        )

        currentMonth := Integer(
            FormatTime(today, "MM")
        )

        lastDay := DaysInMonth(
            currentMonth,
            currentYear
        )

        return Format("{:02}", lastDay)
            . Format("{:02}", currentMonth)
            . currentYear
    }

    if command = "-im"
    {
        currentYear := Integer(
            FormatTime(today, "yyyy")
        )

        currentMonth := Integer(
            FormatTime(today, "MM")
        )

        if currentMonth = 1
        {
            currentYear -= 1
            currentMonth := 12
        }
        else
        {
            currentMonth -= 1
        }

        return "01"
            . Format("{:02}", currentMonth)
            . currentYear
    }

    if command = "-fm"
    {
        previousMonthEnd := DateAdd(
            currentMonthStart,
            -1,
            "Days"
        )

        return FormatTime(
            previousMonthEnd,
            "ddMMyyyy"
        )
    }

    if RegExMatch(
        command,
        "^[+-][0-9]{1,4}$"
    )
    {
        amount := Integer(
            SubStr(command, 2)
        )

        if amount < 1
            return ""

        if SubStr(command, 1, 1) = "-"
            amount := -amount

        return FormatTime(
            DateAdd(today, amount, "Days"),
            "ddMMyyyy"
        )
    }

    return ""
}


AppendSpecialDateSuggestions(query, &tooltipText, &matchCount)
{
    queryLower := StrLower(
        query
    )

    commands := [
        ["h", "Hoje"],
        ["a", "Amanhã"],
        ["o", "Ontem"],
        ["im", "Início do mês"],
        ["fm", "Final do mês"],
        ["-im", "Início do mês passado"],
        ["-fm", "Final do mês passado"]
    ]

    for item in commands
    {
        command := item[1]
        description := item[2]

        if queryLower != ""
        {
            if SubStr(
                command,
                1,
                StrLen(queryLower)
            ) != queryLower
            {
                continue
            }
        }

        result := BuildSpecialDateShortcut(
            command
        )

        matchCount += 1

        tooltipText .= "`n;"
            . command
            . "  →  "
            . description
            . " · "
            . result
    }

    if queryLower = "+"
    {
        matchCount += 1
        tooltipText .= "`n;+N  →  N dias à frente"
    }
    else if RegExMatch(
        queryLower,
        "^\\+[0-9]{1,4}$"
    )
    {
        result := BuildSpecialDateShortcut(
            queryLower
        )

        if result != ""
        {
            matchCount += 1
            tooltipText .= "`n;"
                . queryLower
                . "  →  "
                . result
        }
    }

    if queryLower = "-"
    {
        matchCount += 1
        tooltipText .= "`n;-N  →  N dias atrás"
    }
    else if RegExMatch(
        queryLower,
        "^-[0-9]{1,4}$"
    )
    {
        result := BuildSpecialDateShortcut(
            queryLower
        )

        if result != ""
        {
            matchCount += 1
            tooltipText .= "`n;"
                . queryLower
                . "  →  "
                . result
        }
    }
}


BuildDateShortcut(value)
{
    day := SubStr(
        value,
        1,
        2
    )

    year := FormatTime(
        A_Now,
        "yyyy"
    )

    if StrLen(value) = 4
    {
        month := SubStr(
            value,
            3,
            2
        )
    }
    else
    {
        month := FormatTime(
            A_Now,
            "MM"
        )
    }

    return day . month . year
}


TryExecuteDateShortcut(value)
{
    if !RegExMatch(
        value,
        "^\d{2}(\d{2})?$"
    )
    {
        return false
    }

    day := Integer(
        SubStr(value, 1, 2)
    )

    year := Integer(
        FormatTime(A_Now, "yyyy")
    )

    if StrLen(value) = 4
    {
        month := Integer(
            SubStr(value, 3, 2)
        )
    }
    else
    {
        month := Integer(
            FormatTime(A_Now, "MM")
        )
    }

    if month < 1 || month > 12
        return false

    maxDay := DaysInMonth(
        month,
        year
    )

    if day < 1 || day > maxDay
        return false

    return true
}


DaysInMonth(month, year)
{
    if month = 2
    {
        leapYear := (
            Mod(year, 400) = 0
            || (
                Mod(year, 4) = 0
                && Mod(year, 100) != 0
            )
        )

        return leapYear ? 29 : 28
    }

    if month = 4
        || month = 6
        || month = 9
        || month = 11
    {
        return 30
    }

    return 31
}


IsDateShortcutCandidate(value)
{
    if !RegExMatch(
        value,
        "^\d{1,4}$"
    )
    {
        return false
    }

    length := StrLen(value)

    if length = 1
        return true

    if length = 2
        return TryExecuteDateShortcut(value)

    if length = 3
    {
        day := Integer(
            SubStr(value, 1, 2)
        )

        firstMonthDigit := SubStr(
            value,
            3,
            1
        )

        if day < 1 || day > 31
            return false

        return firstMonthDigit = "0"
            || firstMonthDigit = "1"
    }

    return TryExecuteDateShortcut(value)
}


ExecuteSnippet(key)
{
    global Snippets
    global IgnoreSuggestionInput

    StopLiveSuggestions()


    if key = "olá"
    {
        IgnoreSuggestionInput := true

        try
        {
            ExecuteGreeting()
        }
        finally
        {
            IgnoreSuggestionInput := false
        }

        return
    }


    if !Snippets.Has(key)
        return

    if TryExecuteDateShortcut(
        key
    )
    {
        return
    }

    text := Snippets[key]

    text := ParseSnippetEscapes(
        text
    )

    IgnoreSuggestionInput := true

    try
    {
        PasteMacroText(
            text,
            300
        )
    }
    finally
    {
        IgnoreSuggestionInput := false
    }
}


ExecuteGreeting()
{

    hour := Integer(
        A_Hour
    )

    greeting := ""


    if hour >= 5 && hour < 12
    {
        greeting := "Bom dia"
    }


    else if hour >= 12 && hour < 18
    {
        greeting := "Boa tarde"
    }


    else
    {
        greeting := "Boa noite"
    }


    text := "Olá, " . greeting . ", como posso ajudar?"

    SendText(
        text
    )
}


CreateDefaultIni()
{
    global IniFile

    text := "[bomdia]`n"
    text .= "Text=Bom dia! Tudo bem? Como posso ajudá-lo?`n`n"

    text .= "[obrigado]`n"
    text .= "Text=Muito obrigado pelo contato! Estamos à disposição.`n`n"

    text .= "[pix]`n"
    text .= "Text=Segue nossa chave Pix para pagamento.`n`n"

    text .= "[pedido]`n"
    text .= "Text=Olá! Vou verificar o status do seu pedido e já retorno.`n`n"

    text .= "[entrega]`n"
    text .= "Text=Seu pedido está em processo de entrega.`n`n"

    text .= "[olá]`n"
    text .= "Text=COMANDO_INTELIGENTE"

    file := FileOpen(
        IniFile,
        "w",
        "UTF-8"
    )

    file.Write(
        text
    )

    file.Close()
}


ShowManager(*)
{
    global ManagerGui
    global SnippetList

    if IsObject(ManagerGui)
    {
        ManagerGui.Show()
        return
    }

    ManagerGui := Gui(
        "+AlwaysOnTop",
        "Text Expander"
    )

    ManagerGui.SetFont(
        "s10",
        "Segoe UI"
    )

    ManagerGui.Add(
        "Text",
        "x20 y15 w550 h30",
        "Text Expander"
    )

    ManagerGui.Add(
        "Text",
        "x20 y45 w550 h25",
        "Comandos carregados do arquivo snippets.ini"
    )

    SnippetList := ManagerGui.Add(
        "ListView",
        "x20 y80 w560 h280 Grid",
        ["Atalho", "Texto"]
    )

    SnippetList.ModifyCol(
        1,
        120
    )

    SnippetList.ModifyCol(
        2,
        410
    )

    RefreshList()

    AddButton := ManagerGui.Add(
        "Button",
        "x20 y375 w130 h35",
        "Novo"
    )

    EditButton := ManagerGui.Add(
        "Button",
        "x160 y375 w130 h35",
        "Editar"
    )

    DeleteButton := ManagerGui.Add(
        "Button",
        "x300 y375 w130 h35",
        "Excluir"
    )

    ReloadButton := ManagerGui.Add(
        "Button",
        "x440 y375 w140 h35",
        "Recarregar"
    )

    AddButton.OnEvent(
        "Click",
        (*) => ShowAddEdit()
    )

    EditButton.OnEvent(
        "Click",
        (*) => EditSelected()
    )

    DeleteButton.OnEvent(
        "Click",
        (*) => DeleteSelected()
    )

    ReloadButton.OnEvent(
        "Click",
        (*) => ReloadScript()
    )

    SnippetList.OnEvent(
        "DoubleClick",
        (*) => EditSelected()
    )

    ManagerGui.OnEvent(
        "Close",
        (*) => ManagerGui.Hide()
    )

    ManagerGui.Show(
        "w600 h430 Center"
    )
}


RefreshList()
{
    global SnippetList
    global Snippets

    if !IsObject(SnippetList)
        return

    SnippetList.Delete()

    for key, text in Snippets
    {
        if key = "olá"
        {
            preview := "Saudação automática baseada no horário"
        }
        else
        {
            preview := StrReplace(
                text,
                "`n",
                " "
            )

            if StrLen(preview) > 70
            {
                preview := SubStr(
                    preview,
                    1,
                    70
                )

                preview .= "..."
            }
        }

        SnippetList.Add(
            "",
            ";" . key,
            preview
        )
    }
}


ShowAddEdit(key := "")
{
    global Snippets


    if key = "olá"
    {
        MsgBox(
            "O comando olá é automático.`n`nEle verifica o horário atual e escolhe entre Bom dia, Boa tarde e Boa noite.",
            "Comando inteligente"
        )

        return
    }

    editing := key != ""

    if editing
    {
        title := "Editar comando"
        initialText := Snippets[key]
    }
    else
    {
        title := "Novo comando"
        initialText := ""
    }

    EditGui := Gui(
        "+AlwaysOnTop",
        title
    )

    EditGui.SetFont(
        "s10",
        "Segoe UI"
    )

    EditGui.Add(
        "Text",
        "x20 y20",
        "Nome do atalho"
    )

    KeyEdit := EditGui.Add(
        "Edit",
        "x20 y45 w350",
        key
    )

    EditGui.Add(
        "Text",
        "x20 y80",
        "Exemplo: cliente"
    )

    EditGui.Add(
        "Text",
        "x20 y115",
        "Texto que será inserido"
    )

    TextEdit := EditGui.Add(
        "Edit",
        "x20 y140 w350 h130 Multi WantReturn",
        initialText
    )

    SaveButton := EditGui.Add(
        "Button",
        "x20 y290 w120 h35",
        "Salvar"
    )

    CancelButton := EditGui.Add(
        "Button",
        "x150 y290 w120 h35",
        "Cancelar"
    )

    SaveButton.OnEvent(
        "Click",
        (*) => SaveSnippet(
            EditGui,
            KeyEdit,
            TextEdit,
            key,
            editing
        )
    )

    CancelButton.OnEvent(
        "Click",
        (*) => EditGui.Destroy()
    )

    EditGui.OnEvent(
        "Close",
        (*) => EditGui.Destroy()
    )

    EditGui.Show(
        "w400 h345 Center"
    )

    KeyEdit.Focus()
}


SaveSnippet(
    EditGui,
    KeyEdit,
    TextEdit,
    oldKey,
    editing
)
{
    global IniFile
    global Snippets

    newKey := Trim(
        KeyEdit.Value
    )

    newKey := StrReplace(
        newKey,
        ";",
        ""
    )

    newText := TextEdit.Value

    if newKey = ""
    {
        MsgBox(
            "Digite um nome para o atalho.",
            "Text Expander"
        )

        return
    }

    if newText = ""
    {
        MsgBox(
            "Digite o texto do comando.",
            "Text Expander"
        )

        return
    }

    if newKey = "olá"
    {
        MsgBox(
            "olá é um comando inteligente reservado.",
            "Text Expander"
        )

        return
    }

    if editing && oldKey != newKey
    {
        try
        {
            IniDelete(
                IniFile,
                oldKey
            )
        }

        if Snippets.Has(oldKey)
        {
            Snippets.Delete(
                oldKey
            )
        }
    }

    IniWrite(
        newText,
        IniFile,
        newKey,
        "Text"
    )

    Snippets[newKey] := newText

    RegisterSnippet(
        newKey
    )

    EditGui.Destroy()

    RefreshList()
}


EditSelected(*)
{
    global SnippetList
    global Snippets

    row := SnippetList.GetNext()

    if row = 0
    {
        MsgBox(
            "Selecione um comando.",
            "Text Expander"
        )

        return
    }

    key := SnippetList.GetText(
        row,
        1
    )

    key := StrReplace(
        key,
        ";",
        ""
    )

    if !Snippets.Has(key)
        return

    ShowAddEdit(
        key
    )
}


DeleteSelected(*)
{
    global SnippetList
    global Snippets
    global IniFile

    row := SnippetList.GetNext()

    if row = 0
    {
        MsgBox(
            "Selecione um comando.",
            "Text Expander"
        )

        return
    }

    key := SnippetList.GetText(
        row,
        1
    )

    key := StrReplace(
        key,
        ";",
        ""
    )

    if key = "olá"
    {
        MsgBox(
            "O comando olá é integrado ao sistema e não pode ser excluído.",
            "Text Expander"
        )

        return
    }

    answer := MsgBox(
        "Deseja excluir este comando?",
        "Confirmar exclusão",
        "YesNo"
    )

    if answer != "Yes"
        return

    try
    {
        IniDelete(
            IniFile,
            key
        )
    }

    if Snippets.Has(key)
    {
        Snippets.Delete(
            key
        )
    }

    RefreshList()
}


ReloadScript(*)
{
    Reload
}



RegisterGDLTimers()
{
    Loop 3600
    {
        n := A_Index
        Hotstring(":?Z:;" . n . "s", CreateGDLTimer.Bind(n, "s"))
    }

    Loop 1440
    {
        n := A_Index
        Hotstring(":?Z:;" . n . "min", CreateGDLTimer.Bind(n, "min"))
    }

    Loop 72
    {
        n := A_Index
        Hotstring(":?Z:;" . n . "h", CreateGDLTimer.Bind(n, "h"))
    }
}

RegisterGDLClockAlarms()
{
    Loop 24
    {
        hour := A_Index - 1

        Loop 60
        {
            minute := A_Index - 1
            command := Format("{:02}:{:02}", hour, minute)

            Hotstring(
                ":?Z:;" . command,
                CreateGDLClockAlarm.Bind(hour, minute, command)
            )
        }
    }
}

CreateGDLTimer(value, unit, *)
{
    if unit = "s"
    {
        totalSeconds := value
        description := value . "s"
    }
    else if unit = "min"
    {
        totalSeconds := value * 60
        description := value . "min"
    }
    else
    {
        totalSeconds := value * 3600
        description := value . "h"
    }

    AddGDLTimer(totalSeconds, description)
    ShowGDLTimerConfirmation("Temporizador criado: " . description)
}

CreateGDLClockAlarm(hour, minute, command, *)
{
    nowHour := Integer(FormatTime(A_Now, "HH"))
    nowMinute := Integer(FormatTime(A_Now, "mm"))
    nowSecond := Integer(FormatTime(A_Now, "ss"))

    nowSeconds := (nowHour * 3600) + (nowMinute * 60) + nowSecond
    targetSeconds := (hour * 3600) + (minute * 60)

    diffSeconds := targetSeconds - nowSeconds

    if diffSeconds <= 0
        diffSeconds += 86400

    if diffSeconds > 43200
    {
        ShowGDLTimerConfirmation("Horário fora das próximas 12 horas: " . command)
        return
    }

    AddGDLTimer(diffSeconds, command)
    ShowGDLTimerConfirmation("Alarme marcado para " . command)
}

AddGDLTimer(totalSeconds, description)
{
    global GDLTimers

    id := A_TickCount . "_" . GDLTimers.Count . "_" . description
    endTick := A_TickCount + (totalSeconds * 1000)

    callback := GDLTimerFinished.Bind(id)

    GDLTimers[id] := {
        EndTick: endTick,
        Description: description,
        Callback: callback
    }

    SetTimer(callback, -(totalSeconds * 1000))
    UpdateGDLTimerDisplay()
}

GDLTimerFinished(id, *)
{
    global GDLTimers

    if !GDLTimers.Has(id)
        return

    description := GDLTimers[id].Description
    GDLTimers.Delete(id)

    UpdateGDLTimerDisplay()
    StartGDLAlarm(description)
}

CancelGDLTimers(*)
{
    global GDLTimers

    for id, timer in GDLTimers
    {
        try SetTimer(timer.Callback, 0)
    }

    GDLTimers.Clear()
    StopGDLAlarm()

    ShowGDLTimerConfirmation("Temporizadores e alarmes cancelados")
    UpdateGDLTimerDisplay()
}


ExitAndCleanupGDL(*)
{
    ; Remove do historico do Executar (Win+R) somente a entrada
    ; usada para iniciar o GDL-Macro pelo instalar.cmd.
    CleanupGDLRunHistory()

    expectedDir := A_Temp . "\GDL-Macro"
    currentDir := A_ScriptDir

    if StrLower(currentDir) = StrLower(expectedDir)
    {
        cleanupCmd := 'ping 127.0.0.1 -n 3 >nul & rmdir /s /q "' . currentDir . '"'

        try Run(
            A_ComSpec . ' /d /c "' . cleanupCmd . '"',
            A_Temp,
            "Hide"
        )
    }

    ExitApp()
}

CleanupGDLRunHistory()
{
    runMruKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"

    removedNames := []

    try
    {
        Loop Reg runMruKey, "V"
        {
            valueName := A_LoopRegName

            if valueName = "MRUList"
                continue

            value := ""

            try value := RegRead(runMruKey, valueName)
            catch
                continue

            if value = ""
                continue

            valueLower := StrLower(value)

            isGdlEntry :=
                InStr(valueLower, "raw.githubusercontent.com/gidelucas/gdl-macro/")
                || InStr(valueLower, "gidelucas/gdl-macro/main/instalar.cmd")
                || InStr(valueLower, "%temp%\g.cmd")
                || InStr(valueLower, "\g.cmd")
                || InStr(valueLower, "call %temp%\g.cmd")

            if !isGdlEntry
                continue

            try
            {
                RegDelete(runMruKey, valueName)
                removedNames.Push(valueName)
            }
        }
    }

    if removedNames.Length > 0
    {
        try
        {
            mruList := RegRead(runMruKey, "MRUList")

            for valueName in removedNames
                mruList := StrReplace(mruList, valueName)

            RegWrite(mruList, "REG_SZ", runMruKey, "MRUList")
        }
    }

    ; Segunda passada de seguranca: remove qualquer resto que ainda combine.
    try
    {
        Loop Reg runMruKey, "V"
        {
            valueName := A_LoopRegName

            if valueName = "MRUList"
                continue

            value := ""

            try value := RegRead(runMruKey, valueName)
            catch
                continue

            valueLower := StrLower(value)

            if InStr(valueLower, "gidelucas/gdl-macro")
                || InStr(valueLower, "instalar.cmd")
                || InStr(valueLower, "\g.cmd")
            {
                try RegDelete(runMruKey, valueName)
            }
        }
    }

    ; Reconstroi o MRUList somente com os valores que ainda existem.
    try
    {
        oldMru := RegRead(runMruKey, "MRUList")
        newMru := ""

        for letter in StrSplit(oldMru)
        {
            exists := false

            try
            {
                RegRead(runMruKey, letter)
                exists := true
            }

            if exists
                newMru .= letter
        }

        RegWrite(newMru, "REG_SZ", runMruKey, "MRUList")
    }
}

CreateGDLTimerDisplay()
{
    global GDLTimerGui, GDLTimerText

    GDLTimerGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    GDLTimerGui.BackColor := "202020"
    GDLTimerGui.MarginX := 8
    GDLTimerGui.MarginY := 4

    GDLTimerText := GDLTimerGui.AddText(
        "cFFFFFF w175 Right",
        ""
    )
}

CreateGDLAlarmDisplay()
{
    global GDLAlarmGui, GDLAlarmText

    GDLAlarmGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    GDLAlarmGui.BackColor := "202020"
    GDLAlarmGui.MarginX := 10
    GDLAlarmGui.MarginY := 6

    GDLAlarmText := GDLAlarmGui.AddText(
        "cFFFFFF w230 Right",
        ""
    )
}

PositionGDLBottomRight(guiObj, marginRight := 12, marginBottom := 8)
{
    MonitorGetWorkArea(1, &left, &top, &right, &bottom)

    guiObj.GetPos(&x, &y, &w, &h)

    x := right - w - marginRight
    y := bottom - h - marginBottom

    guiObj.Move(x, y)
}

UpdateGDLTimerDisplay()
{
    global GDLTimers, GDLTimerGui, GDLTimerText, GDLAlarmEndTick

    if !IsObject(GDLTimerGui)
        return

    if GDLAlarmEndTick > A_TickCount
    {
        GDLTimerGui.Hide()
        return
    }

    if GDLTimers.Count = 0
    {
        GDLTimerGui.Hide()
        return
    }

    lines := []
    nowTick := A_TickCount

    for id, timer in GDLTimers
    {
        remainingMs := timer.EndTick - nowTick

        if remainingMs < 0
            remainingMs := 0

        remainingSeconds := Ceil(remainingMs / 1000)

        hours := Floor(remainingSeconds / 3600)
        minutes := Floor(Mod(remainingSeconds, 3600) / 60)
        seconds := Mod(remainingSeconds, 60)

        if hours > 0
            timeText := Format("{:02}:{:02}:{:02}", hours, minutes, seconds)
        else
            timeText := Format("{:02}:{:02}", minutes, seconds)

        lines.Push(timer.Description . "  " . timeText)
    }

    display := ""

    for index, line in lines
    {
        if index > 1
            display .= "`n"

        display .= line
    }

    GDLTimerText.Text := display
    GDLTimerGui.Show("NoActivate AutoSize")
    PositionGDLBottomRight(GDLTimerGui)
}

StartGDLAlarm(description)
{
    global GDLAlarmGui, GDLAlarmText, GDLAlarmEndTick

    GDLAlarmText.Text := "Alarme: " . description
    GDLAlarmEndTick := A_TickCount + 5000

    GDLAlarmGui.Show("NoActivate AutoSize")
    PositionGDLBottomRight(GDLAlarmGui)

    PlayGDLAlarmSound()
    SetTimer(PlayGDLAlarmSound, 2200)
    SetTimer(StopGDLAlarm, -5000)
}

PlayGDLAlarmSound()
{
    global GDLAlarmEndTick

    if A_TickCount >= GDLAlarmEndTick
    {
        SetTimer(PlayGDLAlarmSound, 0)
        return
    }

    media := A_WinDir . "\Media\Alarm01.wav"

    if FileExist(media)
    {
        try SoundPlay(media)
    }
    else
    {
        try SoundBeep(1600, 180)
        try SoundBeep(1200, 160)
        try SoundBeep(1600, 180)
        try SoundBeep(2000, 220)
    }
}

StopGDLAlarm(*)
{
    global GDLAlarmGui, GDLAlarmEndTick

    SetTimer(PlayGDLAlarmSound, 0)
    GDLAlarmEndTick := 0

    if IsObject(GDLAlarmGui)
        GDLAlarmGui.Hide()

    UpdateGDLTimerDisplay()
}

ShowGDLTimerConfirmation(message)
{
    ToolTip(message)
    SetTimer(() => ToolTip(), -1400)
}

CaptureExplorerSelection()
{
    global LastExplorerPath, LastExplorerTick

    hwnd := WinExist("A")

    if !hwnd
        return

    className := WinGetClass("ahk_id " . hwnd)

    if className != "CabinetWClass" && className != "ExploreWClass"
        return

    path := GetSelectedExplorerPath(hwnd)

    if path = ""
        return

    LastExplorerPath := path
    LastExplorerTick := A_TickCount
}

GetSelectedExplorerPath(hwnd)
{
    try
    {
        shell := ComObject("Shell.Application")

        for window in shell.Windows
        {
            try
            {
                if window.HWND != hwnd
                    continue

                selected := window.Document.SelectedItems

                if selected.Count > 0
                    return selected.Item(0).Path
            }
        }
    }

    return ""
}

InsertSelectedPath(*)
{
    global LastExplorerPath

    currentPath := ""

    hwnd := WinExist("A")

    if hwnd
    {
        className := WinGetClass("ahk_id " . hwnd)

        if className = "CabinetWClass" || className = "ExploreWClass"
            currentPath := GetSelectedExplorerPath(hwnd)
    }

    if currentPath = ""
        currentPath := LastExplorerPath

    if currentPath = ""
    {
        ToolTip("Nenhum arquivo ou pasta selecionado no Explorer.")
        SetTimer(() => ToolTip(), -1500)
        return
    }

    networkPath := BuildComputerPath(currentPath)

    savedClipboard := ClipboardAll()

    try
    {
        A_Clipboard := networkPath

        if ClipWait(1)
        {
            SendEvent("^v")
            Sleep(120)
        }
    }
    finally
    {
        A_Clipboard := savedClipboard
    }

    ToolTip("Caminho capturado")
    SetTimer(() => ToolTip(), -1200)
}

BuildComputerPath(path)
{
    if SubStr(path, 1, 2) = "\\"
        return path

    if RegExMatch(path, "i)^([A-Z]):\\(.*)$", &match)
    {
        drive := StrUpper(match[1])
        rest := match[2]

        if rest = ""
            return A_ComputerName . ":" . drive . ":"

        return A_ComputerName . ":" . drive . ":\" . rest
    }

    return path
}

GetCurrentOrLastExplorerPath()
{
    global LastExplorerPath

    currentPath := ""
    hwnd := WinExist("A")

    if hwnd
    {
        className := WinGetClass("ahk_id " . hwnd)

        if className = "CabinetWClass" || className = "ExploreWClass"
            currentPath := GetSelectedExplorerPath(hwnd)
    }

    if currentPath = ""
        currentPath := LastExplorerPath

    return currentPath
}

FindGbak()
{
    candidates := [
        "C:\Program Files\Firebird\Firebird_3_0\gbak.exe",
        "C:\Program Files\Firebird\Firebird_4_0\gbak.exe",
        "C:\Program Files\Firebird\Firebird_5_0\gbak.exe"
    ]

    for candidate in candidates
    {
        if FileExist(candidate)
            return candidate
    }

    return ""
}

OpenAdminPowerShellBackup(*)
{
    selectedPath := GetCurrentOrLastExplorerPath()

    if selectedPath = ""
    {
        ShowGDLMessage("Selecione um arquivo FDB no Explorer.")
        return
    }

    if !RegExMatch(selectedPath, "i)\.fdb$")
    {
        ShowGDLMessage("Selecione um arquivo FDB para fazer o backup.")
        return
    }

    gbak := FindGbak()

    if gbak = ""
    {
        MsgBox(
            "Nao foi encontrado gbak.exe do Firebird 3, 4 ou 5.",
            "GDL Macro - Backup",
            "Icon!"
        )
        return
    }

    sourceDatabase := BuildFirebirdDatabasePath(selectedPath)
    backupPath := RegExReplace(selectedPath, "i)\.fdb$", ".FBK")

    if FileExist(backupPath)
    {
        answer := MsgBox(
            "Ja existe um backup com este nome:`n`n"
            . backupPath
            . "`n`nDeseja substituir?",
            "GDL Macro - Backup",
            "YesNo Icon?"
        )

        if answer != "Yes"
            return
    }

    psCommand :=
        "& " . GDLPSQuote(gbak)
        . " -BACKUP"
        . " -VERBOSE"
        . " -USER SYSDBA"
        . " -FETCH_PASSWORD stdin"
        . " " . GDLPSQuote(sourceDatabase)
        . " " . GDLPSQuote(backupPath)

    OpenElevatedPowerShell(psCommand, GetGDLParentFolder(selectedPath))
}

OpenAdminPowerShellRestore(*)
{
    selectedPath := GetCurrentOrLastExplorerPath()

    if selectedPath = ""
    {
        ShowGDLMessage("Selecione um arquivo FBK no Explorer.")
        return
    }

    if !RegExMatch(selectedPath, "i)\.fbk$")
    {
        ShowGDLMessage("Selecione um arquivo FBK para fazer o restore.")
        return
    }

    gbak := FindGbak()

    if gbak = ""
    {
        MsgBox(
            "Nao foi encontrado gbak.exe do Firebird 3, 4 ou 5.",
            "GDL Macro - Restore",
            "Icon!"
        )
        return
    }

    restoreLocalPath := RegExReplace(
        selectedPath,
        "i)\.fbk$",
        "_RESTAURADO.FDB"
    )

    if FileExist(restoreLocalPath)
    {
        MsgBox(
            "O arquivo de destino ja existe:`n`n"
            . restoreLocalPath
            . "`n`nO restore foi cancelado para evitar sobrescrever a base.",
            "GDL Macro - Restore",
            "Icon!"
        )
        return
    }

    restoreDatabase := BuildFirebirdDatabasePath(restoreLocalPath)

    psCommand :=
        "& " . GDLPSQuote(gbak)
        . " -CREATE"
        . " -VERBOSE"
        . " -USER SYSDBA"
        . " -FETCH_PASSWORD stdin"
        . " " . GDLPSQuote(selectedPath)
        . " " . GDLPSQuote(restoreDatabase)

    OpenElevatedPowerShell(psCommand, GetGDLParentFolder(selectedPath))
}

OpenElevatedPowerShell(command, workingDir := "")
{
    psExe := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"

    if !FileExist(psExe)
    {
        MsgBox(
            "PowerShell nao foi encontrado neste computador.",
            "GDL Macro",
            "Icon!"
        )
        return
    }

    args :=
        "-NoProfile -NoExit -Command "
        . Chr(34)
        . command
        . Chr(34)

    try
    {
        Run(
            "*RunAs " . GDLQuoteArg(psExe) . " " . args,
            workingDir
        )
    }
    catch as error
    {
        MsgBox(
            "Nao foi possivel abrir o PowerShell como administrador.`n`n"
            . error.Message,
            "GDL Macro",
            "Icon!"
        )
    }
}

BuildFirebirdDatabasePath(path)
{
    if SubStr(path, 1, 2) = "\\"
        return path

    if RegExMatch(path, "i)^[A-Z]:\\")
        return "localhost:" . path

    if RegExMatch(path, "i)^[^\\/:]+:[A-Z]:\\")
        return path

    return path
}

GetGDLParentFolder(path)
{
    SplitPath(path, , &dir)
    return dir
}

GDLQuoteArg(value)
{
    return Chr(34) . value . Chr(34)
}

GDLPSQuote(value)
{
    return "'" . StrReplace(value, "'", "''") . "'"
}

ShowGDLMessage(message)
{
    ToolTip(message)
    SetTimer(() => ToolTip(), -1500)
}


CaptureExplorerSelectionNames()
{
    global LastSelectedFileNames

    hwnd := WinExist("A")

    if !hwnd
        return

    className := WinGetClass("ahk_id " . hwnd)

    if className != "CabinetWClass" && className != "ExploreWClass"
        return

    names := []

    try
    {
        shell := ComObject("Shell.Application")

        for window in shell.Windows
        {
            try
            {
                if window.HWND != hwnd
                    continue

                selected := window.Document.SelectedItems

                if selected.Count = 0
                    return

                for item in selected
                {
                    path := item.Path

                    if path = ""
                        continue

                    if DirExist(path)
                        continue

                    SplitPath(path, &fileName)

                    if fileName != ""
                        names.Push(fileName)
                }

                break
            }
        }
    }
    catch
    {
        return
    }

    if names.Length > 0
        LastSelectedFileNames := names
}

CopyCachedSelectedFileNames(*)
{
    global LastSelectedFileNames

    if LastSelectedFileNames.Length = 0
    {
        ShowGDLTimerConfirmation("Nenhum arquivo foi capturado no Explorer.")
        return
    }

    result := ""

    for index, name in LastSelectedFileNames
    {
        if index > 1
            result .= "`r`n"

        result .= name
    }

    A_Clipboard := ""
    Sleep(100)
    A_Clipboard := result

    if !ClipWait(2)
    {
        ShowGDLTimerConfirmation("Nao foi possivel gravar no clipboard.")
        return
    }

    ShowGDLTimerConfirmation(
        LastSelectedFileNames.Length
        . " nome(s) copiado(s). Use Ctrl+V."
    )
}




; ============================================================
; COPIAR CONTEUDO DE ARQUIVO TEXTUAL SELECIONADO
; ============================================================

CopySelectedTextFile(*)
{
    selectedPath := GetCurrentOrLastExplorerPath()

    if selectedPath = ""
    {
        ShowGDLTimerConfirmation("Selecione um arquivo textual no Explorer.")
        return
    }

    if DirExist(selectedPath)
    {
        ShowGDLTimerConfirmation("Selecione um arquivo, nao uma pasta.")
        return
    }

    if !FileExist(selectedPath)
    {
        ShowGDLTimerConfirmation("O arquivo selecionado nao existe.")
        return
    }

    if !IsProbablyTextFile(selectedPath)
    {
        MsgBox(
            "O arquivo selecionado nao parece ser predominantemente textual.`n`n"
            . selectedPath,
            "GDL Macro - COPIATXT",
            "Icon!"
        )
        return
    }

    content := ReadTextFileSmart(selectedPath)

    if content = ""
    {
        try
        {
            if FileGetSize(selectedPath) = 0
            {
                A_Clipboard := ""
                ShowGDLTimerConfirmation("Arquivo vazio. Clipboard limpo.")
                return
            }
        }

        MsgBox(
            "Nao foi possivel ler o conteudo textual do arquivo.`n`n"
            . selectedPath,
            "GDL Macro - COPIATXT",
            "Icon!"
        )
        return
    }

    A_Clipboard := ""
    Sleep(80)
    A_Clipboard := content

    if ClipWait(2)
    {
        SplitPath(selectedPath, &fileName)
        ShowGDLTimerConfirmation(
            "Conteudo de " . fileName . " copiado. Use Ctrl+V."
        )
    }
    else
    {
        ShowGDLTimerConfirmation("Nao foi possivel atualizar o clipboard.")
    }
}

IsProbablyTextFile(path)
{
    SplitPath(path, , , &ext)
    ext := StrLower(ext)

    knownTextExtensions := Map(
        "txt", true,
        "log", true,
        "ini", true,
        "cfg", true,
        "conf", true,
        "config", true,
        "sql", true,
        "xml", true,
        "json", true,
        "csv", true,
        "tsv", true,
        "md", true,
        "ahk", true,
        "bat", true,
        "cmd", true,
        "ps1", true,
        "psm1", true,
        "php", true,
        "js", true,
        "ts", true,
        "jsx", true,
        "tsx", true,
        "html", true,
        "htm", true,
        "css", true,
        "scss", true,
        "less", true,
        "py", true,
        "java", true,
        "c", true,
        "h", true,
        "cpp", true,
        "hpp", true,
        "cs", true,
        "vb", true,
        "vbs", true,
        "reg", true,
        "yaml", true,
        "yml", true,
        "toml", true,
        "properties", true,
        "env", true,
        "lst", true,
        "dat", true
    )

    if knownTextExtensions.Has(ext)
        return true

    try
    {
        file := FileOpen(path, "r")

        if !IsObject(file)
            return false

        bytesToRead := Min(file.Length, 8192)

        if bytesToRead <= 0
        {
            file.Close()
            return true
        }

        buf := Buffer(bytesToRead, 0)
        readCount := file.RawRead(buf, bytesToRead)
        file.Close()

        if readCount <= 0
            return false

        ; BOM UTF-8
        if readCount >= 3
            && NumGet(buf, 0, "UChar") = 0xEF
            && NumGet(buf, 1, "UChar") = 0xBB
            && NumGet(buf, 2, "UChar") = 0xBF
            return true

        ; BOM UTF-16 LE/BE
        if readCount >= 2
        {
            b0 := NumGet(buf, 0, "UChar")
            b1 := NumGet(buf, 1, "UChar")

            if (b0 = 0xFF && b1 = 0xFE)
                || (b0 = 0xFE && b1 = 0xFF)
                return true
        }

        printable := 0
        nulls := 0

        Loop readCount
        {
            b := NumGet(buf, A_Index - 1, "UChar")

            if b = 0
            {
                nulls += 1
                continue
            }

            if b = 9 || b = 10 || b = 13
                || (b >= 32 && b <= 126)
                || b >= 128
            {
                printable += 1
            }
        }

        if nulls > 0
            return false

        return (printable / readCount) >= 0.85
    }
    catch
    {
        return false
    }
}

ReadTextFileSmart(path)
{
    try
    {
        file := FileOpen(path, "r")
        if IsObject(file)
        {
            if file.Length >= 3
            {
                bom := Buffer(3, 0)
                n := file.RawRead(bom, 3)
                file.Close()

                if n >= 3
                    && NumGet(bom, 0, "UChar") = 0xEF
                    && NumGet(bom, 1, "UChar") = 0xBB
                    && NumGet(bom, 2, "UChar") = 0xBF
                    return FileRead(path, "UTF-8")
            }
            else
            {
                file.Close()
            }
        }
    }

    try
        return FileRead(path, "UTF-8")

    catch
    {
        try
            return FileRead(path, "CP0")
        catch
            return ""
    }
}


; ============================================================
; LOCALIZAR XML NFC-e PELA CHAVE COPIADA
; ============================================================

FindNfceXmlByClipboardKey(*)
{
    key := RegExReplace(A_Clipboard, "\D", "")

    ShowKdxmlTip("Lendo chave NFC-e do clipboard...")

    if StrLen(key) != 44
    {
        MsgBox(
            "A area de transferencia nao contem uma chave NFC-e valida de 44 digitos.",
            "GDL Macro - KDXML",
            "Icon!"
        )
        return
    }

    ShowKdxmlTip("Chave valida. Procurando SFL.exe aberto...")

    pid := ProcessExist("SFL.exe")

    if !pid
    {
        MsgBox(
            "O processo SFL.exe nao esta aberto.",
            "GDL Macro - KDXML",
            "Icon!"
        )
        return
    }

    try
    {
        exePath := ProcessGetPath(pid)
    }
    catch as error
    {
        MsgBox(
            "Nao foi possivel identificar o caminho do SFL.exe.`n`n"
            . error.Message,
            "GDL Macro - KDXML",
            "Icon!"
        )
        return
    }

    if exePath = ""
    {
        MsgBox(
            "Nao foi possivel identificar o caminho do SFL.exe.",
            "GDL Macro - KDXML",
            "Icon!"
        )
        return
    }

    SplitPath(exePath, , &sflDir)

    ShowKdxmlTip("SFL.exe encontrado em:`n" . sflDir)

    nfceDir := sflDir . "\NFCE"

    if !DirExist(nfceDir)
    {
        MsgBox(
            "A pasta NFCE nao foi encontrada.`n`n"
            . "SFL.exe: " . exePath . "`n"
            . "Esperado: " . nfceDir,
            "GDL Macro - KDXML",
            "Icon!"
        )
        return
    }

    ShowKdxmlTip("Pasta NFCE encontrada. Procurando a chave...")

    foundFile := ""

    ; Primeiro procura XMLs contendo a chave no nome.
    Loop Files nfceDir . "\*" . key . "*.xml", "FR"
    {
        foundFile := A_LoopFileFullPath
        break
    }

    ; Depois tenta qualquer arquivo contendo a chave.
    if foundFile = ""
    {
        Loop Files nfceDir . "\*" . key . "*", "FR"
        {
            if !InStr(FileExist(A_LoopFileFullPath), "D")
            {
                foundFile := A_LoopFileFullPath
                break
            }
        }
    }

    if foundFile = ""
    {
        MsgBox(
            "Nenhum arquivo contendo esta chave foi encontrado na pasta NFCE.`n`n"
            . key . "`n`n"
            . nfceDir,
            "GDL Macro - KDXML",
            "Icon!"
        )
        return
    }

    ShowKdxmlTip("Arquivo encontrado:`n" . foundFile)

    try
    {
        Run(
            'explorer.exe /select,"' . foundFile . '"'
        )

        ShowKdxmlTip("XML localizado e selecionado no Explorer.")
    }
    catch as error
    {
        MsgBox(
            "O arquivo foi encontrado, mas nao foi possivel abrir o Explorer.`n`n"
            . foundFile . "`n`n"
            . error.Message,
            "GDL Macro - KDXML",
            "Icon!"
        )
    }
}

ShowKdxmlTip(message)
{
    ToolTip(message)
    SetTimer(() => ToolTip(), -2200)
}


; ============================================================
; VISUALIZADOR XML NF-e INTEGRADO AO GDL MACRO
; ============================================================

OpenSelectedXmlViewer(*)
{
    global AppGui

    selectedPath := GetCurrentOrLastExplorerPath()

    if selectedPath = ""
    {
        ShowGDLTimerConfirmation("Selecione um arquivo XML no Explorer.")
        return
    }

    if !RegExMatch(selectedPath, "i)\.xml$")
    {
        ShowGDLTimerConfirmation("O arquivo selecionado nao e XML.")
        return
    }

    if !FileExist(selectedPath)
    {
        ShowGDLTimerConfirmation("O arquivo XML selecionado nao existe.")
        return
    }

    CopySelectedXmlToClipboard(selectedPath)

    ; Cria a interface somente quando o comando ;xml for usado.
    if !IsObject(AppGui)
        CreateMainGui()

    LoadXml(selectedPath)

    try
    {
        AppGui.Show("w1000 h630")
        AppGui.Opt("+AlwaysOnTop")
        AppGui.Opt("-AlwaysOnTop")
    }
}


CopySelectedXmlToClipboard(xmlPath)
{
    xmlText := ""

    try
    {
        xmlText := FileRead(xmlPath, "UTF-8")
    }
    catch
    {
        try
            xmlText := FileRead(xmlPath)
        catch
            return false
    }

    if xmlText = ""
        return false

    A_Clipboard := ""
    Sleep(80)
    A_Clipboard := xmlText

    return ClipWait(2)
}

CloseXmlViewer(*)
{
    global AppGui
    global TabCtrl, StatusText, EnvBanner
    global GeneralFields, EmitFields, DestFields, TotalFields
    global ProductsLV, TaxesLV, PaymentsLV, XmlEdit, ProductSearchEdit
    global ProductRows, TaxRows, PaymentRows
    global CurrentXmlPath, XmlDoc

    try AppGui.Destroy()

    AppGui := 0
    TabCtrl := 0
    StatusText := 0
    EnvBanner := 0
    CurrentXmlPath := ""
    XmlDoc := 0

    GeneralFields := Map()
    EmitFields := Map()
    DestFields := Map()
    TotalFields := Map()

    ProductsLV := 0
    TaxesLV := 0
    PaymentsLV := 0
    XmlEdit := 0
    ProductSearchEdit := 0

    ProductRows := []
    TaxRows := []
    PaymentRows := []
}


; ============================================================
; Visualizador XML NF-e - v1.0
; AutoHotkey v2
; Leitura local via MSXML2.DOMDocument.6.0
; ============================================================

global AppGui := 0
global TabCtrl := 0
global StatusText := 0
global EnvBanner := 0
global CurrentXmlPath := ""
global XmlDoc := 0

global GeneralFields := Map()
global EmitFields := Map()
global DestFields := Map()
global TotalFields := Map()

global ProductsLV := 0
global TaxesLV := 0
global PaymentsLV := 0
global XmlEdit := 0
global ProductSearchEdit := 0

global ProductRows := []
global TaxRows := []
global PaymentRows := []

CreateMainGui()
{
    global AppGui, TabCtrl, StatusText, EnvBanner
    global ProductsLV, TaxesLV, PaymentsLV, XmlEdit, ProductSearchEdit
    global GeneralFields, EmitFields, DestFields, TotalFields

    AppGui := Gui("+Resize +MinSize1000x650", "Visualizador Inteligente de XML Fiscal - NF-e")
    AppGui.SetFont("s9", "Segoe UI")

    EnvBanner := AppGui.Add(
        "Text",
        "x12 y10 w970 h34 Center +0x200 Background808080 cFFFFFF",
        "AMBIENTE NAO IDENTIFICADO"
    )
    EnvBanner.SetFont("s11 Bold", "Segoe UI")

    StatusText := AppGui.Add(
        "Text",
        "x12 y50 w970 h26 +0x200 BackgroundF2F2F2 c333333",
        "  Arquivo: nenhum XML carregado"
    )
    StatusText.SetFont("s9", "Segoe UI")

    TabCtrl := AppGui.Add(
        "Tab3",
        "x12 y84 w970 h521",
        [
            "Dados gerais",
            "Emitente",
            "Destinatario",
            "Produtos",
            "Impostos",
            "Totais",
            "Pagamentos",
            "XML original"
        ]
    )

    ; ---------------- Dados gerais ----------------
    TabCtrl.UseTab("Dados gerais")
    GeneralFields := AddFieldGrid(AppGui, [
        ["Numero", "numero"],
        ["Serie", "serie"],
        ["Modelo", "modelo"],
        ["Data/hora emissao", "dhEmi"],
        ["Natureza operacao", "natOp"],
        ["Tipo operacao", "tpNF"],
        ["Chave de acesso", "chave"],
        ["Valor total NF-e", "vNF"],
        ["Situacao protocolo", "situacao"],
        ["Numero protocolo", "nProt"],
        ["Data protocolo", "dhRecbto"]
    ], 30, 116, 2)

    ; ---------------- Emitente ----------------
    TabCtrl.UseTab("Emitente")
    EmitFields := AddFieldGrid(AppGui, [
        ["Razao social", "xNome"],
        ["Nome fantasia", "xFant"],
        ["CNPJ/CPF", "doc"],
        ["Inscricao Estadual", "IE"],
        ["Regime tributario", "CRT"],
        ["Endereco", "endereco"],
        ["Municipio", "municipio"],
        ["Codigo IBGE", "cMun"],
        ["UF", "UF"],
        ["CEP", "CEP"],
        ["Telefone", "fone"]
    ], 30, 116, 2)

    ; ---------------- Destinatario ----------------
    TabCtrl.UseTab("Destinatario")
    DestFields := AddFieldGrid(AppGui, [
        ["Razao social", "xNome"],
        ["CNPJ/CPF", "doc"],
        ["Inscricao Estadual", "IE"],
        ["Endereco", "endereco"],
        ["Municipio", "municipio"],
        ["Codigo IBGE", "cMun"],
        ["UF", "UF"],
        ["CEP", "CEP"],
        ["Telefone", "fone"]
    ], 30, 116, 2)

    ; ---------------- Produtos ----------------
    TabCtrl.UseTab("Produtos")
    AppGui.Add("Text", "x30 y113 w65 h22", "Pesquisar:")
    ProductSearchEdit := AppGui.Add("Edit", "x95 y111 w310 h24")
    ProductSearchEdit.OnEvent("Change", FilterProducts)

    btnClearSearch := AppGui.Add("Button", "x415 y111 w85 h24", "Limpar")
    btnClearSearch.OnEvent("Click", (*) => ClearProductSearch())

    ProductsLV := AppGui.Add(
        "ListView",
        "x30 y146 w925 h369 Grid +Multi",
        [
            "Item", "Codigo", "EAN/GTIN", "Descricao", "NCM", "CEST",
            "CFOP", "Un", "Qtd", "V.Unit.", "Desconto", "V.Total"
        ]
    )
    SetProductColumnWidths()

    ; ---------------- Impostos ----------------
    TabCtrl.UseTab("Impostos")
    TaxesLV := AppGui.Add(
        "ListView",
        "x30 y116 w925 h399 Grid",
        [
            "Item", "Tributo", "CST/CSOSN", "Base", "Aliquota",
            "Valor", "Complemento"
        ]
    )
    TaxesLV.ModifyCol(1, 50)
    TaxesLV.ModifyCol(2, 90)
    TaxesLV.ModifyCol(3, 90)
    TaxesLV.ModifyCol(4, 110)
    TaxesLV.ModifyCol(5, 90)
    TaxesLV.ModifyCol(6, 110)
    TaxesLV.ModifyCol(7, 340)

    ; ---------------- Totais ----------------
    TabCtrl.UseTab("Totais")
    TotalFields := AddFieldGrid(AppGui, [
        ["Valor produtos", "vProd"],
        ["Descontos", "vDesc"],
        ["Frete", "vFrete"],
        ["Seguro", "vSeg"],
        ["Outras despesas", "vOutro"],
        ["Base ICMS", "vBC"],
        ["ICMS", "vICMS"],
        ["ICMS-ST", "vST"],
        ["FCP", "vFCP"],
        ["IPI", "vIPI"],
        ["PIS", "vPIS"],
        ["COFINS", "vCOFINS"],
        ["IBS", "vIBS"],
        ["CBS", "vCBS"],
        ["Valor total NF-e", "vNF"]
    ], 30, 116, 2)

    ; ---------------- Pagamentos ----------------
    TabCtrl.UseTab("Pagamentos")
    PaymentsLV := AppGui.Add(
        "ListView",
        "x30 y116 w925 h399 Grid",
        ["Codigo", "Descricao", "Valor", "Integracao", "CNPJ credenciadora", "Bandeira", "Autorizacao"]
    )
    PaymentsLV.ModifyCol(1, 70)
    PaymentsLV.ModifyCol(2, 180)
    PaymentsLV.ModifyCol(3, 100)
    PaymentsLV.ModifyCol(4, 110)
    PaymentsLV.ModifyCol(5, 160)
    PaymentsLV.ModifyCol(6, 130)
    PaymentsLV.ModifyCol(7, 140)

    ; ---------------- XML original ----------------
    TabCtrl.UseTab("XML original")
    XmlEdit := AppGui.Add(
        "Edit",
        "x30 y116 w925 h399 ReadOnly -Wrap VScroll HScroll",
        ""
    )
    XmlEdit.SetFont("s9", "Consolas")

    TabCtrl.UseTab()

    AppGui.OnEvent("Size", MainGuiResize)
    AppGui.OnEvent("Close", CloseXmlViewer)
    ; A janela sera mostrada somente depois que o XML for carregado.
}

AddFieldGrid(gui, specs, startX, startY, columns := 2)
{
    controls := Map()
    colWidth := 455
    labelWidth := 125
    editWidth := 285
    rowHeight := 34

    for index, spec in specs
    {
        label := spec[1]
        key := spec[2]

        col := Mod(index - 1, columns)
        row := Floor((index - 1) / columns)

        x := startX + (col * colWidth)
        y := startY + (row * rowHeight)

        gui.Add("Text", "x" x " y" y+4 " w" labelWidth " h22", label)
        ed := gui.Add("Edit", "x" x+labelWidth " y" y " w" editWidth " h24 ReadOnly")
        controls[key] := ed

        copyBtn := gui.Add("Button", "x" x+labelWidth+editWidth+5 " y" y " w35 h24", "C")
        copyBtn.OnEvent("Click", CopyControlValue.Bind(ed))
    }

    return controls
}

MainGuiResize(guiObj, minMax, width, height)
{
    global TabCtrl, StatusText, EnvBanner, ProductsLV, TaxesLV, PaymentsLV, XmlEdit

    if minMax = -1
        return

    try EnvBanner.Move(12, , width - 30)
    try StatusText.Move(12, , width - 30)
    try TabCtrl.Move(, , width - 30, height - 109)

    innerW := width - 75
    innerH := height - 231

    try ProductsLV.Move(, , innerW, innerH + 25)
    try TaxesLV.Move(, , innerW, innerH + 55)
    try PaymentsLV.Move(, , innerW, innerH + 55)
    try XmlEdit.Move(, , innerW, innerH + 55)
}

SelectXmlFile(*)
{
    global AppGui

    path := FileSelect(
        1,
        "",
        "Selecione o XML da NF-e",
        "Arquivos XML (*.xml)"
    )

    if path = ""
        return

    LoadXml(path)
    try AppGui.Show("w1000 h630")
}

LoadXml(path)
{
    global CurrentXmlPath, XmlDoc, StatusText

    if !FileExist(path)
    {
        ShowStatus("Arquivo inexistente.", true)
        return
    }

    try
    {
        fileSize := FileGetSize(path)

        if fileSize <= 0
        {
            ShowStatus("O arquivo XML esta vazio.", true)
            return
        }
    }
    catch
    {
        ShowStatus("Nao foi possivel verificar o arquivo.", true)
        return
    }

    try
    {
        doc := ComObject("MSXML2.DOMDocument.6.0")
        doc.async := false
        doc.validateOnParse := false
        doc.resolveExternals := false
        doc.setProperty("SelectionLanguage", "XPath")
        q := Chr(34)
        doc.setProperty(
            "SelectionNamespaces",
            "xmlns:nfe=" . q . "http://www.portalfiscal.inf.br/nfe" . q
        )

        if !doc.load(path)
        {
            err := doc.parseError
            message := "XML malformado ou invalido."

            try
                message .= "`nLinha: " . err.line . "`nMotivo: " . err.reason

            MsgBox(message, "Visualizador XML NF-e", "Icon!")
            return
        }

        nfeNode := doc.selectSingleNode("//nfe:NFe")

        if !IsObject(nfeNode)
        {
            MsgBox(
                "O XML nao possui uma estrutura NFe/nfeProc reconhecida.",
                "Visualizador XML NF-e",
                "Icon!"
            )
            return
        }

        XmlDoc := doc
        CurrentXmlPath := path

        UpdateXmlEnvironmentBanner()
        PopulateGeneral()
        PopulateParty("emit", true)
        PopulateParty("dest", false)
        PopulateProducts()
        PopulateTaxes()
        PopulateTotals()
        PopulateOriginalXml()
        PopulatePayments()

        SplitPath(path, &fileName)
        StatusText.Text := "  Arquivo: " . fileName
    }
    catch as error
    {
        details := "Falha ao ler o XML.`n`n" . error.Message

        try
        {
            if error.What != ""
                details .= "`n`nOrigem: " . error.What
        }

        try
        {
            if error.Line
                details .= "`nLinha: " . error.Line
        }

        MsgBox(
            details,
            "Visualizador XML NF-e",
            "Icon!"
        )
    }
}


UpdateXmlEnvironmentBanner()
{
    global EnvBanner

    tpAmb := X("//nfe:NFe/nfe:infNFe/nfe:ide/nfe:tpAmb")

    if tpAmb = ""
        tpAmb := XLocal("//*[local-name()='NFe']/*[local-name()='infNFe']/*[local-name()='ide']/*[local-name()='tpAmb']")

    if !IsObject(EnvBanner)
        return

    switch tpAmb
    {
        case "1":
            EnvBanner.Text := "AMBIENTE DE PRODUCAO"
            EnvBanner.Opt("Background198754 cFFFFFF")
        case "2":
            EnvBanner.Text := "AMBIENTE DE HOMOLOGACAO"
            EnvBanner.Opt("Background0D6EFD cFFFFFF")
        default:
            EnvBanner.Text := "AMBIENTE NAO IDENTIFICADO"
            EnvBanner.Opt("Background808080 cFFFFFF")
    }

    ; Forca redesenho do controle apos troca da cor.
    try EnvBanner.Redraw()
}

PopulateGeneral()
{
    global GeneralFields, XmlDoc

    ide := "//nfe:NFe/nfe:infNFe/nfe:ide"

    SetField(GeneralFields, "numero", X(ide . "/nfe:nNF"))
    SetField(GeneralFields, "serie", X(ide . "/nfe:serie"))
    SetField(GeneralFields, "modelo", X(ide . "/nfe:mod"))
    SetField(GeneralFields, "dhEmi", FirstNonEmpty(
        X(ide . "/nfe:dhEmi"),
        X(ide . "/nfe:dEmi")
    ))
    SetField(GeneralFields, "natOp", X(ide . "/nfe:natOp"))

    tpNF := X(ide . "/nfe:tpNF")
    if tpNF = "0"
        tpNFText := "Entrada"
    else if tpNF = "1"
        tpNFText := "Saida"
    else
        tpNFText := DisplayMissing(tpNF)

    SetField(GeneralFields, "tpNF", tpNFText)

    infNode := XmlDoc.selectSingleNode("//nfe:NFe/nfe:infNFe")
    chave := ""
    if IsObject(infNode)
    {
        idValue := infNode.getAttribute("Id")
        if SubStr(idValue, 1, 3) = "NFe"
            chave := SubStr(idValue, 4)
    }

    SetField(GeneralFields, "chave", DisplayMissing(chave))
    SetField(GeneralFields, "vNF", X("//nfe:ICMSTot/nfe:vNF"))

    cStat := X("//nfe:protNFe/nfe:infProt/nfe:cStat")
    xMotivo := X("//nfe:protNFe/nfe:infProt/nfe:xMotivo")

    situacao := ""
    if cStat != "" || xMotivo != ""
        situacao := Trim(cStat . " - " . xMotivo, " -")

    SetField(GeneralFields, "situacao", DisplayMissing(situacao))
    SetField(GeneralFields, "nProt", X("//nfe:protNFe/nfe:infProt/nfe:nProt"))
    SetField(GeneralFields, "dhRecbto", X("//nfe:protNFe/nfe:infProt/nfe:dhRecbto"))
}

PopulateParty(tag, isEmit)
{
    global EmitFields, DestFields

    target := isEmit ? EmitFields : DestFields
    base := "//nfe:NFe/nfe:infNFe/nfe:" . tag
    endTag := isEmit ? "enderEmit" : "enderDest"

    xNome := X(base . "/nfe:xNome")
    xFant := X(base . "/nfe:xFant")
    cnpj := X(base . "/nfe:CNPJ")
    cpf := X(base . "/nfe:CPF")
    doc := FirstNonEmpty(cnpj, cpf)
    ie := X(base . "/nfe:IE")
    crt := X(base . "/nfe:CRT")

    enderecoBase := base . "/nfe:" . endTag

    xLgr := X(enderecoBase . "/nfe:xLgr")
    nro := X(enderecoBase . "/nfe:nro")
    xCpl := X(enderecoBase . "/nfe:xCpl")
    xBairro := X(enderecoBase . "/nfe:xBairro")

    endereco := JoinNonEmpty([xLgr, nro, xCpl, xBairro], ", ")

    SetField(target, "xNome", xNome)
    if isEmit
        SetField(target, "xFant", xFant)

    SetField(target, "doc", doc)
    SetField(target, "IE", ie)

    if isEmit
        SetField(target, "CRT", DescribeCRT(crt))

    SetField(target, "endereco", endereco)
    SetField(target, "municipio", X(enderecoBase . "/nfe:xMun"))
    SetField(target, "cMun", X(enderecoBase . "/nfe:cMun"))
    SetField(target, "UF", X(enderecoBase . "/nfe:UF"))
    SetField(target, "CEP", X(enderecoBase . "/nfe:CEP"))
    SetField(target, "fone", X(enderecoBase . "/nfe:fone"))
}

PopulateProducts()
{
    global ProductsLV, ProductRows, XmlDoc

    ProductRows := []
    ProductsLV.Delete()

    nodes := XmlDoc.selectNodes("//nfe:NFe/nfe:infNFe/nfe:det")

    for det in nodes
    {
        prod := det.selectSingleNode("./nfe:prod")

        if !IsObject(prod)
            continue

        nItem := det.getAttribute("nItem")

        row := [
            nItem,
            NodeText(prod, "./nfe:cProd"),
            NodeText(prod, "./nfe:cEAN"),
            NodeText(prod, "./nfe:xProd"),
            NodeText(prod, "./nfe:NCM"),
            NodeText(prod, "./nfe:CEST"),
            NodeText(prod, "./nfe:CFOP"),
            NodeText(prod, "./nfe:uCom"),
            NodeText(prod, "./nfe:qCom"),
            NodeText(prod, "./nfe:vUnCom"),
            NodeText(prod, "./nfe:vDesc"),
            NodeText(prod, "./nfe:vProd")
        ]

        ProductRows.Push(row)
        ProductsLV.Add("", row*)
    }

    if ProductRows.Length = 0
        ShowStatus("Aviso: XML sem produtos.", false)
}

PopulateTaxes()
{
    global TaxesLV, TaxRows, XmlDoc

    TaxRows := []
    TaxesLV.Delete()

    nodes := XmlDoc.selectNodes("//nfe:NFe/nfe:infNFe/nfe:det")

    for det in nodes
    {
        nItem := det.getAttribute("nItem")
        imposto := det.selectSingleNode("./nfe:imposto")

        if !IsObject(imposto)
            continue

        AddIcmsTaxRows(imposto, nItem)
        AddSimpleTax(imposto, nItem, "IPI", "./nfe:IPI/*")
        AddSimpleTax(imposto, nItem, "PIS", "./nfe:PIS/*")
        AddSimpleTax(imposto, nItem, "COFINS", "./nfe:COFINS/*")
        AddIbsCbsTaxRows(imposto, nItem)
    }
}

AddIcmsTaxRows(imposto, nItem)
{
    global TaxesLV, TaxRows

    group := imposto.selectSingleNode("./nfe:ICMS/*")

    if !IsObject(group)
        return

    cst := FirstNonEmpty(
        NodeText(group, "./nfe:CST"),
        NodeText(group, "./nfe:CSOSN")
    )

    base := FirstNonEmpty(
        NodeText(group, "./nfe:vBC"),
        NodeText(group, "./nfe:vBCST")
    )

    aliq := FirstNonEmpty(
        NodeText(group, "./nfe:pICMS"),
        NodeText(group, "./nfe:pICMSST")
    )

    valor := FirstNonEmpty(
        NodeText(group, "./nfe:vICMS"),
        NodeText(group, "./nfe:vICMSST")
    )

    complemento := "Origem: " . DisplayMissing(NodeText(group, "./nfe:orig"))

    row := [
        nItem, "ICMS", DisplayMissing(cst), DisplayMissing(base),
        DisplayMissing(aliq), DisplayMissing(valor), complemento
    ]

    TaxRows.Push(row)
    TaxesLV.Add("", row*)

    fcp := FirstNonEmpty(
        NodeText(group, "./nfe:vFCP"),
        NodeText(group, "./nfe:vFCPST")
    )

    if fcp != ""
    {
        row2 := [
            nItem, "FCP", DisplayMissing(cst),
            DisplayMissing(FirstNonEmpty(NodeText(group, "./nfe:vBCFCP"), NodeText(group, "./nfe:vBCFCPST"))),
            DisplayMissing(FirstNonEmpty(NodeText(group, "./nfe:pFCP"), NodeText(group, "./nfe:pFCPST"))),
            fcp,
            ""
        ]

        TaxRows.Push(row2)
        TaxesLV.Add("", row2*)
    }
}

AddSimpleTax(imposto, nItem, taxName, xpath)
{
    global TaxesLV, TaxRows

    group := imposto.selectSingleNode(xpath)

    if !IsObject(group)
        return

    cst := NodeText(group, "./nfe:CST")
    base := NodeText(group, "./nfe:vBC")

    if taxName = "IPI"
        aliq := FirstNonEmpty(NodeText(group, "./nfe:pIPI"), NodeText(group, "./nfe:qUnid"))
    else if taxName = "PIS"
        aliq := FirstNonEmpty(NodeText(group, "./nfe:pPIS"), NodeText(group, "./nfe:qBCProd"))
    else
        aliq := FirstNonEmpty(NodeText(group, "./nfe:pCOFINS"), NodeText(group, "./nfe:qBCProd"))

    if taxName = "IPI"
        valor := NodeText(group, "./nfe:vIPI")
    else if taxName = "PIS"
        valor := NodeText(group, "./nfe:vPIS")
    else
        valor := NodeText(group, "./nfe:vCOFINS")

    row := [
        nItem, taxName, DisplayMissing(cst), DisplayMissing(base),
        DisplayMissing(aliq), DisplayMissing(valor), ""
    ]

    TaxRows.Push(row)
    TaxesLV.Add("", row*)
}

AddIbsCbsTaxRows(imposto, nItem)
{
    global TaxesLV, TaxRows

    ; Leiautes novos podem conter grupos IBSCBS com estruturas variaveis.
    ; Aqui exibimos apenas valores efetivamente presentes, sem presumir zero.
    ibsNode := imposto.selectSingleNode(".//*[local-name()='IBSCBS']")

    if !IsObject(ibsNode)
        return

    cst := FindFirstLocalText(ibsNode, ["CST", "cClassTrib"])
    vIBS := FindFirstLocalText(ibsNode, ["vIBS", "vIBSUF", "vIBSMun"])
    vCBS := FindFirstLocalText(ibsNode, ["vCBS"])

    if vIBS != ""
    {
        row := [nItem, "IBS", DisplayMissing(cst), "Nao informado", "Nao informado", vIBS, ""]
        TaxRows.Push(row)
        TaxesLV.Add("", row*)
    }

    if vCBS != ""
    {
        row := [nItem, "CBS", DisplayMissing(cst), "Nao informado", "Nao informado", vCBS, ""]
        TaxRows.Push(row)
        TaxesLV.Add("", row*)
    }
}

PopulateTotals()
{
    global TotalFields

    base := "//nfe:NFe/nfe:infNFe/nfe:total/nfe:ICMSTot"

    fields := [
        "vProd", "vDesc", "vFrete", "vSeg", "vOutro",
        "vBC", "vICMS", "vST", "vFCP", "vIPI", "vPIS",
        "vCOFINS", "vNF"
    ]

    for key in fields
        SetField(TotalFields, key, X(base . "/nfe:" . key))

    SetField(TotalFields, "vIBS", XLocal("//*[local-name()='IBSCBSTot']//*[local-name()='vIBS']"))
    SetField(TotalFields, "vCBS", XLocal("//*[local-name()='IBSCBSTot']//*[local-name()='vCBS']"))
}

PopulatePayments()
{
    global PaymentsLV, PaymentRows, XmlDoc

    PaymentRows := []
    PaymentsLV.Delete()

    detPags := XmlDoc.selectNodes("//nfe:NFe/nfe:infNFe/nfe:pag/nfe:detPag")

    if detPags.length = 0
        detPags := XmlDoc.selectNodes("//*[local-name()='NFe']/*[local-name()='infNFe']/*[local-name()='pag']/*[local-name()='detPag']")

    for det in detPags
    {
        tPag := NodeText(det, "./nfe:tPag")
        vPag := NodeText(det, "./nfe:vPag")
        tpIntegra := NodeText(det, "./nfe:card/nfe:tpIntegra")
        cnpj := NodeText(det, "./nfe:card/nfe:CNPJ")
        bandeira := NodeText(det, "./nfe:card/nfe:tBand")
        aut := NodeText(det, "./nfe:card/nfe:cAut")

        row := [
            DisplayMissing(tPag),
            DescribePayment(tPag),
            DisplayMissing(vPag),
            DisplayMissing(tpIntegra),
            DisplayMissing(cnpj),
            DisplayMissing(bandeira),
            DisplayMissing(aut)
        ]

        PaymentRows.Push(row)
        PaymentsLV.Add("", row*)
    }

    troco := X("//nfe:NFe/nfe:infNFe/nfe:pag/nfe:vTroco")
    if troco = ""
        troco := XLocal("//*[local-name()='NFe']/*[local-name()='infNFe']/*[local-name()='pag']/*[local-name()='vTroco']")

    if troco != ""
    {
        row := ["", "Troco", troco, "", "", "", ""]
        PaymentRows.Push(row)
        PaymentsLV.Add("", row*)
    }

    if PaymentRows.Length = 0
    {
        row := ["", "Nao informado no XML", "", "", "", "", ""]
        PaymentRows.Push(row)
        PaymentsLV.Add("", row*)
    }
}

PopulateOriginalXml()
{
    global XmlEdit, CurrentXmlPath, XmlDoc

    originalText := ""

    ; Le o XML original do arquivo selecionado.
    try
    {
        originalText := FileRead(CurrentXmlPath, "UTF-8")
    }
    catch
    {
        try originalText := FileRead(CurrentXmlPath)
    }

    ; Fallback para o DOM ja carregado.
    if originalText = ""
    {
        try originalText := XmlDoc.xml
    }

    if originalText = ""
    {
        XmlEdit.Value := "Nao foi possivel carregar o conteudo XML original."
        return
    }

    formattedXml := PrettyPrintXmlText(originalText)

    if formattedXml = ""
        formattedXml := originalText

    XmlEdit.Value := formattedXml
}

PrettyPrintXmlText(xmlText)
{
    xmlText := Trim(xmlText)

    if xmlText = ""
        return ""

    result := ""
    level := 0
    pos := 1

    ; Separa tags e textos para montar uma exibicao hierarquica.
    while RegExMatch(xmlText, "s)<[^>]+>|[^<]+", &m, pos)
    {
        token := Trim(m[0], " `t`r`n")
        pos := m.Pos + m.Len

        if token = ""
            continue

        ; Fechamento de elemento: reduz o nivel antes de escrever.
        if RegExMatch(token, "^</")
        {
            if level > 0
                level -= 1

            AppendXmlDisplayLine(&result, level, token)
            continue
        }

        ; Declaracao XML, comentario, DOCTYPE, CDATA e processing instruction.
        if RegExMatch(token, "^<\?")
            || RegExMatch(token, "^<!--")
            || RegExMatch(token, "^<!DOCTYPE")
            || RegExMatch(token, "^<!\[CDATA\[")
            || RegExMatch(token, "^<!")
        {
            AppendXmlDisplayLine(&result, level, token)
            continue
        }

        ; Tag XML.
        if SubStr(token, 1, 1) = "<"
        {
            AppendXmlDisplayLine(&result, level, token)

            ; Tags autocontidas nao abrem novo nivel.
            if !RegExMatch(token, "/>$")
                level += 1

            continue
        }

        ; Conteudo textual.
        AppendXmlDisplayLine(&result, level, token)
    }

    return RTrim(result, "`r`n")
}

AppendXmlDisplayLine(&result, level, text)
{
    indent := ""

    Loop level
        indent .= "  "

    if result != ""
        result .= "`r`n"

    result .= indent . text
}

FilterProducts(*)
{
    global ProductsLV, ProductRows, ProductSearchEdit

    query := StrLower(Trim(ProductSearchEdit.Value))
    ProductsLV.Delete()

    for row in ProductRows
    {
        if query = ""
        {
            ProductsLV.Add("", row*)
            continue
        }

        haystack := StrLower(
            row[2] . " "
            . row[4] . " "
            . row[5] . " "
            . row[7]
        )

        if InStr(haystack, query)
            ProductsLV.Add("", row*)
    }
}

ClearProductSearch()
{
    global ProductSearchEdit

    ProductSearchEdit.Value := ""
    FilterProducts()
}

CopyControlValue(ctrl, *)
{
    value := ctrl.Value

    if value = "" || value = "Nao informado"
    {
        ShowStatus("Nao ha valor para copiar.", false)
        return
    }

    CopyToClipboard(value, "Valor copiado.")
}


CopyXmlAuthorizationStatus(*)
{
    global XmlDoc, CurrentXmlPath

    if !IsObject(XmlDoc)
    {
        ShowStatus("Nenhum XML carregado.", true)
        return
    }

    cStat := X("//nfe:protNFe/nfe:infProt/nfe:cStat")
    xMotivo := X("//nfe:protNFe/nfe:infProt/nfe:xMotivo")
    nProt := X("//nfe:protNFe/nfe:infProt/nfe:nProt")
    dhRecbto := X("//nfe:protNFe/nfe:infProt/nfe:dhRecbto")

    ; 100 = Autorizado o uso da NF-e
    ; 150 = Autorizado o uso da NF-e, autorizacao fora de prazo
    if cStat = "100" || cStat = "150"
        status := "AUTORIZADO"
    else if cStat = ""
        status := "STATUS NAO INFORMADO / SEM PROTOCOLO"
    else
        status := "NAO AUTORIZADO"

    text := "Status XML: " . status

    if cStat != ""
        text .= "`r`ncStat: " . cStat

    if xMotivo != ""
        text .= "`r`nMotivo: " . xMotivo

    if nProt != ""
        text .= "`r`nProtocolo: " . nProt

    if dhRecbto != ""
        text .= "`r`nData protocolo: " . dhRecbto

    CopyToClipboard(text, "Status do XML copiado.")
}

ShowPaymentsTab(*)
{
    global TabCtrl, PaymentRows

    if !IsObject(TabCtrl)
        return

    try TabCtrl.Value := 7

    if PaymentRows.Length = 0
        ShowStatus("Este XML nao possui pagamentos informados.", false)
    else
        ShowStatus(PaymentRows.Length . " registro(s) de pagamento encontrado(s).", false)
}

CopyAccessKey(*)
{
    global GeneralFields

    if !GeneralFields.Has("chave")
        return

    chave := RegExReplace(GeneralFields["chave"].Value, "\D", "")

    if StrLen(chave) != 44
    {
        ShowStatus("Chave de acesso nao disponivel.", true)
        return
    }

    CopyToClipboard(chave, "Chave copiada.")
}

CopySummary(*)
{
    global GeneralFields, EmitFields, DestFields

    if GeneralFields["numero"].Value = ""
    {
        ShowStatus("Nenhum XML carregado.", true)
        return
    }

    text :=
        "NF-e " . GeneralFields["numero"].Value
        . " Serie " . GeneralFields["serie"].Value
        . "`r`nChave: " . GeneralFields["chave"].Value
        . "`r`nEmitente: " . EmitFields["xNome"].Value
        . " - " . EmitFields["doc"].Value
        . "`r`nDestinatario: " . DestFields["xNome"].Value
        . " - " . DestFields["doc"].Value
        . "`r`nValor total: " . GeneralFields["vNF"].Value

    CopyToClipboard(text, "Resumo copiado.")
}

CopyProducts(*)
{
    global ProductRows

    if ProductRows.Length = 0
    {
        ShowStatus("Nao ha produtos para copiar.", true)
        return
    }

    header := "Item`tCodigo`tEAN/GTIN`tDescricao`tNCM`tCEST`tCFOP`tUn`tQtd`tV.Unit.`tDesconto`tV.Total"
    text := header

    for row in ProductRows
        text .= "`r`n" . JoinArray(row, "`t")

    CopyToClipboard(text, "Produtos copiados em formato tabulado.")
}

CopySelectedProducts(*)
{
    global ProductsLV

    rowNum := 0
    text := ""
    count := 0

    loop
    {
        rowNum := ProductsLV.GetNext(rowNum)

        if rowNum = 0
            break

        values := []

        Loop 12
            values.Push(ProductsLV.GetText(rowNum, A_Index))

        if text != ""
            text .= "`r`n"

        text .= JoinArray(values, "`t")
        count += 1
    }

    if count = 0
    {
        ShowStatus("Selecione uma ou mais linhas.", false)
        return
    }

    CopyToClipboard(text, count . " linha(s) copiadas.")
}

ExportProductsCsv(*)
{
    global ProductRows, CurrentXmlPath

    if ProductRows.Length = 0
    {
        ShowStatus("Nao ha produtos para exportar.", true)
        return
    }

    defaultName := "produtos_nfe.csv"

    if CurrentXmlPath != ""
    {
        SplitPath(CurrentXmlPath, &fileName, &dir, &ext, &nameNoExt)
        defaultName := nameNoExt . "_produtos.csv"
    }

    target := FileSelect(
        "S16",
        defaultName,
        "Salvar produtos em CSV",
        "Arquivo CSV (*.csv)"
    )

    if target = ""
        return

    if !RegExMatch(target, "i)\.csv$")
        target .= ".csv"

    header := [
        "Item", "Codigo", "EAN/GTIN", "Descricao", "NCM", "CEST",
        "CFOP", "Un", "Qtd", "V.Unit.", "Desconto", "V.Total"
    ]

    csv := CsvLine(header)

    for row in ProductRows
        csv .= "`r`n" . CsvLine(row)

    try
    {
        if FileExist(target)
            FileDelete(target)

        FileAppend(csv, target, "UTF-8")
        ShowStatus("CSV exportado com sucesso.", false)
    }
    catch as error
    {
        MsgBox(
            "Nao foi possivel exportar o CSV.`n`n" . error.Message,
            "Visualizador XML NF-e",
            "Icon!"
        )
    }
}

CopyToClipboard(text, message)
{
    A_Clipboard := ""
    Sleep(60)
    A_Clipboard := text

    if ClipWait(2)
        ShowStatus(message, false)
    else
        ShowStatus("Falha ao atualizar o clipboard.", true)
}

ShowStatus(message, isError := false)
{
    global StatusText

    try StatusText.Text := message

    ToolTip(message)
    SetTimer(() => ToolTip(), -1800)
}

SetField(mapObj, key, value)
{
    if !mapObj.Has(key)
        return

    mapObj[key].Value := DisplayMissing(value)
}

X(xpath)
{
    global XmlDoc

    try
    {
        node := XmlDoc.selectSingleNode(xpath)

        if IsObject(node)
            return Trim(node.text)
    }

    return ""
}

XLocal(xpath)
{
    global XmlDoc

    try
    {
        node := XmlDoc.selectSingleNode(xpath)

        if IsObject(node)
            return Trim(node.text)
    }

    return ""
}

NodeText(parentNode, xpath)
{
    try
    {
        node := parentNode.selectSingleNode(xpath)

        if IsObject(node)
            return Trim(node.text)
    }

    return ""
}

FindFirstLocalText(parentNode, localNames)
{
    for name in localNames
    {
        try
        {
            node := parentNode.selectSingleNode(".//*[local-name()='" . name . "']")

            if IsObject(node)
            {
                value := Trim(node.text)

                if value != ""
                    return value
            }
        }
    }

    return ""
}

DisplayMissing(value)
{
    value := Trim(value)

    if value = ""
        return "Nao informado"

    return value
}

FirstNonEmpty(values*)
{
    for value in values
    {
        if Trim(value) != ""
            return value
    }

    return ""
}

JoinNonEmpty(values, separator := " ")
{
    result := ""

    for value in values
    {
        value := Trim(value)

        if value = ""
            continue

        if result != ""
            result .= separator

        result .= value
    }

    return result
}

JoinArray(arr, separator)
{
    result := ""

    for index, value in arr
    {
        if index > 1
            result .= separator

        result .= value
    }

    return result
}

CsvLine(arr)
{
    values := []

    for value in arr
    {
        q := Chr(34)
        value := StrReplace(value, q, q . q)
        values.Push(q . value . q)
    }

    return JoinArray(values, ";")
}

DescribeCRT(crt)
{
    switch crt
    {
        case "1": return "1 - Simples Nacional"
        case "2": return "2 - Simples Nacional - excesso sublimite"
        case "3": return "3 - Regime Normal"
        case "4": return "4 - MEI"
        default: return DisplayMissing(crt)
    }
}

DescribePayment(code)
{
    paymentMap := Map(
        "01", "Dinheiro",
        "02", "Cheque",
        "03", "Cartao de Credito",
        "04", "Cartao de Debito",
        "05", "Credito Loja",
        "10", "Vale Alimentacao",
        "11", "Vale Refeicao",
        "12", "Vale Presente",
        "13", "Vale Combustivel",
        "15", "Boleto Bancario",
        "16", "Deposito Bancario",
        "17", "PIX",
        "18", "Transferencia bancaria / carteira digital",
        "19", "Programa de fidelidade / cashback / credito virtual",
        "90", "Sem pagamento",
        "99", "Outros"
    )

    if paymentMap.Has(code)
        return paymentMap[code]

    return code = "" ? "Nao informado" : "Codigo " . code
}

SetProductColumnWidths()
{
    global ProductsLV

    widths := [45, 90, 100, 240, 75, 75, 65, 55, 70, 85, 80, 90]

    for index, width in widths
        ProductsLV.ModifyCol(index, width)
}
