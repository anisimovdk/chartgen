#!/usr/bin/env bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

hash curl yq helm tree &>/dev/null || { echo "Somethins is missing, you need 'curl yq helm tree'"; exit 1;}

command_regex='^(build|clean)$'
url_regex='(https?|ftp|file)://[-[:alnum:]\+&@#/%?=~_|!:,.;]*[-[:alnum:]\+&@#/%=~_|]'
path_regex='^(/)?([^/\0]+(/)?)+$'
namespace_regex='^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'

if [[ -z "$1" ]] || [[ ! "$1" =~ $command_regex ]]; then
  echo "Specify valid command, e.g. 'build' or 'clean'"
  exit 1
elif [[ -z "$2" ]] && [[ ! "$2" =~ $path_regex ]]; then
  echo "Specify chart name, e.g. 'chartgen/foo'"
  exit 1
elif [[ ! "$2" =~ $path_regex ]]; then
  echo "'$2' is not valid chart path, valid pattern is '$path_regex'"
  exit 1
elif [[ -z "$3" ]]; then
  echo "Specify release namespace, e.g. 'default'"
  exit 1
elif [[ ! "$3" =~ $namespace_regex ]]; then
  echo "'$3' is not valid release namespace, valid pattern is '$namespace_regex'"
  exit 1
elif [[ -z "$4" ]]; then
  echo "Specify one or more manifests URLs by args"
  exit 1
fi

cmd=$1
chart=$2
namespace=$3
shift 3
urls=$*

for url in ${urls}
do
  if [[ ! "$url" =~ $url_regex ]]; then
    echo "'$url' is not valid URL, valid URL pattern is '$url_regex'"
    exit 1
  fi
done

charts_dir=$(realpath "$(dirname "${chart}")")
chart_name=$(basename "$chart")
chart_dir="${charts_dir:?}/${chart_name:?}"

build() {
  mkdir -p "${chart_dir}/templates"
  mkdir -p "${chart_dir}/crds"
  mkdir -p "${charts_dir}/manifests/${chart_name}"

  echo "downloading manifests" 1>&2

  pushd "${charts_dir}/manifests/${chart_name}" || exit 1

  export RELEASE_NAME=$chart_name
  export RELEASE_NAMESPACE=$namespace
  for url in ${urls}; do
    echo "Downloading $url"
    curl -L -sSfI "${url}" 1>/dev/null || { echo "'$url' download failed"; exit 1; }
    curl -L "${url}" | \
      yq eval-all '.metadata |= (. *d {"annotations":{"meta.helm.sh/release-name":env(RELEASE_NAME),"meta.helm.sh/release-namespace":env(RELEASE_NAMESPACE)},"labels":{"app.kubernetes.io/instance":env(RELEASE_NAME),"app.kubernetes.io/managed-by":"Helm"}})' | \
      yq -s '(.kind | downcase) + "_" + $index'
  done

  popd || exit 1

  echo "generating ${chart_name}/Chart.yaml" 1>&2

  cat <<EOF > "${chart_dir}/Chart.yaml"
apiVersion: v1
appVersion: "1.0"
description: A Helm chart for Kubernetes
name: ${chart_name}
version: 0.1.0
EOF

  echo "generating ${chart_name}/templates/NOTES.txt" 1>&2

  cat <<EOF > "${chart_dir}/templates/NOTES.txt"
${chart_name} has been installed as release {{ .Release.Name }}.

Run \`helm status {{ .Release.Name }}\` for more information.
Run \`helm delete --purge {{.Release.Name}}\` to uninstall.
EOF

  echo "sorting manifests" 1>&2

  rm ${charts_dir}/manifests/${chart_name}/namespace_*.y*l || true
  mv ${charts_dir}/manifests/${chart_name}/customresourcedefinition_*.y*l "${chart_dir}/crds/" || true
  mv ${charts_dir}/manifests/${chart_name}/*.y*l "${chart_dir}/templates/" || true

  echo "running helm lint" 1>&2

  helm lint "${chart_dir}" || { echo "Output chart is not valids"; exit 1; }

  echo "generated following files:"

  tree "${chart_dir}"
}

clean() {
  rm ${chart_dir}/*.y*l
  rm ${chart_dir}/crds/*.y*l
  rm ${chart_dir}/templates/*.y*l
  rm ${chart_dir}/templates/NOTES.txt
}

case "$cmd" in
  "build" ) build ;;
  "clean" ) clean ;;
  * ) echo "unsupported command: $cmd" 1>&2; exit 1 ;;
esac
