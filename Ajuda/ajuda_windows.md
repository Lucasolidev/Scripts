# 🪟 Cheat Sheet - Administração Windows

![Windows](https://img.shields.io/badge/Windows-0078D4?style=flat&logo=windows&logoColor=white)
![Windows Server](https://img.shields.io/badge/Windows_Server-0078D4?style=flat&logo=windows&logoColor=white)
![PowerShell](https://img.shields.io/badge/Windows_PowerShell-0078D4?style=flat&logo=powershell&logoColor=white)
![CMD](https://img.shields.io/badge/Command_Prompt-4D4D4D?style=flat&logo=windows-terminal&logoColor=white)

Guia de referência rápida com atalhos, utilitários MMC, cmdlets do PowerShell e comandos essenciais para administração do **Windows** e **Windows Server**.

---

## 📁 1. Arquivos, Logs e Diretórios Vitais do Sistema

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `C:\Windows\System32\` | Diretório de binários centrais, ferramentas MMC e bibliotecas DLL do sistema. |
| `C:\Windows\System32\drivers\etc\hosts` | Arquivo de mapeamento estático local de resolução de nomes DNS/IP. |
| `C:\Windows\System32\winevt\Logs\` | Diretório contendo os arquivos físicos de eventos (`.evtx`) lidos pelo Event Viewer. |
| `C:\ProgramData\` | Diretório oculto para dados e configurações compartilhadas de aplicações de serviços. |
| `C:\Windows\Logs\CBS\` | Logs de manutenção e integridade de componentes do sistema (`sfc` e `dism`). |

---

## 🛠️ 2. Sistema e Ferramentas Administrativas
* **Verificar o Tempo de Atividade (Uptime):**
  ```cmd
  cmd /k systeminfo | find "Tempo"
  ```
* **Adicionar e Remover Programas:**
  ```cmd
  appwiz.cpl
  ```
* **Informações do Computador (System Information):**
  ```cmd
  msinfo32.exe
  ```
* **Propriedades da Internet:**
  ```cmd
  inetcpl.cpl
  ```
* **Propriedades do Sistema Avançadas** (Variáveis de Ambiente, Desempenho e Nome do PC):
  ```cmd
  sysdm.cpl
  ```
* **Gerenciamento do Computador** (Acesso rápido a Discos, Serviços, Usuários e Logs):
  ```cmd
  compmgmt.msc
  ```
* **Gerenciador de Serviços** (Iniciar, parar ou reiniciar serviços do Windows):
  ```cmd
  services.msc
  ```
* **Visualizador de Eventos** (Logs do sistema, erros de aplicativos e segurança):
  ```cmd
  eventvwr.msc
  ```
* **Gerenciador de Dispositivos** (Drivers e hardware):
  ```cmd
  devmgmt.msc
  ```
* **Gerenciamento de Disco** (Formatar, redimensionar partições e alterar letras de unidades):
  ```cmd
  diskmgmt.msc
  ```

---

## 👥 3. Gerenciamento de Usuários e Grupos
* **Gerenciar contas de usuário (Contas de Usuário Avançadas):**
  ```cmd
  netplwiz
  ```
* **Usuários e Grupos Locais (Local Users and Groups):**
  ```cmd
  lusrmgr.msc
  ```

---

## 🛡️ 4. Segurança e Políticas (GPO & Secpol)
* **Editor de Diretiva de Grupo Local** (Group Policy - GPO Local):
  ```cmd
  gpedit.msc
  ```
* **Diretiva de Segurança Local** (Políticas de senha, auditoria, etc):
  ```cmd
  secpol.msc
  ```

---

## 🌐 5. Rede e Conexões
* **Conexões de rede (Adaptadores de Rede):**
  ```cmd
  ncpa.cpl
  ```
* **Testar conectividade e porta específica (![PowerShell](https://img.shields.io/badge/Windows_PowerShell-0078D4?style=flat&logo=powershell&logoColor=white)):**
  ```powershell
  Test-NetConnection -ComputerName rdp.agroexport.agr.br -Port 43306
  ```
* **Verificar portas abertas e conexões ativas** (Mostra o PID do processo que está usando a porta):
  ```cmd
  netstat -ano
  ```
* **Limpar cache DNS** (Útil quando um site ou IP mudou recentemente):
  ```cmd
  ipconfig /flushdns
  ```
* **Verificar a rota que os pacotes fazem até um destino:**
  ```cmd
  tracert google.com
  ```

---

## 🧹 6. Manutenção e Reparo do Sistema
* **Limpeza de Disco** (Apagar temporários do Windows Update):
  ```cmd
  cleanmgr
  ```
* **Verificar e corrigir arquivos corrompidos do sistema** (Muito útil se o Windows estiver apresentando erros estranhos):
  ```cmd
  sfc /scannow
  ```
* **Verificar componentes do sistema** (Analisa o armazenamento de componentes):
  ```cmd
  Dism.exe /Online /Cleanup-Image /AnalyzeComponentStore
  ```
* **Limpeza de componentes do sistema** (Inicia a limpeza da imagem do Windows):
  ```cmd
  Dism.exe /Online /Cleanup-Image /StartComponentCleanup
  ```

---

## 💽 7. Armazenamento e Discos
* **Forçar leitura do disco após aumento de armazenamento (CMD):**
  ```cmd
  diskpart
  ```
  *(Dentro do diskpart, digite `rescan`)*

* **Forçar leitura do disco em linha única (![PowerShell](https://img.shields.io/badge/Windows_PowerShell-0078D4?style=flat&logo=powershell&logoColor=white) - O mais rápido):**
  Abre o diskpart, envia a instrução de rescan para reavaliar os discos e encerra a execução em um único segundo.
  ```powershell
  echo "rescan" | diskpart
  ```

* **Comando nativo do ![PowerShell](https://img.shields.io/badge/Windows_PowerShell-0078D4?style=flat&logo=powershell&logoColor=white) (Sem usar Diskpart):**
  O Windows Server possui um cmdlet nativo para atualizar o barramento de armazenamento:
  ```powershell
  Update-HostStorageCache
  ```
  Em seguida, para forçar a atualização dos tamanhos reconhecidos das partições no sistema, rode:
  ```powershell
  Get-Partition | Get-Volume
  ```
