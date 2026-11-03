# Mediarium no Bazzite

O Mediarium roda em um Quadlet Podman rootless. A configuração, o banco de
dados e a chave ficam em `~/.local/share/mediarium/config`; faça backup dessa
pasta inteira. Downloads e bibliotecas ficam em `/run/media/system/hd/mediarium`,
no HD `/dev/sdb1`. O serviço só inicia quando o disco esperado está montado;
se ele ainda não estiver disponível no boot, o systemd tenta novamente.

O container publica a interface apenas em `127.0.0.1:8264`. O Cloudflare
Tunnel disponibiliza a interface publicamente em `https://mediarium.plu.nz`;
o registro DNS é um CNAME com proxy para o túnel do Bazzite, cuja rota aponta
para `http://127.0.0.1:8264`. O Tailscale Serve também disponibiliza HTTPS
somente para a tailnet em `https://bazzite.tail9319fe.ts.net:8449`. Complete
o assistente inicial e configure suas fontes e bibliotecas na interface.
Downloads e bibliotecas compartilham `/data`, permitindo hardlinks no mesmo
filesystem. As portas de entrada de torrents não são publicadas.

## Instalação e operação

```bash
./bazzite/setup.sh mediarium
ssh bazzite systemctl --user status mediarium.service
ssh bazzite podman logs mediarium
ssh bazzite systemctl --user restart mediarium.service
```

Para atualizar: `ssh bazzite podman pull ghcr.io/rdborg/mediarium:latest` e
reinicie o serviço. Não remova o diretório de configuração ou a mídia ao
atualizar. O container executa como root dentro do namespace rootless, mapeado
para o usuário do host; o SELinux é desativado apenas para este container para
não alterar os rótulos do HD compartilhado.
