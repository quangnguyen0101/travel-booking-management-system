# BTL2 — Phân công & mô tả công việc

> Đề tài: **Hệ thống quản lý đặt phòng du lịch (tham khảo booking.com)** — tiếp nối BTL1.
> Đọc [[BTL2 - Kế hoạch thực hiện]] trước khi nhận việc. Deadline nội bộ **22/11/2025**; **nộp nhóm qua group Zalo**, nhóm trưởng nộp LMS **CN 23/11/2025** (đã chốt).
> **Trạng thái: ĐÃ VOTE.** DBMS đã chốt: **MS SQL Server**; stack app do 3 người việc 7 chốt.
> **⚠️ Luật của đề:** **mỗi SV phải viết ít nhất 1 câu ở phần 2** (trigger/thủ tục/hàm). Vì vậy mỗi người đã nhận đúng 1 việc trong nhóm 2–6; việc app/báo cáo chỉ là việc phụ.

## 1. Bảng phân công (đã chốt)

> Nguyên tắc xếp hạn: việc sau chờ việc trước (DDL → SQL → app → báo cáo). Trong cùng một chặng thì chạy song song, nhưng **không ai sửa file của người khác** — chỉ review chéo.
>
> **Kết quả vote:** mỗi người nhận **1 đầu việc phần 2 + 1 việc phụ**; 5/5 thành viên đều có mặt ở nhóm 2–6.

| # | Việc | Người | Hạn | Phần 2? | ☐ |
| --- | --- | --- | --- | --- | --- |
| 1 | DDL bảng + seed ≥ 5 rows/bảng (1.1 + 1.2) — **việc phụ, 2 người** | Đỗ Lê Chí Kiên, Lê Thế Nguyên | 13/11 | Không | ☐ |
| 2 | 3 thủ tục CRUD trên BOOKING (2.1) | Phạm Nhật Quang | 15/11 | ✅ | ☐ |
| 3 | Trigger ràng buộc nghiệp vụ (2.2.1) — chọn ràng buộc | Lê Thế Nguyên | 15/11 | ✅ | ☐ |
| 4 | Trigger thuộc tính dẫn xuất (2.2.2) — chọn thuộc tính | Nguyễn Trương Đăng Quang | 16/11 | ✅ | ☐ |
| 5 | 2 thủ tục truy vấn (2.3) | Đỗ Lê Chí Kiên | 16/11 | ✅ | ☐ |
| 6 | 2 hàm (2.4) | Phan Anh Khoa | 16/11 | ✅ | ☐ |
| 7 | 3 màn hình ứng dụng (3.1–3.3) — **việc phụ, 3 người** | Nguyễn Trương Đăng Quang, Phan Anh Khoa, Phạm Nhật Quang | 20/11 | Đã có việc 2–6 | ☐ |
| 8 | Báo cáo + demo + nộp (Zalo → LMS) | Cả nhóm | 22/11 | — | ☐ |

**Tóm tắt:** 5/5 thành viên có **1 đầu việc phần 2 + 1 việc phụ**:

- **Lê Thế Nguyên** — việc 3 + việc 1
- **Đỗ Lê Chí Kiên** — việc 5 + việc 1
- **Phạm Nhật Quang** — việc 2 + việc 7
- **Phan Anh Khoa** — việc 6 + việc 7
- **Nguyễn Trương Đăng Quang** — việc 4 + việc 7

## 2. Timeline tổng (13 ngày: 10/11–22/11)

| Ngày | Việc | Mốc kiểm tra |
| --- | --- | --- |
| 10/11 | Kickoff: chốt stack app (DBMS đã chốt MS SQL Server), tạo repo, chốt tên proc/trigger/hàm, chốt phân công | Biên bản + repo |
| 11–12/11 | V1 DDL (2 người: schema 11/11, seed bắt đầu 12/11); cả nhóm viết test case + wireframe 3 màn hình | DDL chạy được |
| 13/11 | V1 seed + review; **M1: DB sạch, ≥ 5 rows/bảng** | Review chéo V1 |
| 13–15/11 | V2 CRUD, V3 trigger ràng buộc, V4 trigger dẫn xuất (bắt đầu) | Proc/trigger chạy |
| 15–16/11 | V4 hoàn tất, V5 query proc, V6 hàm; **M2: xong phần 2** | Test case pass; bản sơ bộ |
| 15–19/11 | V7 app (3 người): form → list → dashboard | Kết nối DB thật |
| 20/11 | **M3: demo 3 màn hình** | Cả nhóm chạy thử |
| 20–21/11 | V8 báo cáo, ảnh, slide, video dự phòng | Bản nháp đủ mục |
| 22/11 | **M4: gửi group Zalo + bản in; nhóm trưởng nộp LMS** | File + link trong Zalo |
| 23/11 | **Hạn nộp LMS (đã chốt)** | — |

> Mốc **M2 (16/11)** là bản sơ bộ để nộp/báo cáo ở buổi thực hành thứ 5; nếu buổi 5 rơi vào ngày khác thì lùi mốc cho khớp lịch lớp.

## 3. Chi tiết từng việc

> Mọi mục "Nộp" bên dưới đều hiểu là **gửi file/link vào group Zalo của nhóm** (trừ bản in); nhóm trưởng tổng hợp nộp LMS.

### Việc 1 — DDL + dữ liệu mẫu → đáp ứng 1.1 + 1.2 (3đ)

- **Số người: 2** — **Đỗ Lê Chí Kiên** làm schema/constraints (1.1), **Lê Thế Nguyên** làm seed + test + review (1.2). Schema phải chốt **11/11** để người seed bắt đầu.
- **Làm gì:** Từ lược đồ BTL1, viết `sql/01_schema.sql` gồm `CREATE DATABASE`, toàn bộ 15+ bảng, PK/FK/UNIQUE/CHECK/DEFAULT. Viết `sql/02_seed.sql` với ≥ 5 hàng/bảng.
- **Ràng buộc:** `CHECK (base_price > 0)`, `CHECK (check_out > check_in)`, `CHECK (rating BETWEEN 1 AND 5)`, `CHECK (num_guests > 0)`, `status` dùng `CHECK` constraint; các ràng buộc liên bảng (trùng lịch, tổng tiền) để trigger — **không viết trigger cho thứ CHECK làm được**.
- **Dữ liệu mẫu:** 5+ khách, 5+ host, 5+ chỗ nghỉ (nhiều thành phố), 10+ phòng, booking đủ trạng thái `PENDING/CONFIRMED/CHECKED_IN/COMPLETED/CANCELLED`, payment `PENDING/PAID/REFUNDED/FAILED`, review 1–5 sao. Seed theo thứ tự bảng cha → con.
- **Test:** Chạy từ DB trống; `SELECT COUNT(*)` từng bảng ≥ 5; thử insert vi phạm CHECK để thấy DB chặn.
- **Nộp:** `01_schema.sql`, `02_seed.sql`, `BTL2-01-DDL-<tên>.md` (danh sách bảng + ràng buộc + ảnh kết quả).
- **Hạn:** 13/11. **DoD:** người khác clone repo chạy 2 script là có DB đầy đủ, không lỗi.

### Việc 2 — 3 thủ tục CRUD trên BOOKING → đáp ứng 2.1 (1đ)

- **Làm gì:** Viết `sql/03_crud.sql` gồm `sp_Booking_Insert`, `sp_Booking_Update`, `sp_Booking_Delete`.
- **Validate khi thêm:** guest tồn tại + đang active; room tồn tại + `Available`; `check_in >= CAST(GETDATE() AS DATE)`; `check_out > check_in`; số đêm ≤ 30; `1 <= num_guests <= room.capacity`; mã khuyến mãi còn hạn; không trùng lịch. Mỗi lỗi `THROW` một message riêng, nêu rõ trường nào sai.
- **Validate khi sửa:** chỉ booking `PENDING` được đổi phòng/ngày; luồng trạng thái `PENDING → CONFIRMED → CHECKED_IN → COMPLETED`; cấm sửa `COMPLETED/CANCELLED`; booking đã có payment `PAID` thì không đổi phòng/ngày nếu chưa hoàn tiền.
- **Quy tắc xóa:** chỉ xóa booking `PENDING` (đơn nháp) hoặc `CANCELLED` chưa có payment `PAID`; **cấm xóa** `CONFIRMED/CHECKED_IN/COMPLETED` hoặc đã thanh toán. Mục đích: dọn đơn rác, giữ lịch sử giao dịch. Xóa con (`BOOKING_SERVICE`, `BOOKING_PROMOTION`) trong transaction trước khi xóa booking.
- **Test:** 10 case (hợp lệ, ngày sai, quá sức chứa, trùng lịch, sửa booking completed, xóa booking đã trả tiền...), lưu output.
- **Nộp:** `03_crud.sql` + `tests/2.1-testcases.md`.
- **Hạn:** 15/11.

### Việc 3 — Trigger ràng buộc nghiệp vụ → đáp ứng 2.2.1 (0.5đ)

- **Ràng buộc đề xuất:** một phòng không được có 2 booking “đang hiệu lực” trùng khoảng `[check_in, check_out)`. Có thể đổi sang ràng buộc khác nếu cần trigger hơn — miễn nêu được DML ảnh hưởng và lý do không dùng CHECK.
- **DML ảnh hưởng:** `INSERT BOOKING`; `UPDATE BOOKING` khi đổi `room_id`, `check_in`, `check_out`, `status`.
- **Trigger:** `trg_Booking_NoOverlap` `INSTEAD OF INSERT/UPDATE` trên `BOOKING`; kiểm tra các booking cùng phòng có status `PENDING/CONFIRMED/CHECKED_IN` và `inserted.check_in < old.check_out AND inserted.check_out > old.check_in`; nếu trùng thì `THROW` kèm `booking_id` xung đột.
- **Test:** chồng lấn 1 ngày (lỗi), giáp ngày `check_out = check_in` (không lỗi), khác phòng (không lỗi), booking `CANCELLED` không tính.
- **Nộp:** `04_trigger_rangbuoc.sql` + test log.
- **Hạn:** 15/11.

### Việc 4 — Trigger thuộc tính dẫn xuất → đáp ứng 2.2.2 (0.5đ)

- **Thuộc tính đề xuất:** `BOOKING.total_amount` = số đêm × `ROOM.base_price` + tổng dịch vụ − giảm giá. Có thể đổi sang thuộc tính khác (vd `ACCOMMODATION.avg_rating`, `USER.total_spent`) nếu hợp nghiệp vụ hơn.
- **DML ảnh hưởng:** INSERT/UPDATE `BOOKING` (ngày, phòng); UPDATE `ROOM.base_price`; INSERT/UPDATE/DELETE `BOOKING_SERVICE`; INSERT/DELETE `BOOKING_PROMOTION`.
- **Cách làm (nếu chọn `total_amount`):** dùng `INSTEAD OF INSERT/UPDATE` trên `BOOKING` để gán `total_amount` phần gốc; trigger `AFTER` trên `ROOM`, `BOOKING_SERVICE`, `BOOKING_PROMOTION` gọi hàm `fn_CalcBookingTotal(booking_id)` rồi `UPDATE BOOKING`. Kiểm soát `RECURSIVE_TRIGGERS` để tránh đệ quy.
- **Bonus nếu kịp:** `ACCOMMODATION.avg_rating`, `review_count` tính từ `REVIEW` (trigger AFTER INSERT/UPDATE/DELETE).
- **Test:** thêm dịch vụ → tổng tăng; đổi giá phòng → tổng cập nhật; áp mã %/số tiền → giảm đúng; xóa dịch vụ → tổng giảm.
- **Nộp:** `05_trigger_danxuat.sql` + test log.
- **Hạn:** 16/11.

### Việc 5 — 2 thủ tục truy vấn → đáp ứng 2.3 (1đ)

- **Proc 1:** `sp_Booking_List(p_keyword, p_status, p_from, p_to, p_sort)` — join `BOOKING`, `USERS` (guest), `ROOM`, `ACCOMMODATION`; WHERE optional theo tên khách/phòng/trạng thái/khoảng ngày; ORDER BY whitelist (`check_in`, `total_amount`, `guest_name`) để tránh injection.
- **Proc 2:** `sp_Revenue_By_Accommodation(p_city, p_from, p_to, p_min_revenue)` — join `PAYMENT`, `BOOKING`, `ROOM`, `ACCOMMODATION`; `SUM(amount)`, `COUNT(booking)`, `AVG(amount)`; `WHERE status='PAID'` + khoảng ngày; `GROUP BY` chỗ nghỉ; `HAVING SUM(...) >= p_min`; `ORDER BY` doanh thu giảm dần.
- **Test:** gọi với tham số NULL (không lọc), có lọc, không có kết quả; lưu output.
- **Nộp:** `06_query_procs.sql` + test log.
- **Hạn:** 16/11.

### Việc 6 — 2 hàm → đáp ứng 2.4 (1đ)

- **`fn_GuestTier(p_user_id, p_year)`:** validate user tồn tại + là `GUEST`; mở con trỏ các booking `COMPLETED` trong năm; LOOP cộng `total_amount`; IF phân hạng `PLATINUM ≥ 50tr`, `GOLD ≥ 20tr`, `SILVER ≥ 5tr`, còn lại `BRONZE`; RETURN varchar.
- **`fn_CancelRefund(p_booking_id)`:** validate booking tồn tại + chưa `COMPLETED`; lấy payment `PAID`; IF còn ≥ 7 ngày trước `check_in` → hoàn 100%, 3–6 ngày → 50%, < 3 ngày → 0%; RETURN số tiền.
- **Lưu ý:** hàm chỉ trả 1 giá trị; app gọi `SELECT fn_...(...)`, không dùng hàm để trả result set.
- **Test:** user không tồn tại, năm không có booking, booking chưa thanh toán, các mốc hoàn tiền.
- **Nộp:** `07_functions.sql` + test log.
- **Hạn:** 16/11.

### Việc 7 — 3 màn hình ứng dụng → đáp ứng 3.1–3.3 (3đ)

- **Số người: 3** — **Nguyễn Trương Đăng Quang, Phan Anh Khoa, Phạm Nhật Quang**. Cả 3 đều đã có đầu việc phần 2. **Cách chia vai trò (backend / UI / integration-test) chưa chốt — 3 bạn tự thống nhất ở kickoff.**
- **3.1 Form booking:** `/bookings/new`, `/bookings/<id>/edit`, nút xóa — gọi 3 proc ở việc 2; validate client + hiển thị message từ `THROW`; không tự viết INSERT/UPDATE/DELETE trong app.
- **3.2 Danh sách booking:** `/bookings` — gọi `sp_Booking_List`; ô search (khách/phòng), filter trạng thái, khoảng ngày, sort, phân trang; sửa/xóa ngay trên dòng; báo lỗi logic rõ ràng.
- **3.3 Dashboard:** `/dashboard` — gọi `sp_Revenue_By_Accommodation` + `fn_GuestTier`; bảng doanh thu + biểu đồ (thư viện tùy stack) + tra cứu hạng khách.
- **Stack:** **chưa chốt** — người nhận việc 7 đề xuất (gợi ý: Flask/Bootstrap, Node/Express, PHP...), cả nhóm chốt ở kickoff. Yêu cầu cố định: kết nối CSDL thật; CRUD gọi proc; cấu hình DB trong `.env`; README hướng dẫn chạy; tài khoản DB riêng, không dùng root.
- **Phối hợp:** 3 người tự chia việc theo 3 nhóm gợi ý (backend route + gọi proc / UI template / integration + test lỗi), chốt cùng stack ở kickoff. Không cố định ai làm nhóm nào trước khi họp.
- **Nộp:** source app + `README.md` + ảnh 3 màn hình.
- **Hạn:** 20/11. **DoD:** chạy app theo README, thêm → sửa → xóa → tìm → xem dashboard đều hoạt động trên DB thật.

### Việc 8 — Báo cáo + demo + nộp (chung)

- **Báo cáo theo mẫu BTL2:** 1) Tạo bảng & dữ liệu (DDL, ảnh, số rows); 2) Trigger/thủ tục/hàm (nêu ràng buộc, DML ảnh hưởng, code, kết quả test); 3) Ứng dụng (ảnh 3 màn hình, luồng gọi proc); phụ lục phân công + test case.
- **Slide 10–12 trang** + **video demo 3–5 phút** (dự phòng khi demo trực tiếp lỗi).
- **Nộp:** PDF + script SQL + source + link demo vào **group Zalo của nhóm**; nhóm trưởng tổng hợp nộp LMS; in quyển theo yêu cầu.
- **Hạn:** 22/11. **DoD:** mở PDF đủ mục, link demo chạy được, cả nhóm trả lời được câu hỏi chéo.

## 4. Quy tắc làm việc + nộp bài

- **Repo Git:** `btl2-hcsdl`; nhánh `feat/<việc>-<tên>`; commit message `[2.1] validate trùng lịch`; merge qua PR, 1 người review.
- **Không sửa file người khác** khi chưa báo; mọi thay đổi schema phải thông báo nhóm chat vì ảnh hưởng cả nhóm.
- **File naming:** `BTL2-<số việc>-<nội dung>-<tên>.<ext>`; SQL đặt trong `sql/`, test trong `tests/`, app trong `app/`.
- **Nộp:** gửi file/link vào **group Zalo của nhóm** (ghim tin nhắn); nhóm trưởng tổng hợp nộp LMS. Bản sơ bộ gửi Zalo trước buổi thực hành 5.
- **Trễ hạn:** báo trước ≥ 1 ngày trên nhóm chat + đề xuất hạn mới; không im lặng.

## 5. Checklist trước demo

- [ ] Giải thích được **tại sao** ràng buộc này dùng CHECK, ràng buộc kia dùng TRIGGER.
- [ ] Giải thích được luồng validate và từng message lỗi của 3 proc CRUD.
- [ ] Chạy được test case của **2 người khác** (không chỉ phần mình).
- [ ] Biết màn hình nào gọi proc/hàm nào, tham số lấy từ đâu.
- [ ] Biết app hiển thị lỗi `THROW` thế nào và cách sửa dữ liệu để chạy lại.
- [ ] Có ảnh chụp + video demo dự phòng.

## 6. Lịch check

| Buổi | Thời gian | Nội dung |
| --- | --- | --- |
| Kickoff | 10/11 | Chốt stack, repo, tên đối tượng, nhận việc |
| Standup online | 15 phút mỗi tối 12–21/11 | Mỗi người báo: xong gì, vướng gì, cần ai |
| Review chéo 1 | 16/11 | Chạy toàn bộ phần 2, sửa lỗi chéo |
| Review chéo 2 | 20/11 | Demo 3 màn hình, sửa lỗi tích hợp |
| Tổng duyệt | 22/11 | Đóng gói báo cáo, gửi group Zalo, nhóm trưởng nộp LMS, tập trả lời câu hỏi |
