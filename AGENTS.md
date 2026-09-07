# Regras compartilhadas do projeto

Estas instruções valem para todo o repositório. Antes de iniciar uma tarefa, leia também `docs/AI_CONTEXT.md`.

## Proteção de segredos

- Nunca incluir senhas, tokens de API, chaves privadas ou credenciais literais no código, documentação, templates ou scripts.
- Não usar valores de exemplo que se pareçam com segredos em variáveis como `password`, `smtppass` ou `secret`.
- Para exemplos, utilizar placeholders entre colchetes angulares, como `<senha_do_usuario>`, `<chave_secreta_unica>`, `<usuario_smtp>`, `<senha_smtp>`, `<host_servidor_smtp>`, `<seu_dominio.com.br>` e `<192.168.1.X>`.
- Em Shell/Bash, gerar segredos dinamicamente com `openssl rand -base64 16` ou solicitar entrada com `read -sp`.
- Em PowerShell, solicitar segredos com `Read-Host -AsSecureString` ou gerá-los dinamicamente.
- Não versionar arquivos `.env`, credenciais ou chaves privadas.

## Testes no WSL

- `Ubuntu-24.04` e `Ubuntu-26.04`, bem como seus discos em `C:\\WSL\\`, são Golden Templates intocáveis.
- Nunca executar scripts, instalar pacotes ou alterar o sistema nessas imagens base. Elas só podem ser usadas para análise estática, como `shellcheck`.
- Para testar execução ou instalação de scripts, usar exclusivamente `Ubuntu-24.04-Teste` ou `Ubuntu-26.04-Teste`.
- Criar e destruir as VMs de teste por meio de `C:\\WSL\\manage-test-vm.ps1`.

## Contexto compartilhado

- Manter `docs/AI_CONTEXT.md` atualizado quando uma decisão duradoura de projeto for tomada.


## Estrutura de scripts e ajuda

- Ao criar ou atualizar scripts, consultar os modelos e padrões em `Scripts/Architecture` antes de alterar o conteúdo.
- Ao criar ou atualizar arquivos de ajuda, seguir a estrutura e os padrões documentados em `Scripts/Architecture`.
- Se a tarefa revelar uma melhoria estrutural reutilizável, atualizar os arquivos correspondentes em `Scripts/Architecture` e registrar a decisão em `docs/AI_CONTEXT.md`.
