#!/usr/bin/env bash
# workshop.sh -- o unico comando que o participante precisa decorar.
#
# Tres verbos, tres alvos diferentes -- e a diferenca importa:
#
#   verifica <n>   afirma as tarefas do modulo. Nao muda nada.
#   corrige  <n>   devolve o modulo ao estado INICIAL. Para quem quebrou algo
#                  e quer refazer o exercicio.
#   pula     <n>   aplica o estado FINAL do modulo. Para quem nao tem tempo ou
#                  nao vai fazer aquela trilha -- os modulos seguintes
#                  encontram o ambiente como se ele tivesse feito.
#
# POR QUE 'corrige' NAO E 'pula': o solve deixa o ambiente no fim do modulo.
# Usa-lo como conserto pula o aprendizado sem avisar ninguem. Sao alvos
# opostos, e por isso sao dois arquivos e nao um com flag.
#
# CUMULATIVO: 'pula 3' roda os solve de 1, 2 e 3 -- o modulo 3 pressupoe o
# estado do 2. Todo solve e idempotente, entao repetir nao custa nada alem de
# tempo.
#
# Self-contained de proposito: nao faz source de nada. Roda no terminal
# embutido do Showroom, que nao tem o repositorio da demo garantido.
set -euo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_VAL="${_DIR}/validation"

_MODULOS=(
  "02:Seu ambiente"
  "11:T1 O catalogo e o repositorio"
  "12:T1 OpenShift GitOps"
  "13:T1 OpenShift Pipelines"
  "14:T1 A cadeia de suprimento"
  "15:T1 Trocar a origem das imagens"
  "21:T2 Dentro do Service Mesh"
  "22:T2 Autorizacao por identidade"
  "23:T2 Observabilidade"
  "24:T2 Tracing"
  "25:T2 Fault injection"
  "26:T2 Circuit breaker"
  "27:T2 Canario"
  "31:T3 A borda muda de dono"
  "32:T3 Duas fronteiras, um hostname"
  "33:T3 Planos comerciais"
  "34:T3 Precedencia de policies"
  "35:T3 Metrica de negocio"
  "36:T3 A policy nasce com o servico"
)

_uso() {
  cat <<'EOF'
uso: bash workshop.sh <verbo> <modulo>

  verifica <n>   confere as tarefas do modulo (nao muda nada)
  corrige  <n>   devolve o modulo ao estado inicial
  pula     <n>   aplica o estado final do modulo (e o dos anteriores)
  lista          os modulos e o que cada verbo tem disponivel

exemplos:
  bash workshop.sh verifica 2
  bash workshop.sh corrige 2
  bash workshop.sh pula 6
EOF
}

_arquivo() { # verbo modulo -> caminho, ou vazio
  local _f
  case "$1" in
    verifica) _f=validation.yml ;;
    corrige)  _f=reset.yml ;;
    pula)     _f=solve.yml ;;
    *) return 1 ;;
  esac
  local _p="${_VAL}/module-$2/${_f}"
  [[ -f "$_p" ]] && printf '%s' "$_p"
}

_lista() {
  printf '%-4s %-34s %s\n' "" "modulo" "verbos disponiveis"
  for _m in "${_MODULOS[@]}"; do
    local _n="${_m%%:*}" _t="${_m#*:}" _v=""
    [[ -f "${_VAL}/module-${_n}/validation.yml" ]] && _v+="verifica "
    [[ -f "${_VAL}/module-${_n}/reset.yml" ]]      && _v+="corrige "
    [[ -f "${_VAL}/module-${_n}/solve.yml" ]]      && _v+="pula"
    printf '%-4s %-34s %s\n' "$_n" "$_t" "${_v:-—}"
  done
  cat <<'EOF'

Modulo sem 'pula' termina no mesmo estado em que comecou -- e leitura, medicao,
ou um exercicio que se reverte. Nao ha estado final a aplicar; pular esses e
fechar a pagina.
EOF
}

_roda() { # verbo modulo
  local _p; _p="$(_arquivo "$1" "$2")" || { _uso; exit 2; }
  if [[ -z "$_p" ]]; then
    echo "modulo $2: nada a fazer para '$1' (veja 'bash workshop.sh lista')"
    return 0
  fi
  echo "--> $1 modulo $2"
  ansible-playbook "$_p"
}

_verbo="${1:-}"; _mod="${2:-}"

case "$_verbo" in
  lista|--list|-l) _lista; exit 0 ;;
  ""|-h|--help)    _uso;   exit 0 ;;
esac

[[ "$_mod" =~ ^[0-9]+$ ]] || { _uso; exit 2; }
_mod="$(printf '%02d' "$((10#$_mod))")"

if [[ "$_verbo" == "pula" ]]; then
  # cumulativo: o estado final do modulo N pressupoe o dos anteriores. A
  # numeracao nao e contigua (11..13, 21..27, 31..36), entao itera a LISTA e
  # nao um intervalo -- um 'seq' aqui tentaria modulos que nao existem.
  for _m in "${_MODULOS[@]}"; do
    _n="${_m%%:*}"
    [[ "$_n" > "$_mod" ]] && break
    _roda pula "$_n"
  done
else
  _roda "$_verbo" "$_mod"
fi
