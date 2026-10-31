# Jarvis

O Jarvis roda Music Assistant, Whisper e Piper em Podman rootless. Os arquivos
`.container` são as configurações versionadas dos serviços; os dados ficam em
`~/.local/share/jarvis/` no Jarvis e não devem ser copiados para este
repositório.

## Instalação e atualização

No computador que tem o alias SSH `jarvis`:

```bash
./jarvis/deploy.sh
```

Music Assistant usa `http://jarvis:8095`; use essa interface para adicionar
rádio ou arquivos de música locais. Para garantir inicialização sem uma sessão
SSH ou gráfica ativa, execute uma vez no Jarvis:

```bash
loginctl enable-linger henrique
```

Verificação no Jarvis:

```bash
systemctl --user status music-assistant.service
systemctl --user status wyoming-whisper.service wyoming-piper.service
podman logs music-assistant
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8095/
```

Para atualizar, revise as versões das imagens nos arquivos `.container` e rode
`./jarvis/deploy.sh`. O script reinicia apenas os serviços cujo arquivo
`.container` mudou em relação à cópia no Jarvis. Ele mantém o Home Assistant
desativado e preserva os dados existentes em `~/.local/share/jarvis/homeassistant`
caso queira recuperá-los depois.

## Tampa do notebook

`logind-lid.conf` é instalado em `/etc/systemd/logind.conf.d/jarvis-lid.conf`
para que fechar a tampa não suspenda o Jarvis. Por ser um arquivo do sistema, o
`deploy.sh` pede a senha do `sudo` no Jarvis apenas quando esse arquivo muda.

## Backup

O timer `jarvis-backup.timer` roda `~/.local/bin/jarvis-backup` todo dia às
4h e guarda os 14 arquivos mais recentes em `~/.local/share/jarvis-backups/`.
O arquivo inclui os dados do Music Assistant e do satélite de voz. Os dados
antigos do Home Assistant são excluídos do backup. Os modelos de Whisper e
Piper e os caches ficam de fora, porque são baixados de novo. O Music Assistant
trava os próprios bancos SQLite, então o backup o para por cerca de 10 segundos.
Os backups ficam no mesmo disco: protegem contra erro de configuração, não
contra falha do disco.

```bash
systemctl --user list-timers jarvis-backup.timer
systemctl --user start jarvis-backup.service   # backup imediato
journalctl --user -u jarvis-backup.service
```

Para restaurar, pare os serviços, extraia o arquivo sobre `~/.local/share/` e
inicie o Music Assistant de novo:

```bash
systemctl --user stop music-assistant.service
tar -C ~/.local/share -xzf ~/.local/share/jarvis-backups/jarvis-AAAAMMDD-HHMMSS.tar.gz
systemctl --user start music-assistant.service
```

O Music Assistant oferece músicas locais e rádio. YouTube Music sem anúncios
requer YouTube Music Premium. Depois de adicionar uma fonte (por exemplo,
Radio Browser) e selecionar um player, configure o próprio Music Assistant.

O lançador `jarvis-meet.desktop` abre o Google Meet no Firefox do Jarvis. Entre
na conta Google na tela integrada e teste câmera, microfone, alto-falante e uma
chamada real antes de automatizar chamadas por voz.

O lançador `jarvis-chatgpt.desktop` abre o ChatGPT no Firefox do Jarvis. Entre
na conta Pro diretamente na tela integrada e conceda acesso ao microfone se
solicitado.
