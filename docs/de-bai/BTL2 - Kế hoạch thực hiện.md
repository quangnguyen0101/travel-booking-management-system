# BTL2 — Kế hoạch thực hiện

> **Nguồn yêu cầu:** [[Mô tả BTL2.pdf]] (cùng folder). BTL2 nối tiếp BTL1 — dùng đúng lược đồ đã thiết kế và ánh xạ ở [[BTL1 - Kế hoạch thực hiện]].
> **Nhóm 5 người.** **DBMS đã chốt: MS SQL Server.** **Stack ứng dụng (phần 3) chưa chốt** — 3 người nhận việc 7 (Nguyễn Trương Đăng Quang, Phan Anh Khoa, Phạm Nhật Quang) sẽ đề xuất và chốt. Kế hoạch dùng cú pháp T-SQL.
> **Deadline LMS:** CN **23/11/2025** — **đã chốt**. Mốc nội bộ: gửi group Zalo xong **22/11**, nộp LMS **23/11**; không có tuần đệm.
> **Nộp nhóm:** mọi sản phẩm gửi vào **group Zalo của nhóm**; nhóm trưởng tổng hợp và nộp LMS theo đề.

## 0. Phạm vi & các điểm chờ chốt

| Hạng mục | Chốt / trạng thái |
| --- | --- |
| Đề tài | Hệ thống quản lý đặt phòng du lịch (tham khảo booking.com) — tiếp nối BTL1 |
| CSDL | Đủ **toàn bộ bảng** đã ánh xạ ở BTL1 (≥ 15 bảng); không lược bớt để đủ điểm 1.1 |
| Bảng trọng tâm | **BOOKING** — dùng cho thủ tục 2.1, thủ tục 2.3 và cả 3 màn hình; trigger có thể chạm bảng liên quan |
| Ràng buộc | CHECK cho ràng buộc kiểm tra được trong 1 bảng; TRIGGER chỉ cho ràng buộc liên bảng/liên thời điểm |
| **DBMS** | **Đã chốt:** MS SQL Server — dùng T-SQL (`THROW`, trigger `INSTEAD OF`/`AFTER`, `CHECK` constraint) |
| **Ứng dụng** | **Chưa chốt stack** (Flask/Bootstrap chỉ là gợi ý). Chốt yêu cầu: web/app kết nối CSDL thật; CRUD **gọi thủ tục**, không viết SQL trực tiếp trong app. Người nhận việc 7 đề xuất stack, cả nhóm chốt |

Danh sách bảng dự kiến (theo lược đồ BTL1): `USERS`, `GUEST`, `HOST`, `ADMIN`, `ACCOMMODATION`, `HOTEL`, `HOMESTAY`, `ROOM`, `AMENITY`, `ROOM_AMENITY`, `ROOM_PHOTO`, `BOOKING`, `SERVICE`, `BOOKING_SERVICE`, `PAYMENT`, `PROMOTION`, `BOOKING_PROMOTION`, `REVIEW`, `MESSAGE`, `CANCELLATION`.

> **DBMS đã chốt: MS SQL Server.** Cả nhóm dùng chung một instance/DB; cú pháp T-SQL thống nhất (`THROW`, `INSTEAD OF`/`AFTER` trigger, `CHECK` constraint).

## 1. Checklist chấm điểm

### Phần 1 — Bảng & dữ liệu mẫu (3đ)

- [ ] **1.1 (2đ)** Viết DDL đủ bảng, đúng kiểu dữ liệu; có PK, FK, UNIQUE, CHECK, DEFAULT, ON DELETE/UPDATE.
- [ ] Ràng buộc ngữ nghĩa BTL1: cái nào CHECK được thì dùng CHECK (`giá > 0`, `check_out > check_in`, `rating 1..5`, `status` enum, email/phone format...), **không dùng trigger**.
- [ ] **1.2 (1đ)** Seed ≥ **5 hàng/bảng**, dữ liệu có nghĩa (khách Việt, chỗ nghỉ ở TP.HCM/Đà Nẵng/Hà Nội...), phủ đủ trạng thái booking/payment/review.
- [ ] Script chạy sạch từ DB trống; có phần `DROP`/`RESET` an toàn.

### Phần 2 — Trigger, thủ tục, hàm (4đ)

- [ ] **2.1 (1đ)** 3 thủ tục INSERT/UPDATE/DELETE trên `BOOKING`; validate từng trường, báo lỗi cụ thể bằng `THROW`; nêu rõ **khi nào được xóa / không được xóa** và mục đích của thủ tục xóa.
- [ ] **2.2.1 (0.5đ)** Trigger ràng buộc nghiệp vụ: **chọn 1 ràng buộc cần trigger** (đề xuất: chống đặt trùng khoảng thời gian trên cùng một phòng); xác định DML ảnh hưởng (INSERT/UPDATE); viết trigger `INSTEAD OF INSERT/UPDATE` trên `BOOKING`.
- [ ] **2.2.2 (0.5đ)** Trigger thuộc tính dẫn xuất: **chọn 1 thuộc tính dẫn xuất** (đề xuất: `BOOKING.total_amount` = số đêm × giá phòng + dịch vụ − khuyến mãi); xác định đủ DML của bảng nguồn tương ứng (nếu chọn `total_amount`: BOOKING, `ROOM.base_price`, `BOOKING_SERVICE`, `BOOKING_PROMOTION`); tính từ dữ liệu gốc, không giả sử đã có sẵn.
- [ ] **2.3 (1đ)** 2 thủ tục chỉ chứa truy vấn: 1 proc lọc danh sách booking (≥ 2 bảng, WHERE, ORDER BY); 1 proc doanh thu (aggregate, GROUP BY, HAVING, WHERE, ORDER BY, ≥ 2 bảng). Ít nhất 1 proc đụng `BOOKING`.
- [ ] **2.4 (1đ)** 2 hàm: có IF/LOOP, **con trỏ**, truy vấn dữ liệu, tham số đầu vào + validate; trả về 1 giá trị.
- [ ] **⚠️ Điều kiện sống còn:** **mỗi SV viết ít nhất 1 câu ở phần 2** và hiểu toàn bộ phần 2 để trả lời khi demo.

### Phần 3 — Ứng dụng (3đ)

- [ ] **3.1 (1đ)** Màn hình thêm/sửa/xóa booking — gọi 3 proc ở 2.1; validate 2 lớp (client + proc); hiện đúng thông báo lỗi từ `THROW`.
- [ ] **3.2 (1đ)** Màn hình danh sách booking — gọi `sp_Booking_List`; tìm kiếm theo khách/phòng/trạng thái/khoảng ngày; sắp xếp; sửa/xóa ngay trên danh sách; phân trang; báo lỗi logic.
- [ ] **3.3 (1đ)** Màn hình dashboard — gọi `sp_Revenue_By_Accommodation` + `fn_GuestTier`; bảng + biểu đồ.
- [ ] **Bắt buộc:** app kết nối đúng CSDL đã chốt, dùng tài khoản DB riêng, không hard-code SQL CRUD trong app.

## 2. Hợp đồng kỹ thuật (để 5 người code khớp nhau)

> Đây là **thiết kế kỹ thuật đề xuất**, không phải phân công. Tên đối tượng và **nội dung trigger** (ràng buộc nào, thuộc tính dẫn xuất nào) có thể đổi khi người nhận việc chốt, miễn giữ đúng chức năng.

| Câu | Đối tượng | Tên chốt | Input → Output |
| --- | --- | --- | --- |
| 2.1 | Proc thêm | `sp_Booking_Insert` | guest_id, room_id, check_in, check_out, num_guests, promo_code → `new_booking_id` |
| 2.1 | Proc sửa | `sp_Booking_Update` | booking_id, room_id, check_in, check_out, num_guests, status → thông báo |
| 2.1 | Proc xóa | `sp_Booking_Delete` | booking_id → thông báo |
| 2.2.1 | Trigger | `trg_Booking_NoOverlap` (đề xuất) | INSTEAD OF INSERT/UPDATE trên `BOOKING` |
| 2.2.2 | Trigger | `trg_Booking_TotalAmount` (đề xuất) + trigger phụ trên `ROOM`, `BOOKING_SERVICE`, `BOOKING_PROMOTION` | đồng bộ lại khi dữ liệu nguồn INSERT/UPDATE/DELETE |
| 2.3 | Proc danh sách | `sp_Booking_List` | keyword, status, from_date, to_date, sort → result set |
| 2.3 | Proc doanh thu | `sp_Revenue_By_Accommodation` | city, from_date, to_date, min_revenue → result set |
| 2.4 | Hàm hạng khách | `fn_GuestTier` | user_id, year → `BRONZE/SILVER/GOLD/PLATINUM` |
| 2.4 | Hàm hoàn tiền | `fn_CancelRefund` | booking_id → số tiền hoàn |
| 3.x | App | `booking_form`, `booking_list`, `dashboard` | route app gọi đúng proc/hàm |

**Quy ước chung:** tên bảng snake_case; PK `<bảng>_id`; FK dùng cùng tên cột; status dùng `CHECK` constraint; mọi proc/hàm/trigger nằm trong `sql/`, có comment mục đích; báo lỗi bằng `THROW` với message rõ ràng.

> **Lưu ý kỹ thuật SQL Server:** ưu tiên `INSTEAD OF INSERT/UPDATE` cho ràng buộc trên `BOOKING`; với `total_amount` có thể dùng `INSTEAD OF` để gán cột, trigger `AFTER` trên bảng con (`ROOM`, `BOOKING_SERVICE`, `BOOKING_PROMOTION`) cập nhật `BOOKING`. Kiểm soát `RECURSIVE_TRIGGERS` để tránh đệ quy; không giả sử cột dẫn xuất đã có sẵn.

## 3. Timeline 4 chặng (10/11 → 23/11)

| Chặng | Thời gian | Việc | Xong khi (mốc) |
| --- | --- | --- | --- |
| **1. Nền CSDL** | 10–13/11 | Chốt lược đồ BTL1; **chốt stack app** (DBMS đã chốt MS SQL Server); **Đỗ Lê Chí Kiên + Lê Thế Nguyên** viết DDL 15+ bảng + CHECK/FK và seed ≥ 5 hàng/bảng; tạo repo | **13/11:** DB chạy sạch từ script, đếm đủ rows |
| **2. SQL logic** | 13–16/11 | 3 proc CRUD; 2 trigger; 2 proc truy vấn; 2 hàm; bộ test case | **16/11:** toàn bộ phần 2 chạy + test pass; có bản sơ bộ cho buổi thực hành 5 |
| **3. Ứng dụng** | 15–20/11 | **3 người** làm 3 màn hình app (stack chốt ở kickoff), kết nối CSDL, gọi proc, validate + báo lỗi | **20/11:** demo được luồng thêm → sửa → xóa → tìm → xem doanh thu |
| **4. Báo cáo & nộp** | 20–22/11 | Ảnh demo, quyển báo cáo theo mẫu, slide, video dự phòng, gửi group Zalo | **22/11:** PDF + script + link demo đã gửi Zalo; nhóm trưởng nộp LMS trước 23/11 |

> **Mốc chết:** 13/11 (DDL), 16/11 (SQL), 20/11 (app), 22/11 (gửi Zalo), **23/11 (nộp LMS)**. Không có tuần đệm — trễ là mất điểm.

## 4. Danh sách công việc & phân bổ (đã chốt)

> **Nguyên tắc:** mỗi người nhận **đúng 1 việc trong nhóm 2–6** (đầu việc phần 2 bắt buộc, vì đề yêu cầu **mỗi SV viết ≥ 1 câu ở phần 2**) + **1 việc phụ** (việc 1 hoặc 7). Không ai chỉ làm app/báo cáo.

1. **[DDL + SEED — việc phụ, 2 người] Toàn bộ bảng & dữ liệu mẫu (1.1 + 1.2 — 3đ).** **Đỗ Lê Chí Kiên** (schema/constraints) + **Lê Thế Nguyên** (seed/test/review). Viết `01_schema.sql`, `02_seed.sql`; kiểm tra đủ bảng/ràng buộc/rows. *Giao: 2 file SQL + log chạy.*
2. **[CRUD] 3 thủ tục thêm/sửa/xóa BOOKING (2.1 — 1đ).** **Phạm Nhật Quang**. Validate chi tiết, quy tắc xóa, test 10 case. *Giao: `03_crud.sql` + test log.*
3. **[TRIGGER RB] Trigger ràng buộc nghiệp vụ (2.2.1 — 0.5đ) — chọn ràng buộc.** **Lê Thế Nguyên**. Đề xuất: chống trùng lịch. Nêu ràng buộc, DML ảnh hưởng, trigger + test. *Giao: `04_trigger_rangbuoc.sql`.*
4. **[TRIGGER DX] Trigger thuộc tính dẫn xuất (2.2.2 — 0.5đ) — chọn thuộc tính.** **Nguyễn Trương Đăng Quang**. Đề xuất: `total_amount`. Tính từ dữ liệu gốc; xử lý đủ DML. *Giao: `05_trigger_danxuat.sql`.*
5. **[QUERY PROC] 2 thủ tục truy vấn (2.3 — 1đ).** **Đỗ Lê Chí Kiên**. Danh sách booking + doanh thu; tham số WHERE/HAVING. *Giao: `06_query_procs.sql`.*
6. **[FUNCTION] 2 hàm (2.4 — 1đ).** **Phan Anh Khoa**. `fn_GuestTier`, `fn_CancelRefund`; IF/LOOP + con trỏ + validate. *Giao: `07_functions.sql`.*
7. **[APP — việc phụ, 3 người] 3 màn hình (3.1–3.3 — 3đ).** **Nguyễn Trương Đăng Quang + Phan Anh Khoa + Phạm Nhật Quang**. Form CRUD, danh sách, dashboard; gọi proc/hàm; validate + báo lỗi. Stack và cách chia vai trò do 3 người này tự chốt. *Giao: source + README chạy.*
8. **[CHUNG] Báo cáo + demo + nộp.** Cả nhóm; nhóm trưởng tổng hợp.

### So sánh 2 việc phụ & cơ sở chọn số người

| Tiêu chí | Việc 1 — DDL + seed (3đ) | Việc 7 — App 3 màn hình (3đ) |
| --- | --- | --- |
| Đầu ra | 15+ bảng, ~50 ràng buộc, ≥ 100 dòng seed | 3 màn hình, gọi 3 proc CRUD + 2 proc query + 2 hàm |
| Ước lượng | **22–28 giờ công** (~2,5–3,5 người-ngày) | **32–40 giờ công** (~4–5 người-ngày) |
| Tính chất | Tuần tự; schema là nguồn sự thật, seed phụ thuộc schema | Song song theo màn hình; tích hợp cuối là điểm nghẽn |
| Kỹ năng | SQL DDL, CHECK/FK, đọc lược đồ BTL1 | Backend + frontend + driver CSDL + UX |
| Rủi ro chính | Schema trễ → block toàn bộ phần 2 | Tích hợp trễ → mất 3đ phần app |
| Cách chia | 1 người schema / 1 người seed + test | **Đề xuất:** 1 backend / 1 UI / 1 integration + test (3 bạn tự chốt) |
| **Số người** | **2** | **3** |

> Tỷ lệ khối lượng ~**1 : 1,5** → chia **2 : 3** là cân bằng. Nếu chỉ 1 người làm DDL, người đó vừa ôm 22–28 giờ vừa làm đầu việc phần 2 dễ quá tải và thành điểm nghẽn; nếu 4 người làm app thì chồng chéo, lợi ích tăng không đáng kể.

## 5. Rủi ro & phương án

| Rủi ro | Ảnh hưởng | Phương án |
| --- | --- | --- |
| Hàm không được trả result set (SQL Server) | 2.4 làm sai | Hàm chỉ `RETURN` scalar; app gọi `SELECT dbo.fn_...(...)` |
| Trigger đệ quy trên SQL Server | 2.2.2 | Ưu tiên `INSTEAD OF` cho `BOOKING`; trigger bảng con `AFTER` cập nhật `BOOKING`; kiểm soát `RECURSIVE_TRIGGERS` |
| Seed vi phạm FK | 1.2 chạy lỗi | Seed theo thứ tự cha → con; dùng transaction; nếu cần thì tạm tắt kiểm tra FK (nhớ bật lại) |
| File gửi Zalo bị trôi/hết hạn | mất file, thành viên không thấy | Ghim tin nhắn trong group; lưu bản local + Git; nhóm trưởng giữ bản gốc |
| App không kịp | mất 3đ | Chốt MVP 3 màn hình, dùng template UI có sẵn, không làm đăng nhập phức tạp |
| DDL trễ → block toàn bộ phần 2 | 2.x và app trễ dây chuyền | **2 người** làm DDL; chốt schema 11/11, seed + test 12–13/11 |
| Deadline 23/11 sát | trễ nộp | Mốc nội bộ 22/11; không có tuần đệm, ai trễ phải báo ngay để chia lại việc |

## 6. Nộp bài

- Nộp **PDF báo cáo + toàn bộ script SQL + source app + link demo** vào **group Zalo của nhóm**; ghim tin nhắn để không trôi.
- Đặt tên theo quy ước `BTL2-<số việc>-<nội dung>-<tên>.<ext>`.
- **Nhóm trưởng** tổng hợp, kiểm tra đủ file rồi nộp LMS trước **CN 23/11/2025** (đã chốt). Bản sơ bộ gửi Zalo trước buổi thực hành 5.
- Trễ hạn báo trước ≥ 1 ngày trên nhóm chat + đề xuất hạn mới.
