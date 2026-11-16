# Ghi chú tích hợp — trigger 2.2.1 (`04_trigger_rangbuoc.sql`)

> Trạng thái: **chưa sửa file của tác giả**. Tài liệu này ghi lại lỗi phát hiện khi ghép 3 gói bài, kèm cách tái hiện và hướng xử lý đề xuất để cả nhóm chốt.

## TL;DR

`04_trigger_rangbuoc.sql` chạy đúng 5/5 test **của riêng nó**, nhưng sau khi cài trigger:

1. **`sp_Booking_Insert` (2.1) hỏng hoàn toàn** — `SCOPE_IDENTITY()` trả `NULL` vì trigger `INSTEAD OF INSERT`, dòng con `BOOKING_ROOM_TYPE` bị chèn với `BOOKING_ID = NULL`.
2. **Trigger chặn nhầm đơn hợp lệ** — nó so trùng lịch theo `BOOKING.ACCOMMODATION_ID`, trong khi nghiệp vụ của schema là theo **hạng phòng + số lượng** (`BOOKING_ROOM_TYPE.ROOM_NAME`, `RESERVED_QUANTITY`).

Ngoài ra, trigger có nhánh chết: `STATUS IN (..., 'CHECKED_IN')`, nhưng `CK_BOOKING_STATUS` chỉ cho phép `PENDING`, `CONFIRMED`, `COMPLETED`, `CANCELLED`.

## Bằng chứng

### 1. `SCOPE_IDENTITY()` bị NULL

Trong `03_crud.sql`:

```sql
INSERT INTO dbo.BOOKING (...) VALUES (...);
SET @BookingId = SCOPE_IDENTITY();          -- dòng 163
UPDATE dbo.BOOKING SET BOOKING_CODE = ... WHERE BOOKING_ID = @BookingId;
INSERT INTO dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ...) VALUES (@BookingId, ...);
```

Với trigger `INSTEAD OF INSERT`, câu `INSERT` thật do trigger thực hiện ở scope khác, nên `SCOPE_IDENTITY()` ở thủ tục trả `NULL`.

Tái hiện (đã cài `04`):

```text
EXEC dbo.sp_Booking_Insert @UserId=2, @AccommodationId=5,
     @RoomName=N'Old Quarter Studio', @CheckIn='2027-01-10',
     @CheckOut='2027-01-12', @Adults=1, @BookingId=@id OUTPUT;

Kết quả:
LOI  515  Cannot insert the value NULL into column 'BOOKING_ID',
          table 'BTL2_Booking_Nhom5.dbo.BOOKING_ROOM_TYPE'; column does not allow nulls.
```

Trước khi cài `04`, `tests/2.1-testcases.sql` đạt **16/16 PASS**. Sau khi cài `04`, thủ tục thêm không dùng được.

### 2. Chặn nhầm hạng phòng khác

Dữ liệu mẫu:

- `ACCOMMODATION_ID = 1` (Saigon Majestic Hotel) có 2 hạng: `Deluxe River View` (2 phòng sẵn sàng) và `Executive Suite` (1 phòng sẵn sàng).
- `BOOKING_ID = 12` đang `PENDING`, giữ `Deluxe River View` ngày `2026-12-01 → 2026-12-03`.

Đặt `Executive Suite` cùng ngày là hợp lệ (khác hạng phòng, còn trống), nhưng:

```text
BI CHAN: Vi pham rang buoc trung lich! Phong/Co so (ACCOMMODATION_ID = 1)
         khoang [2026-12-01 -> 2026-12-03) bi trung voi BOOKING_ID = 12 ...
```

Trigger đang coi **cả cơ sở** là một phòng. Hệ quả: mỗi cơ sở chỉ nhận được 1 đơn đang hiệu lực tại một thời điểm, dù còn nhiều hạng phòng và nhiều phòng trống.

## Vì sao lỗi này xảy ra

File `04` được viết theo mô tả ở bản kế hoạch (`room_id`, `status CHECKED_IN`, đặt theo phòng cụ thể), không theo schema thật đã chốt ở `01_schema.sql`:

| Kế hoạch ban đầu | Schema thực tế |
| --- | --- |
| `BOOKING.room_id` | Không có; đơn gắn hạng phòng qua `BOOKING_ROOM_TYPE` |
| `STATUS` có `CHECKED_IN` | Chỉ `PENDING/CONFIRMED/COMPLETED/CANCELLED` |
| Đặt 1 phòng cụ thể | Đặt `RESERVED_QUANTITY` phòng của một hạng |

## Hướng xử lý đề xuất

### Phương án A — chuyển trigger sang `BOOKING_ROOM_TYPE` (khuyến nghị)

Đặt trigger **`AFTER INSERT, UPDATE` trên `BOOKING_ROOM_TYPE`**, kiểm tra theo đúng hạng phòng và số lượng:

```text
số phòng sẵn sàng của hạng
  = COUNT(ROOM) WHERE AVAILABILITY_STATUS <> 'MAINTENANCE'

số phòng đã giữ trong khoảng giao nhau
  = SUM(RESERVED_QUANTITY) của các BOOKING_ROOM_TYPE
    join BOOKING có STATUS IN ('PENDING','CONFIRMED')
    và khoảng [CHECK_IN_DATE, CHECK_OUT_DATE) giao với dòng mới

nếu số đã giữ + số đặt thêm > số sẵn sàng → THROW kèm BOOKING_ID xung đột
```

Ưu điểm:

- Đúng nghiệp vụ (theo hạng phòng + số lượng), không chặn nhầm hạng khác.
- `AFTER` trigger không phá `SCOPE_IDENTITY()` → `sp_Booking_Insert` và toàn bộ 2.1 chạy lại bình thường.
- Vẫn thuộc 2.2.1: đề bài không bắt buộc trigger phải nằm trên `BOOKING`, chỉ yêu cầu nêu ràng buộc + DML ảnh hưởng + trigger kiểm tra.
- Cần xử lý `UPDATE`/`DELETE`: trừ phần `deleted` trước khi cộng `inserted`, và kiểm tra theo từng nhóm `(ACCOMMODATION_ID, ROOM_NAME)`.

Lưu ý khi báo cáo: phải nêu rõ vì sao **không** đặt trigger trên `BOOKING` — tại thời điểm `INSERT BOOKING`, dòng `BOOKING_ROOM_TYPE` chưa tồn tại nên trigger trên bảng cha không thể biết hạng phòng/số lượng. Đây là lý do kỹ thuật hợp lệ để chọn bảng con.

### Phương án B — giữ `INSTEAD OF` trên `BOOKING`

Chỉ nên chọn nếu nhóm muốn giữ nguyên tên `trg_Booking_NoOverlap` trên `BOOKING`. Khi đó phải sửa **cả** `03_crud.sql`:

- Sinh `BOOKING_CODE` trước khi insert, sau đó lấy lại ID bằng `SELECT @BookingId = BOOKING_ID FROM dbo.BOOKING WHERE BOOKING_CODE = @code` (không dùng `SCOPE_IDENTITY`).
- Vẫn phải xử lý bài toán hạng phòng: bản thân `BOOKING` không đủ dữ liệu để kiểm tra trùng theo hạng. Cách sạch nhất vẫn là thêm trigger trên `BOOKING_ROOM_TYPE`.

→ Phương án B chỉ sửa triệu chứng, không sửa nguyên nhân. **Không khuyến nghị.**

## Việc cần chốt với nhóm

- [ ] Chọn A hay B; nếu A, bạn Nguyên cập nhật `04` và chạy lại 5 ca test + test tích hợp với 2.1.
- [ ] Cập nhật báo cáo mục 2.2.1: ràng buộc, DML ảnh hưởng, lý do không dùng CHECK, lý do đặt trigger trên bảng con.
- [ ] Sau khi sửa, chạy lại toàn bộ pipeline từ DB trống: `01 → 02 → 03 → 04 → test 2.1 → test 04`.
- [ ] Thêm test "đặt hạng phòng khác, cùng cơ sở, cùng ngày" để chứng minh không chặn nhầm.
