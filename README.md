# FIAP

Repositorio para todas as aplicacoes conteinerizadas do Challenge da Fase 2.

## Pre requisitos
- Docker >= 29.3.0
- Docker compose >= 5.1.0
- Make >= 4.3
- Python >= 3.11
- Go >= 1.22.2
- AWS CLI >= 

## Build
Para montar as imagens docker das aplicações use o comando a seguir:

```sh
make build
```

ou para uma aplicação especifica:

```sh
make evaluation
```

## Push
Para enviar as imagens ao AWS ECR primeiro vc deve completar as variaveis de ambiente no **.env** do projeto, depois execute o comando:

```sh
make push
```

## Clean
Caso queria remover as imagens geradas apenas utilize o seguinte comando:

```sh
make clean
```

## Help
Em caso de duvidas sobre os comandos configurados no **make** utilize o comando:

```sh
make help
```

## Fluxo completo
Para realizar o fluxo completo de **remover as imagens**, realizar o **build** e **publicar** no ECR utilize esse comando:

```sh
make
```

# Rodando a Stack
Para rodar o docker-compose com todos os serviços e suas devidas dependencias utilize o seguinte comando:

```sh
docker compose up -d
```

e para parar utilize:

```sh
docker compose down
```
---
### TO DO
- [ ] Criar script de login na AWS (make aws) e adicionar as variaveis no .env
- [ ] Completar as variaveis vazias do .env
- [ ] Testar a stack completa rodando localmente
