# Toolbox — ambiente Arch de desenvolvimento no Bazzite

O `bazzite` executa uma única máquina rootless Podman chamada `lab`, baseada
em Arch Linux. Ela usa Bash com Starship e recebe o mesmo catálogo de pacotes
de desenvolvimento definido no repositório.

| Instância | Finalidade | SSH | Workspace | Home persistente |
|---|---|---|---|---|
| `lab` | Desenvolvimento | `2224` | `~/lab/workspace` | volume `lab-home` |

A imagem é construída de `.setup/toolbox.Dockerfile`. O workspace é uma pasta
normal no Bazzite e o home persistente fica no volume `lab-home`.

## Instalação e atualização

No Bazzite, após aplicar os dotfiles com Stow:

```bash
cd ~/Dotfiles
stow .
./.setup/toolbox-setup.sh
```

O instalador cria `~/lab/workspace`, constrói a imagem, recarrega a unidade
Quadlet `lab` e habilita linger para iniciar o serviço no boot.

## Acesso

```bash
ssh lab
podman exec -it -u henrique lab bash
```

O alias SSH encaminha a porta local `3000` para a porta `3000` dentro do
ambiente.

## Gerenciamento

```bash
systemctl --user status lab.service
systemctl --user restart lab.service
journalctl --user -u lab.service -f
```

Para recriar completamente a máquina, pare a unidade, remova o container e o
volume `lab-home`, e execute novamente `./.setup/toolbox-setup.sh`. O diretório
`~/lab/workspace` deve ser preservado se contiver código.
