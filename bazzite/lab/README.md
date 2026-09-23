# Lab — ambiente Arch de desenvolvimento no Bazzite

O `bazzite` executa uma única máquina rootless Podman chamada `lab`, baseada
em Arch Linux. Ela usa Bash com Starship e recebe o mesmo catálogo de pacotes
de desenvolvimento definido no repositório.

| Instância | Finalidade | SSH | Workspace | Home persistente |
|---|---|---|---|---|
| `lab` | Desenvolvimento | `2224` | `~/lab/workspace` | volume `lab-home` |

A imagem é construída de `bazzite/lab/Dockerfile`. O workspace é uma pasta
normal no Bazzite e o home persistente fica no volume `lab-home`. Na primeira
inicialização, o container clona `https://github.com/xonha/dotfiles.git` em
`~/Dotfiles` e executa `dotdrop install` a partir desse clone.

## Instalação e atualização

No Bazzite, após aplicar os dotfiles com Dotdrop:

```bash
cd ~/Dotfiles
dotdrop install --cfg config/dotdrop.yaml --profile omarchy
./bazzite/lab/setup.sh
```

O instalador cria `~/lab/workspace`, constrói a imagem, recarrega a unidade
Quadlet `lab` e habilita linger para iniciar o serviço no boot.

## Definition of Done da reprodução

Uma recriação de `lab` só está concluída quando:

- `lab.service` está ativo e `ssh lab` funciona;
- `~/Dotfiles` existe dentro do `lab` e é um clone limpo do repositório;
- `dotdrop install` foi executado a partir de `~/Dotfiles`;
- o login usa Bash;
- `config/bash.conf`, `bash_profile`, `config/tmux.conf` e `config/starship.toml` estão
  presentes no home do usuário;
- `starship` e `tmux` estão disponíveis;
- `blesh` está instalado pelo AUR (com build upstream como fallback) e uma
  sessão Bash interativa expõe `BLE_VERSION`;
- os checksums das configurações aplicadas foram comparados com o repositório.

O Foot fica fora do container: é uma configuração gráfica do host que abre a
conexão SSH. Portanto, sua validação ocorre no Omarchy/Bazzite host, não dentro
do `lab`.

## Acesso

```bash
ssh lab
podman exec -it -u henrique lab bash
```

O alias SSH encaminha a porta local `3000` para a porta `3000` dentro do
ambiente.

## Podman dentro do `lab`

O `lab` roda seu próprio Podman rootless, isolado dos serviços do Bazzite.
O `docker` é o shim do `podman-docker` e o `docker-compose` é o provider do
`podman compose` (`config/containers/compose.conf`).

- `lab.container` repassa `/dev/fuse` e `/dev/net/tun`, desativa o label
  SELinux e usa `Unmask=ALL` para que os containers internos montem `/proc`.
- O Dockerfile delega ao usuário os IDs `1-999` e `1001-65535` em
  `/etc/subuid`/`/etc/subgid`, os únicos mapeados pelo `keep-id` externo.
- `containers.conf` (em `/etc/containers/containers.conf.d/10-lab.conf`) usa
  `cgroupfs` e eventos em arquivo, pois não há systemd. Sem cgroups delegados,
  limites de CPU/memória por container interno não são aplicados.
- O `/start.sh` cria `/run/user/1000` e sobe `podman system service`, e o
  `config/bash.conf` exporta `XDG_RUNTIME_DIR` e `DOCKER_HOST` nas sessões SSH.

Validação:

```bash
podman info --format '{{.Host.Security.Rootless}} {{.Store.GraphDriverName}}'
podman run --rm docker.io/library/alpine echo ok
docker compose version
echo "$DOCKER_HOST"
```

Portas publicadas pelos containers internos ficam na rede do `lab`; acesse
pelo encaminhamento SSH (por exemplo, a porta `3000`).

## Gerenciamento

```bash
systemctl --user status lab.service
systemctl --user restart lab.service
journalctl --user -u lab.service -f
```

Para recriar completamente a máquina, pare a unidade, remova o container e o
volume `lab-home`, e execute novamente `./bazzite/lab/setup.sh`. O diretório
`~/lab/workspace` deve ser preservado se contiver código.
