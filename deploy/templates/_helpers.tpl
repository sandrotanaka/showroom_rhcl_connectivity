{{/*
  Origem do conteudo do guia.

  Preferencia: o que o operador escolheu explicitamente; senao, o repositorio
  que o CI recebeu (injetado como gitops.repoURL). O guia mora NESTE repo, entao
  o default correto e ele mesmo -- e assim guia e chart nunca divergem de versao.
*/}}
{{- define "workshop.contentRepo" -}}
{{- .Values.showroom.content.repoUrl | default .Values.gitops.repoURL -}}
{{- end -}}

{{- define "workshop.contentRef" -}}
{{- .Values.showroom.content.repoRef | default .Values.gitops.revision | default "main" -}}
{{- end -}}

{{- define "workshop.url" -}}
https://{{ .Values.showroom.name }}-{{ .Values.showroom.namespace }}.{{ .Values.deployer.domain }}
{{- end -}}
