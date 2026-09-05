# 🚀 Guia Rápido e Cheat Sheet do tmux

![tmux](https://img.shields.io/badge/tmux-1BB91F?style=flat&logo=tmux&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=flat&logo=linux&logoColor=black)
![Terminal](https://img.shields.io/badge/Terminal-informational?style=flat&logo=gnometerminal&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)

O **tmux** (Terminal Multiplexer) permite criar, acessar e alternar entre várias sessões de terminal na mesma janela. O seu maior benefício em servidores é que **os comandos continuam rodando em segundo plano mesmo se a sua conexão SSH cair**.

> 💡 **Tecla de Atalho Principal (Prefix):**  
> Quase todos os comandos dentro do `tmux` exigem que você pressione **`Ctrl + b`** primeiro, solte, e depois aperte a tecla do atalho.

---

## 📌 1. Gerenciamento de Sessões (Fora do tmux / Terminal)

| Ação | Comando Shell |
| :--- | :--- |
| **Iniciar sessão sem nome** | `tmux` |
| **Iniciar sessão com nome** | `tmux new -s nome_da_sessao` |
| **Listar sessões ativas** | `tmux ls` ou `tmux list-sessions` |
| **Voltar a uma sessão (Reanexar)** | `tmux a -t nome_da_sessao` ou `tmux attach -t nome_da_sessao` |
| **Voltar à última sessão acessada** | `tmux a` |
| **Matar/Encerrar uma sessão** | `tmux kill-session -t nome_da_sessao` |
| **Matar TODAS as sessões** | `tmux kill-server` |

---

## 💻 2. Comandos Dentro do tmux (Prefix = `Ctrl + b`)

### 🔌 Conexão & Sessão
* **`Ctrl + b`** depois **`d`** $\rightarrow$ **Sair sem encerrar** (Detach): Sai do tmux deixando tudo rodando em segundo plano.
* **`Ctrl + b`** depois **`s`** $\rightarrow$ **Navegar pelas sessões**: Exibe um menu interativo para alternar de sessão.
* **`Ctrl + b`** depois **`$`** $\rightarrow$ **Renomear a sessão atual**.

---

## 📑 3. Gerenciando Janelas (Tabs)

Uma sessão pode ter várias janelas (como abas de um navegador):

| Atalho (`Ctrl + b` + ...) | Ação |
| :--- | :--- |
| **`c`** | Criar **nova janela** (*Create*) |
| **`,`** | **Renomear** a janela atual |
| **`n`** | Ir para a **próxima** janela (*Next*) |
| **`p`** | Ir para a janela **anterior** (*Previous*) |
| **`0` a `9`** | Ir direto para a janela de número X |
| **`w`** | Menu visual para selecionar a janela |
| **`&`** | Fechar a janela atual (pede confirmação `y/n`) |

---

## 🔲 4. Dividindo a Tela em Painéis (Panes)

Divisão da tela em várias sub-janelas ativas simultaneamente:

| Atalho (`Ctrl + b` + ...) | Ação |
| :--- | :--- |
| **`%`** | Dividir a tela **Verticalmente** (lado a lado `│`) |
| **`"`** | Dividir a tela **Horizontalmente** (em cima e embaixo `─`) |
| **`Setas`** | Mover o cursor entre os painéis (Cima, Baixo, Esquerda, Direita) |
| **`o`** | Ir para o próximo painel |
| **`z`** | **Zoom / Maximizar** o painel atual (aperte novamente para restaurar) |
| **`x`** | Fechar o painel atual |
| **`Espaço`** | Alternar entre layouts automáticos pré-definidos |
| **`{`** / **`}`** | Mover o painel atual para a esquerda/direita |

---

## 📜 5. Rolagem de Tela e Histórico (Scroll Mode)

Como os painéis do tmux controlam o terminal, para subir o histórico de logs:

1. Pressione **`Ctrl + b`** e depois **`[`** (abre o modo de cópia/rolagem).
2. Use as **Setas do Teclado**, **Page Up / Page Down** para rolar a tela para cima ou para baixo.
3. Pressione a tecla **`q`** ou **`Esc`** para sair do modo de rolagem e voltar ao terminal normal.

---

### ⚡ Resumo dos Atalhos Mais Usados no Dia a Dia

```text
Ctrl + b depois d  --> Sai do tmux sem parar o processo (Detach)
Ctrl + b depois %  --> Divide a tela verticalmente (Lado a Lado)
Ctrl + b depois "  --> Divide a tela horizontalmente (Cima / Baixo)
Ctrl + b depois z  --> Maximiza/Restaura a janela em foco
Ctrl + b depois c  --> Cria uma nova aba/janela
Ctrl + b depois n  --> Vai para a próxima aba
Ctrl + b depois [  --> Permite rolar a tela para cima (Aperte 'q' para sair)
```
