# Conectar na instância do lab (SSH com `labsuser.pem`)

## 1. Dados que você precisa (no console AWS do lab)

- **IP público** ou **DNS público** da EC2  
- **Usuário SSH** (depende da AMI):
  - Amazon Linux → `ec2-user`
  - Ubuntu → `ubuntu`
  - Outro → veja a descrição da atividade / console EC2 (“Connect”)

## 2. Windows — permissão da chave (evita erro do OpenSSH)

No PowerShell, na pasta do projeto:

```powershell
cd "c:\Users\lucas\Downloads\FIAP-main\FIAP-main"
icacls labsuser.pem /inheritance:r
icacls labsuser.pem /grant:r "$env:USERNAME:(R)"
```

## 3. Conectar

```powershell
ssh -i .\labsuser.pem ec2-user@SEU_IP_PUBLICO
```

Troque `ec2-user` pelo usuário correto e `SEU_IP_PUBLICO` pelo IP da instância.

Primeira vez: digite `yes` para aceitar a fingerprint.

## 4. Se der “Permission denied (publickey)”

- Usuário errado (`ubuntu` vs `ec2-user`)  
- IP errado ou instância sem IP público  
- Par de chaves não bate com a que foi colocada na EC2 no launch

## 5. Segurança

- **Não** envie `labsuser.pem` por e-mail/chat nem suba no Git (já está no `.gitignore`).
