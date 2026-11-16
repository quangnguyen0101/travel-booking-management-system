/*
 BTL2 - Nhóm 5
 Phần 1.2: Script kiểm thử ràng buộc (Negative Tests: CHECK, FOREIGN KEY, UNIQUE)
 Theo đúng yêu cầu trong đề bài và mục 3 của README.txt:
 "Thử dữ liệu vi phạm CHECK, FK, UNIQUE và lưu thông báo lỗi làm minh chứng."
*/
USE [BTL2_Booking_Nhom5];
GO
SET NOCOUNT ON;

PRINT N'=====================================================================';
PRINT N'PHẦN A: KIỂM THỬ VI PHẠM RÀNG BUỘC CHECK (5 TEST CASES)';
PRINT N'=====================================================================';

-- 1. Vi phạm CHECK giá phòng > 0 (CK_ROOM_RATE_PRICE: UNIT_PRICE > 0)
BEGIN TRY
    INSERT INTO dbo.ROOM_RATE (ACCOMMODATION_ID, ROOM_NAME, ROOM_RATE_ID, UNIT_PRICE, EFFECTIVE_DATE)
    VALUES (1, N'Deluxe River View', 99, -500000.00, '2026-11-13');
END TRY
BEGIN CATCH
    PRINT N'[PASS - CHECK 1 (Gia phong <= 0)]: ' + ERROR_MESSAGE();
END CATCH;

-- 2. Vi phạm CHECK ngày trả > ngày nhận (CK_BOOKING_DATES: CHECK_OUT_DATE > CHECK_IN_DATE)
BEGIN TRY
    INSERT INTO dbo.BOOKING ([STATUS], ADULTS, BOOKING_CODE, PIN_CODE, BOOKING_DATE, CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 2, 'BK_ERR_DATE', '1111', '2026-11-01', '2026-11-20', '2026-11-15', 1, 1);
END TRY
BEGIN CATCH
    PRINT N'[PASS - CHECK 2 (Check-out <= Check-in)]: ' + ERROR_MESSAGE();
END CATCH;

-- 3. Vi phạm CHECK số sao từ 1 đến 5 (CK_ACCOMMODATION_STAR: STAR_RATING BETWEEN 1 AND 5)
BEGIN TRY
    INSERT INTO dbo.ACCOMMODATION ([NAME], STAR_RATING, STREET_ADDRESS, CITY, USER_ID)
    VALUES (N'Khách sạn Lỗi Sao', 6, N'123 Lê Lợi', N'TP.HCM', 6);
END TRY
BEGIN CATCH
    PRINT N'[PASS - CHECK 3 (Star Rating ngoai 1..5)]: ' + ERROR_MESSAGE();
END CATCH;

-- 4. Vi phạm CHECK số khách người lớn >= 1 (CK_BOOKING_ADULTS: ADULTS >= 1)
BEGIN TRY
    INSERT INTO dbo.BOOKING ([STATUS], ADULTS, BOOKING_CODE, PIN_CODE, BOOKING_DATE, CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 0, 'BK_ERR_GUEST', '1111', '2026-11-01', '2026-11-15', '2026-11-18', 1, 1);
END TRY
BEGIN CATCH
    PRINT N'[PASS - CHECK 4 (So khach <= 0)]: ' + ERROR_MESSAGE();
END CATCH;

-- 5. Vi phạm CHECK mã trạng thái Status (CK_BOOKING_STATUS)
BEGIN TRY
    INSERT INTO dbo.BOOKING ([STATUS], ADULTS, BOOKING_CODE, PIN_CODE, BOOKING_DATE, CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('INVALID_STATUS', 2, 'BK_ERR_STATUS', '1111', '2026-11-01', '2026-11-15', '2026-11-18', 1, 1);
END TRY
BEGIN CATCH
    PRINT N'[PASS - CHECK 5 (Sai trang thai Status)]: ' + ERROR_MESSAGE();
END CATCH;

PRINT N'';
PRINT N'=====================================================================';
PRINT N'PHẦN B: KIỂM THỬ VI PHẠM KHÓA NGOẠI - FOREIGN KEY (2 TEST CASES)';
PRINT N'=====================================================================';

-- 6. Vi phạm FK: Đặt phòng với USER_ID không tồn tại trong bảng GUEST (USER_ID = 999)
BEGIN TRY
    INSERT INTO dbo.BOOKING ([STATUS], ADULTS, BOOKING_CODE, PIN_CODE, BOOKING_DATE, CHECK_IN_DATE, CHECK_OUT_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES ('PENDING', 2, 'BK_ERR_FK1', '1111', '2026-11-01', '2026-11-15', '2026-11-18', 999, 1);
END TRY
BEGIN CATCH
    PRINT N'[PASS - FK 1 (USER_ID khong ton tai)]: ' + ERROR_MESSAGE();
END CATCH;

-- 7. Vi phạm FK ghép: Chi tiết đặt phòng trỏ tới hạng phòng không thuộc cơ sở lưu trú của đơn đó
BEGIN TRY
    -- Đơn số 1 đặt ở ACCOMMODATION_ID = 1, nhưng cố chèn hạng phòng của ACCOMMODATION_ID = 2
    INSERT INTO dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES (1, 2, N'Superior Ocean View', 1500000.00, 1);
END TRY
BEGIN CATCH
    PRINT N'[PASS - FK 2 (Hang phong khac co so cua Booking)]: ' + ERROR_MESSAGE();
END CATCH;

PRINT N'';
PRINT N'=====================================================================';
PRINT N'PHẦN C: KIỂM THỬ VI PHẠM RÀNG BUỘC DUY NHẤT - UNIQUE (3 TEST CASES)';
PRINT N'=====================================================================';

-- 8. Vi phạm UNIQUE Email người dùng (UQ_USER_EMAIL)
BEGIN TRY
    INSERT INTO dbo.[USER] (EMAIL, [PASSWORD], FULL_NAME)
    VALUES (N'guest1@gmail.com', 'hash_dup', N'Người Dùng Trùng Email');
END TRY
BEGIN CATCH
    PRINT N'[PASS - UNIQUE 1 (Trung Email USER)]: ' + ERROR_MESSAGE();
END CATCH;

-- 9. Vi phạm UNIQUE Mã số thuế của HOST (UQ_HOST_TAX_CODE)
BEGIN TRY
    INSERT INTO dbo.HOST (USER_ID, TAX_CODE, BUSINESS_NAME, BANK_ACCOUNT)
    VALUES (1, '0312345601', N'Công ty Trùng Mã Số Thuế', '123456789');
END TRY
BEGIN CATCH
    PRINT N'[PASS - UNIQUE 2 (Trung Ma So Thue HOST)]: ' + ERROR_MESSAGE();
END CATCH;

-- 10. Vi phạm UNIQUE Số phòng trong cùng một cơ sở lưu trú (UQ_ROOM_ACCOM_NUMBER)
BEGIN TRY
    INSERT INTO dbo.ROOM (ACCOMMODATION_ID, ROOM_NAME, ROOM_NUMBER, AVAILABILITY_STATUS)
    VALUES (1, N'Executive Suite', '101', 'AVAILABLE'); -- Số phòng 101 đã tồn tại ở cơ sở 1
END TRY
BEGIN CATCH
    PRINT N'[PASS - UNIQUE 3 (Trung So Phong trong cung Co So)]: ' + ERROR_MESSAGE();
END CATCH;
GO
