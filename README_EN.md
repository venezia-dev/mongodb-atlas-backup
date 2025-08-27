# MongoDB Atlas Backup Tool 🗄️

**🇺🇸 English | [🇪🇸 Español](README.md)**

Automated backup system for MongoDB Atlas using Docker. Supports multiple databases, automatic AWS S3 upload, Telegram notifications, and CRON scheduling.

## 🚀 Features

- ✅ **Automatic backups** with `mongodump` and gzip compression
- ✅ **Multiple modes**: Single DB, multiple DBs, or entire cluster
- ✅ **S3 Storage**: Automatic upload with multipart for large files
- ✅ **Automatic retention**: Delete old backups by days
- ✅ **Telegram notifications**: Success or failure alerts
- ✅ **Flexible scheduling**: One-time execution or CRON scheduling
- ✅ **Health checks**: Service status monitoring
- ✅ **Dockerized**: Easy deployment with docker-compose

## 🛠️ Prerequisites

- **Docker** and **docker-compose** installed
- **MongoDB Atlas** with read-only user (recommended)
- **AWS S3** (optional for cloud storage)
- **Telegram Bot** (optional for notifications)

## 📦 Quick Installation

### 1. Clone the repository

```bash
git clone https://github.com/your-username/mongodb-atlas-backup.git
cd mongodb-atlas-backup
```

### 2. Configure environment variables

```bash
cp .env.example .env
```

Edit the `.env` file with your configurations:

```env
# MongoDB Atlas Connection
MONGO_URI="mongodb+srv://USER:PASS@cluster.mongodb.net/?retryWrites=true&w=majority"

# Databases to backup (comma-separated)
MONGO_DBS="webapp,api,logs,analytics"

# Backup settings
RETENTION_DAYS=14
CRON_SCHEDULE="0 3 * * *"  # Daily at 3 AM

# Telegram notifications (optional)
NOTIFY_ON="fail"
TELEGRAM_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_chat_id"

# AWS S3 (optional)
S3_UPLOAD=true
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=your_secret_key
S3_BUCKET=my-backup-bucket
```

### 3. Build and run

```bash
# Build the image
docker-compose build

# Run in background
docker-compose up -d

# View logs in real-time
docker-compose logs -f
```

## 🔧 Detailed Configuration

### Main Environment Variables

| Variable | Description | Example | Required |
|----------|-------------|---------|----------|
| `MONGO_URI` | MongoDB Atlas connection URI | `mongodb+srv://user:pass@cluster.mongodb.net/` | ✅ |
| `MONGO_DBS` | Multiple databases (comma-separated) | `webapp,api,logs` | ⚠️ |
| `MONGO_DB` | Single database | `webapp` | ⚠️ |
| `RETENTION_DAYS` | Local backup retention days | `14` | ✅ |
| `CRON_SCHEDULE` | CRON schedule (empty = single execution) | `0 3 * * *` | ❌ |

⚠️ **Note**: You must configure `MONGO_DBS` OR `MONGO_DB` OR neither (for all DBs).

### AWS S3 Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `S3_UPLOAD` | Enable S3 upload | `false` |
| `AWS_ACCESS_KEY_ID` | AWS access key | - |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | - |
| `AWS_DEFAULT_REGION` | AWS region | `us-east-1` |
| `S3_BUCKET` | S3 bucket name | - |
| `S3_PREFIX` | S3 folder prefix | `mongodb-backups/` |
| `S3_STORAGE_CLASS` | Storage class | `STANDARD` |
| `MULTIPART_THRESHOLD` | Multipart upload threshold | `100MB` |
| `KEEP_LOCAL_BACKUP` | Keep local copy after S3 upload | `true` |

### Telegram Notifications

1. **Create a bot**:
   - Talk to [@BotFather](https://t.me/botfather)
   - Run `/newbot` and follow instructions
   - Save the `TELEGRAM_TOKEN`

2. **Get your Chat ID**:
   - Talk to [@userinfobot](https://t.me/userinfobot)
   - It will give you your `TELEGRAM_CHAT_ID`

3. **Configure in .env**:
```env
NOTIFY_ON=both           # fail, success, both
TELEGRAM_TOKEN=123456789:ABCdefGhIjKlMnOpQrStUvWxYz
TELEGRAM_CHAT_ID=987654321
```

## 📋 Operation Modes

### 1. Multiple Databases (Recommended)

```env
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/
MONGO_DBS=webapp,api,logs,analytics
```

**Result**: Generates one file per DB:
- `backup_webapp_20240824_030000.gz`
- `backup_api_20240824_030000.gz`
- `backup_logs_20240824_030000.gz`
- `backup_analytics_20240824_030000.gz`

### 2. Single Database

```env
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/
MONGO_DB=webapp
```

**Result**: `backup_webapp_20240824_030000.gz`

### 3. All Databases in Cluster

```env
MONGO_URI=mongodb+srv://user:pass@cluster.mongodb.net/
# Without MONGO_DB or MONGO_DBS
```

**Result**: `backup_all_20240824_030000.gz`

## ☁️ AWS S3 Storage

### Basic Configuration

```env
S3_UPLOAD=true
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=secret...
AWS_DEFAULT_REGION=us-east-1
S3_BUCKET=my-backup-bucket
S3_PREFIX=mongodb-backups/
```

### S3 Folder Structure

With current configuration, files are organized by date:

```
s3://my-backup-bucket/mongodb-backups/
├── 2024-08-24/
│   ├── backup_webapp_20240824_030000.gz
│   ├── backup_api_20240824_030000.gz
│   └── backup_logs_20240824_030000.gz
├── 2024-08-25/
│   └── backup_webapp_20240825_030000.gz
└── 2024-08-26/
    └── backup_all_20240826_030000.gz
```

### Advanced S3 Features

- **Smart uploads**: Files <100MB upload directly, >100MB use multipart upload
- **Integrity verification**: Automatic MD5 checksums
- **Automatic retries**: Network failure recovery
- **Storage classes**: `STANDARD`, `STANDARD_IA`, `GLACIER`

### S3 Lifecycle Policy (Retention)

Create a `lifecycle.json` file:

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

Apply with AWS CLI:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket my-backup-bucket \
  --lifecycle-configuration file://lifecycle.json
```

## ⏰ CRON Scheduling

### CRON Schedule Examples

| Expression | Description |
|------------|-------------|
| `0 3 * * *` | Daily at 3:00 AM |
| `0 2 * * 0` | Sundays at 2:00 AM |
| `30 1 1 * *` | First day of month at 1:30 AM |
| `0 */6 * * *` | Every 6 hours |
| `0 0 * * 1-5` | Monday to Friday at midnight |

### Single Execution (No CRON)

Leave `CRON_SCHEDULE` empty for one-time execution:

```env
# CRON_SCHEDULE=  # Commented or empty
```

## 📊 Monitoring and Logs

### View real-time logs

```bash
docker-compose logs -f backup
```

### Health Check

The container includes a health endpoint:

```bash
# Check status
docker exec mongodb-atlas-backup-backup-1 /app/healthcheck.sh
echo $?  # 0 = OK, 1 = ERROR
```

### Status Files

- `/app/last_success.txt`: Last successful backup timestamp
- `/var/log/backup.log`: Complete operations log

## 🚨 Error Management

### Failure Notifications

The system automatically notifies via Telegram when:

- ❌ MongoDB connection fails
- ❌ mongodump error
- ❌ S3 upload fails
- ❌ Backup process error

### Failure Recovery

- **Partial failures**: If one DB fails, continue with next ones
- **S3 retries**: Automatic retries with exponential backoff
- **Detailed logs**: Complete information for debugging

## 🛡️ Security Best Practices

### MongoDB User

Create a read-only user for backups:

```javascript
// In MongoDB Atlas
db.createUser({
  user: "backup-user",
  pwd: "secure-password",
  roles: [
    { role: "read", db: "webapp" },
    { role: "read", db: "api" },
    { role: "read", db: "logs" }
  ]
});
```

### AWS IAM Policy

Minimal S3 policy:

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
            "Resource": "arn:aws:s3:::my-backup-bucket/*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::my-backup-bucket"
        }
    ]
}
```

### Sensitive Variables

- ❌ **Never** commit credentials to repository
- ✅ Use local `.env` files
- ✅ In production, consider AWS Secrets Manager
- ✅ Rotate credentials regularly

## 🔄 Useful Commands

### docker-compose

```bash
# Build image
docker-compose build

# Run in background
docker-compose up -d

# Stop service
docker-compose down

# View logs
docker-compose logs -f

# Restart service
docker-compose restart

# Run backup manually
docker-compose exec backup /app/backup.sh
```

### Backup Management

```bash
# List local backups
ls -la ./backups/

# Check backup sizes
du -sh ./backups/*

# Clean old backups manually
find ./backups -name "backup_*.gz" -mtime +30 -delete
```

## 📈 Optimization and Performance

### Docker Resources

Resources are limited by default:

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

Adjust according to your workload in `docker-compose.yml`.

### Performance Tips

- **Scheduling**: Schedule backups during low activity hours
- **Compression**: .gz files save ~70% space
- **S3 Multipart**: Improves speed for files >100MB
- **Retention**: Keep only necessary backups

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/new-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 🆘 Support and Issues

If you encounter problems or have questions:

1. Check [existing Issues](https://github.com/your-username/mongodb-atlas-backup/issues)
2. Create a new Issue with problem details
3. Include relevant logs and configuration (without credentials)

---

## 📚 Complete Configuration Examples

### Basic Configuration (Local Only)

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

### Advanced Configuration (With S3)

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
AWS_SECRET_ACCESS_KEY=secret...
AWS_DEFAULT_REGION=us-east-1
S3_BUCKET=company-backups
S3_PREFIX=mongodb/production/
S3_STORAGE_CLASS=STANDARD_IA
KEEP_LOCAL_BACKUP=false

# Notifications
NOTIFY_ON=both
TELEGRAM_TOKEN="123456:ABC-DEF"
TELEGRAM_CHAT_ID="987654321"

# Additional settings
TZ="America/New_York"
```

### Development Configuration

```env
# .env
MONGO_URI="mongodb+srv://dev-user:password@dev-cluster.mongodb.net/"
MONGO_DB="webapp-dev"
RETENTION_DAYS=3
# No CRON_SCHEDULE for manual execution
NOTIFY_ON="both"
S3_UPLOAD=false
```

Ready to use! 🚀