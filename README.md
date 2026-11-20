# travel-booking-management-system — BTL2 Hệ CSDL, Nhóm 5

Hệ thống quản lý đặt phòng du lịch (tham khảo Booking.com), tiếp nối lược đồ BTL1.

- **DBMS:** MS SQL Server (T-SQL)
- **Database:** `BTL2_Booking_Nhom5`
- **Số bảng:** 36
- **Ứng dụng:** Flask 3 + `pymssql` (`app/`)
- **Repo:** `travel-booking-management-system` (theo quy ước tại `docs/de-bai/BTL2 - Phân công công việc.md`, mục 4)

## Trạng thái các đầu việc

| Việc | Nội dung | File | Người | Trạng thái |
| --- | --- | --- | --- | --- |
| 1 | DDL toàn bộ bảng + ràng buộc (1.1) | `sql/01_schema.sql` | Đỗ Lê Chí Kiên | ✅ Đã tích hợp |
| 1 | Dữ liệu mẫu ≥ 5 dòng/bảng (1.2) | `sql/02_seed.sql` | Lê Thế Nguyên | ✅ Đã tích hợp |
| 2 | 3 thủ tục CRUD trên `BOOKING` (2.1) | `sql/03_crud.sql` | Phạm Nhật Quang | ✅ Đã tích hợp — 16/16 test PASS |
| 3 | Trigger ràng buộc nghiệp vụ (2.2.1) | `sql/04_trigger_rangbuoc.sql` | Lê Thế Nguyên | ✅ Đã tích hợp — 11/11 test PASS |
| 4 | Trigger thuộc tính dẫn xuất (2.2.2) | `sql/05_trigger_danxuat.sql` | Nguyễn Trương Đăng Quang | ✅ Đã tích hợp — 13/13 test PASS |
| 5 | 2 thủ tục truy vấn (2.3) | `sql/06_query_procs.sql` | Đỗ Lê Chí Kiên | ✅ Đã tích hợp — 3/3 test tự động PASS |
| 6 | 2 hàm (2.4) | `sql/07_functions.sql` | Phan Anh Khoa | ✅ Đã tích hợp — 14/14 test PASS |
| 7 | 3 màn hình ứng dụng (3.1–3.3) | `app/` + `sql/08_app_login.sql` | Quang, Khoa, Quang | ✅ Đã tích hợp — 39/39 test PASS |

> Trigger 2.2.1 đặt trên `BOOKING_ROOM_TYPE` (không phải `BOOKING`), kiểm tra sức chứa theo **hạng phòng + khoảng ngày**, nên không còn chặn nhầm đơn khác hạng và không phá `SCOPE_IDENTITY()` của `sp_Booking_Insert`. Issue #1 đã được xử lý.

## Cấu trúc thư mục

```text
travel-booking-management-system/
├─ README.md
├─ sql/                       # Script chạy trên SQL Server, theo đúng thứ tự số
│  ├─ 01_schema.sql           # Tạo DB + 36 bảng + PK/FK/UNIQUE/CHECK/DEFAULT
│  ├─ 02_seed.sql             # Dữ liệu mẫu toàn bộ 36 bảng
│  ├─ 03_crud.sql             # sp_Booking_Insert / Update / Delete (+ ValidateStay)
│  ├─ 04_trigger_rangbuoc.sql # trg_BookingRoomType_NoOverlap (sức chứa hạng phòng)
│  ├─ 05_trigger_danxuat.sql  # OVERALL_SCORE, AVERAGE_RATING, REVIEW_COUNT
│  ├─ 06_query_procs.sql      # sp_Booking_List, sp_Revenue_By_Accommodation
│  ├─ 07_functions.sql        # fn_GuestTier, fn_CancelRefund
│  └─ 08_app_login.sql        # Tài khoản btl2_app: chỉ SELECT + EXECUTE
├─ tests/                     # Script kiểm tra, tự rollback dữ liệu test
│  ├─ 01_schema_check.sql
│  ├─ 02_test_constraints.sql
│  ├─ 2.1-testcases.sql / .md
│  ├─ 05_trigger_danxuat-testcases.sql
│  ├─ 06_query_procs_testcases.sql
│  └─ 07_functions_testcases.sql
├─ app/                       # Ứng dụng Flask 3 màn hình (xem app/README.md)
│  ├─ app.py
│  ├─ templates/              # base, form, list, dashboard
│  ├─ test_app.py             # Test tích hợp trên DB thật (39 ca)
│  ├─ requirements.txt
│  └─ .env.example
├─ evidence/                  # Ảnh minh chứng gốc, đã đổi tên theo đầu việc
├─ docs/
│  ├─ ghi-chu-*.txt           # Ghi chú từng phần
│  └─ de-bai/                 # Đề bài, kế hoạch, phân công
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
7. `sql/04_trigger_rangbuoc.sql` — trigger chặn đặt vượt số phòng của hạng phòng; cuối file có 11 ca test tự dọn dữ liệu
8. `sql/05_trigger_danxuat.sql` — bổ sung cột dẫn xuất, backfill và tạo 3 trigger
9. `tests/05_trigger_danxuat-testcases.sql` — cần 13/13 `PASS`; test tự rollback
10. `sql/06_query_procs.sql`
11. `tests/06_query_procs_testcases.sql` — xem các bảng kết quả; phần tự động cần 3/3 `PASS`
12. `sql/07_functions.sql`
13. `tests/07_functions_testcases.sql` — cần 14/14 `PASS`; test tự rollback
14. `sql/08_app_login.sql` — tạo tài khoản `btl2_app` cho ứng dụng

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

### Cách 3 — chạy ứng dụng

```powershell
cd app
py -3.12 -m venv .venv
.venv\Scripts\pip install -r requirements.txt
copy .env.example .env
.venv\Scripts\python app.py
```

Mở <http://localhost:5000>. Chi tiết cấu hình và các giới hạn xem `app/README.md`.

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

## Trigger ràng buộc sức chứa (2.2.1)

`sql/04_trigger_rangbuoc.sql` tạo `trg_BookingRoomType_NoOverlap` — `AFTER INSERT, UPDATE, DELETE` trên `BOOKING_ROOM_TYPE`:

- Mỗi hạng phòng `(ACCOMMODATION_ID, ROOM_NAME)` không được bán vượt số phòng trong `ROOM` có `AVAILABILITY_STATUS <> 'MAINTENANCE'`.
- Chỉ cộng các đơn `STATUS <> 'CANCELLED'` có khoảng `[CHECK_IN_DATE, CHECK_OUT_DATE)` giao nhau; giáp ngày (`check_out` cũ = `check_in` mới) được phép.
- `INSERT`/`UPDATE` vượt sức chứa bị chặn bằng `THROW 52001`, kèm hạng phòng, sức chứa, số phòng đã giữ và `BOOKING_ID` xung đột.
- `DELETE` chỉ giải phóng chỗ nên không cần chặn.

Vì sao đặt trên bảng con: lúc `INSERT BOOKING`, dòng `BOOKING_ROOM_TYPE` chưa tồn tại nên trigger trên `BOOKING` không biết hạng phòng và số lượng. Dùng `AFTER` (không `INSTEAD OF`) để `SCOPE_IDENTITY()` trong `sp_Booking_Insert` vẫn trả đúng `BOOKING_ID` — đây chính là lỗi tích hợp của bản cũ (issue #1). `sp_Booking_Update` cập nhật `BOOKING` trước rồi mới cập nhật `BOOKING_ROOM_TYPE`, để trigger đọc đúng khoảng ngày cuối cùng.

Lưu ý: `UPDATE BOOKING` trực tiếp để đổi ngày (không qua thủ tục 2.1) không đi qua trigger này; đường ghi chuẩn của app luôn qua 2.1 và được `sp_Booking_ValidateStay` kiểm tra.

## Thuộc tính dẫn xuất (2.2.2)

`sql/05_trigger_danxuat.sql` bổ sung migration (không sửa `01_schema.sql` của việc 1.1):

| Cột | Công thức | Bảng nguồn |
| --- | --- | --- |
| `REVIEW.OVERALL_SCORE` | trung bình 6 điểm thành phần, thang 1–10 | `REVIEW` |
| `ACCOMMODATION.AVERAGE_RATING` | trung bình `REVIEW.OVERALL_SCORE` của cơ sở | `REVIEW` → `BOOKING` |
| `ACCOMMODATION.REVIEW_COUNT` | số review của cơ sở | `REVIEW` → `BOOKING` |

- `AVERAGE_RATING` dùng `OVERALL_SCORE`, nên trigger tính `OVERALL_SCORE` được đặt chạy **First**, trigger tính rating cơ sở chạy **Last** trên `REVIEW`.
- Trigger đọc lại dữ liệu gốc từ bảng, không lấy giá trị có sẵn trên dòng `inserted`.
- Xử lý đủ INSERT/UPDATE/DELETE `REVIEW`, đổi `REVIEW.BOOKING_ID`, và đổi `BOOKING.ACCOMMODATION_ID`.
- File chạy lại được: cột/ràng buộc có kiểm tra tồn tại, trigger drop rồi tạo lại, dữ liệu cũ được backfill.

## Hai thủ tục truy vấn (2.3)

`sql/06_query_procs.sql` chỉ đọc dữ liệu, không thay đổi bảng.

| Thủ tục | Tham số | Kết quả |
| --- | --- | --- |
| `sp_Booking_List` | `@p_keyword`, `@p_status`, `@p_from`, `@p_to`, `@p_sort` | Mỗi booking một dòng: khách, cơ sở, hạng phòng, số đêm, số phòng, `TOTAL_AMOUNT` (đã trừ voucher) |
| `sp_Revenue_By_Accommodation` | `@p_city`, `@p_from`, `@p_to`, `@p_min_revenue` | Doanh thu `PAID` theo cơ sở + loại tiền: tổng, số booking, trung bình mỗi khoản |

- `sp_Booking_List`: tìm theo tên khách / hạng phòng / cơ sở / mã đơn; lọc ngày nhận phòng (gồm hai đầu mút); sort `check_in`, `total_amount`, `guest_name`; giá trị sort khác dùng `check_in`.
- `sp_Revenue_By_Accommodation`: chỉ tính `PAYMENT_STATUS = 'PAID'`, lọc theo `PAYMENT_DATE`, gom theo cơ sở và `CURRENCY`, `HAVING` lọc doanh thu tối thiểu.
- Khoảng ngày bị ngược trả kết quả rỗng (không báo lỗi).

## Hai hàm (2.4)

| Hàm | Tham số | Kết quả |
| --- | --- | --- |
| `fn_GuestTier` | `user_id`, `year` | `BRONZE` (< 5 triệu), `SILVER` (≥ 5 triệu), `GOLD` (≥ 20 triệu), `PLATINUM` (≥ 50 triệu) |
| `fn_CancelRefund` | `booking_id` | Hoàn 100% nếu còn ≥ 7 ngày, 50% nếu còn 3–6 ngày, 0% nếu dưới 3 ngày |

- `fn_GuestTier` cộng tiền các booking `COMPLETED` theo năm trả phòng, đã trừ voucher tiền mặt.
- `fn_CancelRefund` tính trên tổng các khoản `PAID`; trả `NULL` với tham số/đối tượng không hợp lệ hoặc booking `COMPLETED`, trả `0` với booking chưa thanh toán.
- SQL Server UDF không hỗ trợ `THROW`, nên hàm dùng `NULL`/`0` thay cho lỗi.

## Ứng dụng 3 màn hình (3.x)

| Màn hình | Route | Gọi |
| --- | --- | --- |
| 3.1 Form thêm | `/bookings/new` | `sp_Booking_Insert` |
| 3.1 Form sửa + xóa | `/bookings/<id>/edit`, `POST /bookings/<id>/delete` | `sp_Booking_Update`, `sp_Booking_Delete` |
| 3.2 Danh sách | `/bookings` | `sp_Booking_List` |
| 3.3 Dashboard | `/dashboard` | `sp_Revenue_By_Accommodation`, `fn_GuestTier` |

App **không có** câu INSERT/UPDATE/DELETE trực tiếp; tài khoản `btl2_app` chỉ được `SELECT` + `EXECUTE`, nên mọi thay đổi bắt buộc đi qua thủ tục. Chi tiết xem `app/README.md`.

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
| `04_trigger_rangbuoc.sql` | ✅ 11/11 test tự động PASS, `sp_Booking_Insert` vẫn tạo được đơn |
| `05_trigger_danxuat.sql` + `05_trigger_danxuat-testcases.sql` | ✅ 13/13 PASS, kể cả khi đã cài `04` |
| `06_query_procs.sql` + `06_query_procs_testcases.sql` | ✅ 14 truy vấn mẫu + 3/3 ca tự động PASS |
| `07_functions.sql` + `07_functions_testcases.sql` | ✅ 14/14 PASS |
| `app/test_app.py` | ✅ 39/39 PASS |

## Giới hạn đã biết

- `sp_Booking_List` chưa phân trang; app phân trang trên toàn bộ kết quả.
- `fn_GuestTier`, `fn_CancelRefund` dùng `CURSOR` để cộng tiền — đủ đúng cho đồ án, chưa tối ưu cho dữ liệu lớn.
- App demo chạy localhost, chưa có đăng nhập và CSRF token.
- Trigger 2.2.1 bám vào `BOOKING_ROOM_TYPE`; đổi ngày bằng `UPDATE BOOKING` trực tiếp (ngoài thủ tục 2.1) không được kiểm tra lại.

## Theo dõi lỗi

Lỗi tích hợp và việc cần chốt được theo dõi tại [Issues](https://github.com/quangnguyen0101/travel-booking-management-system/issues).

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
