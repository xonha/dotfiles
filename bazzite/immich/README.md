# Immich — Fotos e vídeos no Bazzite

O Immich roda no `bazzite` como uma implantação Compose rootless usando o
`podman compose` já disponível no sistema. A configuração segue o Compose
oficial do Immich, com ajustes mínimos para Podman, SELinux e acesso restrito
por endereço.

## Arquitetura

| Item | Valor |
|------|-------|
| Host | `bazzite` — Bazzite Silverblue |
| Backend | Podman rootless + `podman compose` |
| Versioned Compose | `bazzite/immich/docker-compose.yml` neste repositório |
| Diretório Compose | `/var/home/henrique/immich/` |
| Servidor | `immich_server` |
| PostgreSQL | `immich_postgres` |
| Redis/Valkey | `immich_redis` |
| Machine learning | `immich_machine_learning`, CPU |
| Versão | `v3` (a versão da imagem é determinada pela release atual) |
| Porta local | `2283` |

O arquivo versionado em `bazzite/immich/docker-compose.yml` é baseado no
Compose da release oficial atual do Immich. Ele contém os ajustes locais para
Podman, SELinux e os endereços LAN/Tailscale/localhost. A cópia operacional
fica em `/var/home/henrique/immich/docker-compose.yml` no Bazzite.

O `.env` não é versionado: ele contém a senha do PostgreSQL e valores
específicos da máquina.

## Armazenamento

| Dados | Caminho | Disco |
|-------|---------|-------|
| Compose e configuração | `/var/home/henrique/immich/` | NVMe do Bazzite |
| PostgreSQL | `/var/home/henrique/immich/postgres` | NVMe local |
| Fotos e vídeos | `/run/media/system/hd/immich/library` | `/dev/sdb1`, ext4, HD |
| Cache de modelos | Volume Podman `model-cache` | armazenamento local do Podman |

O PostgreSQL não deve ser colocado em um futuro pool de mergerfs/SnapRAID ou
em um compartilhamento de rede. A biblioteca de mídia está separada para
permitir uma migração futura do armazenamento sem mudar a arquitetura lógica
do Immich.

O HD é montado pelo mecanismo de automount do Bazzite em
`/run/media/system/hd`. Antes de iniciar ou atualizar o Immich, confirme que
esse caminho é realmente `/dev/sdb1`; caso contrário, não inicie o Compose.

## Rede e acesso

O servidor está publicado somente nestes endereços locais:

```text
192.168.0.34:2283       LAN
100.120.120.71:2283     Tailscale
127.0.0.1:2283          destino do Tailscale Funnel
```

Não há port forwarding no roteador e não há publicação direta da porta 2283
na Internet.

### Tailscale Funnel

O Funnel está ativo para permitir que pessoas sem Tailscale acessem o Immich
pelo navegador:

```text
https://bazzite.tail9319fe.ts.net:10000
```

A configuração atual do Funnel é mantida pelo estado do daemon do Tailscale,
não por um Quadlet ou arquivo deste repositório. O serviço local encaminhado é
`http://127.0.0.1:2283`.

Verificar:

```bash
tailscale funnel status
tailscale serve status
```

Recriar ou atualizar o Funnel:

```bash
tailscale funnel --bg --https=10000 http://127.0.0.1:2283
```

Desativar toda a configuração Funnel:

```bash
tailscale funnel reset
```

O Funnel torna o endpoint público. Para compartilhar fotos, prefira links
públicos do Immich com senha e data de expiração, desabilitando download e
upload quando não forem necessários. Não compartilhe a conta administrativa.

O serviço Tailscale Serve existente para `localhost:3000` deve ser preservado;
por isso o Immich usa a porta pública `10000`, em vez de substituir o Serve na
porta 443.

## Operação

No `bazzite`:

```bash
cd /var/home/henrique/immich

# Estado
podman compose ps
podman ps --filter name=immich

# Logs
podman logs -f immich_server
podman logs -f immich_postgres

# A partir da máquina onde este repositório está disponível, publicar o Compose versionado
scp bazzite/immich/docker-compose.yml bazzite:/var/home/henrique/immich/docker-compose.yml

# No bazzite, validar e aplicar a configuração
cd /var/home/henrique/immich
podman compose config
podman compose up -d

# Persistência no boot
systemctl --user status podman-restart.service
```

O `podman-restart.service` deve permanecer habilitado porque os containers
foram criados com `restart=always`. O `loginctl` do usuário `henrique` deve
continuar com `Linger=yes`.

Não use `podman compose down` como rotina de atualização sem confirmar o
impacto; o PostgreSQL e a biblioteca são dados persistentes importantes.

## Segurança e escopo

- PostgreSQL e Redis não têm portas publicadas para a rede.
- SELinux permanece `Enforcing`; os bind mounts do Immich usam `:Z`.
- CUDA, ROCm, OpenVINO e outras acelerações de ML não estão configuradas.
- Google Takeout, NAS, parity, backups off-site e serviços adicionais ainda
  não fazem parte desta implantação.
- O Funnel deve ser tratado como exposição pública e desligado quando não for
  necessário.

## Referências

- [Immich — Docker Compose](https://docs.immich.app/install/docker-compose/)
- [Immich — Sharing](https://docs.immich.app/features/sharing/)
- [Tailscale — Funnel](https://tailscale.com/docs/features/tailscale-funnel)
