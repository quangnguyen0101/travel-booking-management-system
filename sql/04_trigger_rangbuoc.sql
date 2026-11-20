/*
===============================================================================
 BTL2 - Nhóm 5
 Việc 3 — Trigger ràng buộc nghiệp vụ -> Đáp ứng 2.2.1 (0.5đ)
 File nộp: 04_trigger_rangbuoc.sql
 Hệ quản trị CSDL: MS SQL Server (Chạy trực tiếp trên SSMS)

 1. RÀNG BUỘC NGHIỆP VỤ:
    - Mỗi HẠNG PHÒNG (ACCOMMODATION_ID, ROOM_NAME) không được bán vượt số
      phòng thực tế đang sẵn sàng.
    - "Phòng sẵn sàng" = phòng trong bảng ROOM có
      AVAILABILITY_STATUS <> 'MAINTENANCE'.
    - "Đã giữ" = tổng RESERVED_QUANTITY của các booking còn hiệu lực
      (STATUS <> 'CANCELLED') có khoảng lưu trú giao với khoảng đang xét:
          old.CHECK_IN_DATE < new.CHECK_OUT_DATE
          AND new.CHECK_IN_DATE < old.CHECK_OUT_DATE
    - Cho phép giáp ngày: khách mới nhận phòng đúng ngày khách cũ trả phòng
      (new.CHECK_IN_DATE = old.CHECK_OUT_DATE) không tính là trùng.

 2. DML ẢNH HƯỞNG:
    - INSERT / UPDATE trên dbo.BOOKING_ROOM_TYPE (thêm hạng phòng, đổi số
      lượng, đổi hạng phòng).
    - DELETE trên dbo.BOOKING_ROOM_TYPE chỉ giải phóng chỗ nên không cần chặn.
    - Đổi ngày/trạng thái trên BOOKING: thủ tục 2.1 gọi sp_Booking_ValidateStay
      trước khi ghi; trigger đọc lại ngày mới từ BOOKING khi dòng chi tiết
      được cập nhật (xem thứ tự UPDATE trong 03_crud.sql).

 3. VÌ SAO ĐẶT TRIGGER TRÊN BOOKING_ROOM_TYPE:
    - Lúc INSERT BOOKING, dòng BOOKING_ROOM_TYPE chưa tồn tại nên trigger trên
      BOOKING không biết hạng phòng và số lượng để kiểm tra.
    - Dùng AFTER (không dùng INSTEAD OF) để SCOPE_IDENTITY() trong
      sp_Booking_Insert vẫn trả đúng BOOKING_ID vừa tạo — đây là lỗi tích hợp
      của bản trigger cũ (issue #1).
    - Ràng buộc liên bảng/liên dòng nên không thể thay bằng CHECK constraint.

 4. MÃ LỖI: 52001 — vượt sức chứa của hạng phòng.
===============================================================================
*/

USE [BTL2_Booking_Nhom5];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET NOCOUNT ON;
GO

-- Bản cũ (INSTEAD OF trên BOOKING) không còn dùng; xóa nếu database đã cài.
IF OBJECT_ID(N'dbo.trg_Booking_NoOverlap', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Booking_NoOverlap;
GO
IF OBJECT_ID(N'dbo.trg_BookingRoomType_NoOverlap', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_BookingRoomType_NoOverlap;
GO

-- ============================================================================
-- PHẦN 1: TRIGGER KIỂM TRA SỨC CHỨA THEO HẠNG PHÒNG
-- ============================================================================
CREATE TRIGGER dbo.trg_BookingRoomType_NoOverlap
ON dbo.BOOKING_ROOM_TYPE
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- DELETE chỉ trả phòng về kho, không thể làm vượt sức chứa.
    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    DECLARE @NewBookingId      INT,
            @AccommodationId   INT,
            @RoomName          NVARCHAR(100),
            @AvailableRooms    INT,
            @ReservedRooms     INT,
            @RequestedRooms    SMALLINT,
            @CheckIn           DATE,
            @CheckOut          DATE,
            @ConflictBookingId INT,
            @ErrMsg            NVARCHAR(2048);

    ;WITH Capacity AS (
        SELECT r.ACCOMMODATION_ID, r.ROOM_NAME, COUNT(*) AS AVAILABLE_ROOMS
        FROM dbo.ROOM AS r
        WHERE r.AVAILABILITY_STATUS <> 'MAINTENANCE'
        GROUP BY r.ACCOMMODATION_ID, r.ROOM_NAME
    ),
    NewRows AS (
        SELECT i.BOOKING_ID, i.ACCOMMODATION_ID, i.ROOM_NAME, i.RESERVED_QUANTITY,
               b.CHECK_IN_DATE, b.CHECK_OUT_DATE
        FROM inserted AS i
        JOIN dbo.BOOKING AS b ON b.BOOKING_ID = i.BOOKING_ID
    ),
    Demand AS (
        SELECT n.BOOKING_ID, n.ACCOMMODATION_ID, n.ROOM_NAME, n.RESERVED_QUANTITY,
               n.CHECK_IN_DATE, n.CHECK_OUT_DATE,
               ISNULL(c.AVAILABLE_ROOMS, 0) AS AVAILABLE_ROOMS,
               -- Chỉ cộng các đơn khác đang hiệu lực và giao khoảng ngày.
               ISNULL((
                   SELECT SUM(o.RESERVED_QUANTITY)
                   FROM dbo.BOOKING_ROOM_TYPE AS o
                   JOIN dbo.BOOKING AS ob ON ob.BOOKING_ID = o.BOOKING_ID
                   WHERE o.ACCOMMODATION_ID = n.ACCOMMODATION_ID
                     AND o.ROOM_NAME = n.ROOM_NAME
                     AND ob.BOOKING_ID <> n.BOOKING_ID
                     AND ob.[STATUS] <> 'CANCELLED'
                     AND ob.CHECK_IN_DATE < n.CHECK_OUT_DATE
                     AND n.CHECK_IN_DATE < ob.CHECK_OUT_DATE
               ), 0) AS OTHER_RESERVED
        FROM NewRows AS n
        LEFT JOIN Capacity AS c
               ON c.ACCOMMODATION_ID = n.ACCOMMODATION_ID
              AND c.ROOM_NAME = n.ROOM_NAME
    )
    SELECT TOP (1)
        @NewBookingId    = d.BOOKING_ID,
        @AccommodationId = d.ACCOMMODATION_ID,
        @RoomName        = d.ROOM_NAME,
        @AvailableRooms  = d.AVAILABLE_ROOMS,
        @ReservedRooms   = d.OTHER_RESERVED,
        @RequestedRooms  = d.RESERVED_QUANTITY,
        @CheckIn         = d.CHECK_IN_DATE,
        @CheckOut        = d.CHECK_OUT_DATE
    FROM Demand AS d
    WHERE d.RESERVED_QUANTITY + d.OTHER_RESERVED > d.AVAILABLE_ROOMS
    ORDER BY d.BOOKING_ID, d.ROOM_NAME;

    IF @NewBookingId IS NULL
        RETURN;

    -- Lấy một đơn đang giữ chỗ để đưa vào thông báo lỗi.
    SELECT TOP (1) @ConflictBookingId = ob.BOOKING_ID
    FROM dbo.BOOKING_ROOM_TYPE AS o
    JOIN dbo.BOOKING AS ob ON ob.BOOKING_ID = o.BOOKING_ID
    WHERE o.ACCOMMODATION_ID = @AccommodationId
      AND o.ROOM_NAME = @RoomName
      AND ob.BOOKING_ID <> @NewBookingId
      AND ob.[STATUS] <> 'CANCELLED'
      AND ob.CHECK_IN_DATE < @CheckOut
      AND @CheckIn < ob.CHECK_OUT_DATE
    ORDER BY ob.BOOKING_ID;

    SET @ErrMsg = CONCAT(
        N'Trùng lịch: hạng phòng "', @RoomName, N'" (cơ sở ', @AccommodationId,
        N') chỉ có ', @AvailableRooms, N' phòng, đã giữ ', @ReservedRooms,
        N' phòng; đơn #', @NewBookingId, N' đặt thêm ', @RequestedRooms,
        N' phòng trong khoảng ', CONVERT(CHAR(10), @CheckIn, 23), N' - ',
        CONVERT(CHAR(10), @CheckOut, 23),
        CASE WHEN @ConflictBookingId IS NULL THEN N'.'
             ELSE CONCAT(N' (xung đột với BOOKING_ID = ', @ConflictBookingId, N').') END);

    THROW 52001, @ErrMsg, 1;
END;
GO

-- ============================================================================
-- PHẦN 2: KỊCH BẢN TEST (TỰ DỌN DỮ LIỆU, CHẠY LẠI NHIỀU LẦN)
-- Dùng cơ sở 5 (Old Quarter Studio: 2 phòng) và cơ sở 1
-- (Deluxe River View: 2 phòng; Executive Suite: 1 phòng vì 202 đang bảo trì).
-- Ngày test đặt năm 2031 để không giao với dữ liệu mẫu.
-- Ca mong đợi lỗi chạy trong transaction riêng rồi ROLLBACK toàn bộ, vì THROW
-- từ trigger làm transaction không thể rollback về savepoint.
-- ============================================================================
SET NOCOUNT ON;
SET XACT_ABORT OFF;
GO

-- Dọn dữ liệu test còn sót nếu lần chạy trước bị lỗi giữa chừng.
DELETE brt
FROM dbo.BOOKING_ROOM_TYPE AS brt
JOIN dbo.BOOKING AS b ON b.BOOKING_ID = brt.BOOKING_ID
WHERE b.BOOKING_CODE LIKE 'T04[_]%' OR b.SPECIAL_REQUESTS = N'T04_TEST';
DELETE FROM dbo.BOOKING
WHERE BOOKING_CODE LIKE 'T04[_]%' OR SPECIAL_REQUESTS = N'T04_TEST';
GO

DECLARE @log TABLE (
    STT INT IDENTITY(1,1),
    TestCase NVARCHAR(200),
    Expected NVARCHAR(60),
    Actual NVARCHAR(400),
    Result CHAR(4)
);
DECLARE @pass INT = 0, @fail INT = 0;
DECLARE @guest INT = (SELECT MIN(USER_ID) FROM dbo.GUEST);
DECLARE @newId INT = NULL;
DECLARE @b1 INT, @b2 INT, @b3 INT, @b4 INT, @b5 INT, @b6 INT, @b7 INT,
        @b8 INT, @b9 INT, @b10 INT, @b11 INT, @b12 INT, @b13 INT, @b14 INT,
        @b15 INT, @b16 INT, @b17 INT;

BEGIN TRY
    -- 1. Đặt 2/2 phòng của Old Quarter Studio: hợp lệ.
    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 1, 0, 'T04_01', '1111', '2031-01-01', '2031-01-10', '2031-01-12', @guest, 5);
    SET @b1 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (@b1, 5, N'Old Quarter Studio', 1200000, 2);
    INSERT @log VALUES (N'1. Đặt đủ 2/2 phòng', N'KHÔNG LỖI',
        N'Đã thêm đơn #' + CONVERT(NVARCHAR(12), @b1), 'PASS');

    -- 2. Đơn thứ hai trùng ngày, xin thêm 1 phòng: phải bị chặn 52001.
    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                            CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
        VALUES ('PENDING', 1, 0, 'T04_02', '1111', '2031-01-01', '2031-01-11', '2031-01-13', @guest, 5);
        SET @b2 = SCOPE_IDENTITY();
        INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
        VALUES (@b2, 5, N'Old Quarter Studio', 1200000, 1);
        ROLLBACK TRANSACTION;
        INSERT @log VALUES (N'2. Trùng ngày, vượt 1 phòng', N'LỖI 52001', N'FAIL: không chặn được', 'FAIL');
    END TRY
    BEGIN CATCH
        DECLARE @e2 INT = ERROR_NUMBER(), @m2 NVARCHAR(400) = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT @log VALUES (N'2. Trùng ngày, vượt 1 phòng', N'LỖI 52001',
            CASE WHEN @e2 = 52001 THEN N'PASS: ' + @m2 ELSE CONCAT(N'FAIL: lỗi ', @e2, N' - ', @m2) END,
            CASE WHEN @e2 = 52001 THEN 'PASS' ELSE 'FAIL' END);
    END CATCH;

    -- 3. Giáp ngày (check_out cũ = check_in mới), xin 2 phòng: hợp lệ.
    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('CONFIRMED', 1, 0, 'T04_03', '1111', '2031-01-01', '2031-01-12', '2031-01-14', @guest, 5);
    SET @b3 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (@b3, 5, N'Old Quarter Studio', 1200000, 2);
    INSERT @log VALUES (N'3. Giáp ngày, đặt 2 phòng', N'KHÔNG LỖI',
        N'Đã thêm đơn #' + CONVERT(NVARCHAR(12), @b3), 'PASS');

    -- 4. Cùng cơ sở, cùng ngày nhưng KHÁC hạng phòng: hợp lệ.
    BEGIN TRY
        INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                            CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
        VALUES ('CONFIRMED', 2, 0, 'T04_04A', '1111', '2031-01-01', '2031-02-01', '2031-02-03', @guest, 1);
        SET @b4 = SCOPE_IDENTITY();
        INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
        VALUES (@b4, 1, N'Deluxe River View', 2500000, 2);

        INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                            CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
        VALUES ('CONFIRMED', 2, 0, 'T04_04B', '1111', '2031-01-01', '2031-02-01', '2031-02-03', @guest, 1);
        SET @b5 = SCOPE_IDENTITY();
        INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
        VALUES (@b5, 1, N'Executive Suite', 4200000, 1);

        INSERT @log VALUES (N'4. Khác hạng, cùng cơ sở và ngày', N'KHÔNG LỖI',
            N'Đã thêm Deluxe 2 phòng + Executive 1 phòng', 'PASS');
    END TRY
    BEGIN CATCH
        DECLARE @e4 INT = ERROR_NUMBER(), @m4 NVARCHAR(400) = ERROR_MESSAGE();
        INSERT @log VALUES (N'4. Khác hạng, cùng cơ sở và ngày', N'KHÔNG LỖI',
            CONCAT(N'FAIL: lỗi ', @e4, N' - ', @m4), 'FAIL');
    END CATCH;

    -- 5. Đơn CANCELLED không chiếm chỗ: đặt 2 phòng CANCELLED rồi 2 phòng khác vẫn hợp lệ.
    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('CANCELLED', 1, 0, 'T04_05A', '1111', '2031-01-01', '2031-03-01', '2031-03-03', @guest, 5);
    SET @b6 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (@b6, 5, N'Old Quarter Studio', 1200000, 2);

    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('CONFIRMED', 1, 0, 'T04_05B', '1111', '2031-01-01', '2031-03-01', '2031-03-03', @guest, 5);
    SET @b7 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (@b7, 5, N'Old Quarter Studio', 1200000, 2);
    INSERT @log VALUES (N'5. Đơn CANCELLED không tính sức chứa', N'KHÔNG LỖI',
        N'Đơn CANCELLED + đơn mới 2 phòng', 'PASS');

    -- 6. UPDATE tăng số lượng vượt sức chứa: phải bị chặn.
    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 1, 0, 'T04_06A', '1111', '2031-01-01', '2031-04-01', '2031-04-03', @guest, 5);
    SET @b8 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (@b8, 5, N'Old Quarter Studio', 1200000, 1);

    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 1, 0, 'T04_06B', '1111', '2031-01-01', '2031-04-01', '2031-04-03', @guest, 5);
    SET @b9 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (@b9, 5, N'Old Quarter Studio', 1200000, 1);

    BEGIN TRY
        BEGIN TRANSACTION;
        UPDATE dbo.BOOKING_ROOM_TYPE SET RESERVED_QUANTITY = 2 WHERE BOOKING_ID = @b8;
        ROLLBACK TRANSACTION;
        INSERT @log VALUES (N'6. UPDATE tăng lên 3/2 phòng', N'LỖI 52001', N'FAIL: không chặn được', 'FAIL');
    END TRY
    BEGIN CATCH
        DECLARE @e6 INT = ERROR_NUMBER(), @m6 NVARCHAR(400) = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT @log VALUES (N'6. UPDATE tăng lên 3/2 phòng', N'LỖI 52001',
            CASE WHEN @e6 = 52001 THEN N'PASS: ' + @m6 ELSE CONCAT(N'FAIL: lỗi ', @e6, N' - ', @m6) END,
            CASE WHEN @e6 = 52001 THEN 'PASS' ELSE 'FAIL' END);
    END CATCH;

    -- 7. UPDATE giảm số lượng: hợp lệ.
    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 2, 0, 'T04_07', '1111', '2031-01-01', '2031-05-01', '2031-05-03', @guest, 5);
    SET @b10 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (@b10, 5, N'Old Quarter Studio', 1200000, 2);

    BEGIN TRY
        UPDATE dbo.BOOKING_ROOM_TYPE SET RESERVED_QUANTITY = 1 WHERE BOOKING_ID = @b10;
        INSERT @log VALUES (N'7. UPDATE giảm 2 -> 1 phòng', N'KHÔNG LỖI', N'Đã giảm còn 1 phòng', 'PASS');
    END TRY
    BEGIN CATCH
        DECLARE @e7 INT = ERROR_NUMBER(), @m7 NVARCHAR(400) = ERROR_MESSAGE();
        INSERT @log VALUES (N'7. UPDATE giảm 2 -> 1 phòng', N'KHÔNG LỖI',
            CONCAT(N'FAIL: lỗi ', @e7, N' - ', @m7), 'FAIL');
    END CATCH;

    -- 8. Xóa dòng chi tiết giải phóng chỗ: đơn khác đặt lại được.
    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 2, 0, 'T04_08A', '1111', '2031-01-01', '2031-06-01', '2031-06-03', @guest, 5);
    SET @b11 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (@b11, 5, N'Old Quarter Studio', 1200000, 2);

    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 1, 0, 'T04_08B', '1111', '2031-01-01', '2031-06-01', '2031-06-03', @guest, 5);
    SET @b12 = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
        VALUES (@b12, 5, N'Old Quarter Studio', 1200000, 1);
        ROLLBACK TRANSACTION;
        INSERT @log VALUES (N'8. Xóa chi tiết rồi đặt lại', N'CHẶN RỒI CHO PHÉP', N'FAIL: không chặn được', 'FAIL');
    END TRY
    BEGIN CATCH
        DECLARE @e8 INT = ERROR_NUMBER(), @m8 NVARCHAR(400) = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DELETE dbo.BOOKING_ROOM_TYPE WHERE BOOKING_ID = @b11;
        BEGIN TRY
            INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
            VALUES (@b12, 5, N'Old Quarter Studio', 1200000, 1);
            INSERT @log VALUES (N'8. Xóa chi tiết rồi đặt lại', N'CHẶN RỒI CHO PHÉP',
                CASE WHEN @e8 = 52001 THEN N'PASS: chặn đúng, sau khi xóa thì đặt được' ELSE CONCAT(N'FAIL: lỗi ', @e8) END,
                CASE WHEN @e8 = 52001 THEN 'PASS' ELSE 'FAIL' END);
        END TRY
        BEGIN CATCH
            DECLARE @e8b INT = ERROR_NUMBER(), @m8b NVARCHAR(400) = ERROR_MESSAGE();
            INSERT @log VALUES (N'8. Xóa chi tiết rồi đặt lại', N'CHẶN RỒI CHO PHÉP',
                CONCAT(N'FAIL: sau khi xóa vẫn lỗi ', @e8b, N' - ', @m8b), 'FAIL');
        END CATCH;
    END CATCH;

    -- 9. Phòng MAINTENANCE không được tính: Executive Suite chỉ còn 1 phòng.
    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 2, 0, 'T04_09A', '1111', '2031-01-01', '2031-07-01', '2031-07-03', @guest, 1);
    SET @b13 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (@b13, 1, N'Executive Suite', 4200000, 1);

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                            CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
        VALUES ('PENDING', 2, 0, 'T04_09B', '1111', '2031-01-01', '2031-07-01', '2031-07-03', @guest, 1);
        SET @b14 = SCOPE_IDENTITY();
        INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
        VALUES (@b14, 1, N'Executive Suite', 4200000, 1);
        ROLLBACK TRANSACTION;
        INSERT @log VALUES (N'9. Phòng MAINTENANCE không tính', N'LỖI 52001', N'FAIL: không chặn được', 'FAIL');
    END TRY
    BEGIN CATCH
        DECLARE @e9 INT = ERROR_NUMBER(), @m9 NVARCHAR(400) = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT @log VALUES (N'9. Phòng MAINTENANCE không tính', N'LỖI 52001',
            CASE WHEN @e9 = 52001 THEN N'PASS: ' + @m9 ELSE CONCAT(N'FAIL: lỗi ', @e9, N' - ', @m9) END,
            CASE WHEN @e9 = 52001 THEN 'PASS' ELSE 'FAIL' END);
    END CATCH;

    -- 10. INSERT nhiều dòng trong một câu: cả câu phải bị chặn, không lưu nửa vời.
    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 1, 0, 'T04_10A', '1111', '2031-01-01', '2031-08-01', '2031-08-03', @guest, 5);
    SET @b15 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (@b15, 5, N'Old Quarter Studio', 1200000, 1);

    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 1, 0, 'T04_10B', '1111', '2031-01-01', '2031-08-01', '2031-08-03', @guest, 5);
    SET @b16 = SCOPE_IDENTITY();
    INSERT dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                        CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 1, 0, 'T04_10C', '1111', '2031-01-01', '2031-08-01', '2031-08-03', @guest, 5);
    SET @b17 = SCOPE_IDENTITY();

    BEGIN TRY
        BEGIN TRANSACTION;
        INSERT dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
        VALUES (@b16, 5, N'Old Quarter Studio', 1200000, 1),
               (@b17, 5, N'Old Quarter Studio', 1200000, 1);
        ROLLBACK TRANSACTION;
        INSERT @log VALUES (N'10. INSERT 2 dòng vượt sức chứa', N'LỖI 52001', N'FAIL: không chặn được', 'FAIL');
    END TRY
    BEGIN CATCH
        DECLARE @e10 INT = ERROR_NUMBER(), @m10 NVARCHAR(400) = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        INSERT @log VALUES (N'10. INSERT 2 dòng vượt sức chứa', N'LỖI 52001',
            CASE WHEN @e10 = 52001 THEN N'PASS: ' + @m10 ELSE CONCAT(N'FAIL: lỗi ', @e10, N' - ', @m10) END,
            CASE WHEN @e10 = 52001 THEN 'PASS' ELSE 'FAIL' END);
    END CATCH;

    -- 11. sp_Booking_Insert phải chạy được khi đã cài trigger (lỗi 515 của issue #1).
    BEGIN TRY
        EXEC dbo.sp_Booking_Insert @UserId = @guest, @AccommodationId = 5,
             @RoomName = N'Old Quarter Studio', @CheckIn = '2031-09-01', @CheckOut = '2031-09-03',
             @Adults = 1, @SpecialRequests = N'T04_TEST', @BookingId = @newId OUTPUT;

        IF @newId IS NOT NULL
           AND EXISTS (SELECT 1 FROM dbo.BOOKING_ROOM_TYPE WHERE BOOKING_ID = @newId)
            INSERT @log VALUES (N'11. sp_Booking_Insert sau khi cài trigger', N'KHÔNG LỖI 515',
                                N'PASS: tạo được BOOKING_ID = ' + CONVERT(NVARCHAR(12), @newId) + N' và dòng chi tiết', 'PASS');
        ELSE
            INSERT @log VALUES (N'11. sp_Booking_Insert sau khi cài trigger', N'KHÔNG LỖI 515',
                                N'FAIL: thủ tục không trả BOOKING_ID hoặc thiếu dòng chi tiết', 'FAIL');
    END TRY
    BEGIN CATCH
        DECLARE @e11 INT = ERROR_NUMBER(), @m11 NVARCHAR(400) = ERROR_MESSAGE();
        INSERT @log VALUES (N'11. sp_Booking_Insert sau khi cài trigger', N'KHÔNG LỖI 515',
                            CONCAT(N'FAIL: lỗi ', @e11, N' - ', @m11), 'FAIL');
    END CATCH;

    SELECT STT, TestCase, Expected, Actual, Result FROM @log ORDER BY STT;

    SET @pass = (SELECT COUNT(*) FROM @log WHERE Result = 'PASS');
    SET @fail = (SELECT COUNT(*) FROM @log WHERE Result = 'FAIL');
    PRINT CONCAT(N'KẾT QUẢ 2.2.1: ', @pass, N' PASS / ', @fail, N' FAIL');
    IF @fail = 0
        PRINT N'==> PASS toàn bộ. Trigger ràng buộc sức chứa hoạt động đúng.';
    ELSE
        PRINT N'==> CÓ CA FAIL. Xem bảng kết quả phía trên.';
END TRY
BEGIN CATCH
    DECLARE @e INT = ERROR_NUMBER(), @m NVARCHAR(500) = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT STT, TestCase, Expected, Actual, Result FROM @log ORDER BY STT;
    PRINT CONCAT(N'TEST ABORT: lỗi ', @e, N' - ', @m);
    THROW;
END CATCH;

-- Dọn toàn bộ dữ liệu test (kể cả đơn tạo bởi sp_Booking_Insert ở test 11).
DELETE brt
FROM dbo.BOOKING_ROOM_TYPE AS brt
JOIN dbo.BOOKING AS b ON b.BOOKING_ID = brt.BOOKING_ID
WHERE b.BOOKING_CODE LIKE 'T04[_]%' OR b.SPECIAL_REQUESTS = N'T04_TEST';
DELETE FROM dbo.BOOKING
WHERE BOOKING_CODE LIKE 'T04[_]%' OR SPECIAL_REQUESTS = N'T04_TEST';
PRINT N'Đã dọn dữ liệu test.';
GO
