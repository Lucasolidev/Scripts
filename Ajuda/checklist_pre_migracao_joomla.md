# 📋 Migração e recuperação segura — Joomla e aplicações PHP

Use este roteiro com os instaladores LAMP/LEMP e Joomla. Diferencie uma migração de ambiente confiável de uma recuperação após comprometimento.

## 1. Antes da cópia

- Manter o site em manutenção e preservar uma cópia isolada das evidências e logs.
- Inventariar versão do Joomla, extensões, banco, PHP, uploads, tarefas, SMTP e integrações. Não colocar credenciais em relatórios ou tickets.
- Em incidente, renovar credenciais de administração, banco, SMTP e integrações afetadas; revisar sessões e usuários administrativos. Avaliar substituição da chave secreta Joomla e impacto nas sessões.
- Identificar o conjunto de backups disponível. Datas de arquivos e ausência de indicadores conhecidos não garantem backup limpo.

## 2. Preparar a origem confiável

Instalar Joomla e extensões a partir das fontes oficiais e versões compatíveis. Não copiar toda a árvore do servidor comprometido para produção. Revisar separadamente mídias, banco, templates personalizados e código próprio. Não importar automaticamente `.htaccess`, `.user.ini`, cron, instaladores de restauração, cache, arquivos PHP em mídias ou permissões anteriores.

Preservar uma cópia do banco em local protegido fora do DocumentRoot. Revisar contas administrativas, extensões, tarefas e conteúdo ativo. Transferir as credenciais por canal apropriado, nunca por histórico de comandos ou log.

Varredura antivírus, comparação com pacotes oficiais e busca por scripts em uploads são controles complementares. Não excluir arquivos automaticamente com base apenas em nomes ou extensões: caches legítimos podem conter PHP.

## 3. Preparar o destino

1. Usar servidor dedicado novo. Os instaladores recusam destino não vazio e sites personalizados já habilitados.
2. Executar o instalador escolhido e informar as pastas mutáveis realmente necessárias.
3. Manter acesso externo em manutenção; configurar HTTPS direto ou no proxy.
4. Migrar somente arquivos revisados, sem preservar ACLs e permissões inseguras da origem.
5. Importar banco revisado com conta administrativa local; configurar usuário próprio da aplicação.
6. Instalar `configuration.php` revisado como arquivo 0640, proprietário de deploy e grupo www-data. Ajustar caminhos, domínio/proxy e credenciais renovadas.
7. Reaplicar o modelo de permissões descrito na [ajuda Joomla](ajuda_install_lamp_ubuntu_joomla5.md). Nunca executar chown de todo o site para www-data ou conceder ACL herdável de escrita em toda a árvore em produção.
8. Para cada diretório adicional gravável, incluir também o bloqueio de scripts no servidor web.

No perfil Joomla, `.htaccess` não é interpretado; regras oficiais ficam em `/etc/apache2/joomla-rules/`. Personalizações da origem devem ser revisadas pelo administrador.

## 4. Liberação e acompanhamento

Executar a matriz de testes da ajuda Joomla: login, uploads, APIs, tarefas, SMTP, atualização, bloqueios de scripts e de escrita em código. Confirmar IP real e protocolo na cadeia de proxy, políticas de rede, logs e backup recuperável. Remover instaladores e diagnósticos antes da publicação. Registrar o que foi validado, o que continua pendente e a origem dos arquivos publicados.

Auditoria registra eventos; não impede infecção. Um site que carrega corretamente não está necessariamente limpo.
