#!/usr/bin/env bash
# Instala o tesla: script, destinos (Obsidian, GitHub Projects ou Trello), chaves do voxtype e atalhos do Hyprland.
# Idempotente: rodar de novo só confirma o que já está instalado.
#
#   ./install.sh                 pergunta o que não souber (só na primeira vez)
#   ./install.sh --reconfigurar  pergunta tudo de novo
#   ./install.sh --yes           usa os padrões detectados, sem perguntar
#   ./install.sh --sem-ativar    só arquivos: não baixa modelo, não mexe em systemd/hyprctl
set -euo pipefail

REPO=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
DADOS=${XDG_DATA_HOME:-$HOME/.local/share}
ESTADO=${XDG_STATE_HOME:-$HOME/.local/state}/tesla
BIN=$HOME/.local/bin
CONFIG=$CFG/tesla/config.toml
RESPOSTAS=$ESTADO/instalacao.env
MODELO_WHISPER=large-v3-turbo

SIM=0 RECONFIGURAR=0 ATIVAR=1
for arg in "$@"; do
    case $arg in
        --yes|-y) SIM=1 ;;
        --reconfigurar) RECONFIGURAR=1 ;;
        --sem-ativar) ATIVAR=0 ;;
        -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "opção desconhecida: $arg" >&2; exit 2 ;;
    esac
done

passo() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
aviso() { printf '    \033[33m! %s\033[0m\n' "$*"; }

# pergunta "texto" "padrão" -> resposta no stdout
pergunta() {
    local resposta
    if [[ $SIM == 1 ]]; then echo "$2"; return; fi
    read -r -p "    $1 [$2]: " resposta </dev/tty
    echo "${resposta:-$2}"
}

pergunta_secreta() {  # pergunta_secreta "texto" -> resposta no stdout, sem eco no terminal
    local resposta
    read -r -s -p "    $1: " resposta </dev/tty
    echo >/dev/tty
    echo "$resposta"
}

sim_ou_nao() {  # sim_ou_nao "texto" s|n
    local r
    r=$(pergunta "$1 (s/n)" "$2")
    [[ ${r,,} == s* ]]
}

# ------------------------------------------------------------------ 1. dependências
passo "Dependências"
faltando=()
for cmd in voxtype wtype wl-copy notify-send uv; do
    command -v "$cmd" >/dev/null || faltando+=("$cmd")
done
if ((${#faltando[@]})); then
    aviso "faltando: ${faltando[*]}"
    info "Arch:  paru -S voxtype-bin"
    info "       sudo pacman -S --needed wtype wl-clipboard libnotify vulkan-icd-loader pipewire-alsa"
    info "uv:    curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi
info "ok: voxtype wtype wl-copy notify-send uv"
command -v hyprctl >/dev/null || aviso "hyprctl não encontrado: os atalhos não serão configurados"

# ------------------------------------------------------------------ 2. perguntas
mkdir -p "$ESTADO"
# shellcheck source=/dev/null
[[ -f $RESPOSTAS ]] && source "$RESPOSTAS"

encontrar_quadros() {  # imprime arquivos .md de quadros Kanban dentro de vaults do Obsidian
    find "$HOME" -maxdepth 5 -type d -name .obsidian -not -path '*/.*/.obsidian' 2>/dev/null |
        while read -r cofre; do
            grep -lx 'kanban-plugin: board' "$(dirname "$cofre")"/*.md 2>/dev/null || true
        done
}

if [[ ! -f $CONFIG || $RECONFIGURAR == 1 ]]; then
    passo "Destino"
    info "[1] quadro Kanban do Obsidian"
    info "[2] GitHub Projects (cada tarefa vira uma issue)"
    info "[3] Trello (cada tarefa vira um card)"
    tipo_destino=$(pergunta "destino" 1)
fi

if [[ ! -f $CONFIG || $RECONFIGURAR == 1 ]] && [[ $tipo_destino == 2 ]]; then
    command -v gh >/dev/null || { aviso "instale o gh (sudo pacman -S github-cli)"; exit 1; }
    gh auth status 2>&1 | grep -q "'project'" ||
        { aviso "o token do gh não tem o escopo project; rode: gh auth refresh -s project"; exit 1; }
    gh project list --owner @me 2>/dev/null | awk -F'\t' '{print "    [" $1 "] " $2}'
    projeto=$(pergunta "número do project" "")
    repo=$(pergunta "repositório das issues (dono/nome)" "$(gh api user -q .login)/tarefas")
    "$REPO/destinos/github-projects" --repo "$repo" --projeto "$projeto" colunas >/dev/null ||
        { aviso "não consegui ler o project $projeto com o repositório $repo"; exit 1; }
    linha_destino="destino = [\"$BIN/tesla-destino-github\", \"--repo\", \"$repo\", \"--projeto\", \"$projeto\"]"
    QUADRO=""
elif [[ ! -f $CONFIG || $RECONFIGURAR == 1 ]] && [[ $tipo_destino == 3 ]]; then
    CRED=$CFG/tesla/trello.json
    if [[ -f $CRED ]]; then
        info "usando as credenciais de $CRED"
    elif [[ -n ${TRELLO_API_KEY:-} && -n ${TRELLO_TOKEN:-} ]] || [[ $SIM == 0 ]]; then
        info "chave e token em https://trello.com/power-ups/admin (aba Autenticação do Trello)"
        key=${TRELLO_API_KEY:-$(pergunta "chave da API" "")}
        token=${TRELLO_TOKEN:-$(pergunta_secreta "token")}
        [[ -n $key && -n $token ]] || { aviso "chave e token são obrigatórios"; exit 1; }
        mkdir -p "$(dirname "$CRED")"
        (umask 077; python3 -c 'import json, sys; print(json.dumps({"key": sys.argv[1], "token": sys.argv[2]}))' \
            "$key" "$token" >"$CRED")
        info "gravado: $CRED (só você lê)"
    else
        aviso "sem credenciais: defina TRELLO_API_KEY e TRELLO_TOKEN ou rode sem --yes"; exit 1
    fi
    lista=$(env -u TRELLO_API_KEY -u TRELLO_TOKEN "$REPO/destinos/trello" quadros) ||
        { aviso "o Trello recusou as credenciais de $CRED"; exit 1; }
    mapfile -t quadros <<<"$lista"
    for q in "${quadros[@]}"; do info "[${q%%$'\t'*}] ${q#*$'\t'}"; done
    quadro=$(pergunta "id do quadro" "${quadros[0]%%$'\t'*}")
    env -u TRELLO_API_KEY -u TRELLO_TOKEN "$REPO/destinos/trello" --quadro "$quadro" colunas >/dev/null ||
        { aviso "não consegui ler o quadro $quadro"; exit 1; }
    linha_destino="destino = [\"$BIN/tesla-destino-trello\", \"--quadro\", \"$quadro\"]"
    QUADRO=""
elif [[ ! -f $CONFIG || $RECONFIGURAR == 1 ]]; then
    mapfile -t quadros < <(encontrar_quadros)
    padrao=${quadros[0]:-}
    if ((${#quadros[@]})); then
        for i in "${!quadros[@]}"; do info "[$i] ${quadros[$i]}"; done
        escolha=$(pergunta "número ou caminho do quadro" 0)
        [[ $escolha =~ ^[0-9]+$ ]] && quadro=${quadros[$escolha]:-} || quadro=$escolha
    else
        aviso "nenhum quadro Kanban encontrado em vaults do Obsidian"
        quadro=$(pergunta "caminho do .md do quadro" "$padrao")
    fi
    quadro=${quadro/#\~/$HOME}
    [[ -f $quadro ]] || { aviso "arquivo não existe: $quadro"; exit 1; }
    linha_destino="destino = [\"$BIN/tesla-destino-obsidian\", \"--quadro\", \"$quadro\"]"
    QUADRO=$quadro
fi

if [[ ! -f $CONFIG || $RECONFIGURAR == 1 ]]; then
    passo "LLM (só para o atalho SUPER+SHIFT+Y)"
    llm_url=$(pergunta "URL do Ollama" "http://localhost:11434")
    llm_modelo=$(pergunta "modelo" "qwen3:8b")
    curl -fsS --max-time 3 "$llm_url/api/tags" >/dev/null 2>&1 ||
        aviso "Ollama não respondeu em $llm_url; o parser dateparser funciona sem ele"

    passo "GPU do Whisper"
    GPU=""
    if command -v vulkaninfo >/dev/null; then
        mapfile -t gpus < <(vulkaninfo --summary 2>/dev/null |
            awk '/^GPU[0-9]+:/{i=substr($1,4)+0} /deviceType/{t=$3} /deviceName/{sub(/.*= /,""); print i"|"t"|"$0}')
        if ((${#gpus[@]} > 1)); then
            sugestao=""
            for g in "${gpus[@]}"; do
                IFS='|' read -r idx tipo nome <<<"$g"
                info "[$idx] $nome ($tipo)"
                [[ -z $sugestao && $tipo == *DISCRETE* ]] && sugestao=$idx
            done
            GPU=$(pergunta "índice da GPU (vazio = padrão do voxtype)" "$sugestao")
        else
            info "uma GPU só; o voxtype escolhe sozinho"
        fi
    else
        aviso "vulkaninfo não encontrado; o voxtype escolhe a GPU"
    fi

    mkdir -p "$(dirname "$CONFIG")"
    cat >"$CONFIG" <<EOF
# Gerado por $REPO/install.sh. Ver config.example.toml.
$linha_destino

[llm]
url = "$llm_url"
modelo = "$llm_modelo"
EOF
    printf 'GPU=%q\nQUADRO=%q\n' "$GPU" "$QUADRO" >"$RESPOSTAS"
    info "gravado: $CONFIG"
else
    passo "Configuração"
    info "usando $CONFIG (--reconfigurar para mudar)"
fi

# ------------------------------------------------------------------ 3. modelo do Whisper
if [[ $ATIVAR == 1 ]]; then
    passo "Modelo do Whisper ($MODELO_WHISPER)"
    if [[ -f $DADOS/voxtype/models/ggml-$MODELO_WHISPER.bin ]]; then
        info "já baixado"
    else
        voxtype setup --download --model "$MODELO_WHISPER"
    fi
fi

# ------------------------------------------------------------------ 4. arquivos
passo "Executáveis em $BIN"
mkdir -p "$BIN"
ln -sfn "$REPO/tesla" "$BIN/tesla"
ln -sfn "$REPO/tesla-voz" "$BIN/tesla-voz"
ln -sfn "$REPO/destinos/obsidian-kanban" "$BIN/tesla-destino-obsidian"
ln -sfn "$REPO/destinos/github-projects" "$BIN/tesla-destino-github"
ln -sfn "$REPO/destinos/trello" "$BIN/tesla-destino-trello"
info "tesla -> $REPO/tesla"
info "tesla-voz -> $REPO/tesla-voz"
info "tesla-destino-obsidian -> $REPO/destinos/obsidian-kanban"
info "tesla-destino-github -> $REPO/destinos/github-projects"
info "tesla-destino-trello -> $REPO/destinos/trello"

passo "voxtype ($CFG/voxtype/config.toml)"
VCFG=$CFG/voxtype/config.toml
if [[ ! -f $VCFG && -f /etc/voxtype/config.toml ]]; then
    mkdir -p "$(dirname "$VCFG")"
    cp /etc/voxtype/config.toml "$VCFG"
    info "criado a partir de /etc/voxtype/config.toml"
fi
chaves=(
    'hotkey.enabled=false'
    "whisper.model=\"$MODELO_WHISPER\""
    'whisper.language="pt"'
    'whisper.on_demand_loading=true'
    'whisper.gpu_isolation=true'
    'output.notification.on_recording_start=true'
    'output.notification.on_recording_stop=true'
    'output.notification.on_transcription=false'
)
[[ -n ${GPU:-} ]] && chaves+=("whisper.gpu_device=$GPU")
"$REPO/lib/voxtype-config" aplicar "$VCFG" "$ESTADO/voxtype-backup.json" "${chaves[@]}"
info "chaves aplicadas (backup em $ESTADO/voxtype-backup.json)"

passo "Atalhos do Hyprland"
HDIR=$CFG/hypr
if [[ -f $HDIR/hyprland.lua ]]; then
    if [[ -d $HDIR/config ]]; then
        alvo=$HDIR/config/tesla.lua req='require("config.tesla")'
    else
        alvo=$HDIR/tesla.lua req='require("tesla")'
    fi
    ln -sfn "$REPO/hypr/tesla.lua" "$alvo"
    info "$alvo -> $REPO/hypr/tesla.lua"
    if grep -qxF "$req" "$HDIR/hyprland.lua"; then
        info "hyprland.lua já tem $req"
    else
        printf '\n-- tesla (install.sh)\n%s\n' "$req" >>"$HDIR/hyprland.lua"
        info "acrescentado ao hyprland.lua: $req"
        [[ -L $HDIR/hyprland.lua ]] &&
            aviso "hyprland.lua é symlink para $(readlink -f "$HDIR/hyprland.lua"); a linha entrou lá"
    fi
elif [[ -f $HDIR/hyprland.conf ]]; then
    aviso "config clássica (hyprland.conf): cole isto nela"
    cat <<'EOF'
        bind = SUPER SHIFT, T, exec, ~/.local/bin/tesla-voz iniciar dateparser
        bind = SUPER SHIFT, T, submap, voz
        bind = SUPER SHIFT, Y, exec, ~/.local/bin/tesla-voz iniciar llm
        bind = SUPER SHIFT, Y, submap, voz
        submap = voz
        bind = , Return, exec, ~/.local/bin/tesla-voz parar
        bind = , Return, submap, reset
        bind = , Escape, exec, ~/.local/bin/tesla-voz cancelar
        bind = , Escape, submap, reset
        submap = reset
EOF
else
    aviso "configuração do Hyprland não encontrada em $HDIR; atalhos não configurados"
fi

# ------------------------------------------------------------------ 5. ativação
if [[ $ATIVAR == 1 ]]; then
    passo "Ativação"
    caminho_servico=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^PATH=//p')
    [[ :$caminho_servico: == *:$(dirname "$(command -v uv)"):* ]] ||
        aviso "o PATH do systemd --user não tem o uv; rode: systemctl --user import-environment PATH"
    systemctl --user enable voxtype >/dev/null 2>&1 || true
    systemctl --user restart voxtype
    info "voxtype: $(systemctl --user is-active voxtype)"
    # Destino Trello: timer que roda `tesla-destino-trello manter` a cada 2 minutos.
    quadro_trello=$(python3 -c 'import sys, tomllib
d = tomllib.load(open(sys.argv[1], "rb")).get("destino", [])
print(d[d.index("--quadro") + 1] if d and d[0].endswith("tesla-destino-trello") and "--quadro" in d else "")' "$CONFIG")
    UNIDADES=$CFG/systemd/user
    if [[ -n $quadro_trello ]]; then
        mkdir -p "$UNIDADES"
        cat >"$UNIDADES/tesla-trello-manter.service" <<EOF
[Unit]
Description=tesla: arruma o quadro do Trello (checklists de progresso, prazos, mínimo de cards)

[Service]
Type=oneshot
ExecStart=$BIN/tesla-destino-trello --quadro $quadro_trello manter
EOF
        cat >"$UNIDADES/tesla-trello-manter.timer" <<'EOF'
[Unit]
Description=tesla: roda o manter do Trello a cada 2 minutos

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
EOF
        systemctl --user daemon-reload
        systemctl --user enable --now tesla-trello-manter.timer >/dev/null 2>&1
        info "tesla-trello-manter.timer: $(systemctl --user is-active tesla-trello-manter.timer)"
    elif [[ -f $UNIDADES/tesla-trello-manter.timer ]]; then
        systemctl --user disable --now tesla-trello-manter.timer >/dev/null 2>&1 || true
        rm -f -- "$UNIDADES/tesla-trello-manter.timer" "$UNIDADES/tesla-trello-manter.service"
        systemctl --user daemon-reload
        info "destino não é Trello: timer tesla-trello-manter removido"
    fi
    if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        hyprctl reload >/dev/null && info "hyprctl reload: ok"
    fi
fi

# ------------------------------------------------------------------ 6. IDs nos cards existentes
if [[ $SIM == 0 && -n ${QUADRO:-} ]]; then
    passo "IDs nos cards"
    if sim_ou_nao "dar 🆔 aos cards que ainda não têm (permite movê-los por voz)?" n; then
        "$BIN/tesla-destino-obsidian" --quadro "$QUADRO" dar-ids
    fi
fi

passo "Pronto"
info "SUPER+SHIFT+T: fale a tarefa, Enter para terminar, Esc para cancelar"
info "teste sem voz: tesla --dry-run --texto \"estudar redes prioridade alta fim sexta\""
