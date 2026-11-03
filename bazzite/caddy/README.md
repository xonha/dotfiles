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

## Estado da implantação (2026-11-03)

> **Em andamento — ainda não está no ar.** Remova esta seção quando concluir.

Já feito:

- Arquivos versionados em `bazzite/caddy/` e `caddy` registrado em
  `bazzite/setup.sh` e `bazzite/host_setup.sh`.
- Imagem `localhost/caddy-cloudflare:2` construída no bazzite (Caddy v2.11.7
  com `dns.providers.cloudflare`). O `Caddyfile` passou no `caddy validate`,
  que só recusou o token de teste.
- `~/.config/containers/systemd/caddy.env` criado no bazzite com `chmod 600`,
  **ainda sem o token**.
- `keeper.env.example` atualizado para `https://keeper.plu.nz`. O
  `keeper.env` **do host não foi alterado** e continua em
  `https://bazzite.tail9319fe.ts.net:8444`.

Ainda não feito: `caddy.service` não foi iniciado, o `tailscale serve --tcp=443`
não foi configurado e o registro DNS não existe.

Para concluir:

1. Criar o token da Cloudflare (seção abaixo) e preenchê-lo no bazzite:
   `ssh -t bazzite nano ~/.config/containers/systemd/caddy.env`.
2. Criar `A keeper.plu.nz → 100.120.120.71` com proxy **desligado** (no painel
   ou pela API com o token).
3. `./bazzite/setup.sh caddy` — inicia o Caddy, emite `*.plu.nz` e configura a
   443 da tailnet. Conferir com `podman logs caddy` e `tailscale serve status`.
4. Migrar o Keeper no host:
   ```bash
   f=~/.config/containers/systemd/keeper.env
   cp -p "$f" "$f.bak-$(date +%Y%m%d)"
   sed -i \
     -e 's|^BETTER_AUTH_URL=.*|BETTER_AUTH_URL=https://keeper.plu.nz|' \
     -e 's|^TRUSTED_ORIGINS=.*|TRUSTED_ORIGINS=https://keeper.plu.nz,https://bazzite.tail9319fe.ts.net:8444,http://localhost:8088|' \
     "$f"
   systemctl --user restart keeper.service
   ```
5. No Google Cloud (e Microsoft, se usado), adicionar `https://keeper.plu.nz`
   como origem JavaScript e o endereço de retorno correspondente no OAuth.
6. Testar `https://keeper.plu.nz` de um nó da tailnet (login e vínculo de
   conta) e confirmar que de fora da tailnet a conexão não abre.

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
