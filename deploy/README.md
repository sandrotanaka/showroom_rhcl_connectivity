# `deploy/` — o workshop como item de catálogo da RHDP

Chart Helm para o CI **Field Content** da RHDP, modelado sobre o
[field-sourced-content-template](https://github.com/rhpds/field-sourced-content-template).

## Como pedir

No RHDP, ordene o **Field Content CI** com:

```yaml
ocp4_workload_field_content_gitops_repo_url: https://github.com/<org>/showroom_rhcl_connectivity
ocp4_workload_field_content_gitops_repo_path: deploy
```

O role cria **uma** `Application` do Argo apontando para este caminho, confere
que o objeto foi aceito e sai — *fire and forget*. Ele não espera sync nem
health, e o `remove_workload` do role não está implementado: quem limpa é o
cluster morrendo.

## Subir à mão, fora do catálogo

Enquanto o item de catálogo não existe, o guia sobe com um comando — e ele
descobre tudo do cluster, sem hostname escrito:

```bash
helm template w deploy/ \
  --set plataforma.enabled=false \
  --set deployer.domain=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}') \
  --set deployer.apiUrl=$(oc whoami --show-server) \
  --set gitops.repoURL=https://github.com/<org>/showroom_rhcl_connectivity \
  | oc apply -f -
```

`plataforma.enabled=false` porque, subindo à mão, a plataforma é montada pelo
`provision.sh` — o Job só faz sentido no caminho do catálogo.

E o secret do repositório privado, que o `initContainer` e o Job leem:

```bash
printf 'cole o PAT: '; read -rs PAT; echo
oc create secret generic plataforma-git -n showroom --from-literal=password="$PAT"
unset PAT
oc rollout restart deploy/showroom -n showroom
```

> O `read -p` do zsh **não** é prompt — ali `-p` significa "ler de coprocesso", e
> o comando falha deixando a variável vazia. O `printf` antes evita isso.

## O que o chart entrega

| | |
| --- | --- |
| **Showroom** | o guia (Antora) + terminal embutido, publicado por `Route` |
| **userinfo** | `ConfigMap` com o label `demo.redhat.com/userinfo`, que a RHDP lê para mostrar o link e as instruções ao participante |

Não entrega a aplicação do laboratório: subir o **bookinfo** é o módulo 1.1, e
pré-instalá-lo tiraria do participante o primeiro exercício.

## As duas correções em relação ao exemplo do template

**1. `gitops.repoURL`, com `URL` maiúsculo.** O role injeta
`gitops.repoURL` / `revision` / `path`; o `examples/helm/values.yaml` do
template declara `gitops.repoUrl` e `basePath`, então **não recebe a injeção**.
Quem forka o exemplo e esquece de trocar a linha à mão sobe o conteúdo do
repositório upstream da Red Hat — funcionando, com o conteúdo errado, sem erro
nenhum. Aqui usamos o nome que o role escreve, e o guia vem sempre do
repositório que o CI recebeu.

**2. Sem `selfHeal`.** O exemplo do template liga `prune` e `selfHeal` nas
Applications filhas. Aqui não há App-of-Apps — são dois componentes pequenos num
chart só — e, se houvesse, `selfHeal` ficaria desligado: as trilhas 2 e 3 editam
policy ao vivo, e sob *enforcement* o Argo desfaria o movimento no meio do
exercício.

## Valores injetados no provisionamento

```yaml
deployer:
  domain: apps.cluster-guid.sandbox.opentlc.com
  apiUrl: https://api.cluster-guid.sandbox.opentlc.com:6443
gitops:
  repoURL: <o repositório que você informou>
  revision: main
  path: deploy
```

**Nenhum hostname é escrito neste chart.** O cluster é efêmero; todo endereço
sai de `deployer.domain` na hora do provisionamento — a mesma regra que vale
para os scripts da plataforma.

## O ponto de atenção: Ansible no terminal

Os quatro verbos do workshop (`verifica`, `diagnostica`, `corrige`, `pula`)
rodam playbooks com a collection `kubernetes.core`. A imagem padrão do terminal
do Showroom traz `oc` e `git`, mas **não garante Ansible**.

O [`scripts/workshop.sh`](../scripts/workshop.sh) detecta a ausência e cai para
um pod descartável que clona este repositório e roda o playbook lá dentro, com o
**token do participante** — então o workshop funciona nos dois casos, e o chart
não precisa de nenhum `RoleBinding` largo.

Ainda assim, o certo é apontar `showroom.terminal.image` para uma imagem com
Ansible e deixar o fallback como rede de segurança:

- evita a espera de um pod a cada verbo;
- e cobre os playbooks que chamam o CLI `oc` (o módulo 1.6 usa
  `oc auth can-i --as`), que dependem de `oc` no PATH.

## Validar localmente

```bash
helm lint deploy/
helm template t deploy/ \
  --set deployer.domain=apps.exemplo.com \
  --set gitops.repoURL=https://github.com/<org>/showroom_rhcl_connectivity
```

## A plataforma: o cluster do catálogo chega vazio

O item entrega **RHBK, OpenShift Lightspeed e OpenShift GitOps**. Só. O workshop
pressupõe Service Mesh, Connectivity Link, Pipelines, portal e — no perfil
completo — GitLab, Quay, ACS e RHTAS.

Por isso o chart traz um `Job` (`sync-wave: 0`) que roda
[`bootstrap.sh`](bootstrap.sh), embutido no próprio chart por `.Files.Get` para
que ordem de provisionamento e versão do chart nunca divirjam.

### Por que um bootstrap, e não `provision.sh` direto

`provision.sh` sem argumento roda as 17 etapas de uma vez — e `credenciais`
escreve secrets **no namespace do portal**, que ainda não existe. A sequência do
bootstrap é a de `docs/PROVISIONING-1.4.md`, com `identity` **antes** do portal
(o `install.sh` precisa do segredo do client que essa etapa cria).

### Perfis

| | |
| --- | --- |
| `leve` | Service Mesh, Connectivity Link, Pipelines e portal sobre o GitOps que já vem. Os módulos 1.4 e 1.5 ficam indisponíveis. |
| `completo` | acrescenta GitLab, Quay, ACS e RHTAS. Libera 1.4 e 1.5. **Lento e pesado** — as três etapas trazem banco próprio. |

### `modo: check`

Não instala nada: roda `provision.sh --check`, que diz o que falta e em que
ordem. Use no primeiro provisionamento de um cluster que você não montou.

## O que foi medido, e o que não foi

Testado num SNO OCP 4.21 em 2026-08-30 (nome do cluster omitido de proposito: cluster e efemero):

| Verificação | Resultado |
| --- | --- |
| Binários da imagem `openshift/cli` do cluster | `oc`, `python3`, `curl`, `openssl`, `tar`, `bash` presentes; **`git` ausente** |
| Download e extração do repositório por tarball | funciona (testado com repositório público) |
| Repositório privado sem token | falha com mensagem própria, e não com `could not read Username` |
| `helm lint` e `helm template` | passam |

**A imagem não ter `git` mudou o desenho**: o repositório da plataforma vem por
`curl` + `tar`, e não por clone — o que de quebra resolve o repositório privado
sem *credential helper*. O `initContainer` de clone, que era a primeira versão,
falhava com `could not read Username for 'https://github.com'`, uma mensagem
sobre terminal que manda depurar o lado errado de um problema de permissão.

**O repositório da plataforma é privado.** Sem token, o Job para logo no começo.
Marque "repositório privado" ao pedir o item de catálogo — o `bootstrap.sh` lê o
secret que a própria RHDP cria — ou monte um secret e aponte
`plataforma.repo.tokenSecret`.

### Ainda não medido, em ordem de risco

1. **O provisionamento completo de ponta a ponta** — o `bootstrap.sh` nunca rodou
   em modo `apply` num cluster virgem. É onde estão as etapas lentas.
2. **Os plugins do portal** (`build-plugins.sh --publish`, `build-cl-ops.sh`)
   exigem Node 22 e publicação em registry: são passos de laptop, não de Job. Sem
   eles o portal sobe e o workshop funciona — o que se perde são abas, não
   exercícios.
3. O fallback de Ansible do `workshop.sh` (pod, token, clone).
4. `default-site.yml` renderizando as 23 páginas no construtor do Antora.
5. O `ConfigMap` de `userinfo` aparecendo na tela do serviço.
