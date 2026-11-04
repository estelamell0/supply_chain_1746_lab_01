# Guia de Configuração de Ambiente: Python, OpenSSL e Variáveis Globais (PATH)

Este guia prático orienta a instalação e configuração definitiva do **Python**, do **OpenSSL** e das **Variáveis de Ambiente (`PATH`)** no Windows, Linux e macOS.

A configuração correta do `PATH` garante que os comandos `python` e `openssl` funcionem de maneira transparente em qualquer terminal (PowerShell, Prompt de Comando, Git Bash, WSL ou bash/zsh), sem a necessidade de comandos temporários como `$env:PATH += "..."`.

---

## 1. O que é a Variável de Ambiente `PATH`?

Quando você digita um comando como `python` ou `openssl` no terminal, o sistema operacional procura um arquivo executável com esse nome nos diretórios listados na variável de ambiente do sistema chamada `PATH`.
- Se o diretório onde o executável foi instalado **não estiver** no `PATH`, o terminal exibirá erros como:
  - *PowerShell:* `O termo 'openssl' não é reconhecido como nome de cmdlet, função, arquivo de script ou programa operável.`
  - *Bash:* `command not found: openssl`
- Adicionar um diretório via `$env:PATH += ";C:\..."` altera **apenas a janela atual** do PowerShell. Ao fechar e abrir uma nova janela, a configuração é perdida. Por isso, a configuração deve ser feita **globalmente e de forma permanente**.

---

## 2. Instalação e Configuração do Python

### Windows

#### Método 1: Instalador Oficial (Recomendado)
1. Acesse [python.org/downloads](https://www.python.org/downloads/) e baixe o instalador mais recente do Python 3 (3.10 ou superior).
2. Execute o instalador baixado.
3. **PASSO CRÍTICO:** Logo na primeira tela, marque a caixa de seleção:
   - ☑ **"Add python.exe to PATH"** (ou "Add Python to environment variables").
4. Clique em **"Install Now"**.
5. Ao finalizar, se aparecer a opção **"Disable path length limit"**, clique nela para evitar problemas com caminhos longos no Windows.

#### Método 2: Windows Terminal (via WinGet)
Abra o PowerShell e execute:
```powershell
winget install Python.Python.3.12
```
O WinGet já configura o `PATH` do usuário automaticamente.

---

### Linux (Ubuntu / Debian / Mint)
Abra o terminal e instale via `apt`:
```bash
sudo apt update && sudo apt install -y python3 python3-pip python3-venv
```

---

### macOS
Utilize o Homebrew:
```bash
brew install python
```

---

### Verificação do Python
Feche e abra novamente o terminal e execute:
```bash
# Windows / Linux / macOS:
python --version
# ou (em algumas distribuições Linux):
python3 --version
```
*Saída esperada:* `Python 3.10.x` (ou versão superior).

---

## 3. Instalação do OpenSSL

### Windows

O Windows não inclui o utilitário de linha de comando `openssl` por padrão. Escolha **uma** das opções abaixo:

#### Opção A: Via Gerenciador de Pacotes WinGet (Mais Rápido e Limpo)
Abra o PowerShell como Administrador e execute:
```powershell
winget install ShiningLight.OpenSSL
```
*Nota:* Por padrão, o instalador do ShiningLight OpenSSL pergunta se deseja adicionar o binário ao PATH do sistema. Selecione a opção para adicionar ao PATH.

#### Opção B: Aproveitar o OpenSSL já embutido no Git for Windows
Se você já tem o **Git for Windows** instalado na máquina, você já possui o `openssl.exe`. Ele costuma estar localizado em:
- `C:\Program Files\Git\usr\bin` (instalação padrão 64 bits)
- ou `%LOCALAPPDATA%\Programs\Git\usr\bin` (se instalado apenas para o usuário atual)

Para usá-lo em qualquer janela do PowerShell ou CMD sem precisar digitar caminhos completos, basta adicionar essa pasta ao seu `PATH` global permanente (veja a Seção 4).

#### Opção C: Instalador Binário Direto
1. Acesse [slproweb.com/products/Win32OpenSSL.html](https://slproweb.com/products/Win32OpenSSL.html).
2. Baixe a versão estável mais recente (ex: *Win64 OpenSSL v3.x Light*).
3. Durante a instalação, selecione a opção de copiar os binários para o diretório `/bin` da instalação do OpenSSL e marque para adicionar ao `PATH`.

---

### Linux (Ubuntu / Debian / Fedora)
O OpenSSL geralmente já vem instalado. Se necessário:
```bash
# Ubuntu / Debian:
sudo apt update && sudo apt install -y openssl

# Fedora / Red Hat / CentOS:
sudo dnf install -y openssl
```

---

### macOS
Instale via Homebrew:
```bash
brew install openssl
```

---

## 4. Como Configurar as Variáveis de Ambiente (`PATH`) Globalmente

Caso você tenha instalado o OpenSSL ou o Python manualmente e eles não sejam reconhecidos no terminal, siga os passos abaixo para adicioná-los ao `PATH` de forma definitiva.

### No Windows: Método Visual (Interface Gráfica) — Recomendado

1. Pressione o atalho `Win + R`, digite `sysdm.cpl` e pressione **Enter** (ou abra o Menu Iniciar e digite "Variáveis de Ambiente").
2. Na janela que se abre (*Propriedades do Sistema*), selecione a aba **Avançado**.
3. Clique no botão **Variáveis de Ambiente...** no canto inferior direito.
4. Na seção **Variáveis do Sistema** (para valer para todos os usuários) ou **Variáveis de Usuário** (para a sua conta):
   - Localize a linha chamada `Path` (ou `PATH`).
   - Selecione-a e clique em **Editar...**.
5. Na janela de edição:
   - Clique em **Novo**.
   - Digite ou cole o caminho da pasta onde o executável reside.  
     *Exemplos comuns:*
     - OpenSSL nativo: `C:\Program Files\OpenSSL-Win64\bin`
     - OpenSSL do Git: `C:\Program Files\Git\usr\bin`
     - Python: `C:\Users\<SeuUsuario>\AppData\Local\Programs\Python\Python312`
   - Use o botão **Mover para Cima** se desejar dar prioridade a esse diretório.
6. Clique em **OK** na janela de edição, depois em **OK** na janela de Variáveis de Ambiente e em **OK** nas Propriedades do Sistema.
7. **IMPORTANTE:** Feche todas as janelas abertas do terminal (PowerShell, Prompt de Comando, VS Code) e abra uma nova janela para que o Windows carregue o novo `PATH`.

---

### No Windows: Método Via Linha de Comando (PowerShell)

Você também pode adicionar um diretório ao `PATH` do usuário de forma permanente via PowerShell sem abrir telas gráficas:

```powershell
# 1. Defina o caminho que deseja adicionar (ajuste para o seu caso real):
$DiretorioParaAdicionar = "C:\Program Files\Git\usr\bin"

# 2. Leia o PATH atual do usuario:
$UserPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)

# 3. Adicione apenas se ja nao estiver presente:
if ($UserPath -notlike "*$DiretorioParaAdicionar*") {
    $NovoPath = "$UserPath;$DiretorioParaAdicionar"
    [Environment]::SetEnvironmentVariable("Path", $NovoPath, [EnvironmentVariableTarget]::User)
    Write-Host "[OK] Diretorio adicionado ao PATH de usuario com sucesso!" -ForegroundColor Green
    Write-Host "Feche e reabra o PowerShell para aplicar as mudancas." -ForegroundColor Yellow
} else {
    Write-Host "[INFO] O diretorio ja se encontra no PATH do usuario." -ForegroundColor Cyan
}
```

> ⚠️ **Atenção:** Evite utilizar o comando legado `setx PATH "$env:PATH;..."` sem cuidado, pois o `setx` trunca variáveis com mais de 1024 caracteres. O método .NET (`[Environment]::SetEnvironmentVariable`) acima é seguro e preserva caminhos longos.

---

### No Linux e macOS: Método Permanente no Perfil do Shell

Para tornar um caminho permanente no Linux ou macOS, adicione a linha de exportação ao arquivo de perfil do seu shell:

1. Se você usa **Bash** (padrão no Linux e versões antigas do macOS):
   ```bash
   echo 'export PATH="$PATH:/usr/local/opt/openssl/bin"' >> ~/.bashrc && source ~/.bashrc
   ```

2. Se você usa **Zsh** (padrão atual do macOS e comum no Linux):
   ```bash
   echo 'export PATH="$PATH:/usr/local/opt/openssl/bin"' >> ~/.zshrc && source ~/.zshrc
   ```

---

## 5. Checklist de Validação Final

Após concluir os passos e abrir uma **nova janela de terminal**, valide seu ambiente executando:

```bash
# 1. Testar Python:
python --version
# (Ou python3 --version no Linux/macOS)

# 2. Testar OpenSSL:
openssl version

# 3. Testar Git:
git --version
```

### Saídas esperadas:
- `Python 3.10.x` (ou superior)
- `OpenSSL 3.x.x` (ou `OpenSSL 1.1.1x`)
- `git version 2.x.x`

Com esses três comandos respondendo com sucesso em qualquer diretório, seu ambiente está 100% pronto para executar o setup do laboratório (`setup_lab.ps1` ou `setup_lab.sh`) e todas as suas fases práticas.

