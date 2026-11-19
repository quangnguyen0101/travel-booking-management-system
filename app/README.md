# Ứng dụng 3 màn hình (Việc 7, đáp ứng 3.1–3.3)

Web app quản lý booking chạy trên CSDL thật `BTL2_Booking_Nhom5` (MS SQL Server).

- **Stack:** Python 3.12, Flask 3, Jinja + Bootstrap 5, Chart.js, `pymssql`
- Bootstrap và Chart.js nạp qua CDN, không cần build. `pymssql` kết nối thẳng SQL Server nên không phải cài ODBC driver.
- Cấu hình DB nằm trong `app/.env`. App dùng tài khoản riêng `btl2_app`, không dùng `sa`.

## Màn hình ↔ thủ tục / hàm

| Màn hình | Route | Gọi |
| --- | --- | --- |
| 3.1 Form thêm | `/bookings/new` | `sp_Booking_Insert` |
| 3.1 Form sửa | `/bookings/<id>/edit` | `sp_Booking_Update`, hiển thị `fn_CancelRefund` |
| 3.1 Nút xóa (form sửa + từng dòng) | `POST /bookings/<id>/delete` | `sp_Booking_Delete` |
| 3.2 Danh sách | `/bookings` | `sp_Booking_List` (tìm theo khách/phòng/cơ sở/mã đơn, lọc trạng thái, khoảng ngày, sắp xếp, phân trang) |
| 3.2 Đổi trạng thái trên dòng | `POST /bookings/<id>/status` | `sp_Booking_Update @Status` |
| 3.3 Dashboard | `/dashboard` | `sp_Revenue_By_Accommodation` (bảng + biểu đồ), `fn_GuestTier` (tra cứu hạng khách) |

App **không có** câu INSERT/UPDATE/DELETE nào. SELECT trực tiếp chỉ dùng để đổ dropdown (khách, cơ sở, hạng phòng, thành phố) và nạp dữ liệu vào form sửa. Tài khoản `btl2_app` cũng không có quyền ghi bảng, nên mọi thay đổi dữ liệu bắt buộc đi qua thủ tục.

## Cài đặt và chạy

### 1. Chuẩn bị CSDL

Chạy các script theo README gốc: `01` → `02` → `03` → `05` → `06` → `07`. **Bỏ qua `04`** cho tới khi xử lý xong [issue #1](https://github.com/quangnguyen0101/travel-booking-management-system/issues/1), vì trigger 04 làm `sp_Booking_Insert` lỗi 515 và form thêm sẽ không tạo được đơn.

Sau đó chạy `sql/08_app_login.sql` để tạo tài khoản `btl2_app` (chỉ có quyền SELECT + EXECUTE).

Nếu dùng SQL Server cài trên máy (không phải Docker), cần thêm 2 bước:

- **Bật SQL Server Authentication:** SSMS → chuột phải server → *Properties* → *Security* → chọn *SQL Server and Windows Authentication mode* → restart service.
- **Bật TCP/IP:** *SQL Server Configuration Manager* → *SQL Server Network Configuration* → *Protocols for MSSQLSERVER* (hoặc SQLEXPRESS) → *TCP/IP* = Enabled. Với SQLEXPRESS: vào *IP Addresses* → *IPAll*, xóa *TCP Dynamic Ports*, đặt *TCP Port* = `1433`, rồi restart service.

Nếu dùng Docker theo README gốc thì cổng là `14333`.

### 2. Chạy app (PowerShell, từ thư mục gốc repo)

```powershell
cd app
py -3.12 -m venv .venv
.venv\Scripts\pip install -r requirements.txt
copy .env.example .env
.venv\Scripts\python app.py
```

Sửa `.env` nếu khác cấu hình mặc định (`DB_PORT=14333` khi dùng Docker; đổi `DB_PASSWORD` nếu đã đổi trong `08_app_login.sql`), rồi mở <http://localhost:5000>.

### 3. Kiểm tra tích hợp

```powershell
.venv\Scripts\python test_app.py
```

Script chạy luồng đầy đủ thêm → tìm → sửa → đổi trạng thái → xóa → dashboard trên DB thật. Kết quả mong đợi là **31/31 PASS**. Script tạo 1 đơn test (ngày nhận phòng khoảng 400 ngày sau hôm nay) rồi tự xóa, không làm đổi dữ liệu mẫu.

Ca kiểm tra cuối xác nhận `btl2_app` không chạy được `DELETE` trực tiếp (lỗi 229).

## Xử lý lỗi

App kiểm tra dữ liệu ở 2 lớp:

1. **Client:** dùng ràng buộc HTML5 (`required`, `min`, `type=date/number`) và một đoạn JS áp đúng quy tắc của `sp_Booking_ValidateStay`:
   - ngày trả phòng phải sau ngày nhận phòng;
   - mỗi đơn tối đa 30 đêm;
   - số người lớn và tổng số khách không vượt sức chứa của hạng phòng × số phòng.
2. **Thủ tục:** khi thủ tục `THROW`, app hiện `[mã lỗi] thông báo` ở đầu trang, giữ nguyên dữ liệu đã nhập và tô đỏ ô bị lỗi. Ô lỗi được nhận ra từ tiền tố tên trường trong thông báo, ví dụ `CHECK_IN_DATE:` thì tô đỏ ô *Nhận phòng*.

Các lỗi nghiệp vụ hiện trên danh sách (xóa đơn CONFIRMED, chuyển COMPLETED khi đơn còn PENDING...) đều lấy thông báo từ thủ tục. Bảng mã lỗi `511xx`–`513xx` xem trong README gốc.

Ngoài ra:

- Khoảng ngày bị ngược thì app hiện cảnh báo, kết quả để trống.
- Mất kết nối CSDL thì app hiện trang 503 kèm mã lỗi, nhắc kiểm tra `app/.env`.
- `fn_GuestTier` trả `NULL` (năm sai, không phải khách) thì app hiện "Không hợp lệ".

## Ảnh màn hình

| Màn hình | File |
| --- | --- |
| 3.1 Form thêm | `evidence/3.1-form-them.png` |
| 3.1 Form sửa + nút xóa | `evidence/3.1-form-sua.png` |
| 3.2 Danh sách | `evidence/3.2-danh-sach.png` |
| 3.3 Dashboard | `evidence/3.3-dashboard.png` |

## Giới hạn đã biết

- Phân trang làm trong app trên toàn bộ kết quả của `sp_Booking_List`, vì proc chưa có `OFFSET/FETCH`. Đủ cho dữ liệu đồ án.
- Không có đăng nhập và CSRF token. Đây là app demo chạy `localhost`.
- Sửa đơn: để trống *Giờ đến* hoặc *Yêu cầu đặc biệt* thì giữ giá trị cũ, vì `sp_Booking_Update` coi `NULL` là "không đổi".
