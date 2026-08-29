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
content/
  antora.yml                     atributos (hostname NUNCA fica aqui)
  modules/ROOT/
    nav.adoc
    pages/                       11 páginas: índice, visão geral, ambiente,
                                 7 módulos e conclusão
validation/
  module-0X/validation.yml       verificação por módulo (Ansible puro)
ui-config.yml                    tabs do painel direito (nookbag)
```

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
