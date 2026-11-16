/*
 BTL2 - Nhóm 5
 Phần 2.1: Kiểm thử sp_Booking_Insert / sp_Booking_Update / sp_Booking_Delete
 Chạy sau 03_crud.sql trên dữ liệu mẫu 02_seed.sql.
 Ngày tính theo hôm nay nên chạy lại được nhiều lần. Đơn tạo ra ở TC01 được hủy và xóa ở TC16,
 voucher VC_ACTIVE_500K trả lại ACTIVE -> dữ liệu mẫu giữ nguyên sau khi chạy.
 Ca mong đợi lỗi chỉ PASS khi đúng mã lỗi; ca hợp lệ PASS khi không có lỗi.
*/
USE [BTL2_Booking_Nhom5];
GO
SET NOCOUNT ON;

DECLARE @today DATE = CAST(GETDATE() AS DATE);
DECLARE @dm1 DATE = DATEADD(DAY, -1, @today),
        @d20 DATE = DATEADD(DAY, 20, @today), @d21 DATE = DATEADD(DAY, 21, @today),
        @d22 DATE = DATEADD(DAY, 22, @today), @d23 DATE = DATEADD(DAY, 23, @today),
        @d25 DATE = DATEADD(DAY, 25, @today), @d27 DATE = DATEADD(DAY, 27, @today),
        @d30 DATE = DATEADD(DAY, 30, @today), @d32 DATE = DATEADD(DAY, 32, @today),
        @d40 DATE = DATEADD(DAY, 40, @today), @d42 DATE = DATEADD(DAY, 42, @today),
        @d55 DATE = DATEADD(DAY, 55, @today);
DECLARE @id INT, @code VARCHAR(30), @st VARCHAR(12), @vst VARCHAR(10), @in DATE, @out DATE, @ad SMALLINT, @price DECIMAL(18,2);

PRINT N'===== THÊM: sp_Booking_Insert =====';

-- TC01: Hợp lệ, có voucher -> đơn PENDING, voucher chuyển USED
BEGIN TRY
    EXEC dbo.sp_Booking_Insert @UserId = 2, @AccommodationId = 5, @RoomName = N'Old Quarter Studio',
         @CheckIn = @d20, @CheckOut = @d23, @Adults = 2, @Children = 0, @Quantity = 1,
         @VoucherCode = 'VC_ACTIVE_500K', @SpecialRequests = N'Phòng tầng cao', @BookingId = @id OUTPUT;
    SELECT @code = b.BOOKING_CODE, @st = b.[STATUS], @price = brt.ROOM_PRICE_AT_BOOKING
    FROM dbo.BOOKING b JOIN dbo.BOOKING_ROOM_TYPE brt ON brt.BOOKING_ID = b.BOOKING_ID WHERE b.BOOKING_ID = @id;
    SELECT @vst = [STATUS] FROM dbo.VOUCHER WHERE VOUCHER_CODE = 'VC_ACTIVE_500K';
    PRINT CONCAT(N'TC01 [PASS] Thêm hợp lệ: BOOKING_ID=', @id, N', ', @code, N', ', @st, N', ', @d20, N' -> ', @d23,
                 N', giá ', @price, N', voucher VC_ACTIVE_500K -> ', @vst);
END TRY
BEGIN CATCH PRINT CONCAT(N'TC01 [FAIL] ', ERROR_NUMBER(), N' - ', ERROR_MESSAGE()); END CATCH;

-- TC02: Ngày nhận phòng đã qua
BEGIN TRY
    EXEC dbo.sp_Booking_Insert @UserId = 3, @AccommodationId = 5, @RoomName = N'Old Quarter Studio',
         @CheckIn = @dm1, @CheckOut = @d20, @Adults = 2;
    PRINT N'TC02 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC02 ', IIF(ERROR_NUMBER() = 51105, N'[PASS]', N'[FAIL]'), N' Ngày nhận phòng đã qua -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

-- TC03: Ngày trả phòng không sau ngày nhận phòng
BEGIN TRY
    EXEC dbo.sp_Booking_Insert @UserId = 3, @AccommodationId = 5, @RoomName = N'Old Quarter Studio',
         @CheckIn = @d22, @CheckOut = @d20, @Adults = 2;
    PRINT N'TC03 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC03 ', IIF(ERROR_NUMBER() = 51106, N'[PASS]', N'[FAIL]'), N' Ngày trả <= ngày nhận -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

-- TC04: Quá 30 đêm
BEGIN TRY
    EXEC dbo.sp_Booking_Insert @UserId = 3, @AccommodationId = 5, @RoomName = N'Old Quarter Studio',
         @CheckIn = @d20, @CheckOut = @d55, @Adults = 2;
    PRINT N'TC04 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC04 ', IIF(ERROR_NUMBER() = 51107, N'[PASS]', N'[FAIL]'), N' Quá 30 đêm -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

-- TC05: Quá sức chứa (Old Quarter Studio: tối đa 2 người lớn/phòng)
BEGIN TRY
    EXEC dbo.sp_Booking_Insert @UserId = 3, @AccommodationId = 5, @RoomName = N'Old Quarter Studio',
         @CheckIn = @d40, @CheckOut = @d42, @Adults = 3, @Children = 1;
    PRINT N'TC05 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC05 ', IIF(ERROR_NUMBER() = 51111, N'[PASS]', N'[FAIL]'), N' Quá sức chứa -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

-- TC06: Trùng lịch (hạng có 2 phòng, TC01 đã giữ 1 phòng, đặt thêm 2 phòng trùng ngày)
BEGIN TRY
    EXEC dbo.sp_Booking_Insert @UserId = 3, @AccommodationId = 5, @RoomName = N'Old Quarter Studio',
         @CheckIn = @d21, @CheckOut = @d22, @Adults = 2, @Quantity = 2;
    PRINT N'TC06 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC06 ', IIF(ERROR_NUMBER() = 51112, N'[PASS]', N'[FAIL]'), N' Trùng lịch -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

-- TC07: Voucher hết hạn
BEGIN TRY
    EXEC dbo.sp_Booking_Insert @UserId = 1, @AccommodationId = 5, @RoomName = N'Old Quarter Studio',
         @CheckIn = @d40, @CheckOut = @d42, @Adults = 2, @VoucherCode = 'VC_EXPIRED_99K';
    PRINT N'TC07 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC07 ', IIF(ERROR_NUMBER() = 51125, N'[PASS]', N'[FAIL]'), N' Voucher hết hạn -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

-- TC08: USER không phải GUEST (USER 6 là HOST)
BEGIN TRY
    EXEC dbo.sp_Booking_Insert @UserId = 6, @AccommodationId = 5, @RoomName = N'Old Quarter Studio',
         @CheckIn = @d40, @CheckOut = @d42, @Adults = 2;
    PRINT N'TC08 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC08 ', IIF(ERROR_NUMBER() = 51121, N'[PASS]', N'[FAIL]'), N' Không phải GUEST -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

PRINT N'';
PRINT N'===== SỬA: sp_Booking_Update =====';

-- TC09: Đơn PENDING đổi ngày và số khách -> hợp lệ
BEGIN TRY
    EXEC dbo.sp_Booking_Update @BookingId = @id, @CheckIn = @d25, @CheckOut = @d27, @Adults = 1;
    SELECT @in = CHECK_IN_DATE, @out = CHECK_OUT_DATE, @ad = ADULTS FROM dbo.BOOKING WHERE BOOKING_ID = @id;
    PRINT CONCAT(N'TC09 [PASS] Đổi ngày đơn PENDING: ', @in, N' -> ', @out, N', ADULTS=', @ad);
END TRY
BEGIN CATCH PRINT CONCAT(N'TC09 [FAIL] ', ERROR_NUMBER(), N' - ', ERROR_MESSAGE()); END CATCH;

-- TC10: Nhảy trạng thái PENDING -> COMPLETED
BEGIN TRY
    EXEC dbo.sp_Booking_Update @BookingId = @id, @Status = 'COMPLETED';
    PRINT N'TC10 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC10 ', IIF(ERROR_NUMBER() = 51205, N'[PASS]', N'[FAIL]'), N' PENDING -> COMPLETED -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

-- TC11: PENDING -> CONFIRMED -> hợp lệ
BEGIN TRY
    EXEC dbo.sp_Booking_Update @BookingId = @id, @Status = 'CONFIRMED';
    SELECT @st = [STATUS] FROM dbo.BOOKING WHERE BOOKING_ID = @id;
    PRINT CONCAT(N'TC11 [PASS] PENDING -> CONFIRMED: STATUS=', @st);
END TRY
BEGIN CATCH PRINT CONCAT(N'TC11 [FAIL] ', ERROR_NUMBER(), N' - ', ERROR_MESSAGE()); END CATCH;

-- TC12: Đơn CONFIRMED đổi ngày
BEGIN TRY
    EXEC dbo.sp_Booking_Update @BookingId = @id, @CheckIn = @d30, @CheckOut = @d32;
    PRINT N'TC12 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC12 ', IIF(ERROR_NUMBER() = 51203, N'[PASS]', N'[FAIL]'), N' Đổi ngày đơn CONFIRMED -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

-- TC13: Sửa đơn COMPLETED (đơn 1 trong dữ liệu mẫu)
BEGIN TRY
    EXEC dbo.sp_Booking_Update @BookingId = 1, @SpecialRequests = N'Sửa sau khi đã trả phòng';
    PRINT N'TC13 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC13 ', IIF(ERROR_NUMBER() = 51202, N'[PASS]', N'[FAIL]'), N' Sửa đơn COMPLETED -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

PRINT N'';
PRINT N'===== XÓA: sp_Booking_Delete =====';

-- TC14: Xóa đơn CONFIRMED
BEGIN TRY
    EXEC dbo.sp_Booking_Delete @BookingId = @id;
    PRINT N'TC14 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC14 ', IIF(ERROR_NUMBER() = 51302, N'[PASS]', N'[FAIL]'), N' Xóa đơn CONFIRMED -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

-- TC15: Xóa đơn CANCELLED nhưng đã trả tiền (đơn 8: PAYMENT PAID)
BEGIN TRY
    EXEC dbo.sp_Booking_Delete @BookingId = 8;
    PRINT N'TC15 [FAIL] không báo lỗi';
END TRY
BEGIN CATCH PRINT CONCAT(N'TC15 ', IIF(ERROR_NUMBER() = 51303, N'[PASS]', N'[FAIL]'), N' Xóa đơn đã trả tiền -> ', ERROR_NUMBER(), N': ', ERROR_MESSAGE()); END CATCH;

-- TC16: Hủy đơn (CONFIRMED -> CANCELLED) rồi xóa -> hợp lệ, voucher trả lại ACTIVE
BEGIN TRY
    EXEC dbo.sp_Booking_Update @BookingId = @id, @Status = 'CANCELLED';
    EXEC dbo.sp_Booking_Delete @BookingId = @id;
    SELECT @vst = [STATUS] FROM dbo.VOUCHER WHERE VOUCHER_CODE = 'VC_ACTIVE_500K';
    SELECT @ad = COUNT(*) FROM dbo.BOOKING WHERE BOOKING_ID = @id;
    PRINT CONCAT(N'TC16 [PASS] Hủy rồi xóa đơn ', @id, N': còn ', @ad, N' dòng BOOKING; voucher VC_ACTIVE_500K -> ', @vst);
END TRY
BEGIN CATCH PRINT CONCAT(N'TC16 [FAIL] ', ERROR_NUMBER(), N' - ', ERROR_MESSAGE()); END CATCH;
GO
