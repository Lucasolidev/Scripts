# 📝 Cheat Sheet - Editor de Texto Vim

## 🚀 Modos de Operação (Básico)
O Vim é um editor modal. Para usá-lo, você precisa alternar entre diferentes modos:

* **Modo Normal:** Modo padrão ao abrir o Vim. Usado para navegar pelo arquivo e rodar atalhos de teclado. Pressione `Esc` para voltar a este modo.
* **Modo de Inserção (Edição):** Modo para digitar texto.
  * `i` — Inicia a digitação na posição atual do cursor.
  * `a` — Inicia a digitação logo após a posição do cursor.
  * `o` — Abre uma nova linha abaixo da atual e entra em modo de edição.
* **Modo Visual (Seleção):** Usado para selecionar blocos de texto.
  * `v` — Seleção caractere por caractere.
  * `V` — Seleção de linhas inteiras.
* **Modo de Comando:** Usado para salvar, sair e configurar o editor. Ativado digitando `:` a partir do **Modo Normal**.

---

## 💾 Salvar e Sair (Comandos de Terminal do Vim)
No **Modo Normal**, digite `:` seguido pelo comando desejado e pressione `Enter`:

* **Salvar o arquivo:**
  ```vim
  :w
  ```
* **Sair do editor (só funciona se não houver alterações pendentes):**
  ```vim
  :q
  ```
* **Salvar as alterações e sair (Mais comuns):**
  ```vim
  :wq
  ```
  *(Ou simplesmente digite `ZZ` em Modo Normal)*
* **Sair forçado descartando qualquer alteração:**
  ```vim
  :q!
  ```

---

## 🔍 Busca e Substituição
Comandos de busca e substituição executados na linha de comando do Vim:

* **Buscar uma palavra no arquivo:**
  No Modo Normal, digite `/` e a palavra de pesquisa (ex: `/erro`). 
  * Pressione `n` para ir para a próxima ocorrência.
  * Pressione `N` para voltar para a ocorrência anterior.

* **Substituir todas as ocorrências de uma palavra no arquivo inteiro:**
  ```vim
  :%s/palavra_velha/palavra_nova/g
  ```

* **Substituir pedindo confirmação antes de cada alteração:**
  ```vim
  :%s/palavra_velha/palavra_nova/gc
  ```

* **Substituir apenas na linha atual onde o cursor está posicionado:**
  ```vim
  :s/palavra_velha/palavra_nova/g
  ```

---

## 📋 Copiar, Recortar e Colar (Clipboard)
Atalhos executados em **Modo Normal**:

* **Copiar (yank) uma linha inteira:**
  ```vim
  yy
  ```
* **Copiar X linhas (ex: 3 linhas a partir do cursor):**
  ```vim
  3yy
  ```
* **Recortar/Deletar (delete) uma linha inteira:**
  ```vim
  dd
  ```
* **Recortar/Deletar X linhas (ex: 5 linhas):**
  ```vim
  5dd
  ```
* **Colar (paste) o conteúdo copiado/recortado:**
  * `p` — Cola na linha abaixo (ou depois do cursor).
  * `P` — Cola na linha acima (ou antes do cursor).
* **Desfazer a última ação (Undo):**
  ```vim
  u
  ```
* **Refazer a ação desfeita (Redo):**
  ```vim
  Ctrl + r
  ```

---

## ✈️ Navegação Rápida (Atalhos de Teclado)
Atalhos executados em **Modo Normal**:

* **Ir para o início do arquivo:**
  ```vim
  gg
  ```
* **Ir para o final do arquivo:**
  ```vim
  G
  ```
* **Ir para uma linha específica (ex: linha 45):**
  ```vim
  :45
  ```
  *(Ou digite `45G`)*
* **Ir para o início da linha atual:**
  ```vim
  0
  ```
* **Ir para o final da linha atual:**
  ```vim
  $
  ```
* **Movimentação básica alternativa:**
  * `h` (esquerda), `j` (baixo), `k` (cima), `l` (direita).

---

## ⚙️ Configurações Úteis (Temporárias)
Comandos digitados no Modo de Comando (`:`) para ajustar o editor na sessão atual:

* **Exibir números de linha:**
  ```vim
  :set number
  ```
* **Ocultar números de linha:**
  ```vim
  :set nonumber
  ```
* **Ativar destaque de sintaxe colorida:**
  ```vim
  :syntax on
  ```
* **Buscar ignorando maiúsculas/minúsculas:**
  ```vim
  :set ignorecase
  ```
