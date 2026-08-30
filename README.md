# Workshop — Do repositório ao produto de API

Guia autoguiado de **um dia** (≈6h30 de conteúdo) sobre a plataforma de
aplicações da Red Hat, servido pelo Showroom. Conteúdo em **português**; nomes de
produto e de recurso ficam em inglês (Service Mesh, Gateway, AuthPolicy).

Uma aplicação de seis microserviços — o **bookinfo** — atravessa três trilhas e
sai do outro lado com procedência, identidade e valor comercial. Nenhuma linha do
código dos seis serviços é alterada em nenhum momento.

## As três trilhas

| | | |
| --- | --- | --- |
| **1** | **Do repositório ao cluster** — portal; **OpenShift GitOps** e **OpenShift Pipelines** como soluções, com *sync* vs *health*, desvio, `selfHeal`, workspaces e results; e a cadeia que valida o manifesto, espelha a imagem, assina, registra no Rekor e varre no ACS | ~130 min |
| **2** | **Service Mesh** — mTLS, autorização por identidade SPIFFE, grafo, tracing, injeção de falha, circuit breaker e canário entre três versões | ~120 min |
| **3** | **Connectivity Link** — duas fronteiras num hostname, chave por produto, planos comerciais, precedência auditável e métrica de negócio | ~115 min |

As trilhas são independentes: cada uma pressupõe o estado final da anterior, e o
verbo `pula` aplica esse estado para quem começa no meio.

## Por que bookinfo

- **Três versões** de `reviews` no ar. Canário só se distingue de troca de versão
  com três — uma servindo 90%, outra 10%, e uma terceira saudável em zero.
- A **camada de Connectivity Link já existe** em `samples/bookinfo/rhcl/` no
  repositório da plataforma, fora do `kustomization.yaml` de propósito: a amostra
  sobe primeiro como Istio puro, e colocar a plataforma na frente vira um
  movimento do roteiro.
- **Prova visível no navegador** — as estrelas mudam ao recarregar. Verificação
  que não exige terminal.

## Público e ambiente

Desenvolvedores e engenheiros de plataforma, na mesma sala. A tese do dia é o
handoff entre os dois, e o módulo 3.6 é onde eles se encontram.

**Um cluster OpenShift SNO por participante.** Os módulos editam as mesmas
policies e os contadores do limitador são por plano, não por pessoa: num cluster
compartilhado o tráfego de um consome a cota do outro, e o `429` aparece antes da
hora — a pessoa conclui que errou o comando.

## Os três verbos

O participante decora um comando só:

```bash
bash scripts/workshop.sh verifica 33    # confere as tarefas do módulo
bash scripts/workshop.sh corrige 33     # devolve o módulo ao estado INICIAL
bash scripts/workshop.sh pula 33        # aplica o estado FINAL (e o dos anteriores)
bash scripts/workshop.sh lista          # o que cada módulo tem disponível
```

`corrige` e `pula` têm alvos **opostos** — início e fim — e por isso são dois
arquivos, não um com flag. Um `solve` usado como conserto pula o aprendizado sem
avisar ninguém.

Módulo que não muda estado — só leitura e medição — não tem `pula`. O `lista` diz
quais são.

## Estrutura

```
scripts/workshop.sh              os três verbos
content/
  antora.yml                     atributos (hostname NUNCA fica aqui)
  modules/ROOT/
    nav.adoc                     as três trilhas
    pages/                       22 páginas: índice, visão geral, ambiente,
                                 18 módulos e conclusão
validation/
  module-XX/
    validation.yml               verifica — afirma as tarefas do módulo
    reset.yml                    corrige — estado inicial
    solve.yml                    pula — estado final
ui-config.yml                    tabs do painel direito (nookbag)
```

A numeração dos módulos segue a das trilhas: `11`–`15`, `21`–`27`, `31`–`36`.

## As verificações

Playbooks Ansible sem módulo customizado — rodam em qualquer ambiente com
`kubernetes.core`. Cada um afirma as tarefas do módulo e, ao falhar, imprime
**qual** tarefa caiu e o comando que corrige. É a mesma disciplina do
`preflight.sh` da plataforma.

> Para publicar na RHDP com correção automática, o plugin `ftl` do
> [rhdp-skills-marketplace](https://github.com/rhpds/rhdp-skills-marketplace)
> converte estes arquivos para o formato `validation_check`. A estrutura já é a
> que ele espera.

## Regras de conteúdo

- **Nenhum hostname, senha ou nome de cluster no texto.** O cluster é efêmero;
  todo endereço é descoberto por comando. Os atributos `%ATTR_NOT_SET%` em
  `content/antora.yml` são preenchidos em runtime.
- Nome de produto em inglês, com a concordância junto: "no Service Mesh", nunca
  "na malha".
- Cada módulo tem contexto, exercícios, verificação e "o que isso significa".

## O que ainda não foi medido em cluster

- A pipeline `samples-supply-chain` (trilha 1, módulos 1.2 e 1.3) foi escrita mas
  **nenhuma `PipelineRun` executou** até hoje. É o maior risco do dia.
- A `AuthPolicy` anônima da UI (módulo 3.2) resolve o `401` que o
  `prod-web-deny-all` produz na rota nova — o caminho está correto pelo modelo de
  precedência, mas não foi aplicado num cluster.
