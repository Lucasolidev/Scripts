# 🛠️ Guia de instalação LAMP — Ubuntu

Versão **2.1** do [install_lamp_ubuntu.sh](../install_lamp_ubuntu.sh). Prepara Apache2, MariaDB local e PHP-FPM com configuração por site. Use em servidor dedicado novo e diretório vazio; não é atualizador nem ferramenta para higienizar servidor comprometido.

## ⚙️ Execução e parâmetros

```bash
# Revisar origem e conteúdo antes de executar.
chmod +x install_lamp_ubuntu.sh
sudo ./install_lamp_ubuntu.sh
```

O script solicita domínio, destino, usuário de deploy existente, pastas graváveis, módulos PHP opcionais, limite de upload, timeout, HTTPS, firewall, Fail2Ban, senha MariaDB oculta e IPv4 de proxy confiável. No LAMP há opção de phpMyAdmin local.

Ubuntu 22.04 usa PHP 8.3 via PPA ondrej/php; Ubuntu 24.04 usa PHP 8.3 nativo; Ubuntu 26.04 usa PHP 8.5 nativo. A versão é definida por distribuição, sem fallback silencioso ou escolha de uma versão não testada. Homologue as dependências da aplicação.

## 📁 Configurações e segurança

| Item | Comportamento |
| --- | --- |
| Código | Proprietário root/deploy, grupo www-data; raiz 0750; publicar arquivos de código com 0640 e diretórios 0750 |
| Escrita web | Somente diretórios informados; padrão uploads, cache e tmp |
| Scripts em uploads | Acesso HTTP bloqueado, incluindo variantes PHP e nomes com sufixos |
| PHP | Pool dedicado em `/etc/php/<versao>/fpm/pool.d/`, socket específico; não altera CLI |
| Módulos opcionais | SOAP, Imagick, BCMath, APCu, Redis e igbinary, apenas quando selecionados |
| cURL | Preservado; parse_ini_file também disponível |
| Banco | Loopback; credencial root em `/root/credenciais_lamp_<dominio>_<data_hora>.txt`, modo 0600 |
| Diagnóstico | Não cria phpinfo público |
| Relatórios | `/root/relatorio_install_lamp_ubuntu_*.log`, cópia na home sudo e atalho latest; modo 0600 |

O instalador não cria usuário/banco da aplicação. Criá-los com privilégios no banco próprio e host local; não usar a conta root na aplicação.

A escrita em uploads não significa permissão para executar scripts por HTTP. Pastas que precisam executar PHP devem permanecer no código, sem escrita pelo processo web. Todos os pools ainda usam www-data; pool dedicado não é isolamento entre clientes.

No Apache são desativados CGI, SSI, informações/status, listagem, userdir e WebDAV. Reescrita em `.htaccess` é permitida por lista explícita no código; diretórios mutáveis não interpretam `.htaccess`. Para aplicações com outras diretivas necessárias, revise e adicione somente as diretivas indispensáveis ou mova as regras ao VirtualHost. Não use AllowOverride All como correção genérica.

No Nginx, os bloqueios precedem o handler PHP; arquivos inexistentes não são enviados ao FPM. A configuração não impõe uma lista global GET/POST/HEAD, permitindo APIs com outros métodos. O script não configura WebSockets nem HTTP/2 automaticamente.

O VirtualHost padrão nega hosts desconhecidos. Backups não devem ficar dentro do diretório público; bloqueios por extensão não cobrem todo formato de arquivo possível.

## 🔐 HTTPS, proxy e administração

HTTPS opcional usa Certbot, exige DNS/acesso externo para o domínio informado e ativa redirecionamento e cookies Secure após emissão. Sem essa opção, configurar TLS no proxy e validar protocolo, redirecionamentos e cookies antes de autenticar. HSTS não é aplicado automaticamente pelo instalador genérico.

O endereço do proxy limita confiança em X-Forwarded-For. Configurar separadamente a cadeia de proxies, X-Forwarded-Proto e acesso ao backend; o proxy deve sobrescrever cabeçalhos de origem recebidos do público. O script não configura bloqueio de saída por domínio.

UFW preserva as portas de sshd -T, libera 80 e libera 443 quando HTTPS direto é solicitado. Revisar socket activation, NAT e políticas adicionais. Ao aceitar Fail2Ban (padrão Sim), o script habilita SSH via journal e proteção web por arquivos de log: autenticação HTTP e buscas por caminhos usados por bots. LAMP usa apache-auth e apache-botsearch; LEMP usa nginx-http-auth e nginx-botsearch. Cada jaula web considera 5 ocorrências em 10 minutos e aplica bloqueio por 1 hora. Os filtros são os distribuídos pelo pacote; não cobrem automaticamente falhas de login do Joomla ou de outro CMS.

O phpMyAdmin opcional do LAMP escuta somente em **127.0.0.1:8081**. Usar túnel SSH para esse endereço, não encaminhar essa porta pelo proxy público. O banco de armazenamento auxiliar do phpMyAdmin não é criado automaticamente.

## ✅ Publicação e validação manual

Publicar código revisado com proprietário de deploy, grupo www-data, arquivos 0640 e diretórios 0750. Não importar permissões/ACLs da origem. Manter código sem escrita por www-data; atualizações pelo painel exigem uma janela de manutenção e revogação das permissões temporárias, incluindo arquivos novos.

Consultar a [ajuda Joomla](ajuda_install_lamp_ubuntu_joomla5.md) para o procedimento de manutenção e a matriz de homologação, adaptando pastas e aplicação. Em recuperação, seguir o [checklist de migração](checklist_pre_migracao_joomla.md).

Validar manualmente configuração nativa (apache2ctl configtest, php-fpm8.3 -t ou php-fpm8.5 -t), serviços, login, uploads, APIs, integrações, negativa de escrita no código e scripts bloqueados em uploads. PHP CLI não comprova as configurações do FPM. Não deixar diagnóstico público.

Esta revisão recebeu somente análise estática Bash/ShellCheck; não houve teste de instalação. Os testes de execução pertencem ao operador. No WSL, somente as distribuições de teste podem receber instalações.

## Fail2Ban: conferência manual

As regras web ficam em `/etc/fail2ban/jail.d/lamp-web.local` ou `lemp-web.local`. SSH permanece em `web-sshd.local`. Antes de reiniciar, o instalador valida a configuração; depois, consulta cada jaula e interrompe se alguma não estiver ativa.

Na homologação, executar `sudo fail2ban-client status`, consultar as duas jaulas web e testar os filtros com `fail2ban-regex` usando os logs reais do VirtualHost e amostras benignas. Confirmar também que uma ocorrência legítima não resulta em bloqueio indevido. Testes de instalação e banimento não foram executados nesta revisão.

O proxy informado e os endereços de loopback são ignorados pelas jaulas web para evitar bloquear toda a entrada do site. Atrás de proxy/CDN, registrar o IP real não basta: o bloqueio no firewall do backend não alcança o IP do cliente encaminhado. Aplicar a ação de banimento no proxy/borda e validar toda a cadeia antes de considerar essa proteção efetiva para tráfego intermediado.

Referência: [configuração oficial do Fail2Ban](https://github.com/fail2ban/fail2ban/blob/1.1.0/config/jail.conf). O backend polling é usado para arquivos; systemd é reservado ao journal SSH.
