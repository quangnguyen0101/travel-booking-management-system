/* Kiểm tra hai thủ tục sau khi chạy 06_query_procs.sql. */
USE [BTL2_Booking_Nhom5];
GO

-- Lấy toàn bộ booking.
EXEC dbo.sp_Booking_List;
-- Lọc booking đã hoàn thành.
EXEC dbo.sp_Booking_List @p_status = 'COMPLETED';
-- Tìm hạng phòng có tên chứa Deluxe.
EXEC dbo.sp_Booking_List @p_keyword = N'Deluxe';
-- Khoảng ngày nhận phòng, gồm ngày 01/09 và 30/09.
EXEC dbo.sp_Booking_List @p_from = '20260901', @p_to = '20260930';
-- Sắp xếp theo tiền tăng dần và tên khách tăng dần.
EXEC dbo.sp_Booking_List @p_sort = 'total_amount';
EXEC dbo.sp_Booking_List @p_sort = 'guest_name';
-- Không khớp dữ liệu: kết quả rỗng.
EXEC dbo.sp_Booking_List @p_keyword = N'__KHONG_CO_KHACH_HAY_PHONG_NAY_93871__';
-- Sort không hợp lệ: sắp theo ngày nhận phòng.
EXEC dbo.sp_Booking_List @p_sort = 'invalid';

-- Doanh thu toàn bộ và tổng PAID để đối chiếu.
EXEC dbo.sp_Revenue_By_Accommodation;
SELECT CURRENCY, SUM(AMOUNT) AS TOTAL_PAID
FROM dbo.PAYMENT
WHERE PAYMENT_STATUS = 'PAID'
GROUP BY CURRENCY;
-- Có lọc thành phố, thời gian và mức doanh thu tối thiểu.
EXEC dbo.sp_Revenue_By_Accommodation @p_city = N'TP.HCM';
EXEC dbo.sp_Revenue_By_Accommodation
    @p_from = '20260901', @p_to = '20260930', @p_min_revenue = 3000000;
-- Không có kết quả.
EXEC dbo.sp_Revenue_By_Accommodation @p_city = N'__KHONG_CO_THANH_PHO_NAY__';
-- Khoảng ngày ngược không có kết quả ở cả hai thủ tục.
EXEC dbo.sp_Booking_List @p_from = '20261231', @p_to = '20260101';
EXEC dbo.sp_Revenue_By_Accommodation @p_from = '20261231', @p_to = '20260101';
GO

/* Ba ca bổ sung. Chạy toàn bộ file trong SSMS sau 06_query_procs.sql.
   Dữ liệu thử được rollback, kể cả khi có lỗi. Không chạy trong transaction khác.
   IDENTITY có thể tăng sau test dù dữ liệu đã rollback.
*/
USE [BTL2_Booking_Nhom5];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_WARNINGS ON;
SET ANSI_PADDING ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF @@TRANCOUNT <> 0
    THROW 53000, N'Chạy file trong cửa sổ không có transaction đang mở.', 1;

DECLARE @Results TABLE (TestName NVARCHAR(100), Result VARCHAR(4));
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Guest INT = (SELECT MIN(USER_ID) FROM dbo.GUEST);
    DECLARE @Host INT = (SELECT MIN(USER_ID) FROM dbo.HOST);
    IF @Guest IS NULL OR @Host IS NULL
        THROW 53001, N'Cần dữ liệu GUEST và HOST trước khi chạy test.', 1;

    DECLARE @Tag VARCHAR(20) = LEFT(REPLACE(CONVERT(VARCHAR(36),NEWID()),'-',''),20);
    DECLARE @City NVARCHAR(100) = N'TEST23_' + @Tag;
    DECLARE @Code1 VARCHAR(30) = 'T23A_' + @Tag;
    DECLARE @Code2 VARCHAR(30) = 'T23B_' + @Tag;
    DECLARE @Code3 VARCHAR(30) = 'T23C_' + @Tag;
    DECLARE @Today DATE = CONVERT(DATE,SYSDATETIME());
    DECLARE @Start DATE = DATEADD(DAY,60,@Today);

    INSERT dbo.ACCOMMODATION ([NAME],STAR_RATING,STREET_ADDRESS,CITY,USER_ID)
    VALUES (N'Cơ sở kiểm thử 2.3',3,N'Địa chỉ kiểm thử',@City,@Host);
    DECLARE @Accom INT = CONVERT(INT,SCOPE_IDENTITY());
    INSERT dbo.HOTEL (ACCOMMODATION_ID,NUMBER_OF_FLOORS) VALUES (@Accom,2);
    INSERT dbo.ROOM_TYPE
        (ACCOMMODATION_ID,ROOM_NAME,AREA,NUMBER_OF_BEDS,BED_TYPE,ADULTS,CHILDREN)
    VALUES (@Accom,N'Test Standard',25,1,N'Đôi',2,0),
           (@Accom,N'Test Deluxe',35,1,N'Đôi',2,0);
    INSERT dbo.ROOM (ACCOMMODATION_ID,ROOM_NAME,ROOM_NUMBER)
    VALUES (@Accom,N'Test Standard','S01'),(@Accom,N'Test Standard','S02'),
           (@Accom,N'Test Deluxe','D01');

    -- Ngày ở tách nhau để không xung đột với trigger kiểm tra lịch.
    INSERT dbo.BOOKING
        ([STATUS],ADULTS,BOOKING_CODE,PIN_CODE,BOOKING_DATE,CHECK_IN_DATE,CHECK_OUT_DATE,USER_ID,ACCOMMODATION_ID)
    VALUES ('CONFIRMED',1,@Code1,'1234',@Today,@Start,DATEADD(DAY,2,@Start),@Guest,@Accom),
           ('CONFIRMED',1,@Code2,'1234',@Today,DATEADD(DAY,4,@Start),DATEADD(DAY,6,@Start),@Guest,@Accom),
           ('PENDING',1,@Code3,'1234',@Today,DATEADD(DAY,8,@Start),DATEADD(DAY,10,@Start),@Guest,@Accom);
    -- Tìm bằng mã thay vì SCOPE_IDENTITY vì BOOKING có thể có INSTEAD OF trigger.
    DECLARE @B1 INT = (SELECT BOOKING_ID FROM dbo.BOOKING WHERE BOOKING_CODE=@Code1);
    DECLARE @B2 INT = (SELECT BOOKING_ID FROM dbo.BOOKING WHERE BOOKING_CODE=@Code2);
    DECLARE @B3 INT = (SELECT BOOKING_ID FROM dbo.BOOKING WHERE BOOKING_CODE=@Code3);
    INSERT dbo.BOOKING_ROOM_TYPE
        (BOOKING_ID,ACCOMMODATION_ID,ROOM_NAME,ROOM_PRICE_AT_BOOKING,RESERVED_QUANTITY)
    VALUES (@B1,@Accom,N'Test Standard',100000,2),
           (@B1,@Accom,N'Test Deluxe',200000,1),
           (@B2,@Accom,N'Test Standard',100000,1);

    CREATE TABLE #BookingResult (
        BOOKING_ID INT, BOOKING_CODE VARCHAR(30), GUEST_ID INT, GUEST_NAME NVARCHAR(150),
        ACCOMMODATION_ID INT, ACCOMMODATION_NAME NVARCHAR(200), CITY NVARCHAR(100),
        [STATUS] VARCHAR(12), BOOKING_DATE DATE, CHECK_IN_DATE DATE, CHECK_OUT_DATE DATE,
        ADULTS SMALLINT, CHILDREN SMALLINT, TOTAL_NIGHTS INT, ROOM_QUANTITY INT,
        TOTAL_AMOUNT DECIMAL(28,2)
    );

    -- 1. Hai hạng, ba phòng, hai đêm: (100.000 x 2 + 200.000) x 2 = 800.000.
    INSERT #BookingResult EXEC dbo.sp_Booking_List @p_keyword=@Code1;
    IF (SELECT COUNT(*) FROM #BookingResult) <> 1
       OR NOT EXISTS (SELECT 1 FROM #BookingResult WHERE BOOKING_ID=@B1
                      AND ROOM_QUANTITY=3 AND TOTAL_NIGHTS=2 AND TOTAL_AMOUNT=800000)
        THROW 53002, N'FAIL: booking nhiều hạng phòng bị lặp hoặc tính tiền sai.', 1;
    INSERT @Results VALUES (N'Booking nhiều hạng phòng','PASS');
    SELECT N'1. Nhiều hạng phòng' AS TestCase, * FROM #BookingResult;

    -- 2. Đơn chưa có chi tiết vẫn xuất hiện, số phòng 0 và tổng tiền NULL.
    DELETE FROM #BookingResult;
    INSERT #BookingResult EXEC dbo.sp_Booking_List @p_keyword=@Code3;
    IF (SELECT COUNT(*) FROM #BookingResult) <> 1
       OR NOT EXISTS (SELECT 1 FROM #BookingResult WHERE BOOKING_ID=@B3
                      AND ROOM_QUANTITY=0 AND TOTAL_AMOUNT IS NULL)
        THROW 53003, N'FAIL: booking chưa có chi tiết bị mất hoặc có tổng tiền sai.', 1;
    INSERT @Results VALUES (N'Booking chưa có chi tiết','PASS');
    SELECT N'2. Chưa có chi tiết' AS TestCase, * FROM #BookingResult;

    -- 3. Hai loại tiền trong cùng cơ sở phải thành hai nhóm riêng.
    INSERT dbo.PAYMENT
        (CURRENCY,PAYMENT_DATE,PAYMENT_METHOD,AMOUNT,PAYMENT_STATUS,BOOKING_ID,CARD_NUMBER)
    VALUES ('VND',SYSDATETIME(),'AT_PROPERTY',800000,'PAID',@B1,NULL),
           ('USD',SYSDATETIME(),'AT_PROPERTY',100,'PAID',@B2,NULL);
    CREATE TABLE #RevenueResult (
        ACCOMMODATION_ID INT, ACCOMMODATION_NAME NVARCHAR(200), CITY NVARCHAR(100),
        CURRENCY CHAR(3), BOOKING_COUNT INT, TOTAL_REVENUE DECIMAL(38,2),
        AVG_PAYMENT_AMOUNT DECIMAL(28,2)
    );
    INSERT #RevenueResult EXEC dbo.sp_Revenue_By_Accommodation @p_city=@City;
    IF (SELECT COUNT(*) FROM #RevenueResult) <> 2
       OR NOT EXISTS (SELECT 1 FROM #RevenueResult WHERE ACCOMMODATION_ID=@Accom
                      AND CURRENCY='VND' AND BOOKING_COUNT=1
                      AND TOTAL_REVENUE=800000 AND AVG_PAYMENT_AMOUNT=800000)
       OR NOT EXISTS (SELECT 1 FROM #RevenueResult WHERE ACCOMMODATION_ID=@Accom
                      AND CURRENCY='USD' AND BOOKING_COUNT=1
                      AND TOTAL_REVENUE=100 AND AVG_PAYMENT_AMOUNT=100)
        THROW 53004, N'FAIL: doanh thu bị gộp loại tiền hoặc bị nhân theo chi tiết phòng.', 1;
    INSERT @Results VALUES (N'Doanh thu tách loại tiền','PASS');
    SELECT N'3. Tách loại tiền' AS TestCase, * FROM #RevenueResult;

    ROLLBACK TRANSACTION;
    IF EXISTS (SELECT 1 FROM dbo.ACCOMMODATION WHERE CITY=@City)
       OR EXISTS (SELECT 1 FROM dbo.BOOKING WHERE BOOKING_CODE IN (@Code1,@Code2,@Code3))
        THROW 53005, N'FAIL: còn dữ liệu thử sau rollback.', 1;
    SELECT TestName, Result FROM @Results;
    PRINT N'Đã rollback dữ liệu thử. Các mã IDENTITY đã cấp có thể không được dùng lại.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
