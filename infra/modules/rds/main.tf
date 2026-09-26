# =============================================================================
# modules/rds/main.tf: banco de dados PostgreSQL gerenciado (Amazon RDS)
# -----------------------------------------------------------------------------
# Atende: RF-05 (CA-05.1 a CA-05.4) e CA-C.1 · design §6.3
#
# O RDS é um PostgreSQL GERENCIADO: a AWS cuida da instalação, das
# atualizações de segurança, dos backups e do disco. Nós só escolhemos o
# tamanho e as configurações, e o banco fica pronto para receber conexões.
# =============================================================================

# -----------------------------------------------------------------------------
# DB subnet group
# -----------------------------------------------------------------------------
# Diz ao RDS em QUAIS sub-redes ele pode colocar o banco. A AWS exige
# sub-redes em pelo menos 2 AZs, mesmo sem Multi-AZ (CA-02.3), para poder
# mover o banco de AZ se for preciso.
resource "aws_db_subnet_group" "principal" {
  # O RDS só aceita letras minúsculas, números e hífens neste nome.
  name       = "${var.nome}-db-subnets"
  subnet_ids = var.ids_subredes_privadas

  tags = {
    Name = "${var.nome}-db-subnets"
  }
}

# -----------------------------------------------------------------------------
# Instância PostgreSQL
# -----------------------------------------------------------------------------
resource "aws_db_instance" "principal" {
  # Nome da instância no console da AWS (não é o nome do banco).
  identifier = "${var.nome}-db"

  # --- Motor e tamanho ------------------------------------------------------
  # Só a versão PRINCIPAL ("17"), a mesma do Docker Compose local (CA-05.4).
  # A AWS escolhe a versão menor mais recente (ex.: 17.x) e, com o
  # auto_minor_version_upgrade, aplica as correções de segurança da série 17.
  engine                     = "postgres"
  engine_version             = "17"
  auto_minor_version_upgrade = true
  instance_class             = var.classe_instancia

  # 20 GB é o mínimo do RDS. gp3 é o tipo de disco SSD atual: mais barato e
  # com desempenho base melhor que o antigo gp2.
  allocated_storage = 20
  storage_type      = "gp3"

  # --- Banco e credenciais --------------------------------------------------
  # db_name: banco criado na primeira inicialização. password: vem de uma
  # variável sensitive, então aparece como "(sensitive value)" no plan.
  db_name  = var.nome_banco
  username = var.usuario
  password = var.senha

  # --- Rede e segurança -----------------------------------------------------
  db_subnet_group_name   = aws_db_subnet_group.principal.name
  vpc_security_group_ids = [var.id_sg_rds]

  # O banco NÃO recebe IP público: só é alcançável de dentro da VPC
  # (CA-05.2). Mesmo que o SG fosse aberto por engano, não haveria rota da
  # internet até ele.
  publicly_accessible = false

  # Criptografia do disco, dos backups e dos snapshots, com chave gerenciada
  # pela AWS (CA-05.3). Só pode ser definida na CRIAÇÃO do banco: ligar
  # depois exige recriá-lo.
  storage_encrypted = true

  # SSL/TLS: no PostgreSQL 15+, o RDS já vem com rds.force_ssl = 1, ou seja,
  # conexões sem criptografia são RECUSADAS. Não é preciso configurar nada
  # (design §6.3). A API se conecta com DB_SSL=true (CA-04.4).

  # --- Custo (CA-C.1) -------------------------------------------------------
  # Sem Multi-AZ: uma réplica em espera em outra AZ dobraria o custo.
  multi_az = false

  # Backups automáticos guardados por 1 dia (o mínimo com backup ligado).
  backup_retention_period = 1

  # --- Ciclo de vida (escolhas de LABORATÓRIO) ------------------------------
  # Em PRODUÇÃO, estes três valores seriam o contrário:
  # - skip_final_snapshot = true: o "destroy" não cria um snapshot final.
  #   Em produção, esse snapshot é a última cópia dos dados antes de apagar.
  #   Aqui, ele sobraria depois do destroy, consumindo créditos.
  # - deletion_protection = false: permite o "destroy" final (T-13).
  # - apply_immediately = true: aplica mudanças na hora, em vez de esperar a
  #   janela de manutenção semanal (o que pode causar uma breve
  #   indisponibilidade no meio do uso).
  skip_final_snapshot = true
  deletion_protection = false
  apply_immediately   = true

  tags = {
    Name = "${var.nome}-db"
  }
}
