# tesla-notetaker

Adiciona e move tarefas num quadro Kanban por voz. Você aperta um atalho, fala a tarefa e aperta Enter; o card aparece no quadro e uma notificação confirma.

```
microfone → voxtype (Whisper, local) → quadro-voz (texto → ação JSON) → destino (Obsidian Kanban)
```

O [voxtype](https://github.com/peteonrails/voxtype) grava e transcreve com o Whisper rodando na sua máquina. O `quadro-voz` separa nome, prioridade, começo, fim e coluna, com o `dateparser` ou com um LLM local via Ollama, e entrega uma ação JSON a um destino. O destino incluído grava num quadro do plugin Kanban do Obsidian, no formato do plugin Tasks. Para escrever outro destino, veja o [PROTOCOLO.md](PROTOCOLO.md).

## Como falar

| Frase | Resultado |
|---|---|
| "estudar redes prioridade alta começo amanhã fim sexta" | `- [ ] estudar redes ⏫ 🛫 2026-11-11 📅 2026-11-13 🆔 427` em "A fazer" |
| "ler artigo na coluna fazendo" | card sem datas em "Fazendo" |
| "revisar relatório prazo dia 20 prioridade urgente" | 🔺 com 📅 no dia 20 |
| "mover 427 para feito" | o card 427 vai para "Feito" com o ✅ de hoje |

O campo que você não falar fica em branco. Cada card recebe um 🆔 de 3 dígitos, e você move o card dizendo esse número.

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

Na primeira execução o instalador pergunta qual quadro usar (ele procura vaults do Obsidian que tenham quadros Kanban), a URL e o modelo do Ollama, e em qual GPU rodar o Whisper, sugerindo a dedicada. Nas execuções seguintes ele reaproveita as respostas; `--reconfigurar` pergunta de novo e `--yes` aceita os padrões.

O que ele altera no sistema:

| Onde | O quê |
|---|---|
| `~/.local/bin/quadro-voz`, `~/.local/bin/quadro-voz-destino-obsidian` | symlinks para o repositório, então `git pull` atualiza |
| `~/.config/quadro-voz/config.toml` | destino e LLM (ver `config.example.toml`) |
| `~/.config/voxtype/config.toml` | só as chaves `hotkey.enabled`, `whisper.model/language/on_demand_loading/gpu_isolation/gpu_device` e `output.notification.*`, mais os profiles `quadro` e `quadro-llm`. Os valores anteriores ficam em `~/.local/state/quadro-voz/voxtype-backup.json` |
| `~/.config/hypr/config/quadro-voz.lua` | symlink com os atalhos |
| `~/.config/hypr/hyprland.lua` | uma linha `require("config.quadro-voz")` |
| systemd | `systemctl --user enable` e `restart voxtype` |
| Hyprland | `hyprctl reload` |
| `~/.local/share/voxtype/models` | o Whisper `large-v3-turbo` (1,6 GB), baixado se faltar |

No fim o instalador pergunta se deve dar 🆔 aos cards que já existem, para que você possa movê-los por voz. Isso altera o `.md` do quadro.

Com `--sem-ativar` ele só mexe em arquivos: não baixa o modelo e não toca no systemd nem no Hyprland.

## Desinstalar

```bash
./uninstall.sh
```

O script remove os symlinks e a linha do `hyprland.lua` e devolve as chaves do voxtype aos valores anteriores. O config do quadro-voz, o modelo, o serviço voxtype e os 🆔 dos cards continuam no lugar.

## Configuração

`~/.config/quadro-voz/config.toml`:

```toml
destino = ["~/.local/bin/quadro-voz-destino-obsidian", "--quadro", "~/Obsidian/MeuVault/Quadro.md"]

[llm]
url = "http://localhost:11434"
modelo = "qwen3:8b"
```

As variáveis `QUADRO_OLLAMA` e `QUADRO_OLLAMA_MODELO` sobrepõem a seção `[llm]`. O destino Obsidian aceita também `--coluna-padrao` (padrão "A fazer") e `--coluna-feito` (padrão "Feito").

## GPU

Com `whisper.gpu_isolation` e `on_demand_loading`, o voxtype carrega o Whisper a cada gravação e libera a VRAM no fim. O parser LLM pede `keep_alive: 0` ao Ollama, que tira o modelo da VRAM assim que responde. Assim o Whisper e um modelo de 8B cabem numa GPU de 8 GB, e cada tarefa leva alguns segundos a mais para carregar. Se preferir resposta rápida, desligue `gpu_isolation` no config do voxtype.

## Testar sem voz

```bash
quadro-voz --dry-run --texto "estudar redes prioridade alta fim sexta"     # mostra a ação JSON
quadro-voz --dry-run --parser llm --texto "..."                            # o mesmo, com o LLM
echo "comprar café" | quadro-voz                                           # aplica no quadro
```

## Problemas

Se nada acontece ao falar, veja `journalctl --user -u voxtype -n 30`.

A mensagem "destino não configurado" significa que falta rodar o `./install.sh`.

Se o texto foi para o clipboard e o card não apareceu, o voxtype não conseguiu rodar o `quadro-voz` (estourou o tempo ou deu erro) e copiou só a transcrição. Teste com `echo "<frase>" | quadro-voz`.
