# Dotfiles

Configuração pessoal para CachyOS/Arch, instalada com GNU Stow.

## Instalação

```bash
git clone https://github.com/henriqueluhm/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./.setup/install.sh
```

O instalador configura a base de terminal e permite escolher a instalação do
desktop Hyprland. Os ajustes específicos de hardware ficam fora do fluxo
principal.

## ThinkPad

Para habilitar wake por teclado e tampa nesta máquina:

```bash
./.setup/desktop/thinkpad_t495/wakeup.sh
```

Os IDs de hardware e o diagnóstico estão documentados em
[`.setup/README.md`](.setup/README.md).

## Devbot no Bazzite

A imagem e o Quadlet rootless do Devbot são versionados aqui. No `console`,
depois de aplicar os dotfiles com Stow, execute:

```bash
./.setup/devbot/install.sh
```

Ele constrói a imagem, cria o workspace persistente em `~/devbot/workspace` e
habilita `devbot.service` para iniciar no boot. O guia operacional está em
[`.setup/docs/devbot.md`](.setup/docs/devbot.md).
