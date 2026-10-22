# Jarvis: Home Assistant

O Jarvis roda Home Assistant, Music Assistant, Whisper, Piper e o satélite
Linux Voice Assistant em Podman rootless. Os arquivos `.container` são as
configurações versionadas dos serviços;
os dados ficam em `~/.local/share/jarvis/` no Jarvis e não devem ser copiados
para este repositório.

## Instalação e atualização

No computador que tem o alias SSH `jarvis`:

```bash
./jarvis/deploy.sh
```

O Home Assistant usa a porta 8123. Abra `http://jarvis:8123` pela tailnet e
conclua a criação da conta de administrador na interface. Não guarde essa senha
no repositório. Music Assistant usa `http://jarvis:8095`; use essa interface
para adicionar rádio ou arquivos de música locais. Para garantir inicialização
sem uma sessão SSH ou gráfica ativa,
execute uma vez no Jarvis:

```bash
loginctl enable-linger henrique
```

Verificação no Jarvis:

```bash
systemctl --user status homeassistant.service
systemctl --user status music-assistant.service
systemctl --user status wyoming-whisper.service wyoming-piper.service
systemctl --user status linux-voice-assistant.service
podman logs homeassistant
podman logs music-assistant
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8123/
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8095/
```

Para atualizar, revise as versões das imagens nos arquivos `.container`, rode
`./jarvis/deploy.sh` e reinicie os serviços com `systemctl --user restart` no
Jarvis.

## Próximas integrações

- Pareie as luzes e demais dispositivos na interface do Home Assistant.
  A necessidade de um coordenador Zigbee, Thread ou Matter depende dos
  dispositivos reais; um rádio USB exigirá mapeamento adicional no container.
- A voz local requer microfone, alto-falante, wake word, transcrição e síntese
  configurados como um dispositivo Assist. Whisper transcreve em português e
  Piper fala em português brasileiro. Esta instalação não usa a assinatura
  Home Assistant Cloud nem a loja de Apps do Home Assistant OS. Em
  Configurações → Dispositivos e serviços → Adicionar integração, procure
  **Wyoming Protocol** e adicione duas entradas apontando para
  `127.0.0.1:10300` (Whisper) e
  `127.0.0.1:10200` (Piper), depois selecione os dois em um Assist de idioma
  português brasileiro. O satélite deve aparecer como dispositivo ESPHome;
  se não aparecer, adicione uma integração ESPHome no IP Wi-Fi do Jarvis e
  porta 6053 (veja `Server started` em `podman logs linux-voice-assistant`).
  O wake word configurado é `hey_jarvis`. Validar áudio e carga da CPU neste
  notebook; o microfone integrado pode exigir aproximação física.
- Music Assistant oferece músicas locais e rádio, mas YouTube Music sem anúncios
  requer YouTube Music Premium. A conta atual não tem Premium. O processador
  Intel deste notebook é antigo; Smart Fades não funciona sem AVX2. Depois de
  adicionar uma fonte (por exemplo, Radio Browser) e selecionar um player,
  adicione a integração oficial Music Assistant em Home Assistant →
  Configurações → Dispositivos e serviços, usando `127.0.0.1:8095` e a conta
  administradora do Music Assistant. Exponha o player ao Assist em
  Configurações → Assistentes de voz → Expor para comandar a música por voz.
- O lançador `jarvis-meet.desktop` abre o Google Meet no Firefox do Jarvis.
  Entre na conta Google na tela integrada e teste câmera, microfone,
  alto-falante e uma chamada real antes de automatizar chamadas por voz.
