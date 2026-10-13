# GDL Macro

> Automação portátil em AutoHotkey para produtividade, suporte técnico e execução rápida de comandos em ambientes Windows.

O **GDL Macro** é um conjunto de automações desenvolvido para agilizar tarefas repetitivas durante atendimentos técnicos, acessos remotos e uso diário no Windows.  
O projeto utiliza **AutoHotkey v2** e foi pensado para funcionar de forma portátil, sem instalação permanente no computador do cliente.

---

## ✨ Principais recursos

- Expansão de textos e respostas rápidas através do `snippets.ini`
- Comandos iniciados por `;`
- Transformação de texto copiado:
  - `;mai` → MAIÚSCULAS
  - `;min` → minúsculas
  - `;primai` → Primeira Letra De Cada Palavra
- Extração de somente números do clipboard
- Automação de preenchimentos recorrentes
- Temporizadores:
  - `;10s`
  - `;5min`
  - `;2h`
- Alarmes por horário:
  - `;14:30`
  - somente quando o horário estiver dentro das próximas 12 horas
- Cancelamento de temporizadores e alarmes:
  - `;cancela`
- Captura do caminho do arquivo/pasta selecionado no Windows Explorer:
  - `;caminho`
  - exemplo: `PC-CLIENTE:C:\Eres\Banco\SFI.FDB`
- Encerramento com limpeza dos arquivos temporários:
  - `;sair`
- Suporte a snippets SQL com quebra de linha usando `\n`
- Execução portátil com `AutoHotkey64.exe`
- Download automático pelo GitHub através de PowerShell

---

## 🚀 Instalação rápida

O projeto pode ser carregado diretamente do GitHub através do PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$f=Join-Path $env:TEMP 'GDL_instalar.ps1'; Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/Gidelucas/GDL-Macro/main/instalar.ps1' -OutFile $f -UseBasicParsing -ErrorAction Stop; & $f"
```

O instalador:

1. cria uma pasta temporária em `%TEMP%\GDL-Macro`;
2. baixa os arquivos necessários;
3. executa o AutoHotkey portátil;
4. não instala serviço;
5. não cria tarefa agendada;
6. não configura inicialização automática.

Ao finalizar o atendimento, utilize:

```text
;sair
```

O comando encerra o GDL Macro e remove os arquivos temporários utilizados durante a sessão.

---

## 🖥️ Requisitos

- Windows 10 ou Windows 11
- PowerShell disponível
- acesso à internet
- permissão para execução do AutoHotkey portátil

> O projeto é direcionado principalmente para Windows 10 e Windows 11.

---

## 📁 Estrutura do projeto

```text
GDL-Macro/
├── GDL_Macro.ahk
├── snippets.ini
├── AutoHotkey64.exe
├── instalar.ps1
└── README.md
```

### `GDL_Macro.ahk`

Arquivo principal do projeto.

Responsável pelos hotstrings, automações, temporizadores, alarmes, manipulação do clipboard e demais funções.

### `snippets.ini`

Arquivo destinado a textos, comandos SQL, URLs e respostas rápidas.

Exemplo:

```ini
[espera]
Text=Só um momento por gentileza.
```

Uso:

```text
;espera
```

---

## 🧩 Snippets com várias linhas

Para criar snippets maiores, como scripts SQL, utilize `\n` para representar quebra de linha.

Exemplo:

```ini
[sqlteste]
Text=SELECT\n    ID,\n    NOME\nFROM CLIENTE\nWHERE ID = 1;
```

Ao executar:

```text
;sqlteste
```

o resultado será:

```sql
SELECT
    ID,
    NOME
FROM CLIENTE
WHERE ID = 1;
```

---

## ⏱️ Temporizadores

### Segundos

```text
;10s
;30s
```

### Minutos

```text
;5min
;30min
```

### Horas

```text
;1h
;2h
```

O tempo restante é exibido discretamente no canto inferior direito da tela.

---

## ⏰ Alarmes por horário

Também é possível definir um horário específico:

```text
;14:30
```

O GDL Macro verifica se o horário informado ocorre dentro das próximas **12 horas**.

Quando o horário chega, um aviso é exibido no canto inferior direito e um som de alarme é reproduzido.

---

## ❌ Cancelar temporizadores

Para cancelar todos os temporizadores e alarmes ativos:

```text
;cancela
```

---

## 📂 Capturar caminho de arquivo

Selecione um arquivo ou pasta no Windows Explorer e depois utilize:

```text
;caminho
```

Exemplo:

Arquivo selecionado:

```text
C:\Eres\Banco\SFI_GDL.FDB
```

Resultado:

```text
DESKTOP-PC:C:\Eres\Banco\SFI_GDL.FDB
```

O recurso foi pensado para funcionar também durante atendimentos por acesso remoto, desde que o GDL Macro esteja executando na máquina remota.

---

## 🧹 Encerrar e limpar

Ao terminar o atendimento:

```text
;sair
```

O GDL Macro:

1. encerra a execução;
2. verifica se está rodando em `%TEMP%\GDL-Macro`;
3. solicita a remoção da pasta temporária após o encerramento do processo.

Se o script estiver sendo executado fora da pasta temporária, a pasta de desenvolvimento não é removida.

---

## ⌨️ Uso com Silakka54 / Vial

O projeto também pode ser iniciado através de uma macro configurada no teclado **Silakka54**.

A macro pode:

1. abrir `Win + R`;
2. digitar o comando PowerShell;
3. baixar o instalador;
4. iniciar o GDL Macro automaticamente.

Isso permite disponibilizar o ambiente de suporte com uma única tecla.

---

## 🔄 Atualização

Como os arquivos são obtidos diretamente da branch `main`, basta atualizar os arquivos no GitHub mantendo os mesmos nomes:

```text
GDL_Macro.ahk
snippets.ini
AutoHotkey64.exe
instalar.ps1
```

Na próxima execução, a versão atual será baixada novamente.

---

## 🔐 Segurança e uso responsável

O GDL Macro foi criado para uso administrativo e de suporte técnico autorizado.

Recomendações:

- não armazene senhas, tokens ou credenciais sensíveis em repositórios públicos;
- revise os comandos antes de publicá-los;
- utilize apenas em equipamentos nos quais você tenha autorização;
- mantenha o repositório e os arquivos de instalação sob seu controle;
- evite adicionar persistência desnecessária em computadores de clientes.

O projeto não foi desenvolvido para ocultação, persistência ou execução não autorizada.

---

## 🛠️ Tecnologias

- AutoHotkey v2
- PowerShell
- arquivos INI
- GitHub
- Vial / QMK para automação através do Silakka54

---

## 🎯 Objetivo

O objetivo do GDL Macro é simples:

> **reduzir tarefas repetitivas, acelerar atendimentos e disponibilizar ferramentas úteis de suporte em poucos segundos.**

Em vez de instalar várias ferramentas ou repetir comandos manualmente, o GDL Macro concentra pequenas automações em uma interface baseada em comandos rápidos.

---

## 📌 Projeto

**GDL Macro**  
Desenvolvido para produtividade e suporte técnico.

Repositório:

```text
https://github.com/Gidelucas/GDL-Macro
```
