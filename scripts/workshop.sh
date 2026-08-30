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
  bash ~/workshop/scripts/workshop.sh status
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
# Se o terminal tem ansible-playbook, roda direto. Se nao tem -- e a imagem
# padrao do terminal do Showroom nao tem --, INSTALA no proprio home, uma vez.
#
# POR QUE NAO UM POD DESCARTAVEL, que era o desenho anterior: ele apontava para
# quay.io/rhpds/ansible-runner-ocp, que NAO EXISTE publicamente (o Quay responde
# 401; a RHDP publica o Containerfile, nao a imagem). E, mesmo que existisse, o
# modulo 1.6 usa 'oc auth can-i --as' -- que precisa do oc no PATH, e a imagem
# de runner nao tem.
#
# O home e PVC, entao a instalacao sobrevive a restart do pod: a espera de ~1
# minuto acontece uma vez por ambiente, nao por comando.
# O callback 'debug' e o que renderiza msg multilinha. Sem ele o Ansible imprime
# o relatorio como string JSON com \n escapado -- ilegivel exatamente no momento
# em que a pessoa mais precisa ler.
# COMO SE FAZ O RELATORIO SAIR LEGIVEL, em 2026: callback 'default' com
# result_format=yaml. Sem isso o Ansible imprime msg multilinha como string JSON
# com \n escapado -- ilegivel no momento em que a pessoa mais precisa ler.
#
# Duas tentativas anteriores morreram, e as duas so aparecem no ambiente real:
# o callback 'debug' foi removido do ansible-core 2.21, e o
# 'community.general.yaml' foi removido da collection na versao 12. O proprio
# erro do segundo aponta para esta opcao.
export ANSIBLE_STDOUT_CALLBACK=default
export ANSIBLE_CALLBACK_RESULT_FORMAT=yaml
export ANSIBLE_DISPLAY_SKIPPED_HOSTS=false

# O TEMPORARIO PRECISA SAIR DE '~', E NAO E FRESCURA.
#
# O Ansible expande '~' pelo /etc/passwd do usuario, nao pelo $HOME do ambiente.
# Na imagem do terminal o lab-user tem /data no passwd -- um diretorio que NAO
# EXISTE no container --, entao toda execucao morre em 'Failed to create
# temporary directory', com uma mensagem que fala de permissao e nao de caminho.
export ANSIBLE_REMOTE_TMP="${TMPDIR:-/tmp}/.ansible-tmp"
export ANSIBLE_LOCAL_TEMP="${TMPDIR:-/tmp}/.ansible-tmp"
export ANSIBLE_COLLECTIONS_PATH="${HOME:-/tmp}/.ansible/collections"

_ANSIBLE_HOME="${HOME:-/tmp}/.local"

_garante_ansible() {
  command -v ansible-playbook >/dev/null 2>&1 && return 0
  export PATH="${_ANSIBLE_HOME}/bin:${PATH}"
  command -v ansible-playbook >/dev/null 2>&1 && return 0

  echo "(primeira vez: instalando o Ansible no seu home -- leva cerca de um minuto)"
  python3 -m ensurepip --user >/dev/null 2>&1 || true
  # o pacote 'ansible' (nao o 'ansible-core') traz kubernetes.core e
  # community.general junto -- uma dependencia a menos para dar errado no meio
  # de um workshop
  if ! python3 -m pip install --user --quiet --disable-pip-version-check \
        ansible kubernetes >/dev/null 2>&1; then
    echo "nao consegui instalar o Ansible. Sem saida para o PyPI?"
    echo "  python3 -m pip install --user ansible kubernetes"
    return 2
  fi
  export PATH="${_ANSIBLE_HOME}/bin:${PATH}"
  command -v ansible-playbook >/dev/null 2>&1 || { echo "instalei e nao achei ansible-playbook no PATH"; return 2; }
  ansible-galaxy collection list kubernetes.core >/dev/null 2>&1 \
    || ansible-galaxy collection install kubernetes.core >/dev/null 2>&1 \
    || echo "(aviso: kubernetes.core ausente -- as verificacoes vao falhar)"
  echo "(pronto)"
}

_ansible() { # arquivo
  _garante_ansible || return $?
  ansible-playbook "$1"
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
    printf ' seguir:  bash %s proximo\n' "${BASH_SOURCE[0]}"
  fi
  [[ -f "$_PROGRESSO" ]] && printf ' zerar:   rm %s\n' "$_PROGRESSO"
  return 0
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
