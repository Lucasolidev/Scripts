# 🇯 Guia de instalação e operação segura — Joomla 5 / LAMP

![Joomla](https://img.shields.io/badge/Joomla-5-5091CD?logo=joomla)
![Segurança](https://img.shields.io/badge/Instalador-3.5-28A745)

Referência do [install_lamp_ubuntu_joomla5.sh](../install_lamp_ubuntu_joomla5.sh), versão **3.5**. Prepara Apache com PHP-FPM, MariaDB local, Joomla oficial, UFW, Fail2Ban e auditd. O instalador não higieniza uma aplicação comprometida nem substitui a revisão de extensões e dados.

## 📁 1. Arquivos e configurações

| Caminho | Finalidade |
| --- | --- |
| `/etc/apache2/sites-available/<dominio>.conf` | VirtualHost e bloqueios de scripts, arquivos ocultos e backups |
| `/etc/apache2/joomla-rules/<identificador_do_dominio>.conf` | Regras oficiais de URLs, copiadas do pacote verificado e administradas por root |
| `/etc/php/<versao>/fpm/pool.d/joomla_<hash_do_dominio>.conf` | Pool dedicado, socket e restrições PHP da aplicação |
| `/etc/mysql/mariadb.conf.d/60-joomla5.cnf` | MariaDB em loopback, UTF8MB4 |
| `/etc/cron.d/joomla5_<identificador_do_dominio>_scheduler` | Agendador como www-data, a cada cinco minutos, somente após configuração e remoção do instalador |
| `/etc/audit/rules.d/web_security.rules` | Auditoria de alterações do site e configurações |
| `/etc/fail2ban/jail.d/apache-joomla.local` | Proteção web baseada nos logs do Apache |
| `/root/credenciais_joomla_<identificador>_<data_hora>.txt` | Credenciais privadas: root, modo 0600; nunca enviar junto ao relatório |
| `/root/relatorio_install_lamp_ubuntu_joomla5_*.log` | Relatórios sem credenciais; também copiados para a home do usuário sudo |

O nome exato dos arquivos é mostrado pelo instalador. Os identificadores do VirtualHost, das regras e do pool não são necessariamente iguais.

## ⚙️ 2. Preparação e execução

Use **servidor dedicado novo** e destino vazio. O usuário desenvolvedor é opcional: se informado e existente, será proprietário do código; se não existir, será criado com home e senha bloqueada. Configure acesso SSH por chave antes do deploy. O instalador recusa sites personalizados já habilitados. Para reinstalar conscientemente o mesmo domínio, use `--reinstall`: após dois avisos e um backup validado, o vhost Apache, o usuário MariaDB, o banco e os arquivos desse domínio serão removidos e recriados do zero. Sites de outros domínios devem ser desativados antes de continuar. Para migrar, veja o [checklist de recuperação e migração](checklist_pre_migracao_joomla.md).

Raízes admitidas: diretórios dedicados abaixo de `/var/www/`, `/srv/www/`, ou caminhos de pelo menos dois níveis abaixo de `/mnt/` e `/arquivos/`. O destino é resolvido e validado antes de alterar permissões.

```bash
# Revisar o arquivo e sua origem antes de executar.
chmod +x install_lamp_ubuntu_joomla5.sh
sudo ./install_lamp_ubuntu_joomla5.sh
```

| Ubuntu | PHP selecionado | Origem |
| --- | --- | --- |
| 22.04 | 8.3 | PPA ondrej/php |
| 24.04 | 8.3 | Repositório nativo Ubuntu |
| 26.04 | 8.5 | Repositório nativo Ubuntu |

A escolha de versão é explícita; não há fallback silencioso para outra versão PHP. Confirme a compatibilidade das extensões do site na homologação, especialmente no Ubuntu 26.04.

Parâmetros: domínio, destino, banco e usuário próprios, senhas ocultas, usuário de deploy, HTTPS direto opcional, extensões PHP opcionais, pastas adicionais de upload e IPv4 do proxy confiável. Senhas vazias são geradas dinamicamente. Senhas informadas no Joomla exigem pelo menos 16 caracteres. O padrão de uploads adicionais é `phocadownloadpap`.

O pacote Joomla 5 estável é obtido do repositório oficial, validado pelo SHA-256 publicado no release e inspecionado antes de extrair. Releases sem digest são recusados. Esse controle valida o pacote baixado; não valida arquivos trazidos do servidor antigo.

## 🛡️ 3. Proteções e compatibilidade

### Permissões

O código pertence a root ou ao usuário de deploy, com grupo www-data. Diretórios usam 0750 e arquivos 0640. O processo web recebe escrita somente em:

- `images`, `media`, `cache`, `tmp`, `logs`;
- `administrator/cache`, `administrator/logs`;
- diretórios adicionais informados na coleta.

O instalador remove ACLs anteriores antes de aplicar as permissões. Cada pasta gravável também tem bloqueio de scripts por HTTP. `assets` é bloqueada para scripts, mas não recebe escrita por padrão. Arquivos PHP de cache podem continuar sendo lidos internamente pela aplicação; a regra impede acesso HTTP direto, não inclusão interna por PHP.

### Apache

Desativa CGI/CGID, SSI, informações/status, listagem, userdir e WebDAV quando habilitados e sem dependências impeditivas. Usa MPM Event com PHP-FPM. SSL é habilitado quando solicitado; remoteip somente quando um proxy confiável é informado.

Arquivos `.htaccess` não são interpretados, inclusive em uploads. As regras oficiais `htaccess.txt` do pacote são copiadas para `/etc/apache2/joomla-rules/` e incluídas pelo VirtualHost. Após atualizar Joomla, compare as novas regras oficiais e atualize essa cópia como administrador; valide a configuração antes de recarregar. Redirecionamentos personalizados devem ser revisados e aplicados nesse arquivo administrado.

Bloqueia HTTP para scripts PHP e variantes em pastas estáticas/graváveis, diretórios ocultos, `configuration.php` e extensões de backup/log. CSS.gz e JS.gz são preservados. Downloads públicos ZIP/GZ são bloqueados nesse perfil: se necessários, prefira o componente de downloads com autorização ou uma exceção restrita, revisada no VirtualHost. Nunca libere uma extensão de script para corrigir um download.

### PHP

As extensões essenciais incluem MySQL, cURL, GD, mbstring, XML, ZIP e intl. SOAP, Imagick, BCMath, APCu, Redis e igbinary são opcionais. A seleção instala a extensão PHP; selecionar Redis não instala nem configura um servidor Redis.

O pool mantém `curl_exec`, `curl_multi_exec` e `parse_ini_file` disponíveis. Não impõe `allow_url_fopen=Off`. Bloqueia inclusão remota, exposição de versão, erros na resposta e funções de execução de processos; fixa prepend/append vazios e desativa configuração por `.user.ini`. A extensão executável no FPM fica limitada a `.php`.

As restrições são por pool; não alteram o PHP CLI nem outras versões. Um pool dedicado organiza a configuração, mas os pools ainda usam www-data: **não é isolamento entre clientes/tenants**. `disable_functions` é uma barreira complementar e não impede toda escrita, inclusão local ou acesso à rede. Rotinas que dependam de `proc_open` devem usar um fluxo administrativo revisado, não uma liberação global.

### HTTPS e proxy

HTTPS direto usa Certbot e requer DNS/acesso externo para o domínio **e www**. Cookies Secure e HSTS só são ativados após emissão bem-sucedida. Sem HTTPS direto, o operador deve configurar e validar a terminação no proxy antes de autenticar.

O IPv4 informado limita a confiança em `X-Forwarded-For`; o proxy deve sobrescrever esse cabeçalho com a origem validada. Isso não configura automaticamente toda a cadeia Cloudflare/proxy, `X-Forwarded-Proto`, cookies Secure, nem regras de firewall de borda. Em TLS terminado no proxy, configure também o Joomla para operar atrás de balanceador/proxy e valide redirecionamentos, URLs e cookies. Não confie em cabeçalhos recebidos diretamente da internet.

UFW preserva as portas anunciadas por `sshd -T`, libera HTTP e HTTPS quando solicitado. Revise separadamente NAT, socket activation, portas adicionais e restrições do backend. Não há bloqueio de saída por domínio aplicado pelo script. Fail2Ban e auditd não substituem correções da aplicação.

## 🚀 4. Conclusão da instalação e manutenção

Mantenha o site em homologação/manutenção até concluir:

1. Finalizar o instalador Joomla por HTTPS.
2. Durante a instalação inicial, o script libera ao Apache somente a criação de arquivos no diretório raiz do Joomla, para que o próprio assistente gere `configuration.php`. Depois que o Joomla terminar, aplicar `sudo setfacl -x u:www-data <raiz_do_joomla>`, `sudo chown root:www-data <raiz_do_joomla>/configuration.php` e `sudo chmod 640 <raiz_do_joomla>/configuration.php`.
3. Ao final, o script cria um finalizador protegido em `/root/finalizar_joomla_<identificador>.sh`. Execute-o depois do assistente web; ele verifica `configuration.php`, remove `installation` após confirmação e aplica o hardening automaticamente.

### Finalização obrigatória após o assistente web

O instalador termina antes da configuração pelo navegador. Depois de concluir o banco, o usuário administrador e as telas finais do Joomla, **não deixe a instalação aberta**. Execute o comando exibido no resumo final, por exemplo:

```bash
sudo /root/finalizar_joomla_pastoraldacrianca_org_br.sh
```

Digite `FINALIZAR` quando solicitado. O comando verifica se `configuration.php` foi gravado, remove a pasta `installation`, revoga a ACL temporária do Apache e aplica `root:www-data` com modo `640` no arquivo de configuração. Se o assistente ainda não terminou, o finalizador recusa a operação e não altera nada.
3. Remover o diretório `installation` como administrador após conferir o caminho absoluto exato. O processo web não possui permissão de remoção no diretório raiz.
4. Validar login, URLs amigáveis, mídias, cache, envio SMTP, integrações e tarefas agendadas.
5. Publicar somente após concluir a matriz abaixo.

**Atualizações recomendadas:** realizar backup validado, colocar o site em manutenção e atualizar como usuário de deploy usando pacotes oficiais e o fluxo suportado pelo Joomla/extensão. Reaplicar propriedade e permissões após atualização. Não execute este instalador novamente.

**Quando for indispensável atualizar pelo painel:** abrir uma janela curta, com acesso público bloqueado no proxy/firewall e somente o administrador conectado. Conceder ACL temporária de escrita para www-data apenas no site exato, acompanhar a atualização e revogar a ACL assim que concluir, inclusive em falhas. O bloco abaixo abre a janela e registra o fechamento automático ao terminar ou receber interrupção. Adapte a lista às pastas adicionais escolhidas e execute como root após bloquear o acesso público. A restauração também normaliza arquivos novos. Uma queda de energia ou SIGKILL exige executar a restauração manualmente antes de publicar.

```bash
(
set -Eeuo pipefail
test "$(id -u)" -eq 0 || exit 1
SITE='<diretorio_absoluto_do_site>'
DEPLOY='<usuario_de_deploy>'
SITE=$(realpath -e -- "$SITE")
case "$SITE" in /var/www/*|/srv/www/*|/mnt/*/*|/arquivos/*/*) ;; *) exit 1 ;; esac
id "$DEPLOY" >/dev/null
# Copiar a lista exata definida na instalacao, incluindo uploads adicionais.
MUTAVEIS=(images media cache tmp logs administrator/cache administrator/logs phocadownloadpap)
test -z "$(find "$SITE" -type l -print -quit)" || exit 1
restaurar() {
    setfacl -R -b -- "$SITE"
    find "$SITE" -type d -exec setfacl -k {} +
    chown -hR -- "$DEPLOY:www-data" "$SITE"
    find "$SITE" -type d -exec chmod 750 {} +
    find "$SITE" -type f -exec chmod 640 {} +
    for pasta in "${MUTAVEIS[@]}"; do
        test -d "$SITE/$pasta" || continue
        setfacl -R -m u:www-data:rwX -- "$SITE/$pasta"
        find "$SITE/$pasta" -type d -exec setfacl -m d:u:www-data:rwx,d:m::rwx {} +
    done
}
trap restaurar EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
# O acesso publico deve estar bloqueado neste ponto.
setfacl -R -m u:www-data:rwX -- "$SITE"
find "$SITE" -type d -exec setfacl -m d:u:www-data:rwx,d:m::rwx {} +
read -r -p 'Atualize pelo painel. Ao concluir ou cancelar, pressione ENTER para fechar a janela: ' RESPOSTA
# O trap revoga a escrita no codigo e normaliza os novos arquivos ao sair.
)
```

Se houver links simbólicos, revisar separadamente o deploy e não usar esse bloco. Não basta restaurar um snapshot de ACLs: arquivos criados durante a atualização também precisam de normalização. Não deixar o site público se o fechamento da manutenção falhar. Para adicionar uma pasta mutável, incluir simultaneamente sua regra de bloqueio HTTP; não basta conceder ACL.

## ✅ 5. Validação manual de homologação

Nesta revisão foram usados somente ShellCheck e análise de sintaxe Bash. **Instalação, configuração nativa e testes HTTP devem ser executados manualmente pelo operador.** No WSL, usar somente Ubuntu-24.04-Teste/Ubuntu-26.04-Teste, criadas pelo script de gerenciamento autorizado. Golden Templates não são ambientes de instalação.

```bash
# Ajustar a versao conforme o servidor; estes comandos validam configuracoes.
sudo apache2ctl configtest
sudo php-fpm8.3 -t
sudo fail2ban-client -t
sudo systemctl is-active apache2 php8.3-fpm mariadb
sudo apache2ctl -M
sudo auditctl -l
```

`php -i` e `php -m` inspecionam CLI, não comprovam as diretivas efetivas do pool FPM. Para conferir via HTTP, use uma verificação temporária restrita à máquina de homologação, retornando somente os valores necessários, e remova-a imediatamente. Não publique phpinfo.

| Teste | Resultado esperado |
| --- | --- |
| PHP simples no código, login e painel | Funcionam no FPM correto |
| URLs amigáveis, CSS/JS compactados, API | Funcionam; testar GET/POST e métodos necessários à API |
| Upload de imagem, cache e temporários | Funcionam nas pastas autorizadas |
| Escrita como www-data em index.php/configuration.php/plugins | Negada em produção |
| Script inofensivo em images/assets/cache/administrator/cache/uploads adicionais | HTTP negado, sem execução e sem retornar o código-fonte |
| Variantes .phtml/.php5/.phar, letras maiúsculas e sufixos como arquivo.php.jpg | Bloqueadas nas pastas protegidas |
| .htaccess e .user.ini em pasta gravável | Não alteram execução/configuração |
| .git/config, .env, configuration.php, backup.sql | Acesso HTTP negado |
| Acesso pelo IP/Host desconhecido | VirtualHost padrão nega acesso |
| Atualizações, SMTP, reCAPTCHA/APIs, downloads | Funcionam com extensões e regras escolhidas |
| Atualização controlada pelo painel | Funciona durante manutenção; permissões voltam ao padrão ao terminar |
| Proxy e cabeçalho IP forjado por origem não confiável | IP real correto; cabeçalho não confiável não altera origem |
| Falha de pacote/configuração | Instalador interrompe, sem anunciar conclusão |

O cron só dispara tarefas habilitadas e vencidas no Agendador Joomla. Não configura automaticamente indexação, newsletters ou verificações de atualização. Testar cada tarefa necessária. No WSL o instalador informa indisponibilidade do auditd; no servidor Linux suportado a falha de carga é bloqueante.

## 🔎 6. Fontes e limites

- [PHP: limites de disable_functions](https://www.php.net/manual/en/ini.core.php#ini.disable-functions)
- [PHP-FPM: pools, php_admin_value e security.limit_extensions](https://www.php.net/manual/en/install.fpm.configuration.php)
- [Apache: AllowOverride](https://httpd.apache.org/docs/2.4/mod/core.html#allowoverride)
- [Joomla 5: requisitos técnicos](https://manual.joomla.org/docs/5.4/get-started/technical-requirements/)

Nenhuma extensão específica foi identificada como causa comprovada do incidente. Relatos e indicadores justificam contenção, mas não comprovam ausência de malware em backup ou mídia. Não restaurar código antigo sem revisão, nem considerar headers, auditd ou funções desabilitadas como garantia de segurança.
