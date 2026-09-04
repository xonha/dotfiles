# Dotfiles

Configuração pessoal para Arch, instalada com GNU Stow. O instalador detecta
o Omarchy e preserva os componentes que ele administra (Hyprland, shell,
Foot, navegador e gerenciador de arquivos), instalando apenas os complementos
independentes deste repositório.

## Instalação

```bash
git clone https://github.com/henriqueluhm/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./.setup/install.sh
```

O instalador configura a base de terminal e permite escolher a instalação do
desktop. No Omarchy, o perfil legado CachyOS/Hyprland/Noctalia/Kitty não é
aplicado; os dotfiles desse perfil também são excluídos do Stow. Os ajustes
específicos de hardware ficam fora do fluxo principal.

## ThinkPad

Para habilitar wake por teclado e tampa nesta máquina:

```bash
./.setup/desktop/thinkpad_t495/wakeup.sh
```

Os IDs de hardware e o diagnóstico estão documentados em
[`.setup/README.md`](.setup/README.md).

## Ambientes de desenvolvimento no Bazzite

`devbot` (trabalho) e `lab` (projetos pessoais) usam a mesma imagem Toolbox,
mas têm homes, workspaces e portas SSH independentes. No `bazzite`, depois de
aplicar os dotfiles com Stow, execute:

```bash
./.setup/toolbox/install.sh
```

O guia operacional está em [`.docs/toolbox.md`](.docs/toolbox.md).
