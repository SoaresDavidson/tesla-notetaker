# tesla-notetaker

Adiciona e move tarefas num quadro Kanban por voz, no Obsidian ou num GitHub Project. Você aperta um atalho, fala a tarefa e aperta Enter; o card aparece no quadro e uma notificação confirma.

```
microfone → voxtype (Whisper, local) → tesla (texto → ação JSON) → destino (Obsidian Kanban ou GitHub Projects)
```

O [voxtype](https://github.com/peteonrails/voxtype) grava e transcreve com o Whisper rodando na sua máquina. O `tesla` separa nome, prioridade, começo, fim e coluna, com o `dateparser` ou com um LLM local via Ollama, e entrega uma ação JSON a um destino. Há dois destinos incluídos: um grava num quadro do plugin Kanban do Obsidian, no formato do plugin Tasks; o outro cria issues num repositório e as coloca num GitHub Project. Para escrever outro destino, veja o [PROTOCOLO.md](PROTOCOLO.md).

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

Na primeira execução o instalador pergunta o destino. No Obsidian, ele procura vaults com quadros Kanban e pergunta qual usar; no GitHub, ele lista seus projects e pergunta o número do project e o repositório onde criar as issues. Depois pergunta a URL e o modelo do Ollama, e em qual GPU rodar o Whisper, sugerindo a dedicada. Nas execuções seguintes ele reaproveita as respostas; `--reconfigurar` pergunta de novo e `--yes` aceita os padrões.

O que ele altera no sistema:

| Onde | O quê |
|---|---|
| `~/.local/bin/tesla`, `~/.local/bin/tesla-destino-obsidian`, `~/.local/bin/tesla-destino-github` | symlinks para o repositório, então `git pull` atualiza |
| `~/.config/tesla/config.toml` | destino e LLM (ver `config.example.toml`) |
| `~/.config/voxtype/config.toml` | só as chaves `hotkey.enabled`, `whisper.model/language/on_demand_loading/gpu_isolation/gpu_device` e `output.notification.*`, mais os profiles `tesla` e `tesla-llm`. Os valores anteriores ficam em `~/.local/state/tesla/voxtype-backup.json` |
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

Mover para "Feito" fecha a issue como concluída; tirar de "Feito" reabre. Os nomes podem ser trocados com `--campo-status`, `--campo-prioridade`, `--campo-inicio`, `--campo-prazo`, `--coluna-padrao` e `--coluna-feito`. Se o project for de uma organização diferente do dono do repositório, passe `--dono`.

Cada comando faz de 3 a 5 chamadas à API do GitHub, então a notificação demora um ou dois segundos a mais que no Obsidian.

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

Se o texto foi para o clipboard e o card não apareceu, o voxtype não conseguiu rodar o `tesla` (estourou o tempo ou deu erro) e copiou só a transcrição. Teste com `echo "<frase>" | tesla`.
