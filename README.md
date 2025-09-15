# MongoDB Atlas Backup Tool 🗄️

**[🇺🇸 English](README_EN.md) | 🇪🇸 Español**

Sistema automatizado de backups y restauración para MongoDB Atlas usando Docker. Genera archivos `.archive.gz` válidos con validación de integridad, logs estructurados y herramientas de restauración segura.

## 🚀 Características

- ✅ **Backups automáticos** con archivos `.archive.gz` siempre válidos
- ✅ **Validación de integridad** real con `mongorestore --dryRun`
- ✅ **Logs estructurados** con timestamps y salida a archivo
- ✅ **Restauración segura** con backup automático antes de sobrescribir
- ✅ **Variables simplificadas** para fácil configuración
- ✅ **S3 opcional** con `aws s3 cp` y flags de seguridad
- ✅ **Exit codes precisos** para monitoreo automatizado
- ✅ **Dockerizado** para despliegue consistente

## 🛠️ Requisitos Previos

- **Docker** y **docker-compose** instalados
- **MongoDB Atlas** con usuario de solo lectura (recomendado)
- **AWS S3** (opcional para almacenamiento en la nube)
- **Bot de Telegram** (opcional para notificaciones)

## 📦 Instalación Rápida

### 1. Clonar el repositorio

```bash
git clone URL
cd mongodb-atlas-backup
```

### 2. Configurar variables de entorno

```bash
cp .env.example .env
```

Edita el archivo `.env` con tus configuraciones:

```env
# Obligatorio
MONGODB_URI="mongodb+srv://USER:PASS@cluster.mongodb.net"

# Opcional - Bases de datos específicas (vacío = todas)
DBS="prod,prepro,test"

# Configuración de backups
DEST_DIR="/backups"
RETENTION_DAYS=7
FILE_PREFIX="backup"
LOG_DIR="/backups/logs"

# S3 (opcional)
S3_BUCKET="mi-bucket-backups"
KEEP_LOCAL="true"

# Programación CRON
CRON_SCHEDULE="0 3 * * *"  # Diario a las 3 AM
```

### 3. Construir y ejecutar

```bash
# Construir la imagen
docker-compose build

# Ejecutar en background
docker-compose up -d

# Ver logs en tiempo real
docker-compose logs -f
```

## 🔧 Configuración Detallada

### Variables de Entorno Principales

| Variable | Descripción | Ejemplo | Requerido |
|----------|-------------|---------|-----------|
| `MONGODB_URI` | URI de conexión a MongoDB Atlas | `mongodb+srv://user:pass@cluster.mongodb.net` | ✅ |
| `DBS` | Bases de datos específicas (vacío = todas) | `prod,prepro,test` | ❌ |
| `DEST_DIR` | Directorio destino para backups | `/backups` | ❌ |
| `RETENTION_DAYS` | Días de retención de backups | `7` | ❌ |
| `FILE_PREFIX` | Prefijo de archivos de backup | `backup` | ❌ |
| `LOG_DIR` | Directorio para logs | `/backups/logs` | ❌ |
| `S3_BUCKET` | Bucket S3 para upload automático | `mi-bucket` | ❌ |
| `KEEP_LOCAL` | Mantener archivos locales tras S3 | `true` | ❌ |

✨ **Mejoras implementadas**: Archivos siempre válidos `.archive.gz`, validación real, logs estructurados, exit codes precisos.

### Configuración de AWS S3

| Variable | Descripción | Valor por defecto |
|----------|-------------|------------------|
| `S3_UPLOAD` | Habilitar subida a S3 | `false` |
| `AWS_ACCESS_KEY_ID` | Clave de acceso AWS | - |
| `AWS_SECRET_ACCESS_KEY` | Clave secreta AWS | - |
| `AWS_DEFAULT_REGION` | Región AWS | `us-east-1` |
| `S3_BUCKET` | Nombre del bucket S3 | - |
| `S3_PREFIX` | Prefijo de carpetas en S3 | `mongodb-backups/` |
| `S3_STORAGE_CLASS` | Clase de almacenamiento | `STANDARD` |
| `MULTIPART_THRESHOLD` | Umbral para multipart upload | `100MB` |
| `KEEP_LOCAL_BACKUP` | Mantener copia local tras subir a S3 | `true` |

### Notificaciones Telegram

1. **Crear un bot**:
   - Habla con [@BotFather](https://t.me/botfather)
   - Ejecuta `/newbot` y sigue las instrucciones
   - Guarda el `TELEGRAM_TOKEN`

2. **Obtener tu Chat ID**:
   - Habla con [@userinfobot](https://t.me/userinfobot)
   - Te dará tu `TELEGRAM_CHAT_ID`

3. **Configurar en .env**:
```env
NOTIFY_ON=both           # fail, success, both
TELEGRAM_TOKEN=123456789:ABCdefGhIjKlMnOpQrStUvWxYz
TELEGRAM_CHAT_ID=117654321
```

## 📋 Modos de Operación

### 1. Múltiples Bases de Datos (Recomendado)

```env
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/
MONGO_DBS=webapp,api,logs,analytics
```

**Resultado**: Genera un archivo por cada BD:
- `backup_webapp_20240824_030000.gz`
- `backup_api_20240824_030000.gz`
- `backup_logs_20240824_030000.gz`
- `backup_analytics_20240824_030000.gz`

### 2. Una Sola Base de Datos

```env
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/
MONGO_DB=webapp
```

**Resultado**: `backup_webapp_20240824_030000.gz`

### 3. Todas las Bases de Datos del Cluster

```env
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/
# Sin MONGO_DB ni MONGO_DBS
```

**Resultado**: `backup_all_20240824_030000.gz`

## ☁️ Almacenamiento en AWS S3

### Configuración Básica

```env
S3_UPLOAD=true
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=secreto...
AWS_DEFAULT_REGION=us-east-1
S3_BUCKET=mi-bucket-backups
S3_PREFIX=mongodb-backups/
```

### Estructura de Carpetas en S3

Con la configuración actual, los archivos se organizan por fecha:

```
s3://mi-bucket-backups/mongodb-backups/
├── 2024-08-24/
│   ├── backup_webapp_20240824_030000.gz
│   ├── backup_api_20240824_030000.gz
│   └── backup_logs_20240824_030000.gz
├── 2024-08-25/
│   └── backup_webapp_20240825_030000.gz
└── 2024-08-26/
    └── backup_all_20240826_030000.gz
```

### Funcionalidades S3 Avanzadas

- **Uploads inteligentes**: Archivos <100MB se suben directamente, >100MB usan multipart upload
- **Verificación de integridad**: MD5 checksums automáticos
- **Reintentos automáticos**: Recuperación ante fallos de red
- **Clases de almacenamiento**: `STANDARD`, `STANDARD_IA`, `GLACIER`

### Política de Retención S3 (Lifecycle)

Crea un archivo `lifecycle.json`:

```json
{
    "Rules": [
        {
            "ID": "DeleteOldBackups",
            "Status": "Enabled",
            "Filter": {
                "Prefix": "mongodb-backups/"
            },
            "Transitions": [
                {
                    "Days": 30,
                    "StorageClass": "STANDARD_IA"
                },
                {
                    "Days": 90,
                    "StorageClass": "GLACIER"
                }
            ],
            "Expiration": {
                "Days": 365
            }
        }
    ]
}
```

Aplicar con AWS CLI:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket mi-bucket-backups \
  --lifecycle-configuration file://lifecycle.json
```

## ⏰ Programación con CRON

### Ejemplos de Horarios CRON

| Expresión | Descripción |
|-----------|-------------|
| `0 3 * * *` | Diario a las 3:00 AM |
| `0 2 * * 0` | Domingos a las 2:00 AM |
| `30 1 1 * *` | Primer día de cada mes a la 1:30 AM |
| `0 */6 * * *` | Cada 6 horas |
| `0 0 * * 1-5` | Lunes a Viernes a medianoche |

### Ejecución Única (Sin CRON)

Deja `CRON_SCHEDULE` vacío para ejecutar el backup una sola vez:

```env
# CRON_SCHEDULE=  # Comentado o vacío
```

## 📊 Monitoreo y Logs

### Ver logs en tiempo real

```bash
docker-compose logs -f backup
```

### Health Check

El contenedor incluye un endpoint de salud:

```bash
# Verificar estado
docker exec mongodb-atlas-backup-backup-1 /app/healthcheck.sh
echo $?  # 0 = OK, 1 = ERROR
```

### Archivos de Estado

- `/app/last_success.txt`: Timestamp del último backup exitoso
- `/var/log/backup.log`: Log completo de operaciones

## 🚨 Gestión de Errores

### Notificaciones de Fallos

El sistema notifica automáticamente por Telegram cuando:

- ❌ Falla la conexión a MongoDB
- ❌ Error en mongodump
- ❌ Falla la subida a S3
- ❌ Error en el proceso de backup

### Recuperación ante Fallos

- **Fallos parciales**: Si una BD falla, continúa con las siguientes
- **Reintentos S3**: Reintentos automáticos con exponential backoff
- **Logs detallados**: Información completa para debugging

## 🛡️ Buenas Prácticas de Seguridad

### Usuario MongoDB

Crea un usuario de solo lectura para backups:

```javascript
// En MongoDB Atlas
db.createUser({
  user: "backup-user",
  pwd: "password-seguro",
  roles: [
    { role: "read", db: "webapp" },
    { role: "read", db: "api" },
    { role: "read", db: "logs" }
  ]
});
```

### AWS IAM Policy

Política mínima para S3:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::mi-bucket-backups/*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::mi-bucket-backups"
        }
    ]
}
```

### Variables Sensibles

- ❌ **Nunca** commitees credenciales al repositorio
- ✅ Usa archivos `.env` locales
- ✅ En producción, considera usar AWS Secrets Manager
- ✅ Rota credenciales regularmente

## 🔄 Comandos Útiles

### docker-compose

```bash
# Construir imagen
docker-compose build

# Ejecutar en background
docker-compose up -d

# Parar servicio
docker-compose down

# Ver logs
docker-compose logs -f

# Reiniciar servicio
docker-compose restart

# Ejecutar backup manualmente
docker-compose exec backup /app/backup.sh
```

### Gestión de Backups

```bash
# Listar backups locales
ls -la ./backups/

# Verificar tamaño de backups
du -sh ./backups/*

# Limpiar backups antiguos manualmente
find ./backups -name "backup_*.gz" -mtime +30 -delete
```

## 📈 Optimización y Rendimiento

### Recursos Docker

Los recursos están limitados por defecto:

```yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'
    reservations:
      memory: 256M
      cpus: '0.25'
```

Ajusta según tu carga de trabajo en `docker-compose.yml`.

### Consejos de Rendimiento

- **Horarios**: Programa backups en horas de baja actividad
- **Compresión**: Los archivos .gz ahorran ~70% de espacio
- **S3 Multipart**: Mejora la velocidad para archivos >100MB
- **Retención**: Mantén solo los backups necesarios

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Por favor:

1. Haz fork del repositorio
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## 📝 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.

## 🆘 Soporte y Problemas

Si encuentras algún problema o tienes preguntas:

1. Revisa los [Issues existentes](https://github.com/tu-usuario/mongodb-atlas-backup/issues)
2. Crea un nuevo Issue con detalles del problema
3. Incluye logs relevantes y configuración (sin credenciales)

---

## 📚 Ejemplos de Configuración Completos

### Configuración Básica (Solo Local)

```env
# .env
MONGO_URI="mongodb+srv://backup-user:password@cluster.mongodb.net/"
MONGO_DBS="webapp,api"
RETENTION_DAYS=14
CRON_SCHEDULE="0 3 * * *"
NOTIFY_ON="fail"
TELEGRAM_TOKEN="123456:ABC-DEF"
TELEGRAM_CHAT_ID="987654321"
```

### Configuración Avanzada (Con S3)

```env
# .env
# MongoDB
MONGO_URI="mongodb+srv://backup-user:password@cluster.mongodb.net/"
MONGO_DBS="webapp,api,logs,analytics"

# Backups
BACKUP_PREFIX="backup"
RETENTION_DAYS=7
CRON_SCHEDULE="0 2 * * *"

# S3
S3_UPLOAD=true
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=secreto...
AWS_DEFAULT_REGION=us-east-1
S3_BUCKET=empresa-backups
S3_PREFIX=mongodb/production/
S3_STORAGE_CLASS=STANDARD_IA
KEEP_LOCAL_BACKUP=false

# Notificaciones
NOTIFY_ON=both
TELEGRAM_TOKEN="123456:ABC-DEF"
TELEGRAM_CHAT_ID="987654321"

# Configuración adicional
TZ="America/Argentina/Buenos_Aires"
```

### Configuración para Desarrollo

```env
# .env
MONGO_URI="mongodb+srv://dev-user:password@dev-cluster.mongodb.net/"
MONGO_DB="webapp-dev"
RETENTION_DAYS=3
# Sin CRON_SCHEDULE para ejecución manual
NOTIFY_ON="both"
S3_UPLOAD=false
```

## 🔄 Restauración (MANUAL - Solo cuando lo necesites)

> ⚠️ **IMPORTANTE**: El script `restore.sh` NO se ejecuta automáticamente. Solo lo usas manualmente cuando necesites restaurar datos.

### ¿Cuándo usar restore.sh?

- 🆘 **Recuperación ante desastres** (corrupción de datos, errores)
- 🧪 **Testing seguro** (copiar prod → prepro para pruebas)
- 🔄 **Rollback** tras un deploy problemático
- 📋 **Migración de datos** entre entornos

### En el Servidor Docker

- ✅ Solo se ejecuta `backup.sh` automáticamente (vía cron)
- ✅ `restore.sh` está disponible para emergencias
- ❌ Nunca se ejecuta automáticamente

### Uso Típico en Local

```bash
# 1. Descargar backup del servidor
scp server:/backups/backup_prod_20250915_120000.archive.gz .

# 2. Restaurar prod a prepro local (SEGURO)
MONGODB_URI="mongodb://localhost:27017" ./restore.sh backup_prod_20250915_120000.archive.gz prepro prod

# 3. Restaurar backup completo
MONGODB_URI="..." ./restore.sh backup_all_20250915_120000.archive.gz
```

### Casos de Uso Comunes

```bash
# Copiar prod a prepro (testing seguro)
./restore.sh backup_prod_20250915_120000.archive.gz prepro prod

# Rollback a estado anterior
./restore.sh backup_prod_20250914_120000.archive.gz prod prod

# Restaurar BD específica
./restore.sh backup_test_20250915_120000.archive.gz test test
```

### Características de Seguridad

- 🛡️ **Validación previa**: Verifica que el archivo sea válido
- 💾 **Backup automático**: Crea copia de seguridad antes de sobrescribir
- 🔄 **Rollback automático**: Restaura estado anterior si falla
- ⚠️ **Confirmaciones**: Pide confirmación para operaciones peligrosas

## 🔧 Archivos Generados

### Estructura de Backups

```
/backups/
├── logs/
│   ├── backup_20250915_120000.log
│   └── backup_20250915_140000.log
├── backup_prod_20250915_120000.archive.gz
├── backup_prepro_20250915_120000.archive.gz
└── backup_all_20250915_140000.archive.gz
```

### Formato de Archivos

✅ **Siempre válidos**: `backup_[db]_YYYYMMDD_HHMMSS.archive.gz`  
✅ **Compatibles**: `mongorestore --archive --gzip`  
✅ **Verificados**: Validación automática post-backup  

### Logs Estructurados

```
[2025-09-15 12:00:01] [INFO] === Iniciando backup MongoDB ===
[2025-09-15 12:00:01] [INFO] URI: mongodb+srv://***@cluster.mongodb.net/**
[2025-09-15 12:00:01] [INFO] BDs específicas: prod,prepro
[2025-09-15 12:00:05] [INFO] Backup exitoso: prod
[2025-09-15 12:00:10] [INFO] Validación OK: backup_prod_20250915_120000.archive.gz
[2025-09-15 12:00:15] [INFO] === Resumen final ===
[2025-09-15 12:00:15] [INFO] Exitosos: 2
```

## 🚀 ¡Ya está listo para usar!

Tu sistema de backup MongoDB Atlas está optimizado con:

- **Archivos siempre válidos** (no más errores de gzip)
- **Restauración segura** incluida
- **Logs claros** para debugging
- **Variables simplificadas** para configuración fácil
- **S3 opcional** con aws cli estándar