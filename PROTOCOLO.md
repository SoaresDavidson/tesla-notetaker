# Protocolo miolo ↔ destino (versão 1)

O `quadro-voz` (o miolo) entende a frase falada e produz uma ação. Um destino grava essa ação em algum lugar; ele pode ser qualquer executável, em qualquer linguagem, que responda aos subcomandos abaixo. Você escolhe o destino em `~/.config/quadro-voz/config.toml`:

```toml
destino = ["/caminho/do/destino", "--opcao-do-destino", "valor"]
```

O miolo chama esse comando acrescentando o subcomando no fim: `/caminho/do/destino --opcao-do-destino valor colunas`.

## Subcomandos

### `colunas`

Imprime no stdout um array JSON com os nomes das colunas (ou listas, ou estados) do destino.

```json
["A fazer", "Fazendo", "Feito"]
```

O miolo usa essa lista para reconhecer a coluna falada ("na coluna fazendo"). Um destino sem colunas pode devolver `[]`.

### `aplicar`

Lê uma única ação JSON do stdin e aplica. Em sucesso, sai com código 0 e imprime:

```json
{"uid": "427", "resumo": "estudar redes ⏫ 📅 2026-11-13 🆔 427  →  A fazer"}
```

`resumo` é o texto que aparece na notificação. Em erro, sai com código diferente de 0 e escreve a mensagem no stderr. O miolo mostra essa mensagem na notificação.

Subcomandos extras são livres. O destino Obsidian tem `dar-ids`, por exemplo.

## Ações

Os nomes dos campos vêm do VTODO do iCalendar (RFC 5545), para que destinos baseados em `.ics` ou CalDAV convertam direto.

### adicionar

```json
{
  "versao": 1,
  "acao": "adicionar",
  "summary": "estudar redes",
  "priority": 3,
  "dtstart": null,
  "due": "2026-11-13",
  "coluna": null
}
```

| Campo | Tipo | Significado |
|---|---|---|
| `summary` | string, não vazia | nome da tarefa |
| `priority` | inteiro de 1 a 9 ou `null` | escala do VTODO: 1 = mais alta, 9 = mais baixa. O miolo usa 1 (máxima), 3 (alta), 5 (média), 7 (baixa), 9 (mínima) |
| `dtstart` | `AAAA-MM-DD` ou `null` | quando começa |
| `due` | `AAAA-MM-DD` ou `null` | prazo |
| `coluna` | string ou `null` | uma das colunas que o destino listou. `null` = o destino escolhe a padrão |

O destino gera o `uid`, porque é ele quem sabe quais já existem. Para a pessoa conseguir falar o uid ("mover 427 para feito"), prefira números curtos.

### mover

```json
{"versao": 1, "acao": "mover", "uid": "427", "coluna": "Feito"}
```

Move a tarefa `uid` para `coluna`. Se a coluna representa "concluído", cabe ao destino marcar a tarefa como feita. Um destino sem colunas pode mapear a coluna para o `STATUS` do VTODO (`NEEDS-ACTION`, `IN-PROCESS`, `COMPLETED`).

## Versão

Toda ação leva `versao`. O destino deve recusar (código ≠ 0) uma versão que não conhece. Mudanças incompatíveis no formato aumentam esse número.

## Testar um destino sem voz

```bash
destino colunas
echo '{"versao":1,"acao":"adicionar","summary":"teste","priority":null,"dtstart":null,"due":null,"coluna":null}' \
  | destino aplicar
quadro-voz --dry-run --texto "teste prioridade alta fim sexta"   # mostra a ação que seria enviada
```
