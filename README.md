# StockTracker Deployment

## Local lab

1. Sao chép `.env.example` thành `.env` và thay toàn bộ giá trị `CHANGE_ME_*`. Hai client secret phải khớp với realm import cho lần khởi tạo lab đầu tiên.
2. Chạy `docker compose -f docker-compose.yml config` để kiểm tra cấu hình.
3. Chạy migration: `docker compose -f docker-compose.yml run --rm api alembic upgrade head`.
4. Khởi động stack: `docker compose -f docker-compose.yml up -d --wait`.

API chạy HTTP riêng; `api-worker` nhận RabbitMQ message. Grafana có Loki và Prometheus được provision sẵn. Các cổng chỉ bind vào loopback.

## Jenkins lab

`docker compose -f docker-compose.jenkins.yml up -d --build` tạo Jenkins non-root bằng JCasC và một Docker-in-Docker daemon riêng. Tạo các Jenkins credentials: `git-credentials`, `dockerhub-credentials` và secret file `stocktracker-staging-env`. Staging deploy dùng image tag `<branch>-<build number>` và không nạp `docker-compose.override.yml`.

## Backup

Khởi động logical backup bằng profile: `docker compose -f docker-compose.yml --profile backup up -d postgres-backup`. Mỗi file được `pg_restore --list` xác minh và giữ theo `POSTGRES_BACKUP_RETENTION_DAYS`. Restore là thao tác phá hủy; chạy `scripts/postgres/restore.sh` trong container PostgreSQL phù hợp và đặt `RESTORE_CONFIRM` bằng đúng tên database.

Logical dump không thay thế PITR. Production cần WAL archive/object storage, mã hóa, cảnh báo backup trễ và restore drill định kỳ.

## Production boundaries

Compose này phục vụ học tập và staging một host. Production cần TLS ingress, secret manager, Keycloak hostname cố định, backup ngoài host, object storage cho Loki, image digest/signing và distributed scheduler/lock nếu scale DataCollector.
