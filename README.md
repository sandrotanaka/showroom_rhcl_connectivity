# Workshop — Red Hat Connectivity Link

Guia autoguiado de 2 horas sobre o Red Hat Connectivity Link, servido pelo
Showroom. Conteúdo em **português**; nomes de produto e de recurso ficam em
inglês (Service Mesh, Gateway, AuthPolicy).

O conteúdo é derivado da demo em
[rhcl-connectivity-demo](https://github.com/sandrotanaka/rhcl-connectivity-demo)
— cada módulo corresponde a um passo do `docs/DEMO-PASSO-A-PASSO.md`, e cada
verificação a um bloco de `scripts/preflight.sh`.

## Público e formato

- Desenvolvedores e engenheiros de plataforma, na mesma sala.
- **Um cluster OpenShift SNO por participante.** Os módulos 2 e 3 editam as
  mesmas policies e os contadores do Limitador são por plano, não por pessoa:
  num cluster compartilhado, o tráfego de um participante consome a cota do
  outro e o `429` aparece antes da hora.

## Estrutura

```
scripts/workshop.sh              os três verbos: verifica / corrige / pula
content/
  antora.yml                     atributos (hostname NUNCA fica aqui)
  modules/ROOT/
    nav.adoc
    pages/                       11 páginas: índice, visão geral, ambiente,
                                 7 módulos e conclusão
validation/
  module-0X/
    validation.yml               verifica — afirma as tarefas do módulo
    reset.yml                    corrige — estado inicial (quem quebrou algo)
    solve.yml                    pula — estado final (quem não vai fazer)
ui-config.yml                    tabs do painel direito (nookbag)
```

## Os três verbos

O participante decora um comando só:

```bash
bash scripts/workshop.sh verifica 2    # confere as tarefas do módulo
bash scripts/workshop.sh corrige 2     # devolve o módulo ao estado INICIAL
bash scripts/workshop.sh pula 6        # aplica o estado FINAL do módulo
bash scripts/workshop.sh lista         # o que cada módulo tem disponível
```

`corrige` e `pula` têm alvos **opostos** — início e fim — e por isso são dois
arquivos, não um com flag. Um `solve` usado como conserto pula o aprendizado sem
avisar ninguém.

`pula` é **cumulativo**: `pula 3` roda os `solve` de 1, 2 e 3, porque o estado
final do módulo 3 pressupõe o dos anteriores. Todo `solve` é idempotente.

Módulo que não muda estado — só leitura e medição — não tem `pula`. Pular esses
é fechar a página, e o `lista` diz quais são.

## As verificações

Cada módulo termina com um `validation.yml` que o participante roda no terminal
embutido. São playbooks Ansible sem módulo customizado — rodam em qualquer
ambiente com `kubernetes.core`:

```bash
ansible-playbook validation/module-02/validation.yml
```

Cada um afirma as tarefas do módulo e, ao falhar, imprime **qual** tarefa falhou
e o comando que corrige. É a mesma disciplina do `preflight.sh` da demo.

> Para publicar na RHDP com correção automática, o plugin `ftl` do
> [rhdp-skills-marketplace](https://github.com/rhpds/rhdp-skills-marketplace)
> converte estes arquivos para o formato `validation_check` e gera os `solve.yml`
> correspondentes. A estrutura já está no formato que ele espera.

## Regras de conteúdo

- **Nenhum hostname, senha ou nome de cluster no texto.** O cluster é efêmero;
  todo endereço é descoberto por comando, na hora. Os atributos `%ATTR_NOT_SET%`
  em `content/antora.yml` são preenchidos em runtime.
- Nome de produto em inglês, com a concordância junto: "no Service Mesh", nunca
  "na malha".
- Cada módulo tem: contexto, exercícios, verificação e "o que isso significa".

## Publicar

O guia sobe como componente `showroom` do chart de Field Content:

```yaml
components:
  showroom:
    content:
      repoUrl: "https://github.com/sandrotanaka/showroom_rhcl_connectivity.git"
      repoRef: "main"
```
