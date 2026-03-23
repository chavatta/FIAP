# Learner Lab (Vocareum) — resumo para o projeto FIAP

Fonte: instruções do ambiente (atualizadas em 2025-06-24). Use junto com **AWS Details** e **Readme** no painel do lab.

## Regiões permitidas

- **Somente `us-east-1` e `us-west-2`** para a maioria dos serviços.  
- O projeto FIAP no `.env` já usa **`us-east-1`** — mantenha tudo na mesma região (ECR, SQS, DynamoDB, EC2).

## Console AWS

1. **Start Lab** → timer da sessão.  
2. Link **AWS** acima do terminal → abre o console.  
3. Sessão acaba com o timer, mas **recursos ficam**; EC2 **para** e **reinicia** na próxima sessão → **IP público muda** (salvo Elastic IP).

## SSH na EC2 (Linux)

| Onde | Chave | Comando típico |
|------|--------|----------------|
| **us-east-1** | Par **vockey** → baixe **PEM** (Mac/Linux) ou **PPK** (PuTTY no Windows) | `ssh -i labsuser.pem ec2-user@IP_PUBLICO` |
| **Outra região** (ex.: us-west-2) | Criar **novo** key pair ao lançar a instância | Mesmo padrão com o PEM dessa região |

- Security group: **porta 22** aberta para o seu IP (ou o que o enunciado pedir).  
- Usuário comum: **`ec2-user`** (Amazon Linux).  
- **Terminal do próprio lab** (browser): a chave já está em `~/.ssh/labsuser.pem` →  
  `ssh -i ~/.ssh/labsuser.pem ec2-user@<public-ip>`

**Windows:** PuTTY + **labsuser.ppk** (Download PPK em **AWS Details**) **ou** OpenSSH + **labsuser.pem** + `icacls` (ver `docs/CONEXAO-SSH-LABS.md`).

## Limites EC2 (importante)

- Tipos: **nano, micro, small, medium, large** (on-demand).  
- **Máx. 9 instâncias** rodando por região; **máx. 32 vCPU** no total (entre serviços).  
- **≥20 instâncias** ao mesmo tempo → conta pode ser **desativada**.  
- EBS: até **100 GB**, gp2/gp3/sc1/standard.

## IAM no lab

- Você **não** cria usuários/grupos livremente.  
- Use **`LabRole`** / **`LabInstanceProfile`** onde o console pedir (EC2, Lambda, ECS task role, etc.).  
- EC2 com **LabInstanceProfile** → apps na instância podem chamar AWS (S3, SQS, etc.) via role.

## Serviços úteis para o Challenge FIAP

| Serviço | Observação |
|---------|------------|
| **ECR** | LabRole é **read-only**; no console você tem **write** → `docker push` após login. |
| **ECS / EKS** | Permitidos; instâncias **large** ou menores; usar **LabRole** em task/cluster conforme doc. |
| **SQS, DynamoDB** | Permitidos (analytics / evaluation). |
| **CloudShell** | CLI já configurado; ícone no topo do console. |
| **CloudFormation** | Bom para subir e **apagar** stack inteira e economizar budget. |

## Orçamento (budget)

- Monitorar no topo do lab; Budgets atualizam a cada **8–12 h**.  
- Estourar o budget → **conta desabilitada** e perda de progresso/recursos.  
- **Parar/terminar** EC2, RDS, NAT, SageMaker, etc. quando não usar.  
- Instâncias **reiniciam** ao dar Start Lab de novo → custam de novo.

## Checklist rápido — subir stack FIAP no lab

1. Região **us-east-1**.  
2. Criar **SQS** + **DynamoDB**; copiar URLs/nomes para `.env`.  
3. **EC2** (ex.: Amazon Linux 2, **t3.small** ou **t2.medium** dentro do permitido), key **vockey**, security group (22 + portas dos serviços se for testar por IP).  
4. Na EC2: Docker + Docker Compose; clone/build das imagens ou `docker compose up`.  
5. **ECR**: criar repositórios, `aws ecr get-login-password`, tag e push (URLs no `.env` do Makefile).  
6. Anotar **novo IP público** sempre que a sessão reiniciar a instância.

## Links internos do repo

- **Ordem completa AWS CLI + Docker:** **`docs/AWS-DEPLOY-ORDEM.md`**  
- SSH pelo Windows com PEM: **`docs/CONEXAO-SSH-LABS.md`**  
- Não commitar chaves: **`.gitignore`** (`*.pem`, `ssourl.txt`, `.env`)
