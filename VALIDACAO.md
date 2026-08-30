# Roteiro de validação no ambiente novo

Ordem em que as coisas quebram, e o que olhar quando quebrarem. Cada item tem o
comando que confirma.

## Antes de pedir o cluster

- [ ] **Os dois repositórios estão publicados e alcançáveis.** O do workshop
      ainda não tem *remote*; o da plataforma é privado (`404` sem token).
- [ ] **Token do repositório privado.** Marque *"repositório privado"* no
      formulário do pedido, ou monte um secret e aponte
      `plataforma.repo.tokenSecret`. Sem isso o Job para no primeiro passo — com
      mensagem própria, não com `could not read Username`.
- [ ] `deploy/values.yaml` → `plataforma.repo.url` aponta para o repositório
      certo e `perfil` é o que você quer (`completo` é lento).

## 1. O pedido

```
ocp4_workload_field_content_gitops_repo_url: <repo do workshop>
ocp4_workload_field_content_gitops_repo_path: deploy
```

A ordem termina **verde antes de o workshop existir** — o role é *fire and
forget* e a RHDP não monitora o que o GitOps aplica. O sinal de pronto é o
`preflight`, não a tela do pedido.

## 2. O provisionamento

```bash
oc get job monta-plataforma -n showroom
oc logs -n showroom job/monta-plataforma -f
```

- [ ] o download do repositório da plataforma (primeira linha do log);
- [ ] `provision.sh` até `gitops`;
- [ ] `identity` **antes** do portal — se inverter, o `install.sh` não acha o
      segredo do client;
- [ ] `rhdh/install.sh`;
- [ ] no perfil completo: `gitlab`, `cicd`, `registry`, `security`,
      `setup-supply-chain.sh`, `credenciais`.

> Rodar antes com `plataforma.modo=check` não instala nada e diz o que falta e em
> que ordem. É o teste barato antes de gastar a hora.

**Nunca rodou em `apply` num cluster virgem.** É a maior incógnita do conjunto.

## 3. O guia

- [ ] a `Route` do Showroom responde;
- [ ] o Antora renderizou as **23 páginas** — se `default-site.yml` estiver
      errado, o site sobe vazio ou sem navegação;
- [ ] as abas do painel direito aparecem (sem `ui-config.yml` o painel abre em
      branco);
- [ ] o `ConfigMap` de `userinfo` aparece na tela do serviço na RHDP.

## 4. O terminal

- [ ] `ls ~/rhcl ~/workshop` — o `initContainer` popula o home; se falhar, o
      módulo 02 não tem de onde rodar nada;
- [ ] `command -v ansible-playbook` — se ausente, o `workshop.sh` cai para um pod
      descartável, **e esse caminho nunca executou**;
- [ ] `bash ~/workshop/scripts/workshop.sh diagnostica` — sem número, olha só a
      plataforma. É o primeiro comando a rodar num ambiente novo.

## 5. Os módulos, na ordem em que dependem uns dos outros

| Módulo | O que valida de verdade |
| --- | --- |
| 02 | a plataforma inteira, pelo `preflight` |
| 1.1 | `provision.sh samples` sobe o bookinfo com sidecar (`2/2`) |
| 1.2 | Argo com `Application` `Synced`, e o desvio detectado |
| 1.3 | `valida-policies` executa — exige `cicd` **e** `platform` |
| 1.4 | **a cadeia nunca executou em cluster nenhum**; seis `PipelineRun` |
| 1.5 | as cópias existem no Quay e os pods passam a usá-las |
| 1.6 | `oc auth can-i --as` — exige o verbo `impersonate` |
| 2.x | mTLS `STRICT`, SPIFFE, Kiali, Tempo, canário de três versões |
| 3.1 | remover a `HTTPRoute` do upstream antes de publicar as novas |
| 3.2 | **a `AuthPolicy` anônima nunca foi aplicada** — o `401` da UI é o teste |
| 3.5 | `TelemetryPolicy` só aceita `Gateway` nesta release |
| 3.6 | golden path exige credencial de Git válida |

## O que sabidamente não é coberto

- **Plugins do portal** (`build-plugins.sh --publish`, `build-cl-ops.sh`): exigem
  Node 22 e publicação em registry — passos de laptop, não de Job. Sem eles o
  portal sobe e o workshop funciona; perdem-se abas, não exercícios.
- **Correção do guia ao vivo**: o conteúdo é clonado na subida do pod. Para uma
  correção valer durante a turma, é preciso reiniciar o Deployment do Showroom.
