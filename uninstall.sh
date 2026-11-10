#!/usr/bin/env bash
# Desfaz o install.sh: tira executáveis, atalhos e as chaves do voxtype (restaura o backup).
# Não apaga config, modelo do Whisper nem os 🆔 do quadro; só avisa.
#
#   ./uninstall.sh               desinstala e recarrega voxtype/Hyprland
#   ./uninstall.sh --sem-ativar  só arquivos: não mexe em systemd/hyprctl
set -euo pipefail

REPO=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
CFG=${XDG_CONFIG_HOME:-$HOME/.config}
ESTADO=${XDG_STATE_HOME:-$HOME/.local/state}/tesla
BIN=$HOME/.local/bin
ATIVAR=1
for arg in "$@"; do
    case $arg in
        --sem-ativar) ATIVAR=0 ;;
        -h|--help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "opção desconhecida: $arg" >&2; exit 2 ;;
    esac
done

info() { printf '    %s\n' "$*"; }

# Só remove symlinks que apontam para este repositório.
remover_link() {
    if [[ -L $1 && $(readlink -f "$1") == "$REPO"/* ]]; then
        rm -- "$1"
        info "removido: $1"
    fi
}

remover_link "$BIN/tesla"
remover_link "$BIN/tesla-destino-obsidian"

HDIR=$CFG/hypr
for alvo in "$HDIR/config/tesla.lua" "$HDIR/tesla.lua"; do remover_link "$alvo"; done
if [[ -f $HDIR/hyprland.lua ]] && grep -q 'tesla' "$HDIR/hyprland.lua"; then
    # --follow-symlinks: o hyprland.lua pode ser symlink para um repositório de dotfiles.
    sed -i --follow-symlinks \
        -e '/^-- tesla (install.sh)$/d' \
        -e '/^require("\(config\.\)\{0,1\}tesla")$/d' "$HDIR/hyprland.lua"
    # Remove a linha em branco que o install.sh deixou no fim, se sobrou.
    sed -i --follow-symlinks -e '${/^$/d}' "$HDIR/hyprland.lua"
    info "require do tesla removido de hyprland.lua"
fi

if [[ -f $ESTADO/voxtype-backup.json ]]; then
    "$REPO/lib/voxtype-config" restaurar "$CFG/voxtype/config.toml" "$ESTADO/voxtype-backup.json"
    info "voxtype: chaves restauradas e profiles tesla/tesla-llm removidos"
fi
rm -f -- "$ESTADO/instalacao.env"
rmdir -- "$ESTADO" 2>/dev/null || true

if [[ $ATIVAR == 1 ]]; then
    systemctl --user is-active -q voxtype && systemctl --user restart voxtype
    [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && hyprctl reload >/dev/null
fi

echo
info "Ficaram (apague à mão se quiser):"
info "  $CFG/tesla/config.toml"
info "  o serviço voxtype (systemctl --user disable --now voxtype) e o pacote voxtype-bin"
info "  o modelo do Whisper em ${XDG_DATA_HOME:-$HOME/.local/share}/voxtype/models"
info "  os 🆔 nos cards do quadro"
