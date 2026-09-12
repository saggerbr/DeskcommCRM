#!/usr/bin/env bash
# Constrói uma das imagens próprias do produto com uma versão explícita.
#
# A publicação só é permitida no CI. A VPS do cliente apenas baixa imagens já
# publicadas; build local é útil para validar um PR, nunca para distribuir uma
# release. O workflow publish-image.yml passa as duas referências durante a
# migração de registry: Docker Hub é o destino novo e GHCR mantém os clientes
# cujo atualizador antigo ainda aponta para lá.
set -euo pipefail

uso() {
  cat <<'EOF'
Uso:
  bash scripts/publicar-imagem-docker.sh \
    --image <deskcommcrm|deskcomm-worker|deskcomm-scheduler> \
    --version <X.Y.Z|sha> \
    --repository <registry/dono> [--repository <registry/dono> ...] \
    [--tag <tag> ...] [--label <chave=valor> ...] [--publish]

Sem --publish, monta a imagem localmente. Com --publish, só roda no CI e
publica todas as tags no(s) repositório(s) informados.
EOF
}

imagem=""
versao=""
publicar=false
declare -a repos=()
declare -a tags=()
declare -a labels=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --image) imagem="${2:-}"; shift 2 ;;
    --version) versao="${2:-}"; shift 2 ;;
    --repository) repos+=("${2:-}"); shift 2 ;;
    --tag) tags+=("${2:-}"); shift 2 ;;
    --label) labels+=("${2:-}"); shift 2 ;;
    --publish) publicar=true; shift ;;
    -h|--help) uso; exit 0 ;;
    *) echo "Argumento inválido: $1" >&2; uso >&2; exit 2 ;;
  esac
done

case "$imagem" in
  deskcommcrm) arquivo="Dockerfile" ;;
  deskcomm-worker) arquivo="Dockerfile.worker" ;;
  deskcomm-scheduler) arquivo="Dockerfile.scheduler" ;;
  *) echo "--image deve ser uma das três imagens próprias do produto." >&2; exit 2 ;;
esac

# Releases usam SemVer; builds de branch usam o SHA curto produzido pelo CI.
if ! [[ "$versao" =~ ^([0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?|[0-9a-f]{7,40})$ ]]; then
  echo "--version deve ser SemVer (ex.: 1.20.0) ou um SHA curto." >&2
  exit 2
fi

[ "${#repos[@]}" -gt 0 ] || { echo "Informe ao menos um --repository." >&2; exit 2; }

if [ "$publicar" = true ] && [ "${CI:-}" != "true" ]; then
  echo "Publicação recusada fora do CI: releases são construídas no GitHub Actions." >&2
  exit 2
fi

declare -a refs=()
for repo in "${repos[@]}"; do
  [[ "$repo" =~ ^[a-z0-9.-]+/[a-z0-9][a-z0-9_-]*$ ]] || {
    echo "Repositório inválido: $repo (use registry/dono)." >&2
    exit 2
  }
  refs+=("${repo}/${imagem}:${versao}")
  for tag in "${tags[@]}"; do
    [[ "$tag" =~ ^[0-9A-Za-z._-]+$ ]] || { echo "Tag inválida: $tag" >&2; exit 2; }
    refs+=("${repo}/${imagem}:${tag}")
  done
done

declare -a comando=(docker buildx build --platform linux/amd64 --file "$arquivo" --build-arg "APP_VERSION=${versao}")
for ref in "${refs[@]}"; do comando+=(--tag "$ref"); done
for label in "${labels[@]}"; do
  [[ "$label" = *=* ]] || { echo "Label inválido: $label" >&2; exit 2; }
  comando+=(--label "$label")
done

if [ "$publicar" = true ]; then
  comando+=(--push)
else
  comando+=(--load)
fi

"${comando[@]}" .
