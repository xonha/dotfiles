# Caddy (HTTPS privado em plu.nz)

O Caddy dá HTTPS com nome próprio (`https://keeper.plu.nz`) aos serviços
privados do bazzite, sem abri-los para a internet:

```
keeper.plu.nz ──DNS only (Cloudflare)──▶ 100.120.120.71 (bazzite na tailnet)
                                          │ tailscale serve --tcp=443
                                          ▼
                              Caddy em 127.0.0.1:8453 ──▶ 127.0.0.1:8088 (keeper)
```

- **DNS:** cada serviço tem um registro `A <nome>.plu.nz → 100.120.120.71` com
  proxy **desligado** (nuvem cinza). O IP é da faixa 100.64/10 do Tailscale;
  fora da tailnet o nome resolve, mas a conexão não abre.
- **Certificado:** curinga `*.plu.nz` do Let's Encrypt via desafio DNS-01 com
  o módulo `caddy-dns/cloudflare`. Não há porta aberta à internet, e os logs
  públicos de certificados mostram só `*.plu.nz`.
- **Porta 443:** o bazzite tem `net.ipv4.ip_unprivileged_port_start=445`, então
  o Caddy rootless escuta em `127.0.0.1:8453`, e o Tailscale Serve encaminha a
  443 da tailnet para lá em TCP puro.

Os registros públicos com proxy (`jellyfin.plu.nz`, `mediarium.plu.nz`) usam o
Cloudflare Tunnel e não passam por aqui.

Em produção desde 2026-11-03: certificado `*.plu.nz` emitido pelo Let's
Encrypt e renovado pelo próprio Caddy. O registro `keeper.plu.nz` foi criado
pela API com o token do `caddy.env`. Antes da migração, o `keeper.env` do host
foi salvo em `keeper.env.bak-20261103`.

## Token da Cloudflare

Crie um token em *My Profile → API Tokens → Create Token → Edit zone DNS*,
restrito à zona `plu.nz` (`Zone → DNS → Edit`). No bazzite:

```bash
cp bazzite/caddy/caddy.env.example ~/.config/containers/systemd/caddy.env
chmod 600 ~/.config/containers/systemd/caddy.env
# preencha CLOUDFLARE_API_TOKEN
```

## Instalação

```bash
./bazzite/setup.sh caddy
```

O setup constrói `localhost/caddy-cloudflare:2` a partir do `Containerfile`,
instala o `Caddyfile` em `~/.config/caddy/`, inicia `caddy.service` e configura
`tailscale serve --tcp=443`. Os certificados ficam em `~/.local/share/caddy/data`.

## Adicionar um serviço

1. Crie o registro `A <nome>.plu.nz → 100.120.120.71`, DNS only.
2. Adicione um bloco `@<nome> host <nome>.plu.nz` + `handle` no `Caddyfile`.
3. No bazzite, copie o arquivo e recarregue:

```bash
scp bazzite/caddy/Caddyfile bazzite:~/.config/caddy/Caddyfile
ssh bazzite systemctl --user restart caddy.service
```

## Operação

```bash
systemctl --user status caddy.service
podman logs -f caddy
tailscale serve status            # deve listar tcp://127.0.0.1:8453 na 443
```

Para atualizar o Caddy, reconstrua a imagem:

```bash
podman build --pull -f Containerfile -t localhost/caddy-cloudflare:2 .
systemctl --user restart caddy.service
```

## Problemas conhecidos

Alguns roteadores e o Pi-hole descartam respostas DNS com IP privado
("proteção contra DNS rebinding"). Se `keeper.plu.nz` não resolver numa rede
específica, verifique isso ou use o endereço `.ts.net` do serviço.
