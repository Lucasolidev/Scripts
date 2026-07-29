# 🪟 Cheat Sheet - Administração Windows

## 📌 Meus comandos pessoais mais usados

### 🛠️ Sistema e Ferramentas
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

### 👥 Gerenciamento de Usuários
* **Gerenciar contas de usuário (Contas de Usuário Avançadas):**
  ```cmd
  netplwiz
  ```
* **Usuários e Grupos Locais (Local Users and Groups):**
  ```cmd
  lusrmgr.msc
  ```

### 🛡️ Segurança e Políticas
* **Editor de Diretiva de Grupo Local** (Group Policy - GPO Local):
  ```cmd
  gpedit.msc
  ```
* **Diretiva de Segurança Local** (Políticas de senha, auditoria, etc):
  ```cmd
  secpol.msc
  ```

### 🌐 Rede e Conexões
* **Conexões de rede (Adaptadores de Rede):**
  ```cmd
  ncpa.cpl
  ```
* **Testar conectividade e porta específica (PowerShell):**
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

### 🧹 Manutenção e Reparo
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

### 💽 Armazenamento e Discos
* **Forçar leitura do disco após aumento de armazenamento (CMD):**
  ```cmd
  diskpart
  ```
  *(Dentro do diskpart, digite `rescan`)*

* **Forçar leitura do disco em linha única (PowerShell - O mais rápido):**
  Abre o diskpart, envia a instrução de rescan para reavaliar os discos e encerra a execução em um único segundo.
  ```powershell
  echo "rescan" | diskpart
  ```

* **Comando nativo do PowerShell (Sem usar Diskpart):**
  O Windows Server possui um cmdlet nativo para atualizar o barramento de armazenamento:
  ```powershell
  Update-HostStorageCache
  ```
  Em seguida, para forçar a atualização dos tamanhos reconhecidos das partições no sistema, rode:
  ```powershell
  Get-Partition | Get-Volume
  ```
