-- tesla: tarefas por voz no quadro (voxtype + tesla).
-- SUPER+SHIFT+T (parser dateparser) ou SUPER+SHIFT+Y (parser LLM) começa a gravar e entra
-- no submap "voz": Enter (ou o mesmo atalho) para e transcreve, Esc cancela.
-- Fora da gravação o Enter funciona normalmente.

local mod = "SUPER"
local voz = os.getenv("HOME") .. "/.local/bin/tesla-voz"

local function gravarTarefa(parser)
    return function()
        hl.exec_cmd(voz .. " iniciar " .. parser)
        hl.dispatch(hl.dsp.submap("voz"))
    end
end

local function sairDaVoz(acao)
    return function()
        hl.exec_cmd(voz .. " " .. acao)
        hl.dispatch(hl.dsp.submap("reset"))
    end
end

hl.bind(mod .. " + SHIFT + T", gravarTarefa("dateparser"))
hl.bind(mod .. " + SHIFT + Y", gravarTarefa("llm"))

hl.define_submap("voz", function()
    hl.bind("Return",              sairDaVoz("parar"))
    hl.bind("KP_Enter",            sairDaVoz("parar"))
    hl.bind(mod .. " + SHIFT + T", sairDaVoz("parar"))
    hl.bind(mod .. " + SHIFT + Y", sairDaVoz("parar"))
    hl.bind("Escape",              sairDaVoz("cancelar"))
end)
