# Protocolo miolo ↔ destino (versão 1)

O `tesla` (o miolo) entende a frase falada e produz uma ação. Um destino grava essa ação em algum lugar; ele pode ser qualquer executável, em qualquer linguagem, que responda aos subcomandos abaixo. Você escolhe o destino em `~/.config/tesla/config.toml`:

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

### `etiquetas` (opcional)

Imprime no stdout um array JSON com as etiquetas (labels, tags, categorias) que a ação pode usar em `categories`. Cada item é um nome ou um objeto com exemplos de tarefas que já usam a etiqueta:

```json
["pessoal", {"nome": "materias", "exemplos": ["fazer lista da prova 3", "estudar compiladores"]}]
```

O parser LLM só escolhe etiquetas desta lista e usa os exemplos para entender o assunto de cada uma. Se o destino não tiver esse subcomando (sai com código ≠ 0), o miolo segue sem etiquetas.

### `aplicar`

Lê uma única ação JSON do stdin e aplica. Em sucesso, sai com código 0 e imprime:

```json
{"uid": "427", "resumo": "estudar redes ⏫ 📅 2026-11-13 🆔 427  →  A fazer"}
```

`resumo` é o texto que aparece na notificação. Em erro, sai com código diferente de 0 e escreve a mensagem no stderr. O miolo mostra essa mensagem na notificação.

Subcomandos extras são livres. O destino Obsidian tem `dar-ids`, por exemplo. O destino GitHub Projects usa o número da issue como `uid`.

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
| `description` | string ou `null` | detalhes da tarefa (DESCRIPTION do VTODO) |
| `categories` | lista de strings | etiquetas, sempre entre as que o subcomando `etiquetas` listou (CATEGORIES do VTODO) |
| `checklist` | lista de strings | passos da tarefa, na ordem falada |
| `size` | `XS`, `S`, `M`, `L`, `XL` ou `null` | esforço estimado |

Os quatro últimos campos são opcionais: o parser dateparser os manda vazios e um destino pode ignorá-los. Um destino que não sabe gravar um campo deve avisar no `resumo` em vez de falhar.

O destino gera o `uid`, porque é ele quem sabe quais já existem. Para a pessoa conseguir falar o uid ("mover 427 para feito"), prefira números curtos.

### mover

```json
{"versao": 1, "acao": "mover", "uid": "427", "coluna": "Feito"}
```

Move a tarefa `uid` para `coluna`. Se a coluna representa "concluído", cabe ao destino marcar a tarefa como feita. Um destino sem colunas pode mapear a coluna para o `STATUS` do VTODO (`NEEDS-ACTION`, `IN-PROCESS`, `COMPLETED`).

## Destinos em Python

Os destinos incluídos herdam de `Destino`, em `destinos/protocolo.py`. O miolo é o contexto do padrão Strategy e cada destino é uma estratégia: o miolo só conhece o comando configurado. A classe base cuida dos argumentos `--coluna-padrao` e `--coluna-feito`, dos subcomandos, da checagem de `versao`, do despacho de `adicionar` e `mover` e das mensagens de erro. Um destino novo implementa quatro coisas:

```python
from protocolo import Destino, executar

class MeuDestino(Destino):
    extras = {"listar": "listar"}          # subcomandos próprios, opcional

    @classmethod
    def argumentos(cls, ap): ap.add_argument("--onde", required=True)
    def colunas(self) -> list[str]: ...
    def adicionar(self, acao: dict) -> dict: ...   # devolve {"uid", "resumo"}
    def mover(self, acao: dict) -> dict: ...

if __name__ == "__main__":
    sys.exit(executar(MeuDestino, __doc__))
```

O arquivo fica em `destinos/`, ao lado de `protocolo.py`. O Python resolve o symlink de `~/.local/bin` e acha o módulo pelo diretório real do script. `self.e_feito(coluna)` diz se a coluna é a de concluídos, e `chave()` e `nomes_prioridade()` ajudam a casar nomes falados com os do destino.

## Versão

Toda ação leva `versao`. O destino deve recusar (código ≠ 0) uma versão que não conhece. Mudanças incompatíveis no formato aumentam esse número.

## Testar um destino sem voz

```bash
destino colunas
echo '{"versao":1,"acao":"adicionar","summary":"teste","priority":null,"dtstart":null,"due":null,"coluna":null}' \
  | destino aplicar
tesla --dry-run --texto "teste prioridade alta fim sexta"   # mostra a ação que seria enviada
```
