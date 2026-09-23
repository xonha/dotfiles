---
name: human-review
description: Revisa um PR e posta como GitHub review com comentarios inline (um por achado, ancorados em linhas de codigo), em tom humano e informal PT-BR sem acentos. Use quando o usuario pedir review de PR nesse estilo, code review humanizado, ou comentarios nas linhas ao inves de um comentario solto no corpo do PR.
---

# Human Review

Skill pra revisar Pull Requests e publicar o review com comentarios **inline**
(ancorados em linhas de codigo), em tom humano e informal.

## Quando usar

- Pedido de review de PR ("revisa o PR X", "code review humano").
- Usuario quer comentarios nas linhas, nao um texto solto no corpo do PR.

## Tom (o ponto principal)

- Portugues do Brasil, informal, **sem acentos**.
- Abreviacoes naturais: "vc", "pra", "tb", "ta".
- Informal, mas **sem girias**. Direto e tecnico.
- Um comentario por achado.
- **Tom de duvida, nao de veredito**: nao afirma que ta errado, pergunta se ta certo.
  Fala como quem leu rapido e quer confirmar com o autor, nao como quem ja decidiu.
  Usa "acho que", "sera que", "nao sei se", "confere?", "faz sentido isso?" em vez de
  "isso ta errado" / "precisa mudar". O autor sabe mais do contexto que a gente.
- Por padrao posta so 🔴 (bloqueador) e 🟡 (ajuste recomendado). Pula 🟢 nitpick,
  salvo se o usuario pedir.
- No preview da conversa, usa os emojis de severidade normalmente.
- **Nos comentarios postados no PR (body do comentario inline), sem emojis.** Texto limpo.
- Sempre que der, manda sugestao de codigo (bloco `suggestion`) junto — mesmo no tom
  de duvida ("algo assim talvez?"). So pula quando o fix nao for trivial (precisa de
  mudanca em varios arquivos/camadas) — nao vale se esforcar muito pra forcar uma.

## Processo

1. **Contexto**: se tiver card (Jira/issue) ligado, le o escopo + Definition of Done.
   Confirma o que o PR deveria entregar.
2. **Codigo**: le o diff do PR **e** o codigo ao redor (nao so o diff) pra entender os
   padroes existentes e achar bug de verdade. Compara com implementacoes irmas.
3. **Mapeia achado -> linha**: cada achado vira um comentario ancorado em arquivo +
   linha(s) do head do PR. Confirma o working tree limpo e pega o SHA do head pra os
   numeros baterem.
4. **Severidade**: classifica 🔴 / 🟡 / 🟢 no preview. Posta so 🔴 e 🟡 — sem emoji no body do comentario GitHub.
5. **Preview**: mostra o review pro usuario antes de postar. So posta apos o ok dele.
6. **Posta**: um review unico via API, com todos os comentarios inline. Sem comentario
   solto no corpo.

## Como postar (gh api)

Endpoint: `POST /repos/{owner}/{repo}/pulls/{n}/reviews` com `comments[]`.

Monta o payload em **Python** — escapa acento, aspas, backtick e o fence `suggestion`
sem dor — e manda com `gh api --input`. Template pronto em [`post_review.py`](post_review.py).

- `commit_id`: fixa no SHA do head — `gh pr view <N> --json headRefOid -q .headRefOid`.
- Comentario de 1 linha: `{path, line, side:"RIGHT", body}`.
- Multi-linha: `{path, start_line, line, start_side:"RIGHT", side:"RIGHT", body}`.
- `event`: `COMMENT` (ou `REQUEST_CHANGES` se o usuario quiser barrar o merge).
- A linha precisa existir no diff (arquivo alterado no PR). Achado sem linha no diff
  (ex: falta de teste de integracao) ancora num arquivo proximo que esta no diff e
  explica no texto.

## Bloco de sugestao

Pra sugerir codigo, o corpo do comentario inclui um bloco `suggestion` que substitui
**exatamente** as linhas do range comentado (cuida a indentacao final):

````
```suggestion
                code,
                "Mensagem amigavel pro usuario.",
```
````
