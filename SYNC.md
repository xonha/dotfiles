# Regras de sincronização de calendários

## Objetivo

Substituir o Keeper.sh por um sincronizador próprio, executado no Bazzite,
usando a Google Calendar API e mantendo os eventos sincronizados sem criar
ciclos ou duplicações.

## Calendários envolvidos

| Direção | Origem | Destino |
|---|---|---|
| Trabalho → pessoal | `henrique.oliveira@maistodos.com.br` / `MaisTodos` | `henriquecastro1198@gmail.com` / `MaisTodos` |
| Pessoal → trabalho | `henriquecastro1198@gmail.com` / `Pessoal` | `henrique.oliveira@maistodos.com.br` / `MaisTodos` |

## Trabalho → pessoal

Os eventos do calendário corporativo `MaisTodos` devem ser copiados para o
calendário pessoal `MaisTodos` preservando, quando disponíveis. Eventos cujo
título seja exatamente `[PESSOAL]` devem ser ignorados neste fluxo:

- título;
- descrição;
- horário, duração e fuso horário;
- localização;
- recorrência;
- participantes;
- dados de videoconferência (`conferenceData`), incluindo o link do Google Meet;
- alterações e cancelamentos posteriores na origem.

Eventos removidos na origem devem ser removidos do destino quando tiverem sido
criados pelo sincronizador.

## Pessoal → trabalho

Os eventos do calendário pessoal `Pessoal` devem bloquear o horário no
calendário corporativo `MaisTodos`, sem expor detalhes pessoais.

No destino, cada evento deve conter somente:

- título fixo: `[PESSOAL]`;
- data, horário, duração e fuso horário.

Não devem ser copiados:

- título original;
- descrição;
- localização;
- participantes;
- link ou dados do Google Meet;
- anexos ou outros detalhes do evento.

Alterações de horário, duração ou cancelamento na origem devem ser refletidas
no evento anonimizado do destino.

## Proteção contra ciclos e duplicações

Todo evento criado pelo sincronizador deve carregar uma identificação técnica
da origem e da direção, por exemplo:

```text
X-SYNC-SOURCE: personal
X-SYNC-SOURCE-ID: <id-do-evento-na-origem>
X-SYNC-DIRECTION: personal-to-work
```

O sincronizador deve:

- atualizar eventos gerenciados por ele em vez de criar duplicatas;
- ignorar eventos gerados pelo próprio sincronizador ao processar a direção
  inversa;
- nunca tratar um evento `Personal → MaisTodos` como origem para o fluxo
  `MaisTodos → MaisTodos` pessoal;
- nunca alterar ou remover eventos criados manualmente no destino;
- nunca copiar eventos `[PESSOAL]` do `MaisTodos` corporativo para o `MaisTodos`
  pessoal;
- manter um mapa persistente entre ID da origem e ID do destino.

## Operação

- Durante o desenvolvimento, execução manual e local, sem timer e sem alterar
  o Bazzite;
- Após validação, execução periódica no Bazzite via `systemd --user`;
- autenticação OAuth armazenada no Secret Service;
- nenhum token ou segredo no repositório;
- modo `dry-run` obrigatório antes de alterações;
- logs suficientes para auditar criações, atualizações, remoções e falhas;
- retries para falhas temporárias da API;
- sincronização incremental sempre que possível.

## Fases de implantação

1. **Teste local em modo `dry-run`**: somente leitura, sem alterações nos
   calendários.
2. **Aplicação local controlada**: executar uma janela pequena e revisar os
   eventos criados ou atualizados.
3. **Validação bidirecional**: testar alterações, cancelamentos, anonimização e
   proteção contra ciclos.
4. **Instalação no Bazzite**: somente depois dos testes locais, configurar o
   serviço e o timer do `systemd --user`.

## Pendência

Definir o tratamento dos eventos pessoais que já existem atualmente no
calendário corporativo: convertê-los para o formato `[PESSOAL]` ou deixar os
eventos existentes intactos e aplicar a regra somente a eventos novos ou
gerenciados pelo sincronizador.
