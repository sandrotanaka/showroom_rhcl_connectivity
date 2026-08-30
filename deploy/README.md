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

## O que não foi medido em cluster

Este chart nunca subiu na RHDP. Os pontos a verificar na primeira execução, em
ordem de risco:

1. o fallback de Ansible (pod, token, clone) — nunca executou;
2. `default-site.yml` renderizando as 23 páginas no construtor do Antora;
3. o `ConfigMap` de `userinfo` sendo lido pela RHDP e aparecendo na tela do
   serviço.
