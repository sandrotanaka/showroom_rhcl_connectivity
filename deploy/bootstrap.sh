#!/usr/bin/env bash
# ===========================================================================
# bootstrap.sh -- monta a plataforma do workshop num cluster do CI Field
# Content, que chega com RHBK, Lightspeed e OpenShift GitOps e mais nada.
#
# POR QUE UM SCRIPT E NAO SO 'provision.sh': a ordem real intercala o portal.
# 'provision.sh' sem argumento roda as 17 etapas de uma vez -- e 'credenciais'
# escreve secrets NO NAMESPACE DO PORTAL, que ainda nao existe. A sequencia
# abaixo e a de docs/PROVISIONING-1.4.md, que ja pagou esse preco.
#
# IDEMPOTENTE: cada etapa confere antes de criar. Rodar de novo num cluster
# montado nao quebra nada -- e o modo 'check' nao muda nada em hipotese alguma.
#
# Self-contained: nao faz source de nada.
# ===========================================================================
set -uo pipefail

PERFIL="${PERFIL:-completo}"     # leve | completo
MODO="${MODO:-apply}"            # apply | check
REPO_DIR="${REPO_DIR:-/plataforma}"

_log()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
_warn() { printf '\033[33m[aviso]\033[0m %s\n' "$*"; }
_die()  { printf '\033[31m[erro]\033[0m %s\n' "$*" >&2; exit 1; }

for b in oc python3 curl openssl tar; do
  command -v "$b" >/dev/null 2>&1 || _die "falta '$b' na imagem do job"
done

# --------------------------------------------------------------------------
# TRAZER O REPOSITORIO DA PLATAFORMA -- por tarball, e nao por git.
#
# Dois motivos, os dois medidos: a imagem 'oc' do cluster NAO tem git, e o
# repositorio da plataforma costuma ser PRIVADO (o do projeto responde 404 sem
# autenticacao). Um clone anonimo falha com 'could not read Username', que e
# uma mensagem sobre terminal e nao sobre permissao -- e manda quem depura para
# o lado errado.
#
# O token vem, nesta ordem:
#   1. PLATAFORMA_TOKEN (secret montado no Job)
#   2. o secret de repositorio que o proprio CI cria quando voce marca
#      "repositorio privado" no formulario da RHDP
_baixa_repo() {
  [[ -f "${REPO_DIR}/scripts/provision.sh" ]] && { _log "plataforma ja presente em ${REPO_DIR}"; return 0; }

  local _tok="${PLATAFORMA_TOKEN:-}"
  if [[ -z "$_tok" ]]; then
    _tok="$(oc get secret field-content-repo-credentials -n openshift-gitops \
             -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"
    [[ -n "$_tok" ]] && _log "token do repositorio veio do secret que o CI criou"
  fi

  local _url="${PLATAFORMA_REPO}" _ref="${PLATAFORMA_REF:-main}"
  local _slug; _slug="$(printf '%s' "$_url" | sed -E 's|^https?://[^/]+/||; s|\.git$||')"
  local _host; _host="$(printf '%s' "$_url" | sed -E 's|^https?://([^/]+)/.*|\1|')"

  local _alvo
  case "$_host" in
    github.com) _alvo="https://api.github.com/repos/${_slug}/tarball/${_ref}" ;;
    *)          _alvo="${_url%.git}/-/archive/${_ref}/${_ref}.tar.gz" ;;   # GitLab
  esac

  mkdir -p "$REPO_DIR"
  _log "baixando ${_slug}@${_ref}"
  local _hdr=()
  [[ -n "$_tok" ]] && _hdr=(-H "Authorization: Bearer ${_tok}")

  # BAIXA E SO DEPOIS EXTRAI. Com 'curl | tar', o tar comeca a ler antes de o
  # curl saber que falhou, e o erro que aparece primeiro e 'gzip: unexpected end
  # of file' -- que fala de arquivo corrompido quando o problema e permissao.
  local _tgz=/tmp/plataforma.tgz
  if ! curl -sfL "${_hdr[@]}" -o "$_tgz" "$_alvo"; then
    if [[ -z "$_tok" ]]; then
      _die "nao baixei ${_slug}. Repositorio privado sem token: marque 'repositorio privado' ao pedir o item de catalogo, ou monte um secret e aponte PLATAFORMA_TOKEN."
    fi
    _die "nao baixei ${_slug} nem com token -- confira o escopo do token e a ref '${_ref}'"
  fi
  tar xzf "$_tgz" -C "$REPO_DIR" --strip-components=1 \
    || _die "o tarball de ${_slug} nao extraiu"
  rm -f "$_tgz"
  [[ -f "${REPO_DIR}/scripts/provision.sh" ]] || _die "o tarball nao tem scripts/provision.sh -- confira a ref"
}

_baixa_repo
cd "$REPO_DIR" || _die "repositorio da plataforma nao esta em ${REPO_DIR}"
_log "sessao: $(oc whoami) em $(oc whoami --show-server)"

# --------------------------------------------------------------------------
# MODO CHECK -- diz o que falta e em que ordem, sem instalar nada.
# --------------------------------------------------------------------------
if [[ "$MODO" == "check" ]]; then
  _log "modo check: nada sera instalado"
  bash scripts/provision.sh --check
  echo
  _log "portal e plugins (fora do provision.sh)"
  oc get deploy -A -l app.kubernetes.io/name=developer-hub --no-headers 2>/dev/null | head -3 \
    || echo "  portal ainda nao instalado -> bash rhdh/install.sh"
  exit 0
fi

# --------------------------------------------------------------------------
# 1. A PLATAFORMA, ate 'gitops'.
#    O item de catalogo ja instalou o OpenShift GitOps; a etapa e idempotente e
#    acrescenta o ApplicationSet que o modulo 3.6 precisa.
# --------------------------------------------------------------------------
_log "plataforma (operators .. gitops)"
bash scripts/provision.sh operators mesh platform gateway devportal demo \
                          consoles tracing dashboards gitops || _die "etapa de plataforma falhou"

# --------------------------------------------------------------------------
# 2. IDENTITY ANTES DO PORTAL.
#    O install.sh precisa do segredo do client 'rhdh', e quem o cria e esta
#    etapa. O caminho inverso nao existe: 'identity' deriva o host do portal do
#    dominio de apps, sem precisar que ele exista.
# --------------------------------------------------------------------------
_log "identidade (antes do portal, e nao depois)"
bash scripts/provision.sh identity || _warn "identity falhou -- o portal subira sem login unificado"

# --------------------------------------------------------------------------
# 3. O PORTAL. Nao e etapa do provision.sh: e produto que roda sobre a
#    plataforma, com scripts proprios -- a mesma fronteira entre base/ e
#    platform-reference/.
# --------------------------------------------------------------------------
_log "Developer Hub"
bash rhdh/install.sh || _warn "portal falhou -- os modulos 1.1 e 3.6 ficam sem catalogo"

# Os plugins da comunidade e o proprio exigem Node 22 e publicacao em registry:
# sao passos de laptop, e nao de job. Sem eles o portal sobe e o workshop
# funciona -- o que se perde sao abas, nao exercicios.
if [[ -f rhdh/cl-ops.env ]]; then
  bash rhdh/setup-plugins.sh || _warn "setup-plugins falhou"
else
  _warn "sem rhdh/cl-ops.env: portal sem os plugins proprios (esperado neste caminho)"
fi
bash rhdh/setup-catalog.sh || _warn "catalogo do portal nao configurado"

# --------------------------------------------------------------------------
# 4. CI/CD E SEGURANCA. So no perfil completo -- sao as etapas lentas, e a
#    trilha 1 as usa nos modulos 1.4 e 1.5.
# --------------------------------------------------------------------------
if [[ "$PERFIL" == "completo" ]]; then
  _log "cadeia de suprimento (gitlab, cicd, registry, security)"
  bash scripts/provision.sh gitlab  || _warn "gitlab falhou -- e a etapa mais lenta"
  bash scripts/provision.sh cicd    || _warn "cicd falhou"
  bash scripts/provision.sh registry|| _warn "registry (Quay) falhou"
  bash scripts/provision.sh security|| _warn "security (ACS) falhou"
  bash scripts/setup-supply-chain.sh || _warn "RHTAS/Chains nao configurados: sem assinatura"
  _log "credenciais (por ultimo: escreve no namespace do portal)"
  bash scripts/provision.sh credenciais || _warn "credenciais falhou"
else
  _log "perfil leve: apenas Pipelines, sem Quay/ACS/GitLab"
  bash scripts/provision.sh cicd || _warn "cicd falhou"
fi

# --------------------------------------------------------------------------
# 5. A APLICACAO DO LABORATORIO NAO SOBE AQUI.
#    Subir o bookinfo e o modulo 1.1 do workshop. Pre-instalar tiraria do
#    participante o primeiro exercicio.
# --------------------------------------------------------------------------
_log "pronto -- a aplicacao do laboratorio e exercicio, nao provisionamento"
bash scripts/preflight.sh || _warn "preflight acusou pendencia; a saida acima diz qual"
