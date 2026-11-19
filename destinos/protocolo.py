"""Base comum dos destinos escritos em Python (padrão Strategy).

O `tesla` (o miolo) é o contexto: ele chama o comando configurado em `destino` sem saber
o que há do outro lado. Cada destino é uma estratégia concreta. A fronteira entre os dois
continua sendo o PROTOCOLO.md, então um destino pode ser escrito em qualquer linguagem.

Para um destino em Python, este módulo cuida do que é igual em todos: argumentos comuns,
subcomandos, checagem da versão, despacho da ação e erros no stderr. Um destino novo só
implementa a classe e chama `executar`:

    class MeuDestino(Destino):
        @classmethod
        def argumentos(cls, ap): ap.add_argument("--onde", required=True)
        def colunas(self): ...
        def adicionar(self, acao): ...
        def mover(self, acao): ...

    if __name__ == "__main__":
        sys.exit(executar(MeuDestino, __doc__))
"""

from __future__ import annotations

import argparse
import json
import sys
import unicodedata
from abc import ABC, abstractmethod
from typing import Callable

VERSAO_PROTOCOLO = 1

# PRIORITY do VTODO -> nomes aceitos para a opção de prioridade, em ordem de preferência.
NOMES_PRIORIDADE = {
    1: ["urgente", "maxima", "alta", "p0"],
    3: ["alta", "p0"],
    5: ["media", "normal", "p1"],
    7: ["baixa", "p2"],
    9: ["minima", "baixa", "p2"],
}


def chave(s: str) -> str:
    """Minúsculas e sem acento, para comparar nomes falados com nomes do destino."""
    return "".join(c for c in unicodedata.normalize("NFD", s.lower()) if unicodedata.category(c) != "Mn").strip()


def nomes_prioridade(p: int) -> list[str]:
    """Nomes aceitos para a PRIORITY p; valores intermediários caem no nível mais próximo."""
    return NOMES_PRIORIDADE[min(NOMES_PRIORIDADE, key=lambda k: abs(k - p))]


class Destino(ABC):
    """Estratégia: um lugar onde as ações do tesla são gravadas.

    `extras` liga subcomandos próprios do destino a métodos sem argumentos, que
    imprimem a própria saída (ex.: {"dar-ids": "dar_ids"}).
    """

    extras: dict[str, str] = {}

    def __init__(self, args: argparse.Namespace):
        self.args = args

    @classmethod
    def argumentos(cls, ap: argparse.ArgumentParser) -> None:
        """Acrescenta as opções próprias do destino. --coluna-padrao e --coluna-feito já existem."""

    def e_feito(self, coluna: str) -> bool:
        return chave(coluna) == chave(self.args.coluna_feito)

    @abstractmethod
    def colunas(self) -> list[str]: ...

    @abstractmethod
    def adicionar(self, acao: dict) -> dict:
        """Devolve {"uid", "resumo"}."""

    @abstractmethod
    def mover(self, acao: dict) -> dict:
        """Devolve {"uid", "resumo"}."""

    def aplicar(self, acao: dict) -> dict:
        if acao.get("versao") != VERSAO_PROTOCOLO:
            raise ValueError(f"versão de protocolo não suportada: {acao.get('versao')}")
        acoes: dict[str, Callable[[dict], dict]] = {"adicionar": self.adicionar, "mover": self.mover}
        metodo = acoes.get(acao.get("acao"))
        if not metodo:
            raise ValueError(f"ação desconhecida: {acao.get('acao')}")
        return metodo(acao)


def executar(classe: type[Destino], doc: str | None = None) -> int:
    """Ponto de entrada de um destino: lê argv, roda o subcomando e devolve o código de saída."""
    ap = argparse.ArgumentParser(description=doc, formatter_class=argparse.RawDescriptionHelpFormatter)
    classe.argumentos(ap)
    ap.add_argument("--coluna-padrao", default="A fazer")
    ap.add_argument("--coluna-feito", default="Feito")
    ap.add_argument("subcomando", choices=["colunas", "aplicar", *classe.extras])
    args = ap.parse_args()

    try:
        destino = classe(args)
        if args.subcomando == "colunas":
            print(json.dumps(destino.colunas(), ensure_ascii=False))
        elif args.subcomando == "aplicar":
            print(json.dumps(destino.aplicar(json.loads(sys.stdin.read())), ensure_ascii=False))
        else:
            getattr(destino, classe.extras[args.subcomando])()
        return 0
    except Exception as e:
        print(e, file=sys.stderr)
        return 1
