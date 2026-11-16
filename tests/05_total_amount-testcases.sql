/*
===============================================================================
 BTL2 - Nhóm 5
 Phần 2.2.2: Test trigger thuộc tính dẫn xuất BOOKING.TOTAL_AMOUNT
 Nguyễn Trương Đăng Quang

 Chạy sau 05_trigger_danxuat.sql.
 Toàn bộ test nằm trong một transaction và ROLLBACK ở cuối, nên dữ liệu mẫu
 của 02_seed.sql không thay đổi. Có thể chạy lại nhiều lần.

 Điều kiện: DB đã nạp 01_schema, 02_seed, 05_trigger_danxuat (không cần 04).
 Nếu đã cài 04_trigger_rangbuoc.sql, phải vá trg_Booking_NoOverlap để nó
 chuyển tiếp TOTAL_AMOUNT, xem cảnh báo in ra khi chạy file này.

 Các case:
   1. Đơn mới chưa có hạng phòng -> TOTAL_AMOUNT = 0.
   2. INSERT 2 dòng BOOKING_ROOM_TYPE trong 1 câu -> cộng đủ 2 hạng phòng.
   3. UPDATE ngày trả phòng -> tính lại theo số đêm mới.
   4. UPDATE ROOM_PRICE_AT_BOOKING -> tính lại theo giá mới.
   5. Gắn voucher -> trừ đúng mức giảm.
   6. Giảm giá lớn hơn tiền phòng -> TOTAL_AMOUNT = 0 (không âm).
   7. Đổi VOUCHER.DISCOUNT_VALUE -> đơn đang dùng voucher tính lại.
   8. Ghi trực tiếp TOTAL_AMOUNT -> trigger tự tính lại.
   9. Bỏ voucher -> cộng lại tiền phòng.
  10. Xóa hết hạng phòng -> TOTAL_AMOUNT = 0.
  11. Kiểm tra chéo toàn bộ BOOKING khớp view.
===============================================================================
*/

USE [BTL2_Booking_Nhom5];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- Dọn dữ liệu test còn sót nếu lần chạy trước bị lỗi trước khi rollback.
DELETE bv
FROM dbo.BOOKING_VOUCHER AS bv
JOIN dbo.BOOKING AS b ON b.BOOKING_ID = bv.BOOKING_ID
WHERE b.BOOKING_CODE LIKE 'BK_TEST_TA_%';
DELETE brt
FROM dbo.BOOKING_ROOM_TYPE AS brt
JOIN dbo.BOOKING AS b ON b.BOOKING_ID = brt.BOOKING_ID
WHERE b.BOOKING_CODE LIKE 'BK_TEST_TA_%';
DELETE FROM dbo.BOOKING WHERE BOOKING_CODE LIKE 'BK_TEST_TA_%';
DELETE FROM dbo.VOUCHER WHERE VOUCHER_CODE = 'VC_TEST_TA_300K';
GO

-- 04 có INSTEAD OF INSERT, UPDATE trên BOOKING: nó nuốt mọi UPDATE vào BOOKING
-- nên trigger TOTAL_AMOUNT không ghi được gì.
IF EXISTS (SELECT 1 FROM sys.triggers
           WHERE name = 'trg_Booking_NoOverlap' AND is_instead_of_trigger = 1)
    PRINT N'CẢNH BÁO: đã cài 04_trigger_rangbuoc.sql. Cần thêm "b.TOTAL_AMOUNT = i.TOTAL_AMOUNT" vào UPDATE trong trg_Booking_NoOverlap, nếu không các case 2-9 sẽ FAIL.';
GO

DECLARE @log TABLE (
    STT INT IDENTITY(1,1),
    Test NVARCHAR(250) NOT NULL,
    Expected NVARCHAR(100) NOT NULL,
    Actual NVARCHAR(100) NOT NULL,
    Result CHAR(4) NOT NULL
);

DECLARE @pass INT = 0, @fail INT = 0;
DECLARE @b INT, @t DECIMAL(18,2);

BEGIN TRY
    BEGIN TRANSACTION;

    INSERT INTO dbo.BOOKING
        ([STATUS], ADULTS, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
         CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES
        ('PENDING', 2, 'BK_TEST_TA_01', '9201', '2026-11-01',
         '2026-11-20', '2026-11-22', 1, 1);

    SET @b = (SELECT BOOKING_ID FROM dbo.BOOKING WHERE BOOKING_CODE = 'BK_TEST_TA_01');

    /* 1. Chưa có hạng phòng */
    SELECT @t = TOTAL_AMOUNT FROM dbo.BOOKING WHERE BOOKING_ID = @b;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'1. Đơn mới, chưa có hạng phòng',
            N'0.00',
            CONVERT(VARCHAR(30), @t),
            CASE WHEN @t = 0 THEN 'PASS' ELSE 'FAIL' END);

    /* 2. 2 đêm x (2,500,000 + 4,000,000) = 13,000,000 */
    INSERT INTO dbo.BOOKING_ROOM_TYPE
        (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES
        (@b, 1, N'Deluxe River View', 2500000.00, 1),
        (@b, 1, N'Executive Suite',   4000000.00, 1);

    SELECT @t = TOTAL_AMOUNT FROM dbo.BOOKING WHERE BOOKING_ID = @b;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'2. INSERT 2 hạng phòng (2 đêm)',
            N'13000000.00',
            CONVERT(VARCHAR(30), @t),
            CASE WHEN @t = 13000000.00 THEN 'PASS' ELSE 'FAIL' END);

    /* 3. 3 đêm x 6,500,000 = 19,500,000 */
    UPDATE dbo.BOOKING SET CHECK_OUT_DATE = '2026-11-23' WHERE BOOKING_ID = @b;

    SELECT @t = TOTAL_AMOUNT FROM dbo.BOOKING WHERE BOOKING_ID = @b;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'3. Đổi 2 -> 3 đêm',
            N'19500000.00',
            CONVERT(VARCHAR(30), @t),
            CASE WHEN @t = 19500000.00 THEN 'PASS' ELSE 'FAIL' END);

    /* 4. 3 x (3,000,000 + 4,000,000) = 21,000,000 */
    UPDATE dbo.BOOKING_ROOM_TYPE
    SET ROOM_PRICE_AT_BOOKING = 3000000.00
    WHERE BOOKING_ID = @b AND ROOM_NAME = N'Deluxe River View';

    SELECT @t = TOTAL_AMOUNT FROM dbo.BOOKING WHERE BOOKING_ID = @b;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'4. Đổi giá hạng phòng Deluxe',
            N'21000000.00',
            CONVERT(VARCHAR(30), @t),
            CASE WHEN @t = 21000000.00 THEN 'PASS' ELSE 'FAIL' END);

    /* 5. Gắn voucher 300,000 -> 20,700,000 */
    INSERT INTO dbo.VOUCHER
        (VOUCHER_CODE, DISCOUNT_VALUE, APPLICABLE_CONDITIONS, EXPIRY_DATE, [STATUS], USER_ID)
    VALUES
        ('VC_TEST_TA_300K', 300000.00, N'Test 2.2.2', '2027-12-31', 'ACTIVE', 1);

    INSERT INTO dbo.BOOKING_VOUCHER (BOOKING_ID, VOUCHER_CODE)
    VALUES (@b, 'VC_TEST_TA_300K');

    SELECT @t = TOTAL_AMOUNT FROM dbo.BOOKING WHERE BOOKING_ID = @b;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'5. Gắn voucher giảm 300,000',
            N'20700000.00',
            CONVERT(VARCHAR(30), @t),
            CASE WHEN @t = 20700000.00 THEN 'PASS' ELSE 'FAIL' END);

    /* 6. Giảm giá lớn hơn tiền phòng -> 0, không âm */
    UPDATE dbo.VOUCHER SET DISCOUNT_VALUE = 999999999.00
    WHERE VOUCHER_CODE = 'VC_TEST_TA_300K';

    SELECT @t = TOTAL_AMOUNT FROM dbo.BOOKING WHERE BOOKING_ID = @b;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'6. Giảm giá > tiền phòng',
            N'0.00',
            CONVERT(VARCHAR(30), @t),
            CASE WHEN @t = 0 THEN 'PASS' ELSE 'FAIL' END);

    /* 7. Trả mức giảm về 300,000 -> 20,700,000 */
    UPDATE dbo.VOUCHER SET DISCOUNT_VALUE = 300000.00
    WHERE VOUCHER_CODE = 'VC_TEST_TA_300K';

    SELECT @t = TOTAL_AMOUNT FROM dbo.BOOKING WHERE BOOKING_ID = @b;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'7. Đổi lại mức giảm voucher',
            N'20700000.00',
            CONVERT(VARCHAR(30), @t),
            CASE WHEN @t = 20700000.00 THEN 'PASS' ELSE 'FAIL' END);

    /* 8. Ghi trực tiếp cột dẫn xuất -> trigger tính lại */
    UPDATE dbo.BOOKING SET TOTAL_AMOUNT = 123 WHERE BOOKING_ID = @b;

    SELECT @t = TOTAL_AMOUNT FROM dbo.BOOKING WHERE BOOKING_ID = @b;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'8. Ghi trực tiếp TOTAL_AMOUNT = 123',
            N'20700000.00',
            CONVERT(VARCHAR(30), @t),
            CASE WHEN @t = 20700000.00 THEN 'PASS' ELSE 'FAIL' END);

    /* 9. Bỏ voucher -> 21,000,000 */
    DELETE FROM dbo.BOOKING_VOUCHER WHERE BOOKING_ID = @b;

    SELECT @t = TOTAL_AMOUNT FROM dbo.BOOKING WHERE BOOKING_ID = @b;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'9. Bỏ voucher khỏi đơn',
            N'21000000.00',
            CONVERT(VARCHAR(30), @t),
            CASE WHEN @t = 21000000.00 THEN 'PASS' ELSE 'FAIL' END);

    /* 10. Xóa hết hạng phòng -> 0 */
    DELETE FROM dbo.BOOKING_ROOM_TYPE WHERE BOOKING_ID = @b;

    SELECT @t = TOTAL_AMOUNT FROM dbo.BOOKING WHERE BOOKING_ID = @b;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'10. Xóa hết hạng phòng của đơn',
            N'0.00',
            CONVERT(VARCHAR(30), @t),
            CASE WHEN @t = 0 THEN 'PASS' ELSE 'FAIL' END);

    /* 11. Kiểm tra chéo toàn bộ bảng */
    INSERT INTO @log (Test, Expected, Actual, Result)
    SELECT N'11. Toàn bộ BOOKING khớp view',
           N'0 dòng lệch',
           CONCAT(COUNT(*), N' dòng lệch'),
           CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
    FROM dbo.BOOKING AS b
    JOIN dbo.vw_BookingTotalAmount AS v ON v.BOOKING_ID = b.BOOKING_ID
    WHERE b.TOTAL_AMOUNT <> v.TOTAL_AMOUNT;

    SELECT @pass = COUNT(*) FROM @log WHERE Result = 'PASS';
    SET @fail = (SELECT COUNT(*) FROM @log) - @pass;

    SELECT STT, Test, Expected, Actual, Result FROM @log ORDER BY STT;

    ROLLBACK TRANSACTION;

    PRINT N'Đã rollback: dữ liệu mẫu giữ nguyên.';
    PRINT CONCAT(N'KẾT QUẢ 2.2.2 (TOTAL_AMOUNT): ', @pass, N' PASS / ', @fail, N' FAIL');
    IF @fail = 0
        PRINT N'==> PASS toàn bộ. Trigger TOTAL_AMOUNT hoạt động đúng.';
    ELSE
        PRINT N'==> CÓ CASE FAIL, xem bảng kết quả phía trên.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT N'LỖI: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO
