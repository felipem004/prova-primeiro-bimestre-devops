# =============================================================================
# outputs.tf: saídas do projeto principal
# -----------------------------------------------------------------------------
# Atende: RF-06 (CA-06.2) · design §7
#
# Estes valores aparecem no terminal ao fim do "apply" e podem ser vistos de
# novo a qualquer momento com "terraform output". São as informações usadas
# nos testes de aceite da T-12.
#
# Nenhuma saída expõe a senha do banco (CA-06.2).
# =============================================================================

output "url_api" {
  description = "URL do health check da API. Deve responder 200 alguns minutos após o apply."
  value       = "http://${module.ec2.ip_publico}/health"
}

output "ip_publico_ec2" {
  description = "IP público da EC2. Muda se a instância for parada e ligada de novo (rode 'terraform apply -refresh-only' para atualizar)."
  value       = module.ec2.ip_publico
}

output "comando_ssh" {
  description = "Comando para acessar a EC2 por SSH (só funciona a partir do IP liberado em cidr_ssh)."
  # labsuser.pem é a chave privada baixada do Learner Lab ("AWS Details" ->
  # "Download PEM"). ec2-user é o usuário padrão do Amazon Linux.
  value = "ssh -i labsuser.pem ec2-user@${module.ec2.ip_publico}"
}

output "endpoint_rds" {
  description = "Hostname do banco RDS. Só é acessível de dentro da VPC (pela EC2)."
  value       = module.rds.endereco
}
