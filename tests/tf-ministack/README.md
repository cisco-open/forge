# Testar Terraform/OpenTofu no MiniStack

Valida a camada de **recursos AWS** do Forge (SQS, S3, SSM, IAM, Lambda, EKS
control-plane) localmente, sem conta nem token. Limitacoes aceitas abaixo.

## Como funciona

Um arquivo `ministack_override.tf` (sufixo `_override.tf` = o OpenTofu mescla no
seu provider `aws`) injeta os endpoints do MiniStack. Nada nos seus modulos
muda.

## Passo a passo (exemplo, prova o ciclo)

```bash
# 1. suba o MiniStack (use o docker-compose.yml do projeto de smoke)
docker run -d -p 4566:4566 -v /var/run/docker.sock:/var/run/docker.sock \
  ministackorg/ministack:latest

# 2. rode o exemplo
cd example
USE_MINISTACK=true tofu init
USE_MINISTACK=true tofu test      # aplica no MiniStack e checa, depois destroi
# ou:
../tf-ministack.sh plan example
../tf-ministack.sh apply example
```

## Aplicar nos stacks reais do Forge

**Com OpenTofu puro:** copie `ministack_override.tf` para o diretorio do stack
que quer testar e rode `tofu init && tofu plan` (ou use `tf-ministack.sh`).

**Com Terragrunt:** cole o bloco de `terragrunt-ministack.hcl` no seu
`terragrunt.hcl` raiz. Ele so gera o override quando `USE_MINISTACK=true`:

```bash
USE_MINISTACK=true terragrunt plan
# (TF_BIN=terragrunt ./tf-ministack.sh plan caminho/do/stack)
```

## Limitacoes aceitas (importante)

- **EKS e' so control-plane raso.** Cluster/node group/addon viram objetos CRUD;
  nada roda de verdade. Sem kubelet, Karpenter, ARC ou Calico.
- **Modulos com provider `kubernetes`/`helm` vao falhar** contra o EKS falso
  (tentam falar com a API de um cluster que nao existe). Para testar no
  MiniStack, **escope para os stacks de recursos AWS** e exclua/desligue os
  modulos que dependem do cluster. Sugestoes:
  - rode apenas os diretorios de stack AWS (Terragrunt: aponte para eles);
  - ou use uma variavel tipo `count = var.enable_k8s ? 1 : 0` e rode com
    `-var enable_k8s=false` quando `USE_MINISTACK=true`.
- **IAM nao e' enforced.** `apply` de roles/policies funciona, mas o emulador
  nao nega nada -> nao prova isolamento de tenant.
- Trate como teste de **convergencia de plan/apply** dos recursos AWS, nao como
  verdade de comportamento. A verdade continua sendo AWS efemera real.

## Seguranca

- `tf-ministack.sh` aborta se o MiniStack nao responder em :4566, para nunca
  cair na AWS real por engano.
- Credenciais sao `test`/`test` (so emulador).
- Fixe a imagem do MiniStack numa tag real no docker-compose (nao use :latest).
