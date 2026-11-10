-- tesla: tarefas por voz no quadro (voxtype + tesla).
-- SUPER+SHIFT+T (parser dateparser) ou SUPER+SHIFT+Y (parser LLM) começa a gravar e entra
-- no submap "voz": Enter (ou o mesmo atalho) para e transcreve, Esc cancela.
-- Fora da gravação o Enter funciona normalmente.

local mod = "SUPER"

local function gravarTarefa(perfil)
    return function()
        hl.exec_cmd("voxtype record start --profile " .. perfil)
        hl.dispatch(hl.dsp.submap("voz"))
    end
end

local function sairDaVoz(acao)
    return function()
        hl.exec_cmd("voxtype record " .. acao)
        hl.dispatch(hl.dsp.submap("reset"))
    end
end

hl.bind(mod .. " + SHIFT + T", gravarTarefa("tesla"))
hl.bind(mod .. " + SHIFT + Y", gravarTarefa("tesla-llm"))

hl.define_submap("voz", function()
    hl.bind("Return",              sairDaVoz("stop"))
    hl.bind("KP_Enter",            sairDaVoz("stop"))
    hl.bind(mod .. " + SHIFT + T", sairDaVoz("stop"))
    hl.bind(mod .. " + SHIFT + Y", sairDaVoz("stop"))
    hl.bind("Escape",              sairDaVoz("cancel"))
end)
