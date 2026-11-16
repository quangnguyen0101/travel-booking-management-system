/*
===============================================================================
 BTL2 - Nhóm 5
 Phần 2.2.2: Test trigger thuộc tính dẫn xuất
 Nguyễn Trương Đăng Quang

 Chạy sau 05_trigger_danxuat.sql.
 Toàn bộ test nằm trong một transaction và ROLLBACK ở cuối, nên dữ liệu mẫu
 của 02_seed.sql không thay đổi. Có thể chạy lại nhiều lần.

 Các case:
   1. Baseline: điểm review và rating cơ sở đã được backfill đúng.
   2. INSERT REVIEW  -> OVERALL_SCORE, REVIEW_COUNT, AVERAGE_RATING.
   3. Thêm review thứ 2 cùng cơ sở -> rating là trung bình cộng.
   4. UPDATE điểm review -> cả điểm review và rating cơ sở đổi.
   5. UPDATE REVIEW.BOOKING_ID -> rating cơ sở cũ và mới đều đổi.
   6. UPDATE BOOKING.ACCOMMODATION_ID -> rating cơ sở cũ và mới đều đổi.
   7. DELETE REVIEW -> giảm REVIEW_COUNT và tính lại AVERAGE_RATING.
   8. Kiểm tra chéo toàn bộ bảng: không còn dòng lệch với dữ liệu gốc.
===============================================================================
*/

USE [BTL2_Booking_Nhom5];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

-- Dọn dữ liệu test còn sót nếu lần chạy trước bị lỗi trước khi rollback.
DELETE r
FROM dbo.REVIEW AS r
JOIN dbo.BOOKING AS b ON b.BOOKING_ID = r.BOOKING_ID
WHERE b.BOOKING_CODE LIKE 'BK_TEST_DX_%';
DELETE FROM dbo.BOOKING WHERE BOOKING_CODE LIKE 'BK_TEST_DX_%';
GO

DECLARE @log TABLE (
    STT INT IDENTITY(1,1),
    Test NVARCHAR(250) NOT NULL,
    Expected NVARCHAR(100) NOT NULL,
    Actual NVARCHAR(100) NOT NULL,
    Result CHAR(4) NOT NULL
);

DECLARE @pass INT = 0, @fail INT = 0;
DECLARE @b1 INT, @b2 INT, @b3 INT, @r1 INT, @r2 INT;
DECLARE @c INT, @a DECIMAL(4,2);

BEGIN TRY
    BEGIN TRANSACTION;

    /* ------------------------------------------------------------------
       1. BASELINE — backfill từ 02_seed.sql
       Review 1: (9.5 + 9.5 + 10 + 9 + 10 + 9.5) / 6 = 9.58
       ------------------------------------------------------------------ */
    SELECT @c = REVIEW_COUNT, @a = AVERAGE_RATING
    FROM dbo.ACCOMMODATION WHERE ACCOMMODATION_ID = 1;

    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'1. Baseline cơ sở 1 (1 review, điểm 9.58)',
            N'1 | 9.58',
            CONCAT(@c, N' | ', ISNULL(CONVERT(VARCHAR(20), @a), N'NULL')),
            CASE WHEN @c = 1 AND @a = 9.58 THEN 'PASS' ELSE 'FAIL' END);

    /* ------------------------------------------------------------------
       2. INSERT REVIEW — cơ sở 6, review toàn 8 điểm
       ------------------------------------------------------------------ */
    INSERT INTO dbo.BOOKING
        ([STATUS], ADULTS, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
         CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES
        ('COMPLETED', 2, 'BK_TEST_DX_01', '9101', '2026-09-01',
         '2026-09-05', '2026-09-07', 1, 6);

    SET @b1 = (SELECT BOOKING_ID FROM dbo.BOOKING WHERE BOOKING_CODE = 'BK_TEST_DX_01');

    INSERT INTO dbo.REVIEW
        (TITLE, REVIEW_DATE, IS_VERIFIED_STAY, CLEANLINESS, COMFORT,
         [LOCATION], FACILITIES, STAFF, VALUE_FOR_MONEY, BOOKING_ID)
    VALUES
        (N'Test 2.2.2 - review 1', '2026-09-08', 1, 8, 8, 8, 8, 8, 8, @b1);

    SET @r1 = (SELECT REVIEW_ID FROM dbo.REVIEW WHERE BOOKING_ID = @b1);

    SELECT @a = OVERALL_SCORE FROM dbo.REVIEW WHERE REVIEW_ID = @r1;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'2a. INSERT review toàn 8 điểm -> OVERALL_SCORE',
            N'8.00',
            ISNULL(CONVERT(VARCHAR(20), @a), N'NULL'),
            CASE WHEN @a = 8.00 THEN 'PASS' ELSE 'FAIL' END);

    SELECT @c = REVIEW_COUNT, @a = AVERAGE_RATING
    FROM dbo.ACCOMMODATION WHERE ACCOMMODATION_ID = 6;

    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'2b. INSERT review -> cơ sở 6 có 1 review, điểm 8.00',
            N'1 | 8.00',
            CONCAT(@c, N' | ', ISNULL(CONVERT(VARCHAR(20), @a), N'NULL')),
            CASE WHEN @c = 1 AND @a = 8.00 THEN 'PASS' ELSE 'FAIL' END);

    /* ------------------------------------------------------------------
       3. THÊM REVIEW THỨ 2 CÙNG CƠ SỞ — trung bình (8 + 6) / 2 = 7
       ------------------------------------------------------------------ */
    INSERT INTO dbo.BOOKING
        ([STATUS], ADULTS, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
         CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES
        ('COMPLETED', 2, 'BK_TEST_DX_02', '9102', '2026-09-01',
         '2026-09-10', '2026-09-12', 1, 6);

    SET @b2 = (SELECT BOOKING_ID FROM dbo.BOOKING WHERE BOOKING_CODE = 'BK_TEST_DX_02');

    INSERT INTO dbo.REVIEW
        (TITLE, REVIEW_DATE, IS_VERIFIED_STAY, CLEANLINESS, COMFORT,
         [LOCATION], FACILITIES, STAFF, VALUE_FOR_MONEY, BOOKING_ID)
    VALUES
        (N'Test 2.2.2 - review 2', '2026-09-13', 1, 6, 6, 6, 6, 6, 6, @b2);

    SET @r2 = (SELECT REVIEW_ID FROM dbo.REVIEW WHERE BOOKING_ID = @b2);

    SELECT @c = REVIEW_COUNT, @a = AVERAGE_RATING
    FROM dbo.ACCOMMODATION WHERE ACCOMMODATION_ID = 6;

    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'3. Thêm review thứ 2 (8 và 6) -> trung bình 7.00',
            N'2 | 7.00',
            CONCAT(@c, N' | ', ISNULL(CONVERT(VARCHAR(20), @a), N'NULL')),
            CASE WHEN @c = 2 AND @a = 7.00 THEN 'PASS' ELSE 'FAIL' END);

    /* ------------------------------------------------------------------
       4. UPDATE ĐIỂM REVIEW 1 VỀ 5 -> trung bình (5 + 6) / 2 = 5.50
       ------------------------------------------------------------------ */
    UPDATE dbo.REVIEW
    SET CLEANLINESS = 5, COMFORT = 5, [LOCATION] = 5,
        FACILITIES = 5, STAFF = 5, VALUE_FOR_MONEY = 5
    WHERE REVIEW_ID = @r1;

    SELECT @a = OVERALL_SCORE FROM dbo.REVIEW WHERE REVIEW_ID = @r1;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'4a. UPDATE review 1 về 5 điểm -> OVERALL_SCORE',
            N'5.00',
            ISNULL(CONVERT(VARCHAR(20), @a), N'NULL'),
            CASE WHEN @a = 5.00 THEN 'PASS' ELSE 'FAIL' END);

    SELECT @c = REVIEW_COUNT, @a = AVERAGE_RATING
    FROM dbo.ACCOMMODATION WHERE ACCOMMODATION_ID = 6;

    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'4b. UPDATE review -> rating cơ sở 6 = 5.50',
            N'2 | 5.50',
            CONCAT(@c, N' | ', ISNULL(CONVERT(VARCHAR(20), @a), N'NULL')),
            CASE WHEN @c = 2 AND @a = 5.50 THEN 'PASS' ELSE 'FAIL' END);

    /* ------------------------------------------------------------------
       5. CHUYỂN REVIEW 2 SANG CƠ SỞ 7 (qua BOOKING_ID)
       Cơ sở 6 còn 1 review điểm 5; cơ sở 7 có 1 review điểm 6.
       ------------------------------------------------------------------ */
    INSERT INTO dbo.BOOKING
        ([STATUS], ADULTS, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
         CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES
        ('COMPLETED', 2, 'BK_TEST_DX_03', '9103', '2026-09-01',
         '2026-09-15', '2026-09-17', 1, 7);

    SET @b3 = (SELECT BOOKING_ID FROM dbo.BOOKING WHERE BOOKING_CODE = 'BK_TEST_DX_03');

    UPDATE dbo.REVIEW SET BOOKING_ID = @b3 WHERE REVIEW_ID = @r2;

    SELECT @c = REVIEW_COUNT, @a = AVERAGE_RATING
    FROM dbo.ACCOMMODATION WHERE ACCOMMODATION_ID = 6;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'5a. Chuyển review đi -> cơ sở 6 còn 1 review, điểm 5.00',
            N'1 | 5.00',
            CONCAT(@c, N' | ', ISNULL(CONVERT(VARCHAR(20), @a), N'NULL')),
            CASE WHEN @c = 1 AND @a = 5.00 THEN 'PASS' ELSE 'FAIL' END);

    SELECT @c = REVIEW_COUNT, @a = AVERAGE_RATING
    FROM dbo.ACCOMMODATION WHERE ACCOMMODATION_ID = 7;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'5b. Chuyển review đến -> cơ sở 7 có 1 review, điểm 6.00',
            N'1 | 6.00',
            CONCAT(@c, N' | ', ISNULL(CONVERT(VARCHAR(20), @a), N'NULL')),
            CASE WHEN @c = 1 AND @a = 6.00 THEN 'PASS' ELSE 'FAIL' END);

    /* ------------------------------------------------------------------
       6. CHUYỂN BOOKING 3 TỪ CƠ SỞ 7 VỀ CƠ SỞ 6
       Cơ sở 7 về 0 review; cơ sở 6 có 2 review, trung bình 5.50.
       ------------------------------------------------------------------ */
    UPDATE dbo.BOOKING SET ACCOMMODATION_ID = 6 WHERE BOOKING_ID = @b3;

    SELECT @c = REVIEW_COUNT, @a = AVERAGE_RATING
    FROM dbo.ACCOMMODATION WHERE ACCOMMODATION_ID = 7;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'6a. Đơn chuyển đi -> cơ sở 7 hết review',
            N'0 | NULL',
            CONCAT(@c, N' | ', ISNULL(CONVERT(VARCHAR(20), @a), N'NULL')),
            CASE WHEN @c = 0 AND @a IS NULL THEN 'PASS' ELSE 'FAIL' END);

    SELECT @c = REVIEW_COUNT, @a = AVERAGE_RATING
    FROM dbo.ACCOMMODATION WHERE ACCOMMODATION_ID = 6;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'6b. Đơn chuyển đến -> cơ sở 6 có 2 review, điểm 5.50',
            N'2 | 5.50',
            CONCAT(@c, N' | ', ISNULL(CONVERT(VARCHAR(20), @a), N'NULL')),
            CASE WHEN @c = 2 AND @a = 5.50 THEN 'PASS' ELSE 'FAIL' END);

    /* ------------------------------------------------------------------
       7. DELETE REVIEW 2 -> cơ sở 6 còn 1 review, điểm 5.00
       ------------------------------------------------------------------ */
    DELETE FROM dbo.REVIEW WHERE REVIEW_ID = @r2;

    SELECT @c = REVIEW_COUNT, @a = AVERAGE_RATING
    FROM dbo.ACCOMMODATION WHERE ACCOMMODATION_ID = 6;
    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'7. DELETE review -> cơ sở 6 còn 1 review, điểm 5.00',
            N'1 | 5.00',
            CONCAT(@c, N' | ', ISNULL(CONVERT(VARCHAR(20), @a), N'NULL')),
            CASE WHEN @c = 1 AND @a = 5.00 THEN 'PASS' ELSE 'FAIL' END);

    /* ------------------------------------------------------------------
       8. KIỂM TRA CHÉO TOÀN BỘ BẢNG
       ------------------------------------------------------------------ */
    SELECT @c = COUNT(*)
    FROM dbo.REVIEW AS r
    WHERE r.OVERALL_SCORE IS NULL
       OR r.OVERALL_SCORE <> ROUND(
            (r.CLEANLINESS + r.COMFORT + r.[LOCATION]
             + r.FACILITIES + r.STAFF + r.VALUE_FOR_MONEY) / 6.0, 2);

    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'8a. Toàn bộ REVIEW khớp công thức OVERALL_SCORE',
            N'0 dòng lệch',
            CONCAT(@c, N' dòng lệch'),
            CASE WHEN @c = 0 THEN 'PASS' ELSE 'FAIL' END);

    SELECT @c = COUNT(*)
    FROM dbo.ACCOMMODATION AS a
    JOIN dbo.vw_AccommodationRatingStats AS v
        ON v.ACCOMMODATION_ID = a.ACCOMMODATION_ID
    WHERE a.REVIEW_COUNT <> v.REVIEW_COUNT
       OR ISNULL(a.AVERAGE_RATING, -1) <> ISNULL(v.AVERAGE_RATING, -1);

    INSERT INTO @log (Test, Expected, Actual, Result)
    VALUES (N'8b. Toàn bộ ACCOMMODATION khớp rating tính lại',
            N'0 dòng lệch',
            CONCAT(@c, N' dòng lệch'),
            CASE WHEN @c = 0 THEN 'PASS' ELSE 'FAIL' END);

    /* ------------------------------------------------------------------
       KẾT QUẢ
       ------------------------------------------------------------------ */
    SELECT STT, Test, Expected, Actual, Result
    FROM @log
    ORDER BY STT;

    SET @pass = (SELECT COUNT(*) FROM @log WHERE Result = 'PASS');
    SET @fail = (SELECT COUNT(*) FROM @log WHERE Result = 'FAIL');

    PRINT CONCAT(N'KẾT QUẢ 2.2.2: ', @pass, N' PASS / ', @fail, N' FAIL');
    IF @fail = 0
        PRINT N'==> PASS toàn bộ. Trigger thuộc tính dẫn xuất hoạt động đúng.';
    ELSE
        PRINT N'==> CÓ CASE FAIL, xem bảng kết quả phía trên.';

    ROLLBACK TRANSACTION;
    PRINT N'Đã rollback: dữ liệu mẫu giữ nguyên.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;
    PRINT N'LỖI: ' + ERROR_MESSAGE();
    THROW;
END CATCH;
GO
