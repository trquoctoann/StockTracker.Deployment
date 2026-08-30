# Mốc nền tảng dữ liệu

## Mục tiêu

Mốc này biến DataCollector từ một scheduler chạy trong bộ nhớ thành pipeline có trạng thái bền vững, có thể truy vết và khôi phục. API vẫn sở hữu dữ liệu nghiệp vụ; collector sở hữu schema PostgreSQL `collector` cho metadata điều phối.

## Luồng chạy

1. Scheduler hoặc endpoint `/run/*` tạo một `run_id`.
2. Collector giữ khóa cục bộ và PostgreSQL advisory lock theo tên pipeline. Hai instance không thể chạy cùng pipeline đồng thời.
3. Run được ghi vào `collector.pipeline_runs`; heartbeat được cập nhật trong lúc chạy.
4. Mỗi đơn vị công việc được ghi vào `collector.pipeline_steps` với trạng thái `running`, `completed`, `failed` hoặc `skipped`.
5. Phản hồi vnstock hợp lệ được đóng gói cùng nguồn, tham số, schema version và run id; dữ liệu được nén gzip và đưa vào S3/S3Mock. SHA-256 và object key được ghi ở `collector.raw_objects`.
6. Sau khi sink xác nhận thành công, collector cập nhật watermark theo pipeline, stream và partition. Cursor có `state=data|empty`; nếu nguồn hoặc sink lỗi thì watermark cũ được giữ nguyên.
7. Run kết thúc ở `completed`, `failed` hoặc `cancelled`. Run mất heartbeat được đánh dấu `abandoned` khi service khởi động lại.

## Resume và replay

Gửi body sau tới endpoint của cùng pipeline:

```json
{"resume_from": "00000000-0000-0000-0000-000000000000"}
```

Collector đọc các step `completed` của run cha. Run mới ghi các step đó là `skipped`, rồi chỉ chạy phần còn thiếu. Raw object có thể được nạp qua `RawArchive.load(key, expected_checksum=...)`; checksum được xác minh trước khi payload JSON, pandas Series hoặc DataFrame được khôi phục cho một replay job.

## RabbitMQ và quan sát

Lỗi tạm thời được publish sang queue `<queue>.retry.<delay-ms>.<n>` có TTL `API_RABBITMQ_RETRY_DELAY_MS`. RabbitMQ dead-letter message về routing key gốc sau TTL; khi quá `API_RABBITMQ_MAX_RETRIES`, message đi vào `<queue>.dead`.

Prometheus thu thập số run theo trạng thái, thời gian chạy và thời điểm thành công gần nhất. Alertmanager nhận cảnh báo target down, queue backlog, DLQ có message, pipeline lỗi và pipeline không thành công quá 26 giờ. Receiver mặc định chỉ giữ cảnh báo trong giao diện local; staging/production cần thêm email, Slack, PagerDuty hoặc webhook phù hợp.

## Kiểm tra nhanh

```powershell
docker compose config
docker compose up -d --wait postgres rabbitmq s3mock alertmanager prometheus
docker compose run --rm --no-deps datacollector alembic upgrade head
docker compose up -d --wait api api-worker datacollector
```

Kiểm tra schema bằng `SELECT * FROM collector.pipeline_runs ORDER BY submitted_at DESC;`, raw object ở S3Mock port `9092`, Prometheus port `9091` và Alertmanager port `9093`.

## Ranh giới hiện tại

- S3Mock chỉ dùng cho local lab; staging/production phải dùng object storage bền vững, encryption, lifecycle và versioning.
- Resume dựa trên step thành công. Sink phải tiếp tục duy trì idempotency vì process có thể dừng sau khi sink commit nhưng trước khi step được đánh dấu hoàn tất.
- APScheduler vẫn nằm trong service. Advisory lock bảo vệ chạy trùng, nhưng lịch chạy bền vững và catch-up policy nên chuyển sang EventBridge, Kubernetes CronJob hoặc một orchestrator ở mốc triển khai tiếp theo.
