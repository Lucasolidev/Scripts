# 🌿 Guia Prático e Comandos de Operação do Git & GitHub Workflow

Este guia reúne os comandos essenciais para versionamento de código, gerenciamento de branches, envio de commits, resolução de conflitos e boas práticas com o **Git** e **GitHub**.

---

## ⚙️ 1. Configurações Iniciais do Git

* **Configurar nome do autor e e-mail global:**
  ```bash
  git config --global user.name "Seu Nome"
  git config --global user.email "seu_email@empresa.com"
  ```

* **Configurar o nome da branch padrão para `main`:**
  ```bash
  git config --global init.defaultBranch main
  ```

* **Listar todas as configurações ativas:**
  ```bash
  git config --list
  ```

---

## 🚀 2. Ciclo de Vida do Código (Add, Commit, Push, Pull)

* **Iniciar um novo repositório na pasta atual:**
  ```bash
  git init
  ```

* **Clonar um repositório remoto:**
  ```bash
  git clone https://github.com/usuario/repositorio.git
  ```

* **Verificar o status dos arquivos (modificados, staged, não rastreados):**
  ```bash
  git status
  ```

* **Adicionar alterações para a área de staging:**
  ```bash
  # Adicionar um arquivo específico:
  git add meu_arquivo.js

  # Adicionar TODOS os arquivos modificados e novos:
  git add -A
  # ou:
  git add .
  ```

* **Criar um commit com mensagem descritiva:**
  ```bash
  git commit -m "feat: adiciona nova funcionalidade de autenticação"
  ```

* **Baixar e atualizar alterações do repositório remoto (`pull`):**
  ```bash
  git pull origin main
  ```

* **Enviar os commits locais para o repositório remoto (`push`):**
  ```bash
  git push origin main
  ```

---

## 🌿 3. Gerenciamento de Branches (Ramificações)

* **Listar todas as branches locais:**
  ```bash
  git branch
  ```

* **Listar todas as branches (locais e remotas):**
  ```bash
  git branch -a
  ```

* **Criar e alternar para uma nova branch:**
  ```bash
  git checkout -b feature/nova-tela
  # Ou comando moderno:
  git switch -c feature/nova-tela
  ```

* **Alternar entre branches existentes:**
  ```bash
  git checkout main
  # Ou:
  git switch main
  ```

* **Unir (Merge) alterações de uma branch na branch atual:**
  ```bash
  # Estando na branch 'main':
  git merge feature/nova-tela
  ```

* **Excluir uma branch local com segurança (após merge):**
  ```bash
  git branch -d feature/nova-tela
  ```

* **Forçar exclusão de uma branch local não mesclada:**
  ```bash
  git branch -D feature/nova-tela
  ```

---

## 📦 4. Salvamento Temporário (`git stash`)

O `stash` salva suas alterações modificadas sem precisar fazer um commit, deixando a árvore limpa para trocar de branch.

* **Salvar alterações no stash:**
  ```bash
  git stash
  # Com mensagem identificadora:
  git stash save "Trabalho em andamento na tela de login"
  ```

* **Listar o histórico de stashes:**
  ```bash
  git stash list
  ```

* **Recuperar e aplicar o último stash salvo (e remove do stash):**
  ```bash
  git stash pop
  ```

* **Descartar/Limpar todos os stashes salvos:**
  ```bash
  git stash clear
  ```

---

## ⏪ 5. Histórico e Correções de Erros (Undo & Reset)

* **Ver o histórico de commits formatado em uma linha:**
  ```bash
  git log --oneline --graph --all -n 10
  ```

* **Desfazer alterações em um arquivo antes de adicionar ao staging:**
  ```bash
  git checkout -- arquivo.js
  # Ou comando moderno:
  git restore arquivo.js
  ```

* **Remover um arquivo da área de staging (unstage) mantendo as edições:**
  ```bash
  git reset HEAD arquivo.js
  # Ou:
  git restore --staged arquivo.js
  ```

* **Alterar a mensagem do último commit:**
  ```bash
  git commit --amend -m "fix: mensagem corrigida do ultimo commit"
  ```

* **Desfazer os últimos commits mantendo os arquivos modificados:**
  ```bash
  git reset --soft HEAD~1
  ```

* **Descartar TOTALMENTE os últimos commits e todas as alterações no disco (CUIDADO):**
  ```bash
  git reset --hard HEAD~1
  ```

---

## 🌐 6. Gerenciamento de Repositórios Remotos (`git remote`)

* **Exibir repositórios remotos configurados:**
  ```bash
  git remote -v
  ```

* **Adicionar um repositório remoto origin:**
  ```bash
  git remote add origin https://github.com/usuario/repositorio.git
  ```

* **Alterar a URL de um repositório remoto existente:**
  ```bash
  git remote set-url origin https://github.com/usuario/novo_repositorio.git
  ```
