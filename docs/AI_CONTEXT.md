# Contexto compartilhado de IA

## Repositório

- Raiz Git: `C:\\Users\\LUCAS\\Documents\\Projetos_Ai\\GitHub`.
- O conteúdo do repositório remoto está em `Scripts/`.
- Remoto: `https://github.com/Lucasolidev/Scripts`.
- Não fazer push sem solicitação explícita do usuário.

## Regras de WSL

- `Ubuntu-24.04` e `Ubuntu-26.04` são Golden Templates intocáveis, incluindo seus discos em `C:\\WSL\\`.
- Qualquer teste de execução ou instalação deve usar `Ubuntu-24.04-Teste` ou `Ubuntu-26.04-Teste`.
- Criar e destruir VMs de teste com `C:\\WSL\\manage-test-vm.ps1`.

## Segurança

- Não registrar nem expor senhas, tokens, chaves privadas ou outros segredos.
- Usar `.env.example`, `.env.sample` ou `.env.template` para exemplos sem valores reais.


## Padrão para scripts e ajuda

- Usar `Scripts/Architecture` como referência obrigatória ao criar ou atualizar scripts e arquivos de ajuda.
- Quando houver uma melhoria estrutural reutilizável, atualizar também os padrões em `Scripts/Architecture`.

## Instaladores web — revisão de segurança de 07/09/2026

- LAMP/LEMP 2.1 e Joomla 2.3 destinam-se a servidor dedicado novo e DocumentRoot vazio. Não usar como atualizador ou ferramenta de limpeza após incidente.
- Fail2Ban nos instaladores LAMP/LEMP inclui SSH e filtros web de autenticação HTTP/botsearch. Arquivos web usam polling e journal SSH usa systemd. Atrás de proxy/CDN, a ação de bloqueio de clientes precisa ser integrada à borda; registrar IP real não torna o firewall local eficaz contra conexões intermediadas.
- Código pertence a root/deploy; www-data escreve somente nas pastas mutáveis declaradas, que também devem bloquear scripts por HTTP. Atualizações pelo painel exigem manutenção e revogação das permissões temporárias, inclusive em arquivos novos.
- PHP-FPM usa pool e socket por site, sem impor as mesmas restrições ao CLI. cURL permanece disponível; SOAP/Imagick/BCMath/APCu/Redis/igbinary são opcionais. Pools com o mesmo usuário não são isolamento entre clientes.
- Joomla carrega as regras oficiais fora do DocumentRoot, em /etc/apache2/joomla-rules/, com AllowOverride None. Não copiar regras desconhecidas da origem para a configuração ativa.
- Usuário solicitou validação manual das instalações nesta revisão: somente ShellCheck e análise de sintaxe, sem instalação/execução dos scripts.
