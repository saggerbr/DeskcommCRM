# Publicar imagens no Docker Hub

As únicas imagens construídas por este projeto são `deskcommcrm`,
`deskcomm-worker` e `deskcomm-scheduler`. Elas são publicadas como
`docker.io/somamais/<imagem>:<versão>` pelo CI; WAHA, Redis, Caddy e demais
dependências continuam sendo consumidas diretamente dos respectivos upstreams.

## Preparação única

No repositório GitHub, cadastre os secrets de Actions:

- `DOCKERHUB_USERNAME`: usuário com permissão de escrita na organização `somamais`;
- `DOCKERHUB_TOKEN`: access token do Docker Hub com permissão de leitura/escrita.

As três imagens precisam estar públicas no Docker Hub. O instalador e o Portainer
fazem pull anônimo; uma imagem privada faz a instalação falhar.

## Como sai uma versão

Não execute `docker push` na VPS nem na máquina de desenvolvimento. Use o workflow
GitHub **release**: ele calcula a versão a partir de `.changes/`, abre o PR de release
e, quando esse PR é mesclado, cria a tag `vX.Y.Z`. A tag dispara
`publish-image.yml`, que chama o script versionado:

```bash
bash scripts/publicar-imagem-docker.sh --help
```

O script exige uma versão explícita, constrói `linux/amd64` e recusa publicação fora
do CI. Para uma release `X.Y.Z`, o CI publica `X.Y.Z` e `X.Y` e só move `stable`
depois que app, worker e scheduler foram publicados com sucesso.

Durante a migração, o CI também mantém as mesmas tags no GHCR. Isso permite que um
atualizador antigo conclua a primeira atualização; instalações novas já usam o Docker Hub.
