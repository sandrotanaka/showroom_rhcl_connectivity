#!/usr/bin/env bash
# workshop.sh -- o unico comando que o participante precisa decorar.
#
# Tres verbos, tres alvos diferentes -- e a diferenca importa:
#
#   verifica    <n>  afirma as tarefas do modulo. Nao muda nada.
#   diagnostica <n>  olha as camadas de baixo e imprime sintoma, causa provavel
#                    e comando. NUNCA falha -- falhar esconderia o relatorio.
#   corrige     <n>  devolve o modulo ao estado INICIAL. Para quem quebrou algo
#                    e quer refazer o exercicio.
#   pula        <n>  aplica o estado FINAL do modulo. Para quem nao tem tempo ou
#                    nao vai fazer aquela trilha -- os modulos seguintes
#                    encontram o ambiente como se ele tivesse feito.
#
# POR QUE 'diagnostica' NAO E 'verifica' COM MAIS SAIDA: verificar responde
# passou/nao passou e PRECISA falhar; diagnosticar responde por que, e precisa
# imprimir tudo mesmo quando alguma consulta nao resolve. Juntar os dois daria
# um comando que esconde metade do relatorio justamente no caso ruim.
#
# TODO MODULO RESPONDE AOS QUATRO. Onde nao ha estado a aplicar ou restaurar, o
# playbook diz isso em voz alta em vez de nao existir -- o participante nao
# precisa decorar quais modulos tem quais verbos.
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

# ONDE O PROGRESSO MORA: no HOME, que aqui e PVC. Sobrevive a F5, a reconexao
# do terminal e a restart do pod -- que sao exatamente os tres momentos em que
# alguem pergunta "em que passo eu estava?".
#
# Fora do repositorio de proposito: progresso e do participante, nao do
# conteudo, e um 'git pull' nao pode apaga-lo.
_PROGRESSO="${HOME:-/tmp}/.workshop-progresso"

_MODULOS=(
  "02:Seu ambiente"
  "11:T1 O catalogo e o repositorio"
  "12:T1 OpenShift GitOps"
  "13:T1 OpenShift Pipelines"
  "14:T1 A cadeia de suprimento"
  "15:T1 Trocar a origem das imagens"
  "16:T1 Quem pode o que (RBAC)"
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

  verifica    <n>  confere as tarefas do modulo (nao muda nada)
  diagnostica <n>  por que nao passou: sintoma, causa provavel e comando
  corrige     <n>  devolve o modulo ao estado inicial
  pula        <n>  aplica o estado final do modulo (e o dos anteriores)
  status           a trilha inteira, com o que ja passou
  proximo          verifica onde voce esta; passou, anuncia o proximo
  lista            os modulos e o que cada verbo tem disponivel

exemplos:
  bash workshop.sh verifica 33
  bash workshop.sh diagnostica 33
  bash workshop.sh corrige 33
  bash workshop.sh pula 33

sem numero, 'diagnostica' olha a plataforma inteira:
  bash workshop.sh diagnostica

perdeu o lugar:
  bash workshop.sh status
EOF
}

_arquivo() { # verbo modulo -> caminho, ou vazio
  local _f
  case "$1" in
    verifica)    _f=validation.yml ;;
    diagnostica) _f=diagnose.yml ;;
    corrige)     _f=reset.yml ;;
    pula)        _f=solve.yml ;;
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
    [[ -f "${_VAL}/module-${_n}/diagnose.yml" ]]   && _v+="diagnostica "
    [[ -f "${_VAL}/module-${_n}/reset.yml" ]]      && _v+="corrige "
    [[ -f "${_VAL}/module-${_n}/solve.yml" ]]      && _v+="pula"
    printf '%-4s %-34s %s\n' "$_n" "$_t" "${_v:-—}"
  done
  cat <<'EOF'

Todo modulo responde aos quatro verbos. Onde nao ha estado a aplicar ou a
restaurar, o proprio playbook diz isso -- e diz por que.
EOF
}

# ---------------------------------------------------------------------------
# COMO O PLAYBOOK RODA
#
# Se o terminal tem ansible-playbook, roda direto -- e e o caminho normal.
#
# Se nao tem (a imagem padrao do terminal do Showroom nao garante Ansible), cai
# para um pod descartavel que CLONA ESTE REPOSITORIO e roda o playbook la
# dentro. Clonar, e nao mandar os arquivos numa ConfigMap: os diagnosticos fazem
# 'import_playbook: ../comum/...', e ConfigMap nao guarda subdiretorio -- achatar
# os nomes quebraria justamente o import.
#
# CONSEQUENCIA A SABER: o pod roda o que esta no repositorio REMOTO. Edicao
# local de playbook nao e vista por esse caminho.
#
# O POD USA O SEU TOKEN, e nao a ServiceAccount do namespace: assim o verbo mede
# a SUA permissao (senao o modulo 1.6 estaria medindo outra identidade), e o
# chart de deploy nao precisa de nenhum RoleBinding largo.
#
# LIMITE: playbooks que chamam o CLI 'oc' (o modulo 16 usa 'oc auth can-i --as')
# dependem de oc no PATH do pod. Por isso o certo e apontar
# showroom.terminal.image para uma imagem com Ansible, e deixar o fallback como
# rede de seguranca -- nao como caminho principal.
# O callback 'debug' e o que renderiza msg multilinha. Sem ele o Ansible imprime
# o relatorio como string JSON com \n escapado -- ilegivel exatamente no momento
# em que a pessoa mais precisa ler.
export ANSIBLE_STDOUT_CALLBACK=debug
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

_ansible() { # arquivo
  local _p="$1"
  if command -v ansible-playbook >/dev/null 2>&1; then
    ansible-playbook "$_p"
    return $?
  fi

  local _img="${WORKSHOP_RUNNER_IMAGE:-quay.io/rhpds/ansible-runner-ocp:latest}"
  local _tok _api _repo _rev
  _tok="$(oc whoami -t 2>/dev/null || true)"
  _api="$(oc whoami --show-server 2>/dev/null || true)"
  [[ -n "$_tok" && -n "$_api" ]] || { echo "sem sessao: rode 'oc login' antes"; return 2; }

  _repo="${WORKSHOP_REPO_URL:-$(git -C "$_DIR" remote get-url origin 2>/dev/null || true)}"
  _rev="${WORKSHOP_REPO_REF:-$(git -C "$_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)}"
  [[ -n "$_repo" ]] || { echo "nao descobri a origem do repositorio; exporte WORKSHOP_REPO_URL"; return 2; }

  local _rel="${_p#"$_DIR"/}"
  echo "(sem ansible-playbook local -- rodando em pod com ${_img})"
  oc run "workshop-run-$$" --rm -i --restart=Never --quiet --image="$_img" \
    --env="K8S_AUTH_API_KEY=${_tok}" \
    --env="K8S_AUTH_HOST=${_api}" \
    --env="K8S_AUTH_VERIFY_SSL=false" \
    -- sh -c "git clone --depth 1 --branch '${_rev}' '${_repo}' /w >/dev/null 2>&1 \
              && cd /w && ansible-playbook '${_rel}'"
}

# ---------------------------------------------------------------------------
# PROGRESSO
#
# Um modulo so entra na lista quando a VERIFICACAO passa -- nunca por ter sido
# aberto. Assim 'status' responde "o que eu fiz", e nao "onde eu cliquei".
_passou()  { [[ -f "$_PROGRESSO" ]] && grep -qx "$1" "$_PROGRESSO"; }
_marca()   { _passou "$1" || echo "$1" >> "$_PROGRESSO"; }
_titulo()  { for _m in "${_MODULOS[@]}"; do [[ "${_m%%:*}" == "$1" ]] && { printf '%s' "${_m#*:}"; return; }; done; }
_atual()   { for _m in "${_MODULOS[@]}"; do _passou "${_m%%:*}" || { printf '%s' "${_m%%:*}"; return; }; done; }

_status() {
  local _feitos=0 _total=0 _at; _at="$(_atual)"
  for _m in "${_MODULOS[@]}"; do
    local _n="${_m%%:*}" _t="${_m#*:}" _marca=" " _seta="  "
    _total=$((_total+1))
    if _passou "$_n"; then _marca="x"; _feitos=$((_feitos+1)); fi
    [[ "$_n" == "$_at" ]] && _seta="->"
    printf ' %s [%s] %-4s %s\n' "$_seta" "$_marca" "$_n" "$_t"
  done
  echo
  if [[ -z "$_at" ]]; then
    printf ' %s de %s -- acabou. Va para a conclusao do guia.\n' "$_feitos" "$_total"
  else
    printf ' %s de %s. Voce esta no modulo %s -- %s\n' "$_feitos" "$_total" "$_at" "$(_titulo "$_at")"
    printf ' seguir:  bash workshop.sh proximo\n'
  fi
  [[ -f "$_PROGRESSO" ]] && printf ' zerar:   rm %s\n' "$_PROGRESSO"
}

_proximo() {
  local _at; _at="$(_atual)"
  [[ -n "$_at" ]] || { echo "nao ha proximo: todos os modulos passaram."; return 0; }

  printf '\n--> verificando o modulo %s -- %s\n\n' "$_at" "$(_titulo "$_at")"
  if _roda verifica "$_at"; then
    _marca "$_at"
    local _prox; _prox="$(_atual)"
    if [[ -z "$_prox" ]]; then
      printf '\n[ok] modulo %s fechado. Era o ultimo -- va para a conclusao.\n' "$_at"
    else
      printf '\n[ok] modulo %s fechado.\n     proximo: %s -- %s\n' "$_at" "$_prox" "$(_titulo "$_prox")"
    fi
  else
    # NAO AVANCA, e ja diz por que. Um wizard que avanca com a verificacao
    # falhando ensina o participante a ignorar a verificacao.
    printf '\n[--] o modulo %s ainda nao passou. Voce continua nele.\n' "$_at"
    printf '     diagnostico:\n\n'
    _roda diagnostica "$_at" || true
    return 1
  fi
}

_roda() { # verbo modulo
  local _p; _p="$(_arquivo "$1" "$2")" || { _uso; exit 2; }
  if [[ -z "$_p" ]]; then
    echo "modulo $2: nada a fazer para '$1' (veja 'bash workshop.sh lista')"
    return 0
  fi
  echo "--> $1 modulo $2"
  _ansible "$_p"
}

_verbo="${1:-}"; _mod="${2:-}"

case "$_verbo" in
  lista|--list|-l) _lista;   exit 0 ;;
  status)          _status;  exit 0 ;;
  proximo|proxima) _proximo; exit $? ;;
  ""|-h|--help)    _uso;     exit 0 ;;
esac

# 'diagnostica' sem numero olha so as camadas de plataforma
if [[ "$_verbo" == "diagnostica" && -z "$_mod" ]]; then
  _ansible "${_VAL}/comum/diagnose-plataforma.yml"
  exit $?
fi

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
