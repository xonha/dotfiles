# Toolbox — ambientes Arch de desenvolvimento no Bazzite

Uma imagem rootless Podman compartilhada sustenta dois ambientes isolados no
`bazzite`: trabalho no `devbot` e projetos pessoais no `lab`.

| Instância | Finalidade | SSH | Workspace | Home persistente |
|---|---|---|---|---|
| `devbot` | Trabalho | `2223` | `~/devbot/workspace` | volume `devbot-home` |
| `lab` | Projetos pessoais | `2224` | `~/lab/workspace` | volume `lab-home` |

Ambas usam `localhost/toolbox:latest`, construída de
`.setup/toolbox/Dockerfile`. Cada uma monta suas próprias pastas e volume; uma
não compartilha código nem configuração da outra. As chaves autorizadas de
`~/.ssh/authorized_keys` no `bazzite` são copiadas para cada home ao iniciar.

Durante a construção, o Toolbox executa os mesmos estágios `10-bootstrap-yay`,
`30-server-packages` e `40-login-shell` usados pelo host. O último valida o
Zsh e o torna o shell de login de `henrique`. A variante `toolbox` do estágio
de pacotes mantém as ferramentas comuns, mas exclui os itens exclusivos de
host (Docker, Tailscale e earlyoom).
O usuário `henrique` usa a mesma configuração Zsh do repositório (`.zshrc`,
`.zshenv` e `.p10k.zsh`), copiada apenas na primeira inicialização do home
persistente.

## Instalação e atualização

No `bazzite`, após aplicar os dotfiles com Stow:

```bash
cd ~/Dotfiles
stow .
./.setup/toolbox/install.sh
```

O instalador cria os workspaces, constrói a imagem, reinicia as duas unidades
e habilita linger. O `[Install]` dos Quadlets faz com que ambas iniciem no boot
sem login interativo.

## Acesso

```bash
ssh devbot                 # trabalho; encaminha localhost:3000
ssh lab                    # pessoal; encaminha localhost:3001 para :3000

# No bazzite
podman exec -it -u henrique devbot bash
podman exec -it -u henrique lab bash
```

## Gerenciamento

```bash
systemctl --user status devbot.service lab.service
systemctl --user restart devbot.service
systemctl --user restart lab.service
journalctl --user -u lab.service -f
```

Para remover deliberadamente apenas um home persistente, pare a respectiva
unidade e remova seu volume (`devbot-home` ou `lab-home`). Os workspaces são
pastas normais no host e não são removidos pelo Podman.
