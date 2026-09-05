# Dotfiles

Configuração pessoal para Arch, instalada com GNU Stow. O instalador detecta
o Omarchy e preserva os componentes que ele administra (shell, Foot, navegador
e gerenciador de arquivos). As configurações de usuário do Hyprland são
versionadas neste repositório e aplicadas após os padrões do Omarchy.

## Instalação

```bash
git clone https://github.com/henriqueluhm/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./.setup/install.sh
```

O instalador configura a base de terminal e permite escolher a instalação do
desktop. O Omarchy já fornece `yay`, então o bootstrap desse helper não é
executado no host. No Omarchy, o perfil legado do Kitty
não é aplicado; os dotfiles correspondentes também são excluídos do Stow.
Os ajustes específicos de hardware ficam fora do fluxo principal.

## ThinkPad

Wake por teclado e tampa via udev rules — diagnóstico e configuração manual
documentados em [`.setup/README.md`](.setup/README.md).

## Ambientes de desenvolvimento no Bazzite

`devbot` (trabalho) e `lab` (projetos pessoais) usam a mesma imagem Toolbox,
mas têm homes, workspaces e portas SSH independentes. No `bazzite`, depois de
aplicar os dotfiles com Stow, execute:

```bash
./.setup/toolbox/install.sh
```

O guia operacional está em [`.docs/toolbox.md`](.docs/toolbox.md).
