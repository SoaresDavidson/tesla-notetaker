# quadro-voz

Adiciona e move tarefas num quadro por voz. Aperte um atalho, fale a tarefa e aperte Enter. O card aparece no quadro e uma notificação confirma.

```
microfone → voxtype (Whisper, local) → quadro-voz (texto → ação JSON) → destino (Obsidian Kanban)
```

- **voxtype** grava e transcreve com o Whisper rodando na sua máquina.
- **quadro-voz** separa nome, prioridade, começo, fim e coluna. Usa o `dateparser`, ou um LLM local pelo Ollama.
- **destino** aplica a ação. O que vem junto grava num quadro do plugin Kanban do Obsidian, no formato do plugin Tasks. Outros destinos seguem o [PROTOCOLO.md](PROTOCOLO.md).

## Como falar

| Frase | Resultado |
|---|---|
| "estudar redes prioridade alta começo amanhã fim sexta" | `- [ ] estudar redes ⏫ 🛫 2026-11-11 📅 2026-11-13 🆔 427` em "A fazer" |
| "ler artigo na coluna fazendo" | card sem datas em "Fazendo" |
| "revisar relatório prazo dia 20 prioridade urgente" | 🔺 com 📅 no dia 20 |
| "mover 427 para feito" | card 427 vai para "Feito" com ✅ de hoje |

Campo não falado fica em branco. Cada card recebe um 🆔 de 3 dígitos, e é por ele que você move o card.

Palavras reconhecidas:
- **prioridade:** máxima/urgente, alta, média/normal, baixa, mínima;
- **começo:** começo, início, a partir de;
- **fim:** fim, prazo, até, entrega, vence;
- **coluna:** na coluna, para a coluna.

Datas aceitas: hoje, amanhã, depois de amanhã, sexta, segunda que vem, dia 20, 20 de novembro, 20/11, daqui a 3 dias, semana que vem.

## Atalhos

| Tecla | Efeito |
|---|---|
| `SUPER+SHIFT+T` | grava (parser dateparser) |
| `SUPER+SHIFT+Y` | grava (parser LLM) |
| `Enter` ou o mesmo atalho | para e transcreve |
| `Esc` | cancela |

Enter e Esc só são capturados durante a gravação.

## Requisitos

- Hyprland com configuração em Lua (`hyprland.lua`). Com `hyprland.conf`, o instalador mostra o trecho para colar.
- [voxtype](https://github.com/peteonrails/voxtype), `wtype`, `wl-clipboard`, `libnotify` e [uv](https://docs.astral.sh/uv/).
- Opcional: [Ollama](https://ollama.com) para o parser LLM.

No Arch:

```bash
paru -S voxtype-bin
sudo pacman -S --needed wtype wl-clipboard libnotify vulkan-icd-loader pipewire-alsa
curl -LsSf https://astral.sh/uv/install.sh | sh
```

## Instalar

```bash
git clone <este repo> ~/besteira/quadro-voz
cd ~/besteira/quadro-voz
./install.sh
```

Na primeira vez ele pergunta:
- qual quadro usar (ele procura vaults do Obsidian com quadros Kanban);
- a URL e o modelo do Ollama;
- em qual GPU rodar o Whisper (sugere a dedicada).

Depois disso não pergunta de novo, a não ser com `--reconfigurar`. `--yes` aceita os padrões.

O que o instalador mexe no sistema:

| Onde | O quê |
|---|---|
| `~/.local/bin/quadro-voz`, `~/.local/bin/quadro-voz-destino-obsidian` | symlinks para o repositório (`git pull` atualiza) |
| `~/.config/quadro-voz/config.toml` | destino e LLM (ver `config.example.toml`) |
| `~/.config/voxtype/config.toml` | só estas chaves: `hotkey.enabled`, `whisper.model/language/on_demand_loading/gpu_isolation/gpu_device`, `output.notification.*`, e os profiles `quadro` e `quadro-llm`. Os valores antigos ficam em `~/.local/state/quadro-voz/voxtype-backup.json` |
| `~/.config/hypr/config/quadro-voz.lua` | symlink com os atalhos |
| `~/.config/hypr/hyprland.lua` | uma linha `require("config.quadro-voz")` |
| systemd | `systemctl --user enable` e `restart voxtype` |
| Hyprland | `hyprctl reload` |
| `~/.local/share/voxtype/models` | baixa o Whisper `large-v3-turbo` (1,6 GB), se faltar |

No fim ele pergunta se deve dar 🆔 aos cards que já existem, para eles poderem ser movidos por voz. Isso altera o seu `.md`.

`--sem-ativar` só mexe em arquivos: não baixa o modelo, não toca no systemd nem no Hyprland.

## Desinstalar

```bash
./uninstall.sh
```

Remove os symlinks e a linha do `hyprland.lua` e devolve as chaves do voxtype aos valores de antes. O config do quadro-voz, o modelo, o serviço voxtype e os 🆔 dos cards ficam.

## Configuração

`~/.config/quadro-voz/config.toml`:

```toml
destino = ["~/.local/bin/quadro-voz-destino-obsidian", "--quadro", "~/Documentos/obsidian/Quadro_tarefas/Quadro.md"]

[llm]
url = "http://localhost:11434"
modelo = "qwen3:8b"
```

As variáveis `QUADRO_OLLAMA` e `QUADRO_OLLAMA_MODELO` sobrepõem a seção `[llm]`. O destino Obsidian também aceita `--coluna-padrao` (padrão "A fazer") e `--coluna-feito` (padrão "Feito").

## GPU

Com `whisper.gpu_isolation` e `on_demand_loading`, o Whisper carrega a cada gravação e libera a VRAM no fim. O parser LLM pede `keep_alive: 0` ao Ollama, então o modelo dele também sai da VRAM ao responder. Assim os dois cabem numa GPU de 8 GB, ao custo de alguns segundos de carregamento por tarefa. Para resposta mais rápida, desligue `gpu_isolation` no config do voxtype.

## Testar sem voz

```bash
quadro-voz --dry-run --texto "estudar redes prioridade alta fim sexta"     # mostra a ação JSON
quadro-voz --dry-run --parser llm --texto "..."                            # idem, com o LLM
echo "comprar café" | quadro-voz                                           # aplica de verdade
```

## Problemas

- **Nada acontece ao falar:** veja `journalctl --user -u voxtype -n 30`.
- **"destino não configurado":** rode `./install.sh`.
- **O texto foi para o clipboard mas o card não apareceu:** o voxtype não conseguiu rodar o `quadro-voz` (tempo esgotado ou erro), e nesse caso ele copia só a transcrição. Teste com `echo "<frase>" | quadro-voz`.
