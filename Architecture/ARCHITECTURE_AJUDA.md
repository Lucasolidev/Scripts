# 📐 Arquitetura e Padronização - Arquivos de Ajuda (`ajuda_*.md`)

Este documento define a especificação arquitetural, diretrizes de design, padrões visuais e o **Prompt Master** para criação de novos arquivos de ajuda (`ajuda_<tecnologia>.md`) no repositório.

---

## 📌 1. Visão Geral e Propósito

Os arquivos de ajuda (`ajuda_*.md`) são guias operacionais rápidos, *cheat sheets* e referências técnicas voltados para administração de sistemas, DevOps, infraestrutura e desenvolvimento.

O objetivo desta padronização é garantir que todos os guias possuam:
* **Consistência Visual**: Layout homogêneo, badges padronizados e emojis temáticos.
* **Alta Usabilidade Operacional**: Comandos prontos para cópia e cola, com sintaxe testada e segura.
* **Foco Enterprise & Hardening**: Ênfase em validações prévias (ex: `-t`, `configtest`), recargas sem downtime (*graceful reload*) e permissões de segurança.

---

## 📁 2. Nomenclatura e Localização dos Arquivos

* **Diretório Padrão**: Todos os arquivos de ajuda devem residir em `Scripts/`.
* **Convenção de Nome**: `ajuda_<tecnologia_ou_contexto>.md` (em minúsculas, usando `snake_case`).
* **Exemplos**:
  * `ajuda_apache2.md`
  * `ajuda_nginx.md`
  * `ajuda_docker.md`
  * `ajuda_linux.md`
  * `ajuda_ufw_iptables.md`
  * `ajuda_mariadb_mysql.md`

---

## 🏗️ 3. Esqueleto Estrutural Padrão

Todo novo arquivo `ajuda_*.md` deve obrigatoriamente seguir a estrutura abaixo:

```markdown
# [EMOJI_TECNOLOGIA] [Cheat Sheet / Guia Prático e Comandos de Operação do ...] [Nome da Tecnologia] [(Contexto/SO)]

![Shield1](url_badge_1)
![Shield2](url_badge_2)
...

Parágrafo introdutório sucinto (2 a 3 linhas) descrevendo o objetivo do guia, escopo e tecnologias contempladas em negrito.

---

## 📁 1. Estrutura de Arquivos e Diretórios Chave (ou Arquivos Vitais)

| Caminho / Arquivo | Descrição |
| :--- | :--- |
| `/caminho/exemplo` | Descrição clara e concisa da função do arquivo ou pasta. |

---

## 🛠️ 2. [Nome da Seção Principal de Comandos com Emoji]

### Nome da Subseção ou Ação (com comentário entre parênteses se CRÍTICO/MANDATÓRIO)
```bash
# Comentário explicativo opcional ou comando alternativo
comando_exemplo --opcoes
```

> 💡 *Caixa de destaque (callout) com dica prática ou aviso relevante.*

---
```

---

## 🎨 4. Guia de Elementos Visuais e Badges (Shields.io)

### 4.1 Badges de Tecnologia
Logo abaixo do título H1 (`#`), insira de 3 a 6 badges do [Shields.io](https://shields.io) correspondentes às tecnologias do guia.

**Sintaxe Padrão**:
```markdown
![Nome](https://img.shields.io/badge/TEXTO-COR_HEX?style=flat&logo=SLUG_LOGO&logoColor=COR_LOGO)
```

**Tabela de Badges Predefinidos no Projeto**:

| Tecnologia | Hex Color | Logo Slug | Logo Color | Markdown Exemplo |
| :--- | :--- | :--- | :--- | :--- |
| **Linux** | `FCC624` | `linux` | `black` | `![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)` |
| **Ubuntu** | `E95420` | `ubuntu` | `white` | `![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=flat&logo=ubuntu&logoColor=white)` |
| **Apache** | `D22128` | `apache` | `white` | `![Apache](https://img.shields.io/badge/Apache-D22128?style=flat&logo=apache&logoColor=white)` |
| **Nginx** | `009639` | `nginx` | `white` | `![Nginx](https://img.shields.io/badge/Nginx-009639?style=flat&logo=nginx&logoColor=white)` |
| **Docker** | `2496ED` | `docker` | `white` | `![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)` |
| **Windows / Server** | `0078D4` | `windows` | `white` | `![Windows](https://img.shields.io/badge/Windows-0078D4?style=flat&logo=windows&logoColor=white)` |
| **PowerShell** | `0078D4` | `powershell` | `white` | `![PowerShell](https://img.shields.io/badge/PowerShell-0078D4?style=flat&logo=powershell&logoColor=white)` |
| **Bash** | `4EAA25` | `gnu-bash` | `white` | `![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)` |
| **PHP** | `777BB4` | `php` | `white` | `![PHP](https://img.shields.io/badge/PHP-777BB4?style=flat&logo=php&logoColor=white)` |
| **MariaDB** | `003545` | `mariadb` | `white` | `![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=flat&logo=mariadb&logoColor=white)` |
| **Git** | `F05032` | `git` | `white` | `![Git](https://img.shields.io/badge/Git-F05032?style=flat&logo=git&logoColor=white)` |
| **Zabbix** | `D40000` | `zabbix` | `white` | `![Zabbix](https://img.shields.io/badge/Zabbix-D40000?style=flat&logo=zabbix&logoColor=white)` |

---

### 4.2 Taxonomia de Emojis para Seções e Tópicos

Use emojis padronizados para manter a consistência visual nos títulos H2 e destaques:

| Categoria | Emoji Padrão | Uso Indicado |
| :--- | :--- | :--- |
| **Arquivos e Pastas** | 📁 / 📄 / 📜 | Estruturas de diretórios, configs e arquivos de log |
| **Serviço e Operações** | 🛠️ / ⚙️ | Comandos de systemctl, restart, status, configurações |
| **Web e Rede** | 🌐 / 🧱 / 🔓 | Nginx, Apache, VirtualHosts, UFW, portas, Firewall |
| **Containers e Ciclo** | 🐳 / 🚀 / ⚡ | Docker, Compose, inicialização rápida, deploy |
| **Segurança e Permissão**| 🔒 / 🛡️ | Hardening, ACLs, permissões, usuários, senhas |
| **Limpeza e Manutenção** | 🧹 / 🗑️ | Purge, rotinas de limpeza de disco, remoção |
| **Monitoramento e Logs** | 📊 / 🔍 / 📤 | Zabbix, consulta de métricas, diagnóstico, tail |
| **Dicas e Avisos** | 💡 / ⚠️ / 🔴 | Callouts de dicas, alertas de segurança e crítico |

---

## 🛠️ 5. Regras de Conteúdo e Boas Práticas Tecnológicas

1. **Sintaxe Explicita em Blocos de Código**:
   * Sempre especificar a linguagem do bloco (ex: ```bash, ```powershell, ```cmd, ```apache, ```nginx, ```yaml, ```sql).
   * Manter cada comando, regra ou instrução copiável em um bloco de código separado, para que possa ser copiado individualmente.
2. **Placeholders Padronizados e Prevenção contra Falsos Positivos de Segurança (GitGuardian / Secret Scanners)**:
   * **PROIBIÇÃO DE CREDENCIAIS REAIS OU SIMULADAS**: Nunca incluir senhas reais, tokens de API, chaves privadas ou credenciais de produção.
   * **EVITAR LITERAIS QUE ACIONEM SCANNERS**: Jamais utilize valores literais em atribuições de variáveis sensíveis em exemplos de código (ex: `password = 'senha123'`, `smtppass = 'SENHA_AQUI'`, `secret = 'abc123xyz'`), pois ativam os detectores de segredos do GitGuardian e GitHub Secret Scanning.
   * **OBRIGATÓRIO USAR PLACEHOLDERS EM COLCHETES ANGULARES**: Todo exemplo de configuração, documentação ou script deve conter apenas tags genéricas: `<senha_do_usuario>`, `<chave_secreta_unica>`, `<usuario_smtp>`, `<senha_smtp>`, `<host_servidor_smtp>`, `<seu_dominio.com.br>`, `<192.168.1.X>`.
3. **Boas Práticas de SysAdmin / DevOps**:
   * **Validação Prévia**: Sempre incluir comando de teste de sintaxe antes de reiniciar serviços (ex: `apache2ctl -t`, `nginx -t`, `testparm -s`).
   * **Graceful Reload**: Dar preferência a `reload` em vez de `restart` quando aplicável para evitar queda de conexões.
   * **Comentários Inline**: Adicionar comentários curtos dentro dos blocos de código `#` para explicar flags complexas ou listar atalhos alternativos (`# Ou de forma simplificada:`).
4. **Alerta de Operações Destrutivas**:
   * Comandos de deleção (`rm -rf`, `docker system prune -a`, `ufw reset`) devem conter avisos claros com `⚠️` ou `🔴`.

---

## 🤖 6. Prompt Master para Gerar Novos Arquivos de Ajuda

Copie e utilize o prompt a seguir ao solicitar que uma IA ou colaborador crie um novo arquivo da série `ajuda_*.md`:

```text
Crie um arquivo de ajuda markdown no padrão do projeto para a tecnologia [NOME DA TECNOLOGIA] (ex: PostgreSQL, Kubernetes, Redis).

O arquivo deve ser salvo como `Scripts/ajuda_[TECNOLOGIA_LOWERCASE].md` e seguir estritamente as diretrizes abaixo:

1. TÍTULO E BADGES:
   - Título H1 com Emoji relativo + "# [EMOJI] Cheat Sheet - Administração [TECNOLOGIA] ([SO/Ambiente])" ou "# [EMOJI] Guia Prático e Comandos de Operação do [TECNOLOGIA]".
   - Adicione 3 a 5 badges do Shields.io (style=flat) com as cores hex e logos corretos das tecnologias envolvidas.

2. ESTRUTURA DE SEÇÕES:
   - Parágrafo introdutório curto em negrito explicando o escopo do guia.
   - Divisores `---` entre todas as seções H2.
   - Seção 1 (H2 com emoji 📁): Tabela markdown com principais caminhos de arquivo, configurações e logs.
   - Seções 2 em diante (H2 numerados e com emojis temáticos): Agrupamento lógico dos comandos mais usados em produção.

3. REGRAS DE CÓDIGO, SEGURANÇA E CONTEÚDO:
   - Todos os blocos de código devem ter linguagem definida (ex: bash, yaml, sql).
   - Mantenha cada comando, regra ou instrução copiável em um bloco de código separado, permitindo a cópia individual.
   - Inclua comentários inline `#` para comandos alternativos ou explicações de flags.
   - Destaque comandos críticos ou de teste de sintaxe com observações entre parênteses como (CRÍTICO) ou (MANDATÓRIO).
   - Adicione callouts `> 💡` com boas práticas de segurança, desempenho e manutenções.
   - SEGURANÇA E GITGUARDIAN: NUNCA use senhas/chaves literais em exemplos. Use obrigatoriamente placeholders em colchetes angulares como `<senha_usuario>`, `<chave_secreta>`, `<host_smtp>`, `<meu_dominio.com.br>`.
   - Mantenha o tom profissional, direto e em Português do Brasil (PT-BR).
```

---

## ✅ 7. Checklist de Qualidade (QA)

Antes de finalizar qualquer novo arquivo `ajuda_*.md`, verifique:

- [ ] O nome do arquivo segue o padrão `Scripts/ajuda_<tecnologia>.md`?
- [ ] Possui badges do Shields.io funcionando e alinhados abaixo do H1?
- [ ] As seções H2 possuem emojis relevantes, números organizados e divisores `---`?
- [ ] A tabela de diretórios e arquivos vitais foi incluída?
- [ ] Os blocos de código contêm especificação de linguagem (`bash`, `yaml`, `nginx`, etc.)?
- [ ] Cada comando, regra ou instrução copiável está em um bloco de código separado?
- [ ] Foram incluídos comandos de validação de sintaxe antes de comandos de reinício/reload?
- [ ] Todos os exemplos de credenciais, senhas e chaves utilizam placeholders explícitos `<...>` para evitar falsos positivos do GitGuardian / Secret Scanners?
- [ ] O texto está totalmente em Português do Brasil (PT-BR)?
