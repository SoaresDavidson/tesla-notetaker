# tesla-notetaker

Adiciona e move tarefas num quadro Kanban por voz, no Obsidian, num GitHub Project ou no Trello. Você aperta um atalho, fala a tarefa e aperta Enter; o card aparece no quadro e uma notificação confirma.

```
microfone → voxtype (Whisper, local) → tesla (texto → ação JSON) → destino (Obsidian Kanban, GitHub Projects ou Trello)
```

O [voxtype](https://github.com/peteonrails/voxtype) grava e transcreve com o Whisper rodando na sua máquina. O `tesla` separa nome, prioridade, começo, fim e coluna, com o `dateparser` ou com um LLM local via Ollama, e entrega uma ação JSON a um destino. Há três destinos incluídos: um grava num quadro do plugin Kanban do Obsidian, no formato do plugin Tasks; outro cria issues num repositório e as coloca num GitHub Project; o terceiro cria cards num quadro do Trello. Para escrever outro destino, veja o [PROTOCOLO.md](PROTOCOLO.md).

## Como falar

| Frase | Resultado |
|---|---|
| "estudar redes prioridade alta começo amanhã fim sexta" | `- [ ] estudar redes ⏫ 🛫 2026-11-11 📅 2026-11-13 🆔 427` em "A fazer" |
| "ler artigo na coluna fazendo" | card sem datas em "Fazendo" |
| "revisar relatório prazo dia 20 prioridade urgente" | 🔺 com 📅 no dia 20 |
| "mover 427 para feito" | o card 427 vai para "Feito" com o ✅ de hoje |

O campo que você não falar fica em branco. No Obsidian, cada card recebe um 🆔 de 3 dígitos; no GitHub, o número é o da issue. Você move o card dizendo esse número.

| Campo | Palavras reconhecidas |
|---|---|
| prioridade | máxima ou urgente, alta, média ou normal, baixa, mínima |
| começo | começo, início, a partir de |
| fim | fim, prazo, até, entrega, vence |
| coluna | na coluna, para a coluna |

Datas aceitas: hoje, amanhã, depois de amanhã, sexta, segunda que vem, dia 20, 20 de novembro, 20/11, daqui a 3 dias, semana que vem.

### Frase livre (parser LLM)

Com `SUPER+SHIFT+Y` você fala do jeito que quiser, e o LLM preenche também etiquetas, descrição, checklist e tamanho:

> "tenho que entregar a lista da prova 3 de segurança até sexta, é urgente, o professor pediu em pdf, falta resolver as questões 4 e 5 e revisar"

vira o card "entregar lista da prova 3 de segurança", com prioridade máxima, prazo na sexta, a etiqueta `materias`, a descrição "o professor pediu em pdf..." e um checklist com "resolver questão 4", "resolver questão 5" e "revisar".

| Campo | Como o LLM decide |
|---|---|
| prioridade | pelo tom: urgente, importante, sem pressa, quando der. Sem nada disso, fica em branco, mas o modelo às vezes chuta. "prioridade X" dito com essas palavras sempre vence |
| começo e fim | a data como você falou, convertida pelo mesmo código do outro parser. Uma data sem "a partir de" ou "começo" vira prazo |
| coluna | só quando você diz o nome da coluna |
| etiquetas | só entre as que o destino já tem. O LLM recebe, para cada etiqueta, as tarefas que já a usam, e decide pelo assunto |
| descrição | o que você disse além do nome e dos outros campos |
| checklist | os passos que você enumerou. O LLM não inventa passos |
| tamanho | estimativa de esforço: XS (minutos) a XL (vários dias) |

Cada frase leva de 13 a 30 segundos com o `qwen3:30b-a3b-instruct-2507` num servidor Ollama: o modelo é carregado a cada pedido e sai da VRAM ao responder.

## Atalhos

| Tecla | Efeito |
|---|---|
| `SUPER+SHIFT+T` | grava (parser dateparser) |
| `SUPER+SHIFT+Y` | grava (parser LLM) |
| `Enter` ou o mesmo atalho | para e transcreve |
| `Esc` | cancela |

O Hyprland só captura Enter e Esc durante a gravação.

## Requisitos

- Hyprland com configuração em Lua (`hyprland.lua`). Com `hyprland.conf`, o instalador mostra o trecho para você colar.
- voxtype, `wtype`, `wl-clipboard`, `libnotify` e [uv](https://docs.astral.sh/uv/).
- [Ollama](https://ollama.com), se quiser o parser LLM.
- [`gh`](https://cli.github.com) autenticado com o escopo `project` (`gh auth refresh -s project`), se quiser o destino GitHub Projects.

No Arch:

```bash
paru -S voxtype-bin
sudo pacman -S --needed wtype wl-clipboard libnotify vulkan-icd-loader pipewire-alsa
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Instalar

```bash
git clone https://github.com/SoaresDavidson/tesla-notetaker
cd tesla-notetaker
./install.sh
```

Na primeira execução o instalador pergunta o destino. No Obsidian, ele procura vaults com quadros Kanban e pergunta qual usar; no GitHub, ele lista seus projects e pergunta o número do project e o repositório onde criar as issues. No Trello, ele pede a chave e o token da API (o token não aparece na tela), grava os dois em `~/.config/tesla/trello.json` e pergunta qual quadro usar. Depois pergunta a URL e o modelo do Ollama, e em qual GPU rodar o Whisper, sugerindo a dedicada. Nas execuções seguintes ele reaproveita as respostas; `--reconfigurar` pergunta de novo e `--yes` aceita os padrões.

O que ele altera no sistema:

| Onde | O quê |
|---|---|
| `~/.local/bin/tesla`, `~/.local/bin/tesla-voz`, `~/.local/bin/tesla-destino-obsidian`, `~/.local/bin/tesla-destino-github`, `~/.local/bin/tesla-destino-trello` | symlinks para o repositório, então `git pull` atualiza |
| `~/.config/tesla/config.toml` | destino e LLM (ver `config.example.toml`) |
| `~/.config/tesla/trello.json` | chave e token do Trello, com permissão 600, se você escolher esse destino |
| `~/.config/voxtype/config.toml` | só as chaves `hotkey.enabled`, `whisper.model/language/on_demand_loading/gpu_isolation/gpu_device` e `output.notification.*`. Os valores anteriores ficam em `~/.local/state/tesla/voxtype-backup.json` |
| `~/.config/systemd/user/tesla-trello-manter.{service,timer}` | só com o destino Trello: o timer do `manter` |
| `~/.config/hypr/config/tesla.lua` | symlink com os atalhos |
| `~/.config/hypr/hyprland.lua` | uma linha `require("config.tesla")` |
| systemd | `systemctl --user enable` e `restart voxtype` |
| Hyprland | `hyprctl reload` |
| `~/.local/share/voxtype/models` | o Whisper `large-v3-turbo` (1,6 GB), baixado se faltar |

Com o destino Obsidian, no fim o instalador pergunta se deve dar 🆔 aos cards que já existem, para que você possa movê-los por voz. Isso altera o `.md` do quadro.

Com `--sem-ativar` ele só mexe em arquivos: não baixa o modelo e não toca no systemd nem no Hyprland.

## Desinstalar

```bash
./uninstall.sh
```

O script remove os symlinks e a linha do `hyprland.lua` e devolve as chaves do voxtype aos valores anteriores. O config do tesla, o modelo, o serviço voxtype e os 🆔 dos cards continuam no lugar.

## Configuração

`~/.config/tesla/config.toml`:

```toml
destino = ["~/.local/bin/tesla-destino-obsidian", "--quadro", "~/Obsidian/MeuVault/Quadro.md"]

[llm]
url = "http://localhost:11434"
modelo = "qwen3:8b"
```

As variáveis `TESLA_OLLAMA` e `TESLA_OLLAMA_MODELO` sobrepõem a seção `[llm]`. O destino Obsidian aceita também `--coluna-padrao` (padrão "A fazer") e `--coluna-feito` (padrão "Feito").

### GitHub Projects

```toml
destino = ["~/.local/bin/tesla-destino-github", "--repo", "seu-usuario/tarefas", "--projeto", "8"]
```

Cada tarefa vira uma issue em `--repo`, adicionada ao project `--projeto` (o número que aparece em `gh project list`). As colunas são as opções do campo Status. O destino preenche estes campos do project quando eles existem:

| Fala | Campo do project | Opção |
|---|---|---|
| prioridade | `Priority` | a opção com o mesmo nome: Urgente ou Máxima, Alta, Média ou Normal, Baixa, Mínima. Também aceita P0, P1 e P2 |
| começo | `Start date` | data |
| fim | `Target date` | data |
| tamanho | `Size` | a opção com o mesmo nome (XS a XL) |

As etiquetas viram labels da issue (só as que já existem no repositório), e a descrição e o checklist vão para o corpo da issue, com o checklist como lista de tarefas do Markdown. Mover para "Feito" fecha a issue como concluída; tirar de "Feito" reabre. Os nomes podem ser trocados com `--campo-status`, `--campo-prioridade`, `--campo-inicio`, `--campo-prazo`, `--campo-tamanho`, `--coluna-padrao` e `--coluna-feito`. Se o project for de uma organização diferente do dono do repositório, passe `--dono`.

Cada comando faz de 3 a 5 chamadas à API do GitHub, então a notificação demora um ou dois segundos a mais que no Obsidian.

### Trello

```toml
destino = ["~/.local/bin/tesla-destino-trello", "--quadro", "AbCd1234"]
```

`--quadro` é o trecho depois de `/b/` na URL do quadro; `tesla-destino-trello quadros` lista os seus. As colunas são as listas abertas do quadro e o número do card é o número curto que o Trello mostra (`#12`). A chave e o token da API ficam em `~/.config/tesla/trello.json`, no formato `{"key": "...", "token": "..."}`; as variáveis `TRELLO_API_KEY` e `TRELLO_TOKEN` têm precedência. Gere os dois em https://trello.com/power-ups/admin, na aba "Autenticação do Trello" da sua Power-Up.

| Fala | No card |
|---|---|
| prioridade | a etiqueta com o nome do nível (Alta, Média, Baixa...), com ou sem o prefixo `Prioridade:`. Sem etiqueta correspondente, a prioridade é ignorada e a notificação avisa |
| começo | data de início |
| fim | data de entrega |
| etiquetas | as etiquetas com o mesmo nome. As de prioridade e de tamanho ficam fora da lista que o LLM vê |
| tamanho | a etiqueta `Size: <tamanho>`, se existir |
| descrição | a descrição do card |
| checklist | um checklist "Passos" no card |

Mover para "Feito" marca a data de entrega como concluída; tirar de "Feito" desmarca.

Com o destino Trello, o instalador também ativa o timer `tesla-trello-manter`, que roda `tesla-destino-trello manter` a cada 2 minutos e faz três coisas no quadro:

1. Card com checklist de progresso (qualquer nome menos "Passos", como "Capítulos" ou "Aulas") que você conclui, movendo para "Feito" ou marcando a data de entrega, tem o próximo item marcado e volta para "A fazer" com prazo novo. No último item, ele fica em "Feito". Assim, "ler livro de 33 capítulos" avança um capítulo a cada conclusão.
2. Card em "A fazer" sem data ganha prazo de 3 dias (`--prazo-dias`).
3. Se "A fazer" tem menos de 4 cards (`--minimo`), o timer puxa os primeiros de "pessoal" e depois de "fixo" (`--reserva`).

Para ver o que ele faria sem mudar nada: `tesla-destino-trello --quadro <id> manter --simular`. O log fica em `journalctl --user -u tesla-trello-manter`.

## GPU

Com `whisper.gpu_isolation` e `on_demand_loading`, o voxtype carrega o Whisper a cada gravação e libera a VRAM no fim. O parser LLM pede `keep_alive: 0` ao Ollama, que tira o modelo da VRAM assim que responde. Assim o Whisper e um modelo de 8B cabem numa GPU de 8 GB, e cada tarefa leva alguns segundos a mais para carregar. Se preferir resposta rápida, desligue `gpu_isolation` no config do voxtype.

## Testar sem voz

```bash
tesla --dry-run --texto "estudar redes prioridade alta fim sexta"     # mostra a ação JSON
tesla --dry-run --parser llm --texto "..."                            # o mesmo, com o LLM
echo "comprar café" | tesla                                           # aplica no quadro
```

## Problemas

Se nada acontece ao falar, veja `journalctl --user -u voxtype -n 30`.

A mensagem "destino não configurado" significa que falta rodar o `./install.sh`.

Os atalhos chamam o `tesla-voz`, que grava com `voxtype record start --file`, espera a transcrição e passa o texto ao `tesla`. O texto nunca é digitado na janela em foco. Para testar o resto da cadeia sem o microfone, rode `echo "<frase>" | tesla`.
