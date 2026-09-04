# InstaMiners

Servidor Minecraft Java **Fabric 26.2**, estilo vanilla+ / quality of life, hospedado no `bazzite` e administrado pelo Crafty Controller.

## Acesso

| Item | Valor |
|---|---|
| Endereço do jogo | `bazzite:25565` |
| Painel Crafty | `https://bazzite:8443` |
| Rede | Tailscale |
| Tipo de conta | Online e offline/pirata (`online-mode=false`) |

O servidor fica acessível apenas pela tailnet; não há port-forwarding público.

## Configuração do mundo

| Propriedade | Valor |
|---|---|
| Loader | Fabric 0.19.5 |
| Minecraft | 26.2 |
| Java | 25 |
| Modo | Survival |
| Dificuldade | Hard |
| Tipo de mundo | Normal, seed aleatório |
| Porta | 25565 |
| Jogadores máximos | 20 |
| Distância de visão/simulação | 10 chunks |
| Memória | 4–8 GB |
| Autostart e crash detection | Ligados |
| MOTD | `Minerando pelo meme!` |

O mundo atual foi gerado em 4 de setembro de 2026. Para gerar outro, pare o Crafty, apague apenas `world/` dentro da pasta do servidor e inicie-o de novo.

## Identidade visual

- Nome no Crafty: **InstaMiners**
- MOTD: **Minerando pelo meme!**
- Ícone exibido no cliente: [`instaminers-server-icon.png`](instaminers-server-icon.png), PNG 64×64 derivado de `instagrau.jpeg` com redução pixelada.

## Mods do servidor

| Mod | Finalidade |
|---|---|
| Fabric API | Base para mods Fabric |
| Carry On | Carregar baús, máquinas e alguns mobs |
| RightClickHarvest | Colher e replantar com botão direito |
| Architectury API + JamLib | Dependências do RightClickHarvest |
| Clumps | Agrupa orbes de XP e reduz lag |
| Jade | Informações de blocos e entidades |
| Lithium | Otimizações da lógica do jogo |
| FerriteCore | Menor consumo de memória |
| Skin Restorer | Restaura skins em modo offline |

## Mods do cliente

Cada jogador precisa de **Fabric 26.2**. Para compatibilidade com o servidor, instale no cliente Fabric API, Carry On e JamLib; sem eles aparecem avisos no log e funções sincronizadas do Carry On não são enviadas ao cliente.

Estes mods são apenas de cliente e são recomendados:

```text
Mouse Tweaks
Inventory Profiles Next
Shulker Box Tooltip
Jade
AppleSkin
Better Advancements
Roughly Enough Items (REI)
Controlling
Xaero's Minimap
Xaero's World Map
Sodium
Lithium
FerriteCore
ImmediatelyFast
Entity Culling
```

Use sempre builds filtradas para **Minecraft 26.2 + Fabric** no Modrinth. Não instale Sodium, ImmediatelyFast ou Entity Culling no servidor: são otimizações de renderização do cliente.

## Skins em modo offline

Como `online-mode=false`, o Minecraft não autentica perfis pelo Mojang e não atribui automaticamente uma skin à conta. O Skin Restorer está configurado para buscar a skin a cada login, nesta ordem:

1. Mojang;
2. Ely.by.

Ele não sobrescreve uma skin que já esteja salva. Depois de instalar ou alterar uma skin, reconecte ao servidor. Para uma conta offline sem skin registrada no Mojang, associe o mesmo nome de usuário no Ely.by.

## Operação e arquivos

O Crafty roda como um container Podman rootless; o servidor não é um container separado. Os dados ficam em `~/.local/share/crafty/` no `bazzite`:

| Caminho | Conteúdo |
|---|---|
| `servers/1e9f95b5-c01c-4b3e-8cfc-709f21c255e1/` | Mundo, mods e configurações do InstaMiners |
| `backups/` | Backups do Crafty |
| `config/` | Banco de dados e configurações do Crafty |

Comandos úteis no `bazzite`:

```bash
systemctl --user status crafty.service
systemctl --user restart crafty.service
tail -f ~/.local/share/crafty/servers/1e9f95b5-c01c-4b3e-8cfc-709f21c255e1/logs/latest.log
```

Os arquivos do servidor pertencem ao namespace rootless do Podman. Para corrigir permissões após uma manipulação manual:

```bash
podman unshare chown -R 1000:0 \
  ~/.local/share/crafty/servers/1e9f95b5-c01c-4b3e-8cfc-709f21c255e1
```
