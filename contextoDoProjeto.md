## Instruções de contexto para a Ferramenta de IA ##

# Narrativa — O Desafio Final da TechNova #
Uma empresa chamada de Desenvolvimento de Software TechNova fechou um contrato com um novo cliente e precisa entregar um ambiente completo e reproduzível de uma nova API — a API de Reservas. 

O CTO Carlos Mendes reuniu a equipea e falou:
    "Vocês passaram o bimestre aprendendo cada peça: versionamento, containers, orquestração, infraestrutura como código, rede, banco de dados, state remoto e módulos. Agora quero ver tudo junto, feito por vocês, do zero. Cada um vai montar o ambiente da API de Reservas sozinho, é assim que eu sei que vocês realmente aprenderam."

A consultora Marina complementou:
    "E não quero código jogado. Quero histórico Git limpo, a aplicação containerizada, o ambiente local subindo com um comando, e a infraestrutura na AWS modularizada com state remoto. Podem usar IA como copiloto, na verdade, quero que usem, mas cada decisão precisa ser entendida e validada por vocês. No final, me entreguem um relatório contando como foi."

# Objetivo:
Entregar a API de Reservas da TechNova, do commit inicial até a infraestrutura na nuvem.

# O que construir:
A API de Reservas é uma aplicação Node.js/Express que gerencia reservas (campos: id, cliente, data, status). Você vai entregar a jornada completa dela.

| Método | Rota | Ação (CRUD) | Descrição |
|--------|------|-------------|-----------|
| `POST` | `/reservas` | **Create** | Cria uma nova reserva (valida os campos obrigatórios) |
| `GET` | `/reservas` | **Read** | Lista todas as reservas |
| `GET` | `/reservas/:id` | **Read** | Busca uma reserva pelo `id` (404 se não existir) |
| `PUT` | `/reservas/:id` | **Update** | Atualiza uma reserva existente |
| `DELETE` | `/reservas/:id` | **Delete** | Remove uma reserva |
| `GET` | `/health` | — | Health check (usado pelo healthcheck do Compose) |

# Estrutura do projeto:
No repositório prova-primeiro-bimestre-devops:

prova-primeiro-bimestre-devops/
├── README.md                     # Nome, RA, descrição do projeto
├── .gitignore
├── app/                          # API de Reservas
│   ├── src/
│   ├── package.json
│   ├── Dockerfile
│   └── .dockerignore
├── docker-compose.yml            # API + PostgreSQL (ambiente local)
├── .env.example
├── infra/                        # Terraform modularizado
│   ├── modules/
│   │   ├── vpc/
│   │   ├── security-group/
│   │   ├── ec2/
│   │   └── rds/
│   ├── main.tf                   # Composição dos módulos
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf              # Provider AWS + backend S3
│   └── backend/                  # S3 + DynamoDB para remote state
├── evidencias/
│   ├── docker-build.txt          # ou screenshot
│   ├── compose-ps.txt            # docker compose ps
│   ├── terraform-plan.txt
│   └── (screenshots opcionais)
└── relatorio.md                  # Relatório do processo com IA


