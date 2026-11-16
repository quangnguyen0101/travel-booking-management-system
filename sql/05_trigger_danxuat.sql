/*
===============================================================================
 BTL2 - Nhóm 5
 Phần 2.2.2: Trigger thuộc tính dẫn xuất
 Nguyễn Trương Đăng Quang

 THUỘC TÍNH CHỌN
   1. BOOKING.TOTAL_AMOUNT (thuộc tính chính của 2.2.2)
      = SUM(số đêm * ROOM_PRICE_AT_BOOKING * RESERVED_QUANTITY) - giảm giá
      giảm giá = VOUCHER.DISCOUNT_VALUE của BOOKING_VOUCHER (tối đa 1 voucher/đơn).
      Schema không có ROOM.BASE_PRICE / BOOKING_SERVICE / BOOKING_PROMOTION:
      - giá phòng lấy từ BOOKING_ROOM_TYPE.ROOM_PRICE_AT_BOOKING (đã chốt lúc
        đặt, nguồn là ROOM_RATE.UNIT_PRICE trong 03_crud) nên đổi ROOM_RATE về
        sau không hồi tố đơn cũ.
      - giảm giá lấy từ BOOKING_VOUCHER -> VOUCHER, không có % nên không cần
        nhân với tiền phòng.
      Không để âm: nếu giảm giá >= tiền phòng thì TOTAL_AMOUNT = 0.

   2. REVIEW.OVERALL_SCORE
      = trung bình 6 điểm thành phần CLEANLINESS, COMFORT, [LOCATION],
        FACILITIES, STAFF, VALUE_FOR_MONEY (thang 1..10).
   3. ACCOMMODATION.AVERAGE_RATING + ACCOMMODATION.REVIEW_COUNT
      = trung bình OVERALL_SCORE và số review của tất cả booking thuộc cơ sở.

   AVERAGE_RATING dùng OVERALL_SCORE (một thuộc tính dẫn xuất khác), nên
   OVERALL_SCORE phải được tính trước. File này đặt trigger tính điểm review
   chạy First và trigger tính rating cơ sở chạy Last cho INSERT/UPDATE trên
   REVIEW, đồng thời trigger rating luôn đọc lại OVERALL_SCORE từ bảng
   REVIEW, không lấy giá trị có sẵn trên dòng inserted.

 DML ẢNH HƯỞNG
   TOTAL_AMOUNT:
   - INSERT / UPDATE BOOKING (CHECK_IN_DATE, CHECK_OUT_DATE).
   - INSERT / UPDATE / DELETE BOOKING_ROOM_TYPE.
   - INSERT / UPDATE / DELETE BOOKING_VOUCHER.
   - UPDATE VOUCHER.DISCOUNT_VALUE.
   - DELETE VOUCHER bị FK_BOOKING_VOUCHER_VOUCHER chặn khi còn đơn dùng.
   OVERALL_SCORE / AVERAGE_RATING / REVIEW_COUNT:
   - INSERT / UPDATE / DELETE trên REVIEW.
   - UPDATE REVIEW.BOOKING_ID: review chuyển sang đơn (và cơ sở) khác.
   - UPDATE BOOKING.ACCOMMODATION_ID: đơn có review chuyển cơ sở.
   Không có DML nào khác làm đổi điểm review hoặc cơ sở của review.

 VÌ SAO KHÔNG DÙNG COMPUTED COLUMN
   - OVERALL_SCORE có thể dùng computed column cùng dòng, nhưng AVERAGE_RATING
     là aggregate nhiều dòng, nhiều bảng nên SQL Server không cho computed column.
   - Dùng trigger thống nhất cho cả hai, và tính lại được khi dữ liệu nguồn đổi.

 CHẠY
   Sau 01_schema.sql + 02_seed.sql (và 03_crud.sql nếu muốn test cùng 2.1).
   File chạy lại nhiều lần được: cột/ràng buộc có kiểm tra tồn tại, trigger
   được drop rồi tạo lại, dữ liệu cũ được backfill từ dữ liệu gốc.
===============================================================================
*/

USE [BTL2_Booking_Nhom5];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

/* ============================================================================
   0. BỔ SUNG CỘT CHO THUỘC TÍNH DẪN XUẤT
   Không sửa 01_schema.sql của người làm 1.1; đây là migration bổ sung.
   ============================================================================ */
IF COL_LENGTH(N'dbo.REVIEW', N'OVERALL_SCORE') IS NULL
    ALTER TABLE dbo.REVIEW ADD OVERALL_SCORE DECIMAL(4,2) NULL;
GO

IF COL_LENGTH(N'dbo.ACCOMMODATION', N'AVERAGE_RATING') IS NULL
    ALTER TABLE dbo.ACCOMMODATION ADD AVERAGE_RATING DECIMAL(4,2) NULL;
GO

IF COL_LENGTH(N'dbo.ACCOMMODATION', N'REVIEW_COUNT') IS NULL
    ALTER TABLE dbo.ACCOMMODATION
        ADD REVIEW_COUNT INT NOT NULL
            CONSTRAINT DF_ACCOMMODATION_REVIEW_COUNT DEFAULT (0);
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints
               WHERE name = N'DF_ACCOMMODATION_REVIEW_COUNT')
    ALTER TABLE dbo.ACCOMMODATION
        ADD CONSTRAINT DF_ACCOMMODATION_REVIEW_COUNT DEFAULT (0) FOR REVIEW_COUNT;
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = N'CK_REVIEW_OVERALL_SCORE'
                 AND parent_object_id = OBJECT_ID(N'dbo.REVIEW'))
    ALTER TABLE dbo.REVIEW
        ADD CONSTRAINT CK_REVIEW_OVERALL_SCORE
            CHECK (OVERALL_SCORE IS NULL OR OVERALL_SCORE BETWEEN 1 AND 10);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = N'CK_ACCOMMODATION_AVERAGE_RATING'
                 AND parent_object_id = OBJECT_ID(N'dbo.ACCOMMODATION'))
    ALTER TABLE dbo.ACCOMMODATION
        ADD CONSTRAINT CK_ACCOMMODATION_AVERAGE_RATING
            CHECK (AVERAGE_RATING IS NULL OR AVERAGE_RATING BETWEEN 1 AND 10);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = N'CK_ACCOMMODATION_REVIEW_COUNT'
                 AND parent_object_id = OBJECT_ID(N'dbo.ACCOMMODATION'))
    ALTER TABLE dbo.ACCOMMODATION
        ADD CONSTRAINT CK_ACCOMMODATION_REVIEW_COUNT
            CHECK (REVIEW_COUNT >= 0);
GO

/* ============================================================================
   1. VIEW TÍNH RATING TỪ DỮ LIỆU GỐC
   Dùng chung cho trigger REVIEW và trigger BOOKING, tránh lặp công thức.
   OUTER APPLY để cơ sở chưa có review vẫn có dòng REVIEW_COUNT = 0.
   ============================================================================ */
CREATE OR ALTER VIEW dbo.vw_AccommodationRatingStats
AS
SELECT a.ACCOMMODATION_ID,
       c.REVIEW_COUNT,
       v.AVERAGE_RATING
FROM dbo.ACCOMMODATION AS a
-- Đếm review có điểm để REVIEW_COUNT cùng tập với AVERAGE_RATING.
OUTER APPLY (
    SELECT COUNT(r.OVERALL_SCORE) AS REVIEW_COUNT
    FROM dbo.BOOKING AS b
    JOIN dbo.REVIEW AS r ON r.BOOKING_ID = b.BOOKING_ID
    WHERE b.ACCOMMODATION_ID = a.ACCOMMODATION_ID
) AS c
-- Chỉ lấy review có điểm; AVG không gặp NULL nên không phát warning.
OUTER APPLY (
    SELECT CAST(AVG(r.OVERALL_SCORE) AS DECIMAL(4,2)) AS AVERAGE_RATING
    FROM dbo.BOOKING AS b
    JOIN dbo.REVIEW AS r ON r.BOOKING_ID = b.BOOKING_ID
    WHERE b.ACCOMMODATION_ID = a.ACCOMMODATION_ID
      AND r.OVERALL_SCORE IS NOT NULL
) AS v;
GO

/* ============================================================================
   2. BACKFILL DỮ LIỆU ĐANG CÓ
   Chạy trước khi tạo trigger để không phụ thuộc trạng thái trigger cũ.
   ============================================================================ */
UPDATE dbo.REVIEW
SET OVERALL_SCORE = ROUND(
        (CLEANLINESS + COMFORT + [LOCATION] + FACILITIES + STAFF + VALUE_FOR_MONEY) / 6.0,
        2);
GO

UPDATE a
SET REVIEW_COUNT = v.REVIEW_COUNT,
    AVERAGE_RATING = v.AVERAGE_RATING
FROM dbo.ACCOMMODATION AS a
JOIN dbo.vw_AccommodationRatingStats AS v
    ON v.ACCOMMODATION_ID = a.ACCOMMODATION_ID;
GO

/* ============================================================================
   3. TRIGGER 1 — TÍNH OVERALL_SCORE TỪ 6 ĐIỂM THÀNH PHẦN
   Chạy First trên INSERT/UPDATE của REVIEW.
   ============================================================================ */
DROP TRIGGER IF EXISTS dbo.trg_Review_ComputeOverallScore;
GO

CREATE TRIGGER dbo.trg_Review_ComputeOverallScore
ON dbo.REVIEW
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Chặn tự gọi lại chính trigger này (nếu server bật recursive triggers).
    IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.trg_Review_ComputeOverallScore')) > 1
        RETURN;

    -- Luôn tính lại từ 6 điểm gốc, kể cả khi có người ghi trực tiếp
    -- OVERALL_SCORE: thuộc tính dẫn xuất không được phép sửa tay.

    UPDATE r
    SET OVERALL_SCORE = ROUND(
            (i.CLEANLINESS + i.COMFORT + i.[LOCATION]
             + i.FACILITIES + i.STAFF + i.VALUE_FOR_MONEY) / 6.0,
            2)
    FROM dbo.REVIEW AS r
    JOIN inserted AS i ON i.REVIEW_ID = r.REVIEW_ID;
END;
GO

/* ============================================================================
   4. TRIGGER 2 — CẬP NHẬT AVERAGE_RATING / REVIEW_COUNT CỦA CƠ SỞ
   Chạy Last trên INSERT/UPDATE/DELETE của REVIEW, sau trigger 1.
   Đọc lại OVERALL_SCORE từ bảng REVIEW nên không phụ thuộc inserted cũ.
   ============================================================================ */
DROP TRIGGER IF EXISTS dbo.trg_Accommodation_RefreshRating;
GO

CREATE TRIGGER dbo.trg_Accommodation_RefreshRating
ON dbo.REVIEW
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.trg_Accommodation_RefreshRating')) > 1
        RETURN;

    DECLARE @Affected TABLE (ACCOMMODATION_ID INT NOT NULL PRIMARY KEY);

    INSERT INTO @Affected (ACCOMMODATION_ID)
    SELECT DISTINCT b.ACCOMMODATION_ID
    FROM inserted AS i
    JOIN dbo.BOOKING AS b ON b.BOOKING_ID = i.BOOKING_ID
    UNION
    SELECT DISTINCT b.ACCOMMODATION_ID
    FROM deleted AS d
    JOIN dbo.BOOKING AS b ON b.BOOKING_ID = d.BOOKING_ID;

    UPDATE a
    SET REVIEW_COUNT = v.REVIEW_COUNT,
        AVERAGE_RATING = v.AVERAGE_RATING
    FROM dbo.ACCOMMODATION AS a
    JOIN dbo.vw_AccommodationRatingStats AS v
        ON v.ACCOMMODATION_ID = a.ACCOMMODATION_ID
    WHERE a.ACCOMMODATION_ID IN (SELECT ACCOMMODATION_ID FROM @Affected);
END;
GO

/* ============================================================================
   5. TRIGGER 3 — ĐƠN CHUYỂN CƠ SỞ THÌ RATING CỦA CẢ HAI CƠ SỞ ĐỔI
   REVIEW đi theo BOOKING, nên UPDATE BOOKING.ACCOMMODATION_ID cũng là DML
   làm đổi rating. Trigger này xử lý cả cơ sở cũ (deleted) và mới (inserted).
   ============================================================================ */
DROP TRIGGER IF EXISTS dbo.trg_Booking_RefreshAccommodationRating;
GO

CREATE TRIGGER dbo.trg_Booking_RefreshAccommodationRating
ON dbo.BOOKING
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(ACCOMMODATION_ID)
        RETURN;

    -- Chỉ làm việc khi thật sự có dòng đổi cơ sở.
    IF NOT EXISTS (
        SELECT 1
        FROM inserted AS i
        JOIN deleted AS d ON d.BOOKING_ID = i.BOOKING_ID
        WHERE i.ACCOMMODATION_ID <> d.ACCOMMODATION_ID
    )
        RETURN;

    DECLARE @Affected TABLE (ACCOMMODATION_ID INT NOT NULL PRIMARY KEY);

    INSERT INTO @Affected (ACCOMMODATION_ID)
    SELECT ACCOMMODATION_ID FROM inserted
    UNION
    SELECT ACCOMMODATION_ID FROM deleted;

    UPDATE a
    SET REVIEW_COUNT = v.REVIEW_COUNT,
        AVERAGE_RATING = v.AVERAGE_RATING
    FROM dbo.ACCOMMODATION AS a
    JOIN dbo.vw_AccommodationRatingStats AS v
        ON v.ACCOMMODATION_ID = a.ACCOMMODATION_ID
    WHERE a.ACCOMMODATION_ID IN (SELECT ACCOMMODATION_ID FROM @Affected);
END;
GO

/* ============================================================================
   6. BẢO ĐẢM THỨ TỰ TRIGGER TRÊN REVIEW
   Trigger 1 phải chạy trước trigger 2 để OVERALL_SCORE có giá trị mới.
   ============================================================================ */
EXEC sp_settriggerorder @triggername = N'dbo.trg_Review_ComputeOverallScore',
                        @order = N'First', @stmttype = N'INSERT';
EXEC sp_settriggerorder @triggername = N'dbo.trg_Review_ComputeOverallScore',
                        @order = N'First', @stmttype = N'UPDATE';
EXEC sp_settriggerorder @triggername = N'dbo.trg_Accommodation_RefreshRating',
                        @order = N'Last', @stmttype = N'INSERT';
EXEC sp_settriggerorder @triggername = N'dbo.trg_Accommodation_RefreshRating',
                        @order = N'Last', @stmttype = N'UPDATE';
GO

/* ============================================================================
   7. KIỂM TRA NHANH SAU KHI CÀI
   Kết quả luôn rỗng nếu mọi giá trị lưu khớp với dữ liệu gốc.
   ============================================================================ */
PRINT N'--- REVIEW lệch OVERALL_SCORE ---';
SELECT r.REVIEW_ID,
       r.OVERALL_SCORE AS DangLuu,
       ROUND((r.CLEANLINESS + r.COMFORT + r.[LOCATION]
              + r.FACILITIES + r.STAFF + r.VALUE_FOR_MONEY) / 6.0, 2) AS TinhLai
FROM dbo.REVIEW AS r
WHERE r.OVERALL_SCORE IS NULL
   OR r.OVERALL_SCORE <> ROUND((r.CLEANLINESS + r.COMFORT + r.[LOCATION]
              + r.FACILITIES + r.STAFF + r.VALUE_FOR_MONEY) / 6.0, 2);

PRINT N'--- ACCOMMODATION lệch AVERAGE_RATING / REVIEW_COUNT ---';
SELECT a.ACCOMMODATION_ID,
       a.REVIEW_COUNT AS CountDangLuu,
       v.REVIEW_COUNT AS CountTinhLai,
       a.AVERAGE_RATING AS AvgDangLuu,
       v.AVERAGE_RATING AS AvgTinhLai
FROM dbo.ACCOMMODATION AS a
JOIN dbo.vw_AccommodationRatingStats AS v
    ON v.ACCOMMODATION_ID = a.ACCOMMODATION_ID
WHERE a.REVIEW_COUNT <> v.REVIEW_COUNT
   OR ISNULL(a.AVERAGE_RATING, -1) <> ISNULL(v.AVERAGE_RATING, -1);

PRINT N'--- 2.2.2: đã tạo trigger OVERALL_SCORE, AVERAGE_RATING, REVIEW_COUNT ---';
GO

/* ============================================================================
   8. THUỘC TÍNH DẪN XUẤT CHÍNH — BOOKING.TOTAL_AMOUNT
   Công thức:
     tiền phòng = SUM(số đêm * ROOM_PRICE_AT_BOOKING * RESERVED_QUANTITY)
     giảm giá   = VOUCHER.DISCOUNT_VALUE của BOOKING_VOUCHER
     TOTAL_AMOUNT = MAX(tiền phòng - giảm giá, 0)
   Schema không có ROOM.BASE_PRICE / BOOKING_SERVICE / BOOKING_PROMOTION nên
   dùng BOOKING_ROOM_TYPE.ROOM_PRICE_AT_BOOKING (giá chốt lúc đặt) và
   BOOKING_VOUCHER -> VOUCHER. Đổi ROOM_RATE.UNIT_PRICE không hồi tố đơn cũ.

   ⚠ ĐÃ KIỂM CHỨNG với 04_trigger_rangbuoc.sql: trigger INSTEAD OF trên BOOKING
   không chặn UPDATE phát sinh từ trigger AFTER, nên cột này vẫn cập nhật đúng.
   ============================================================================ */

IF COL_LENGTH(N'dbo.BOOKING', N'TOTAL_AMOUNT') IS NULL
    ALTER TABLE dbo.BOOKING
        ADD TOTAL_AMOUNT DECIMAL(18,2) NOT NULL
            CONSTRAINT DF_BOOKING_TOTAL_AMOUNT DEFAULT (0);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = N'CK_BOOKING_TOTAL_AMOUNT'
                 AND parent_object_id = OBJECT_ID(N'dbo.BOOKING'))
    ALTER TABLE dbo.BOOKING
        ADD CONSTRAINT CK_BOOKING_TOTAL_AMOUNT CHECK (TOTAL_AMOUNT >= 0);
GO

/* ----------------------------------------------------------------------------
   9. VIEW TÍNH TOTAL_AMOUNT TỪ DỮ LIỆU GỐC
   Dùng chung cho 4 trigger, tránh lặp công thức.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_BookingTotalAmount
AS
SELECT b.BOOKING_ID,
       CAST(
           CASE
               WHEN ISNULL(d.DISCOUNT_VALUE, 0)
                    >= ISNULL(rt.AMOUNT_PER_NIGHT, 0)
                       * DATEDIFF(DAY, b.CHECK_IN_DATE, b.CHECK_OUT_DATE)
                   THEN 0
               ELSE ISNULL(rt.AMOUNT_PER_NIGHT, 0)
                    * DATEDIFF(DAY, b.CHECK_IN_DATE, b.CHECK_OUT_DATE)
                    - ISNULL(d.DISCOUNT_VALUE, 0)
           END
           AS DECIMAL(18,2)) AS TOTAL_AMOUNT
FROM dbo.BOOKING AS b
-- Số đêm phải nằm ngoài SUM: SQL Server cấm outer reference trong aggregate
-- (Msg 8124) nếu biểu thức còn cột khác.
OUTER APPLY (
    SELECT SUM(brt.ROOM_PRICE_AT_BOOKING * brt.RESERVED_QUANTITY) AS AMOUNT_PER_NIGHT
    FROM dbo.BOOKING_ROOM_TYPE AS brt
    WHERE brt.BOOKING_ID = b.BOOKING_ID
) AS rt
OUTER APPLY (
    SELECT MAX(v.DISCOUNT_VALUE) AS DISCOUNT_VALUE
    FROM dbo.BOOKING_VOUCHER AS bv
    JOIN dbo.VOUCHER AS v ON v.VOUCHER_CODE = bv.VOUCHER_CODE
    WHERE bv.BOOKING_ID = b.BOOKING_ID
) AS d;
GO

/* ----------------------------------------------------------------------------
   10. BACKFILL CÁC ĐƠN ĐANG CÓ
   Chạy trước khi tạo trigger để không phụ thuộc trạng thái trigger cũ.
   ---------------------------------------------------------------------------- */
UPDATE b
SET TOTAL_AMOUNT = v.TOTAL_AMOUNT
FROM dbo.BOOKING AS b
JOIN dbo.vw_BookingTotalAmount AS v ON v.BOOKING_ID = b.BOOKING_ID;
GO

/* ----------------------------------------------------------------------------
   11. TRIGGER TOTAL_AMOUNT — phủ đủ DML của mọi bảng nguồn
   ---------------------------------------------------------------------------- */

-- 11a. Đơn đổi ngày ở -> tính lại.
DROP TRIGGER IF EXISTS dbo.trg_Booking_ComputeTotalAmount;
GO

CREATE TRIGGER dbo.trg_Booking_ComputeTotalAmount
ON dbo.BOOKING
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.trg_Booking_ComputeTotalAmount')) > 1
        RETURN;

    UPDATE b
    SET TOTAL_AMOUNT = v.TOTAL_AMOUNT
    FROM dbo.BOOKING AS b
    JOIN inserted AS i ON i.BOOKING_ID = b.BOOKING_ID
    JOIN dbo.vw_BookingTotalAmount AS v ON v.BOOKING_ID = b.BOOKING_ID;
END;
GO

-- 11b. Thêm/sửa/xóa hạng phòng của đơn.
DROP TRIGGER IF EXISTS dbo.trg_BookingRoomType_RefreshTotalAmount;
GO

CREATE TRIGGER dbo.trg_BookingRoomType_RefreshTotalAmount
ON dbo.BOOKING_ROOM_TYPE
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.trg_BookingRoomType_RefreshTotalAmount')) > 1
        RETURN;

    UPDATE b
    SET TOTAL_AMOUNT = v.TOTAL_AMOUNT
    FROM dbo.BOOKING AS b
    JOIN (SELECT BOOKING_ID FROM inserted
          UNION
          SELECT BOOKING_ID FROM deleted) AS a ON a.BOOKING_ID = b.BOOKING_ID
    JOIN dbo.vw_BookingTotalAmount AS v ON v.BOOKING_ID = b.BOOKING_ID;
END;
GO

-- 11c. Gắn/đổi/bỏ voucher của đơn.
DROP TRIGGER IF EXISTS dbo.trg_BookingVoucher_RefreshTotalAmount;
GO

CREATE TRIGGER dbo.trg_BookingVoucher_RefreshTotalAmount
ON dbo.BOOKING_VOUCHER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.trg_BookingVoucher_RefreshTotalAmount')) > 1
        RETURN;

    UPDATE b
    SET TOTAL_AMOUNT = v.TOTAL_AMOUNT
    FROM dbo.BOOKING AS b
    JOIN (SELECT BOOKING_ID FROM inserted
          UNION
          SELECT BOOKING_ID FROM deleted) AS a ON a.BOOKING_ID = b.BOOKING_ID
    JOIN dbo.vw_BookingTotalAmount AS v ON v.BOOKING_ID = b.BOOKING_ID;
END;
GO

-- 11d. Voucher bị đổi mức giảm -> mọi đơn đang dùng voucher đó tính lại.
DROP TRIGGER IF EXISTS dbo.trg_Voucher_RefreshBookingTotal;
GO

CREATE TRIGGER dbo.trg_Voucher_RefreshBookingTotal
ON dbo.VOUCHER
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT UPDATE(DISCOUNT_VALUE)
        RETURN;

    IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.trg_Voucher_RefreshBookingTotal')) > 1
        RETURN;

    UPDATE b
    SET TOTAL_AMOUNT = v.TOTAL_AMOUNT
    FROM dbo.BOOKING AS b
    JOIN dbo.BOOKING_VOUCHER AS bv ON bv.BOOKING_ID = b.BOOKING_ID
    JOIN inserted AS i ON i.VOUCHER_CODE = bv.VOUCHER_CODE
    JOIN dbo.vw_BookingTotalAmount AS v ON v.BOOKING_ID = b.BOOKING_ID;
END;
GO

/* ============================================================================
   12. KIỂM TRA NHANH SAU KHI CÀI
   Kết quả luôn rỗng nếu TOTAL_AMOUNT khớp dữ liệu gốc.
   ============================================================================ */
PRINT N'--- BOOKING lệch TOTAL_AMOUNT ---';
SELECT b.BOOKING_ID,
       b.TOTAL_AMOUNT AS DangLuu,
       v.TOTAL_AMOUNT AS TinhLai
FROM dbo.BOOKING AS b
JOIN dbo.vw_BookingTotalAmount AS v ON v.BOOKING_ID = b.BOOKING_ID
WHERE b.TOTAL_AMOUNT <> v.TOTAL_AMOUNT;

PRINT N'--- 2.2.2: đã tạo BOOKING.TOTAL_AMOUNT + OVERALL_SCORE, AVERAGE_RATING, REVIEW_COUNT ---';
GO
