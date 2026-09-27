# Entrega — Prova do Primeiro Bimestre (DevOps)

**Aluno:** Felipe Gomes Mariano
**RA:** 3225014 
**Data:** 3225014
**Ferramenta de IA utilizada:** Claude Code

## Sobre o projeto

API de Reservas da TechNova: uma API REST em **Node.js/Express** com **PostgreSQL**, que faz o CRUD de reservas (`id`, `cliente`, `data`, `status`) e tem um health check em `/health`.

O projeto cobre a entrega completa da aplicação:

- **Aplicação containerizada** com Docker (`app/`), rodando com usuário sem privilégios.
- **Ambiente local** com Docker Compose (API + PostgreSQL com volume persistente), que sobe com um único comando: `docker compose up -d --build`.
- **Infraestrutura na AWS** com Terraform modularizado (`infra/modules/`: `vpc`, `security-group`, `ec2`, `rds`) e state remoto em S3 com lock em DynamoDB (`infra/backend/`). A EC2 fica em uma sub-rede pública e o RDS em sub-redes privadas, acessível somente pela EC2.
- **Especificação da infraestrutura** (requisitos, design e tarefas) em `infra/specs/`, seguindo o método spec-driven.
- **Evidências** em `evidencias/`, **relatório** do processo com IA em `relatorio.md` e **histórico de prompts** em `historico_de_prompts.md`.

