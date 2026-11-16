/*
===============================================================================
 BTL2 - Nhóm 5
 Việc 3 — Trigger ràng buộc nghiệp vụ -> Đáp ứng 2.2.1 (0.5đ)
 File nộp: 04_trigger_rangbuoc.sql
 Hệ quản trị CSDL: MS SQL Server (Chạy trực tiếp trên SSMS)
===============================================================================

 1. RÀNG BUỘC NGHIỆP VỤ:
    - Một phòng / chỗ nghỉ (ACCOMMODATION_ID trong bảng BOOKING) không được có
      2 booking "đang hiệu lực" (STATUS thuộc 'PENDING', 'CONFIRMED', 'CHECKED_IN')
      trùng khoảng thời gian lưu trú [CHECK_IN_DATE, CHECK_OUT_DATE).
    - Điều kiện trùng lịch (overlap):
          inserted.CHECK_IN_DATE < old.CHECK_OUT_DATE
          AND inserted.CHECK_OUT_DATE > old.CHECK_IN_DATE
    - Cho phép giáp ngày (khách mới nhận phòng đúng vào ngày khách cũ trả phòng:
      inserted.CHECK_IN_DATE = old.CHECK_OUT_DATE).

 2. DML ẢNH HƯỞNG:
    - INSERT INTO dbo.BOOKING
    - UPDATE dbo.BOOKING khi đổi: ACCOMMODATION_ID (room_id), CHECK_IN_DATE (check_in),
      CHECK_OUT_DATE (check_out), [STATUS] (status).

 3. LÝ DO KHÔNG DÙNG CHECK CONSTRAINT:
    - Ràng buộc CHECK chỉ kiểm tra được biểu thức giữa các cột trên CÙNG MỘT DÒNG
      (single-row), không thể truy vấn đối chiếu dòng đang thêm/sửa (inserted)
      với các dòng khác đã tồn tại trong bảng BOOKING, và không thể lấy mã
      BOOKING_ID xung đột để ném thông báo lỗi động bằng lệnh THROW.
===============================================================================
*/

USE [BTL2_Booking_Nhom5];
GO
SET NOCOUNT ON;
GO

-- Xóa trigger cũ nếu đã tồn tại để tạo mới
IF OBJECT_ID(N'dbo.trg_Booking_NoOverlap', N'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Booking_NoOverlap;
GO

-- ============================================================================
-- PHẦN 1: TẠO TRIGGER trg_Booking_NoOverlap (INSTEAD OF INSERT, UPDATE)
-- ============================================================================
CREATE TRIGGER dbo.trg_Booking_NoOverlap
ON dbo.BOOKING
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    DECLARE @IsUpdate BIT = CASE WHEN EXISTS (SELECT 1 FROM deleted) THEN 1 ELSE 0 END;

    -- Chỉ kiểm tra khi INSERT hoặc khi UPDATE các cột ảnh hưởng đến lịch & trạng thái
    IF @IsUpdate = 0
       OR UPDATE(ACCOMMODATION_ID)
       OR UPDATE(CHECK_IN_DATE)
       OR UPDATE(CHECK_OUT_DATE)
       OR UPDATE([STATUS])
    BEGIN
        DECLARE @ConflictBookingID INT = NULL;
        DECLARE @ConflictCode VARCHAR(30) = NULL;
        DECLARE @AccomID INT = NULL;
        DECLARE @NewCheckIn DATE = NULL;
        DECLARE @NewCheckOut DATE = NULL;

        -- Kiểm tra trùng lịch giữa dòng mới/sửa (inserted) với các booking đang có (old)
        SELECT TOP (1)
            @ConflictBookingID = old.BOOKING_ID,
            @ConflictCode      = old.BOOKING_CODE,
            @AccomID           = i.ACCOMMODATION_ID,
            @NewCheckIn        = i.CHECK_IN_DATE,
            @NewCheckOut       = i.CHECK_OUT_DATE
        FROM inserted AS i
        INNER JOIN dbo.BOOKING AS old
            ON i.ACCOMMODATION_ID = old.ACCOMMODATION_ID
           AND old.BOOKING_ID <> ISNULL(i.BOOKING_ID, -1) -- Tránh tự so sánh với chính mình khi UPDATE
        WHERE i.[STATUS] IN ('PENDING', 'CONFIRMED', 'CHECKED_IN')
          AND old.[STATUS] IN ('PENDING', 'CONFIRMED', 'CHECKED_IN')
          AND i.CHECK_IN_DATE < old.CHECK_OUT_DATE
          AND i.CHECK_OUT_DATE > old.CHECK_IN_DATE
        ORDER BY old.BOOKING_ID;

        -- Nếu phát hiện trùng lịch -> THROW lỗi kèm BOOKING_ID xung đột
        IF @ConflictBookingID IS NOT NULL
        BEGIN
            DECLARE @ErrMsg NVARCHAR(400) = FORMATMESSAGE(
                N'Vi pham rang buoc trung lich! Phong/Co so (ACCOMMODATION_ID = %d) khoang [%s -> %s) bi trung voi BOOKING_ID = %d (Ma don: %s).',
                @AccomID,
                CONVERT(VARCHAR(10), @NewCheckIn, 23),
                CONVERT(VARCHAR(10), @NewCheckOut, 23),
                @ConflictBookingID,
                @ConflictCode
            );
            THROW 52001, @ErrMsg, 1;
        END;
    END;

    -- Nếu hợp lệ (không trùng lịch) -> Thực hiện INSERT hoặc UPDATE vào bảng dbo.BOOKING
    IF @IsUpdate = 0
    BEGIN
        INSERT INTO dbo.BOOKING (
            [STATUS],
            ADULTS,
            CHILDREN,
            BOOKING_CODE,
            PIN_CODE,
            BOOKING_DATE,
            CHECK_IN_DATE,
            CHECK_OUT_DATE,
            ESTIMATED_ARRIVAL_TIME,
            SPECIAL_REQUESTS,
            USER_ID,
            ACCOMMODATION_ID
        )
        SELECT
            ISNULL(i.[STATUS], 'PENDING'),
            i.ADULTS,
            ISNULL(i.CHILDREN, 0),
            i.BOOKING_CODE,
            i.PIN_CODE,
            ISNULL(i.BOOKING_DATE, CONVERT(DATE, SYSDATETIME())),
            i.CHECK_IN_DATE,
            i.CHECK_OUT_DATE,
            i.ESTIMATED_ARRIVAL_TIME,
            i.SPECIAL_REQUESTS,
            i.USER_ID,
            i.ACCOMMODATION_ID
        FROM inserted AS i;
    END
    ELSE
    BEGIN
        UPDATE b
        SET b.[STATUS]               = i.[STATUS],
            b.ADULTS                 = i.ADULTS,
            b.CHILDREN               = i.CHILDREN,
            b.BOOKING_CODE           = i.BOOKING_CODE,
            b.PIN_CODE               = i.PIN_CODE,
            b.BOOKING_DATE           = i.BOOKING_DATE,
            b.CHECK_IN_DATE          = i.CHECK_IN_DATE,
            b.CHECK_OUT_DATE         = i.CHECK_OUT_DATE,
            b.ESTIMATED_ARRIVAL_TIME = i.ESTIMATED_ARRIVAL_TIME,
            b.SPECIAL_REQUESTS       = i.SPECIAL_REQUESTS,
            b.USER_ID                = i.USER_ID,
            b.ACCOMMODATION_ID       = i.ACCOMMODATION_ID
        FROM dbo.BOOKING AS b
        INNER JOIN inserted AS i
            ON b.BOOKING_ID = i.BOOKING_ID;
    END;
END;
GO

-- ============================================================================
-- PHẦN 2: KỊCH BẢN TEST TRÊN SSMS (CHẠY F5 NHIỀU LẦN KHÔNG LỖI)
-- Dữ liệu mẫu đối chiếu từ 02_seed.sql:
--   + BOOKING_ID = 11 (BK20260011): ACCOMMODATION_ID = 3, STATUS = 'CONFIRMED',
--     khoảng ngày [2026-11-20 -> 2026-11-22).
--   + BOOKING_ID = 6  (BK20260006): ACCOMMODATION_ID = 2, STATUS = 'CANCELLED',
--     khoảng ngày [2026-10-10 -> 2026-10-12).
-- ============================================================================

-- Xóa các dòng test cũ (nếu có) để có thể bấm F5 chạy lại bất kỳ lúc nào
DELETE FROM dbo.BOOKING WHERE BOOKING_CODE LIKE 'BK_TEST_%';

DECLARE @TestLog TABLE (
    STT INT IDENTITY(1,1),
    Kich_Ban_Test NVARCHAR(100),
    Thao_Tac_DML NVARCHAR(180),
    Ky_Vong NVARCHAR(40),
    Ket_Qua_Test_Log NVARCHAR(400)
);

PRINT N'===============================================================================';
PRINT N'TEST LOG — KIỂM THỬ TRIGGER trg_Booking_NoOverlap TRÊN SSMS';
PRINT N'===============================================================================';

-- ----------------------------------------------------------------------------
-- TEST 1: Chồng lấn 1 ngày với đơn đang hiệu lực (Kỳ vọng: LỖI - BỊ CHẶN)
-- Đơn 11 đang giữ ACCOMMODATION_ID = 3 từ 2026-11-20 đến 2026-11-22 (CONFIRMED).
-- Thử đặt ACCOMMODATION_ID = 3 từ 2026-11-21 đến 2026-11-24 (trùng ngày 21/11).
-- ----------------------------------------------------------------------------
BEGIN TRY
    INSERT INTO dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE, CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 2, 0, 'BK_TEST_OVERLAP', '9001', '2026-11-01', '2026-11-21', '2026-11-24', 2, 3);

    INSERT INTO @TestLog VALUES (N'1. Chồng lấn 1 ngày', N'INSERT ACCOM=3 [2026-11-21 -> 2026-11-24)', N'BÁO LỖI', N'FAIL: Không chặn được');
END TRY
BEGIN CATCH
    INSERT INTO @TestLog VALUES (N'1. Chồng lấn 1 ngày', N'INSERT ACCOM=3 [2026-11-21 -> 2026-11-24)', N'BÁO LỖI', N'PASS (Đã chặn): ' + ERROR_MESSAGE());
    PRINT N'[PASS - TEST 1 (Chồng lấn 1 ngày -> Bị chặn)]: ' + ERROR_MESSAGE();
END CATCH;

-- ----------------------------------------------------------------------------
-- TEST 2: Giáp ngày check_out cũ = check_in mới (Kỳ vọng: KHÔNG LỖI)
-- Đơn 11 trả phòng ngày 2026-11-22 tại ACCOMMODATION_ID = 3.
-- Đặt mới nhận phòng đúng ngày 2026-11-22 đến 2026-11-25 tại ACCOMMODATION_ID = 3.
-- ----------------------------------------------------------------------------
BEGIN TRY
    INSERT INTO dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE, CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('CONFIRMED', 2, 0, 'BK_TEST_ADJACENT', '9002', '2026-11-01', '2026-11-22', '2026-11-25', 2, 3);

    INSERT INTO @TestLog VALUES (N'2. Giáp ngày (check_out = check_in)', N'INSERT ACCOM=3 [2026-11-22 -> 2026-11-25)', N'KHÔNG LỖI', N'PASS: Thêm thành công đơn BK_TEST_ADJACENT');
    PRINT N'[PASS - TEST 2 (Giáp ngày check_out = check_in = 2026-11-22 -> Không lỗi)]: Đã thêm BK_TEST_ADJACENT.';
END TRY
BEGIN CATCH
    INSERT INTO @TestLog VALUES (N'2. Giáp ngày (check_out = check_in)', N'INSERT ACCOM=3 [2026-11-22 -> 2026-11-25)', N'KHÔNG LỖI', N'FAIL: ' + ERROR_MESSAGE());
    PRINT N'[FAIL - TEST 2]: ' + ERROR_MESSAGE();
END CATCH;

-- ----------------------------------------------------------------------------
-- TEST 3: Cùng khoảng ngày nhưng khác phòng / khác cơ sở (Kỳ vọng: KHÔNG LỖI)
-- Đặt ngày 2026-11-20 -> 2026-11-22 (giống đơn 11) nhưng ở ACCOMMODATION_ID = 2.
-- ----------------------------------------------------------------------------
BEGIN TRY
    INSERT INTO dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE, CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('CONFIRMED', 2, 0, 'BK_TEST_DIFF_ROOM', '9003', '2026-11-01', '2026-11-20', '2026-11-22', 3, 2);

    INSERT INTO @TestLog VALUES (N'3. Khác phòng / Khác cơ sở', N'INSERT ACCOM=2 [2026-11-20 -> 2026-11-22)', N'KHÔNG LỖI', N'PASS: Thêm thành công đơn BK_TEST_DIFF_ROOM');
    PRINT N'[PASS - TEST 3 (Cùng ngày nhưng khác phòng ACCOMMODATION_ID = 2 -> Không lỗi)]: Đã thêm BK_TEST_DIFF_ROOM.';
END TRY
BEGIN CATCH
    INSERT INTO @TestLog VALUES (N'3. Khác phòng / Khác cơ sở', N'INSERT ACCOM=2 [2026-11-20 -> 2026-11-22)', N'KHÔNG LỖI', N'FAIL: ' + ERROR_MESSAGE());
    PRINT N'[FAIL - TEST 3]: ' + ERROR_MESSAGE();
END CATCH;

-- ----------------------------------------------------------------------------
-- TEST 4: Trùng ngày với booking đã CANCELLED (Kỳ vọng: KHÔNG LỖI)
-- Đơn số 6 ở ACCOMMODATION_ID = 2 [2026-10-10 -> 2026-10-12) có STATUS = 'CANCELLED'.
-- Đặt mới đúng ACCOMMODATION_ID = 2 và đúng ngày [2026-10-10 -> 2026-10-12).
-- ----------------------------------------------------------------------------
BEGIN TRY
    INSERT INTO dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE, CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('CONFIRMED', 2, 0, 'BK_TEST_CANCELLED', '9004', '2026-10-01', '2026-10-10', '2026-10-12', 4, 2);

    INSERT INTO @TestLog VALUES (N'4. Booking cũ CANCELLED không tính', N'INSERT ACCOM=2 [2026-10-10 -> 2026-10-12)', N'KHÔNG LỖI', N'PASS: Đơn cũ CANCELLED không tính, thêm thành công BK_TEST_CANCELLED');
    PRINT N'[PASS - TEST 4 (Trùng ngày với đơn CANCELLED -> Không lỗi)]: Đã thêm BK_TEST_CANCELLED.';
END TRY
BEGIN CATCH
    INSERT INTO @TestLog VALUES (N'4. Booking cũ CANCELLED không tính', N'INSERT ACCOM=2 [2026-10-10 -> 2026-10-12)', N'KHÔNG LỖI', N'FAIL: ' + ERROR_MESSAGE());
    PRINT N'[FAIL - TEST 4]: ' + ERROR_MESSAGE();
END CATCH;

-- ----------------------------------------------------------------------------
-- TEST 5: UPDATE đổi ngày gây trùng lịch (Kỳ vọng: LỖI - BỊ CHẶN)
-- Sửa ngày nhận phòng của đơn BK_TEST_ADJACENT từ 2026-11-22 lùi về 2026-11-21
-- -> Gây chồng lấn 1 ngày với BOOKING_ID = 11 [2026-11-20 -> 2026-11-22).
-- ----------------------------------------------------------------------------
BEGIN TRY
    UPDATE dbo.BOOKING
    SET CHECK_IN_DATE = '2026-11-21'
    WHERE BOOKING_CODE = 'BK_TEST_ADJACENT';

    INSERT INTO @TestLog VALUES (N'5. UPDATE đổi ngày gây trùng lịch', N'UPDATE BK_TEST_ADJACENT: CHECK_IN = 2026-11-21', N'BÁO LỖI', N'FAIL: Không chặn được UPDATE');
END TRY
BEGIN CATCH
    INSERT INTO @TestLog VALUES (N'5. UPDATE đổi ngày gây trùng lịch', N'UPDATE BK_TEST_ADJACENT: CHECK_IN = 2026-11-21', N'BÁO LỖI', N'PASS (Đã chặn UPDATE): ' + ERROR_MESSAGE());
    PRINT N'[PASS - TEST 5 (UPDATE đổi ngày gây trùng lịch -> Bị chặn)]: ' + ERROR_MESSAGE();
END CATCH;

-- Hiển thị bảng tổng hợp kết quả Test Log ngay trên tab Results của SSMS
SELECT * FROM @TestLog;

-- Hiển thị các đơn đặt phòng trong bảng BOOKING để đối chiếu
SELECT BOOKING_ID, BOOKING_CODE, ACCOMMODATION_ID, [STATUS], CHECK_IN_DATE, CHECK_OUT_DATE
FROM dbo.BOOKING
WHERE BOOKING_ID >= 6
ORDER BY BOOKING_ID;

-- Xóa 3 đơn test hợp lệ sau khi xem kết quả để giữ sạch dữ liệu mẫu gốc
DELETE FROM dbo.BOOKING WHERE BOOKING_CODE LIKE 'BK_TEST_%';
GO
