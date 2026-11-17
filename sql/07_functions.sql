/*
===============================================================================
 BTL2 - Nhóm 5
 Phần 2.4: Hai hàm scalar
 Phan Anh Khoa

 Chạy sau 01_schema.sql và 02_seed.sql.

 - dbo.fn_GuestTier: cộng giá trị các booking COMPLETED theo năm trả phòng,
   trừ voucher tiền mặt, rồi xếp hạng BRONZE / SILVER / GOLD / PLATINUM.
 - dbo.fn_CancelRefund: tính tiền hoàn trên khoản thanh toán PAID theo số ngày
   còn lại đến ngày nhận phòng.

 SQL Server UDF chỉ trả về giá trị, không hỗ trợ THROW/RAISERROR. Vì vậy các
 tham số hoặc đối tượng không hợp lệ trả về NULL; booking hợp lệ chưa thanh
 toán trả về 0. Hàm không cập nhật PAYMENT hay CANCELLATION.
===============================================================================
*/
USE [BTL2_Booking_Nhom5];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- Xếp hạng khách theo tổng giá trị các booking đã hoàn thành trong năm.
CREATE OR ALTER FUNCTION dbo.fn_GuestTier
(
    @p_user_id INT,
    @p_year    INT
)
RETURNS VARCHAR(10)
AS
BEGIN
    IF @p_user_id IS NULL OR @p_user_id <= 0
       OR @p_year IS NULL OR @p_year NOT BETWEEN 1 AND 9999
       OR NOT EXISTS (
           SELECT 1
           FROM dbo.GUEST
           WHERE USER_ID = @p_user_id
       )
        RETURN NULL;

    DECLARE @booking_id INT,
            @check_in_date DATE,
            @check_out_date DATE,
            @nightly_amount DECIMAL(38,2),
            @discount_value DECIMAL(18,2),
            @booking_total DECIMAL(38,2),
            @total_spent DECIMAL(38,2) = 0;

    DECLARE booking_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT BOOKING_ID, CHECK_IN_DATE, CHECK_OUT_DATE
        FROM dbo.BOOKING
        WHERE USER_ID = @p_user_id
          AND [STATUS] = 'COMPLETED'
          AND YEAR(CHECK_OUT_DATE) = @p_year
        ORDER BY BOOKING_ID;

    OPEN booking_cursor;
    FETCH NEXT FROM booking_cursor
        INTO @booking_id, @check_in_date, @check_out_date;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @nightly_amount =
                   ISNULL(SUM(CAST(br.ROOM_PRICE_AT_BOOKING * br.RESERVED_QUANTITY
                                   AS DECIMAL(28,2))), 0),
               @discount_value = ISNULL(MAX(v.DISCOUNT_VALUE), 0)
        FROM dbo.BOOKING_ROOM_TYPE AS br
        LEFT JOIN dbo.BOOKING_VOUCHER AS bv
            ON bv.BOOKING_ID = br.BOOKING_ID
        LEFT JOIN dbo.VOUCHER AS v
            ON v.VOUCHER_CODE = bv.VOUCHER_CODE
        WHERE br.BOOKING_ID = @booking_id;

        SET @booking_total =
            @nightly_amount * DATEDIFF(DAY, @check_in_date, @check_out_date);

        IF @booking_total > @discount_value
            SET @booking_total = @booking_total - @discount_value;
        ELSE
            SET @booking_total = 0;

        SET @total_spent = @total_spent + @booking_total;

        FETCH NEXT FROM booking_cursor
            INTO @booking_id, @check_in_date, @check_out_date;
    END;

    CLOSE booking_cursor;
    DEALLOCATE booking_cursor;

    IF @total_spent >= 50000000
        RETURN 'PLATINUM';
    IF @total_spent >= 20000000
        RETURN 'GOLD';
    IF @total_spent >= 5000000
        RETURN 'SILVER';
    RETURN 'BRONZE';
END;
GO

-- Tính khoản hoàn theo số ngày nguyên còn lại trước ngày nhận phòng.
CREATE OR ALTER FUNCTION dbo.fn_CancelRefund
(
    @p_booking_id INT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    IF @p_booking_id IS NULL OR @p_booking_id <= 0
        RETURN NULL;

    DECLARE @booking_status VARCHAR(12),
            @check_in_date DATE,
            @paid_amount DECIMAL(18,2),
            @payment_amount DECIMAL(18,2),
            @days_before_check_in INT;

    SELECT @booking_status = [STATUS],
           @check_in_date = CHECK_IN_DATE
    FROM dbo.BOOKING
    WHERE BOOKING_ID = @p_booking_id;

    IF @booking_status IS NULL OR @booking_status = 'COMPLETED'
        RETURN NULL;

    SET @paid_amount = 0;
    DECLARE payment_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT AMOUNT
        FROM dbo.PAYMENT
        WHERE BOOKING_ID = @p_booking_id
          AND PAYMENT_STATUS = 'PAID'
        ORDER BY PAYMENT_ID;

    OPEN payment_cursor;
    FETCH NEXT FROM payment_cursor INTO @payment_amount;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @paid_amount = @paid_amount + @payment_amount;
        FETCH NEXT FROM payment_cursor INTO @payment_amount;
    END;
    CLOSE payment_cursor;
    DEALLOCATE payment_cursor;

    SET @days_before_check_in =
        DATEDIFF(DAY, CONVERT(DATE, GETDATE()), @check_in_date);

    IF @days_before_check_in >= 7
        RETURN @paid_amount;
    IF @days_before_check_in >= 3
        RETURN CAST(@paid_amount * 0.50 AS DECIMAL(18,2));
    RETURN 0;
END;
GO
