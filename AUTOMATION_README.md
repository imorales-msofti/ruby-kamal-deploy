# 🤖 Kamal + AWS Automation Scripts

Scripts para automatizar el deployment y teardown de aplicaciones Rails usando Kamal en AWS.

## 📋 Prerequisitos

- AWS CLI configurado (`aws configure`)
- Terraform instalado
- Kamal instalado (`gem install kamal`)
- Clave SSH en `~/.ssh/kamal-server-key.pem` (privada) y `.pub` (pública)
- Docker con buildx instalado localmente

## 🚀 Uso

### Deploy Completo (Primera vez o después de teardown)

```bash
./deploy-automation.sh
```

Este script hace:
1. **Terraform Plan** - Muestra qué se va a crear
2. **Terraform Apply** - Crea infraestructura en AWS (EC2, Security Group, ECR, Key Pair)
3. **Get Outputs** - Obtiene IPs y URLs de la infraestructura
4. **Wait for EC2** - Espera a que la instancia esté lista
5. **Configure Docker** - Configura permisos de Docker en el servidor
6. **Update deploy.yml** - Actualiza automáticamente la configuración con el nuevo host
7. **Configure ECR** - Configura credenciales del registry
8. **Kamal Setup** - Despliega la aplicación con Kamal

### Teardown Completo

```bash
./teardown.sh
```

Este script hace:
1. **Muestra recursos** - Lista lo que se va a destruir
2. **Kamal Remove** - Elimina contenedores de la aplicación (si el servidor está accesible)
3. **Terraform Destroy** - Destruye toda la infraestructura de AWS
4. **Clean Up** - Limpia archivos locales temporales

### Deploy Subsiguiente (después de cambios en código)

Si la infraestructura ya existe y solo quieres hacer deploy de cambios:

```bash
# Configurar password del registry
export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region us-east-1)

# Deploy
kamal deploy
```

## 📁 Estructura de Archivos

```
.
├── deploy-automation.sh    # Script principal de deployment
├── teardown.sh            # Script de destrucción de infraestructura
├── main.tf               # Configuración principal de Terraform
├── variables.tf          # Variables de Terraform
├── outputs.tf            # Outputs de Terraform
├── config/
│   └── deploy.yml       # Configuración de Kamal
└── .ssh/
    ├── kamal-server-key.pem  # Clave privada SSH
    └── kamal-server-key.pub  # Clave pública SSH
```

## 🔧 Comandos Útiles Post-Deploy

```bash
# Ver logs de la aplicación
kamal app logs

# Ver logs en tiempo real
kamal app logs -f

# Ver contenedores corriendo
kamal app containers

# Reiniciar aplicación
kamal app restart

# Acceder al contenedor
kamal app exec -i bash

# Ver estado del proxy
kamal proxy logs
```

## 🔄 Workflow Típico de Desarrollo

### 1. Primer Deploy
```bash
./deploy-automation.sh
```

### 2. Hacer Cambios en el Código
```bash
# Editar archivos...
git add .
git commit -m "New feature"
```

### 3. Deploy de Cambios
```bash
export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region us-east-1)
kamal deploy
```

### 4. Testing y Verificación
```bash
# Ver logs
kamal app logs

# Verificar contenedores
kamal app containers

# Probar en navegador
curl http://$(terraform output -raw instance_public_dns)
```

### 5. Teardown (cuando termines)
```bash
./teardown.sh
```

## ⚙️ Configuración

### Variables de Terraform

Edita `variables.tf` para personalizar:

```hcl
variable "instance_type" {
  default = "t3.micro"  # Tipo de instancia EC2
}

variable "instance_name" {
  default = "AppServerInstance"  # Nombre de la instancia
}

variable "ecr_repository_name" {
  default = "kamal-app"  # Nombre del repositorio ECR
}
```

### Configuración de Kamal

Edita `config/deploy.yml` para personalizar:

```yaml
service: kamal-app
image: kamal-app

env:
  clear:
    RAILS_ENV: production  # O development/staging

builder:
  arch: amd64
  remote: true  # Build en servidor
```

## 🔍 Troubleshooting

### Error: "Permission denied" al ejecutar scripts
```bash
chmod +x deploy-automation.sh teardown.sh
```

### Error: "docker permission denied"
El script ya configura esto automáticamente, pero si lo necesitas manualmente:
```bash
ssh -i ~/.ssh/kamal-server-key.pem ubuntu@<EC2_HOST> \
  "sudo usermod -aG docker ubuntu && sudo systemctl restart docker"
```

### Error: "KAMAL_REGISTRY_PASSWORD not set"
```bash
export KAMAL_REGISTRY_PASSWORD=$(aws ecr get-login-password --region us-east-1)
```

### Ver recursos de Terraform
```bash
terraform show
terraform state list
```

### Restaurar deploy.yml desde backup
```bash
cp config/deploy.yml.bak config/deploy.yml
```

## 📊 Costos Estimados (AWS)

- **EC2 t3.micro**: ~$0.0104/hora (~$7.5/mes)
- **ECR Storage**: $0.10/GB-mes
- **Data Transfer**: Variable según uso

💡 **Tip**: Usa `./teardown.sh` cuando no estés usando la infraestructura para ahorrar costos.

## 🛡️ Seguridad

Los scripts incluyen:
- ✅ Security Group con reglas específicas (SSH, HTTP, HTTPS)
- ✅ Uso de claves SSH privadas
- ✅ ECR con escaneo de imágenes habilitado
- ✅ Encriptación AES256 en ECR
- ✅ Variables de entorno para secrets

## 📝 Notas

- El script hace backup automático de `deploy.yml` antes de modificarlo
- La clave SSH debe existir antes de ejecutar el script
- El primer deploy toma más tiempo (construcción de imagen, setup de servidor)
- Los deploys subsiguientes son más rápidos (solo actualización de contenedores)

## 🔗 Recursos Adicionales

- [Documentación de Kamal](https://kamal-deploy.org)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
