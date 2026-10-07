
#Requires AutoHotkey v2.0
#SingleInstance Force

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
            "mai", "Texto copiado em MAIÚSCULAS",
            "min", "Texto copiado em minúsculas",
            "primai", "Iniciais Das Palavras Em Maiúsculas"
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

    helpText .= "`n;mai  →  Texto copiado em MAIÚSCULAS"
    helpText .= "`n;min  →  Texto copiado em minúsculas"
    helpText .= "`n;primai  →  Inicial de cada palavra em maiúscula"

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


    totalCommands := Snippets.Count + Actions.Count + 5

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
