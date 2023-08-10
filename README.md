# chartgen

Chartgen is a dumb simple Helm Chart generator from manifest URLs

## Features

* CRDs auto-detect
* helm lables, annotation auto-injection
* namespace resource auto-remover
* helmfile ready to use

## Requirements

* `curl` for downloading manifests
* `yq` for patching manifests
* `helm` for linting output helm chart
* `tree` for listing output helm chart files

Feel free to modify.

## Usage

`./chartgen <cmd> <output_helmchart_dir> <chart_release_namespace> [url1] [url2] [urlN]`

```bash
./chartgen.sh build chartgen/cdi kubevirt-cdi \
  "https://github.com/kubevirt/containerized-data-importer/releases/download/v1.56.0/cdi-operator.yaml" \
  "https://github.com/kubevirt/containerized-data-importer/releases/download/v1.56.0/cdi-cr.yaml"
```

You must specify `<chart_release_namespace>` for correct helm labels and annotation injection.

## Usage with `helmfile`

Put `chartgen.sh` near `helmfile.yaml` and run `helmfile apply`, profit!

```yaml
# helmfile.yaml
releases:
  - name: cdi
    chart: chartgen/cdi
    namespace: cdi
    disableValidation: true
    createNamespace: true
    hooks:
      - events:
          - prepare
          - cleanup
        command: ./chartgen.sh
        args:
          - '{{`{{if eq .Event.Name "prepare"}}build{{else}}clean{{end}}`}}'
          - '{{`{{.Release.Chart}}`}}'
          - '{{`{{.Release.Namespace}}`}}'
          - https://github.com/kubevirt/containerized-data-importer/releases/download/v1.56.0/cdi-operator.yaml
          - https://github.com/kubevirt/containerized-data-importer/releases/download/v1.56.0/cdi-cr.yaml
```

## Thanks

To [@mumoshu](https://github.com/mumoshu) for [helmify-kustomize](https://gist.github.com/mumoshu/f9d0bd98e0eb77f636f79fc2fb130690) and ability to use it with helmfile [Helmfile-hooks](https://helmfile.readthedocs.io/en/latest/#helmfile-kustomize)
