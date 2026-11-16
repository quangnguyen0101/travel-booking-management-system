# btl2-hcsdl — BTL2 Hệ CSDL, Nhóm 5

Hệ thống quản lý đặt phòng du lịch (tham khảo Booking.com), tiếp nối lược đồ BTL1.

- **DBMS:** MS SQL Server (T-SQL)
- **Database:** `BTL2_Booking_Nhom5`
- **Số bảng:** 36
- **Repo:** `btl2-hcsdl` (theo quy ước tại `docs/de-bai/BTL2 - Phân công công việc.md`, mục 4)

## Trạng thái các đầu việc

| Việc | Nội dung | File | Người | Trạng thái |
| --- | --- | --- | --- | --- |
| 1 | DDL toàn bộ bảng + ràng buộc (1.1) | `sql/01_schema.sql` | Đỗ Lê Chí Kiên | ✅ Đã tích hợp |
| 1 | Dữ liệu mẫu ≥ 5 dòng/bảng (1.2) | `sql/02_seed.sql` | Lê Thế Nguyên | ✅ Đã tích hợp |
| 2 | 3 thủ tục CRUD trên `BOOKING` (2.1) | `sql/03_crud.sql` | Phạm Nhật Quang | ✅ Đã tích hợp |
| 3 | Trigger ràng buộc nghiệp vụ (2.2.1) | `sql/04_trigger_rangbuoc.sql` | Lê Thế Nguyên | ⚠️ Có, nhưng **xung đột tích hợp** — xem [issue #1](https://github.com/quangnguyen0101/btl2-hcsdl/issues/1) |
| 4 | Trigger thuộc tính dẫn xuất (2.2.2) | `sql/05_trigger_danxuat.sql` | Nguyễn Trương Đăng Quang | ⬜ Chưa nộp |
| 5 | 2 thủ tục truy vấn (2.3) | `sql/06_query_procs.sql` | Đỗ Lê Chí Kiên | ⬜ Chưa nộp |
| 6 | 2 hàm (2.4) | `sql/07_functions.sql` | Phan Anh Khoa | ⬜ Chưa nộp |
| 7 | 3 màn hình ứng dụng (3.1–3.3) | `app/` | Quang, Khoa, Quang | ⬜ Chưa nộp |

> Tên file 05–07 là **chỗ giữ chỗ theo kế hoạch**, chưa có nội dung. Khi nhận bài, đặt đúng tên này để giữ thứ tự chạy.

## Cấu trúc thư mục

```text
btl2-hcsdl/
├─ README.md
├─ sql/                  # Script chạy trên SQL Server, theo đúng thứ tự số
│  ├─ 01_schema.sql      # Tạo DB + 36 bảng + PK/FK/UNIQUE/CHECK/DEFAULT
│  ├─ 02_seed.sql        # Dữ liệu mẫu toàn bộ 36 bảng
│  ├─ 03_crud.sql        # sp_Booking_Insert / Update / Delete (+ ValidateStay)
│  └─ 04_trigger_rangbuoc.sql
├─ tests/                # Script kiểm tra, chỉ đọc hoặc tự dọn dữ liệu test
│  ├─ 01_schema_check.sql
│  ├─ 02_test_constraints.sql
│  ├─ 2.1-testcases.sql
│  └─ 2.1-testcases.md
├─ evidence/             # Ảnh minh chứng gốc, đã đổi tên theo đầu việc
├─ docs/
│  ├─ ghi-chu-1.1-1.2.txt
│  ├─ ghi-chu-2.1.txt
│  └─ de-bai/            # Đề bài, kế hoạch, phân công
└─ app/                  # (chưa có) ứng dụng 3 màn hình
```

## Cách chạy

### Cách 1 — SSMS

Mở lần lượt từng file bằng **File → Open**, bấm F5 theo đúng thứ tự:

1. `sql/01_schema.sql`
2. `tests/01_schema_check.sql` — kiểm tra đủ 36 bảng, đủ PK, không có FK/CHECK bị tắt
3. `sql/02_seed.sql`
4. `tests/02_test_constraints.sql` — thử dữ liệu vi phạm CHECK/FK/UNIQUE
5. `sql/03_crud.sql`
6. `tests/2.1-testcases.sql` — xem kết quả ở tab **Messages**, cần 16/16 `[PASS]`
7. `sql/04_trigger_rangbuoc.sql` — **chỉ chạy sau khi xử lý [issue #1](https://github.com/quangnguyen0101/btl2-hcsdl/issues/1)**

`01_schema.sql` và `02_seed.sql` đều có chốt an toàn: nếu database đã có bảng/dữ liệu thì dừng, không ghi đè.

### Cách 2 — sqlcmd (Docker/CI)

```bash
docker run -d --name btl2-mssql \
  -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='Btl2@Nhom5!2026' \
  -p 14333:1433 mcr.microsoft.com/mssql/server:2025-latest

SQLCMD="/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P Btl2@Nhom5!2026 -C -I -f 65001"
docker exec btl2-mssql bash -lc "$SQLCMD -i /tmp/repo/sql/01_schema.sql"
# ... lặp lại theo thứ tự trên
```

- `-I`: bật `QUOTED_IDENTIFIER` (bắt buộc với filtered index/trigger).
- `-f 65001`: đọc file UTF-8, giữ đúng tiếng Việt.

### Tạo lại DB từ đầu

```sql
USE master;
ALTER DATABASE BTL2_Booking_Nhom5 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE BTL2_Booking_Nhom5;
```

## Quy ước dữ liệu

| Cột | Giá trị hợp lệ |
| --- | --- |
| `BOOKING.STATUS` | `PENDING`, `CONFIRMED`, `COMPLETED`, `CANCELLED` |
| `PAYMENT.PAYMENT_STATUS` | `PENDING`, `PAID`, `FAILED`, `REFUNDED` |
| `PAYMENT.PAYMENT_METHOD` | `CARD`, `AT_PROPERTY` |
| `ROOM.AVAILABILITY_STATUS` | `AVAILABLE`, `BOOKED`, `MAINTENANCE` |
| `VOUCHER.STATUS` | `ACTIVE`, `EXPIRED`, `USED` |
| `CANCELLATION.REFUND_STATUS` | `PENDING`, `COMPLETED`, `FAILED`, `NOT_REQUIRED` |
| `GUEST.GENDER` | `MALE`, `FEMALE`, `OTHER` (được NULL) |

Đơn đặt phòng gắn với **hạng phòng** (`BOOKING_ROOM_TYPE.ROOM_NAME` + `RESERVED_QUANTITY`), chưa gán số phòng thực tế.

## Mã lỗi của thủ tục 2.1

| Khoảng mã | Nhóm |
| --- | --- |
| `511xx` | Kiểm tra dùng chung khi thêm/sửa (`sp_Booking_ValidateStay`) |
| `5112x` | Thêm (`sp_Booking_Insert`) |
| `512xx` | Sửa (`sp_Booking_Update`) |
| `513xx` | Xóa (`sp_Booking_Delete`) |

Thông báo lỗi bắt đầu bằng tên trường bị sai, ví dụ `CHECK_IN_DATE: ...`.

## Kết quả chạy thử của repo này

Chạy trên SQL Server 2025 (`mcr.microsoft.com/mssql/server:2025-latest`) trong Docker, DB tạo mới hoàn toàn:

| Bước | Kết quả |
| --- | --- |
| `01_schema.sql` | ✅ 36 bảng |
| `01_schema_check.sql` | ✅ Đủ PK, không có FK/CHECK bị tắt |
| `02_seed.sql` | ✅ 36/36 bảng có dữ liệu |
| `02_test_constraints.sql` | ✅ 10/10 ca vi phạm bị chặn |
| `03_crud.sql` | ✅ Tạo 4 thủ tục |
| `2.1-testcases.sql` | ✅ 16/16 PASS |
| `04_trigger_rangbuoc.sql` | ✅ 5/5 test riêng PASS, nhưng ⚠️ làm hỏng `sp_Booking_Insert` — xem [issue #1](https://github.com/quangnguyen0101/btl2-hcsdl/issues/1) |

## Theo dõi lỗi

Lỗi tích hợp và việc cần chốt được theo dõi tại [Issues](https://github.com/quangnguyen0101/btl2-hcsdl/issues).

## Phân công

Theo `docs/de-bai/BTL2 - Phân công công việc.md`:

- **Lê Thế Nguyên** — việc 3 (trigger ràng buộc) + việc 1 (seed/test/review)
- **Đỗ Lê Chí Kiên** — việc 5 (2 thủ tục truy vấn) + việc 1 (schema/constraints)
- **Phạm Nhật Quang** — việc 2 (CRUD) + việc 7 (app)
- **Phan Anh Khoa** — việc 6 (2 hàm) + việc 7 (app)
- **Nguyễn Trương Đăng Quang** — việc 4 (trigger dẫn xuất) + việc 7 (app)

## Quy ước Git

- Nhánh: `feat/<việc>-<tên>`; commit: `[2.1] validate trùng lịch`.
- Merge qua PR, 1 người review.
- Không sửa file của người khác khi chưa báo — mọi thay đổi schema phải thông báo nhóm.
