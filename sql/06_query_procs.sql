/*
 BTL2 - Nhóm 5 | Phần 2.3 - Đỗ Lê Chí Kiên
 Hai thủ tục chỉ truy vấn dữ liệu, không thay đổi bảng hay dữ liệu.
*/
USE [BTL2_Booking_Nhom5];
GO
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

-- 1. Danh sách booking, lọc theo ngày nhận phòng.
-- p_sort: check_in, total_amount, guest_name. Giá trị khác dùng check_in.
CREATE OR ALTER PROCEDURE dbo.sp_Booking_List
    @p_keyword NVARCHAR(200) = NULL,
    @p_status VARCHAR(12) = NULL,
    @p_from DATE = NULL,
    @p_to DATE = NULL,
    @p_sort VARCHAR(20) = 'check_in'
AS
BEGIN
    SET NOCOUNT ON;

    -- Cộng tiền và số phòng theo từng booking trước khi JOIN.
    ;WITH RoomTotals AS (
        SELECT BOOKING_ID,
               SUM(CAST(ROOM_PRICE_AT_BOOKING * RESERVED_QUANTITY AS DECIMAL(28,2))) AS NIGHTLY_AMOUNT,
               SUM(CAST(RESERVED_QUANTITY AS INT)) AS ROOM_QUANTITY
        FROM dbo.BOOKING_ROOM_TYPE
        GROUP BY BOOKING_ID
    ), BookingList AS (
        SELECT b.BOOKING_ID, b.BOOKING_CODE,
               u.USER_ID AS GUEST_ID, u.FULL_NAME AS GUEST_NAME,
               a.ACCOMMODATION_ID, a.[NAME] AS ACCOMMODATION_NAME, a.CITY,
               b.[STATUS], b.BOOKING_DATE, b.CHECK_IN_DATE, b.CHECK_OUT_DATE,
               b.ADULTS, b.CHILDREN,
               DATEDIFF(DAY,b.CHECK_IN_DATE,b.CHECK_OUT_DATE) AS TOTAL_NIGHTS,
               ISNULL(rt.ROOM_QUANTITY,0) AS ROOM_QUANTITY,
               -- Chưa có chi tiết đặt phòng thì tổng tiền là NULL.
               CAST(CASE
                   WHEN rt.BOOKING_ID IS NULL THEN NULL
                   WHEN rt.NIGHTLY_AMOUNT * DATEDIFF(DAY,b.CHECK_IN_DATE,b.CHECK_OUT_DATE)
                        < ISNULL(v.DISCOUNT_VALUE,0) THEN 0
                   ELSE rt.NIGHTLY_AMOUNT * DATEDIFF(DAY,b.CHECK_IN_DATE,b.CHECK_OUT_DATE)
                        - ISNULL(v.DISCOUNT_VALUE,0)
               END AS DECIMAL(28,2)) AS TOTAL_AMOUNT
        FROM dbo.BOOKING AS b
        JOIN dbo.GUEST AS g ON g.USER_ID = b.USER_ID
        JOIN dbo.[USER] AS u ON u.USER_ID = g.USER_ID
        JOIN dbo.ACCOMMODATION AS a ON a.ACCOMMODATION_ID = b.ACCOMMODATION_ID
        LEFT JOIN RoomTotals AS rt ON rt.BOOKING_ID = b.BOOKING_ID
        LEFT JOIN dbo.BOOKING_VOUCHER AS bv ON bv.BOOKING_ID = b.BOOKING_ID
        LEFT JOIN dbo.VOUCHER AS v ON v.VOUCHER_CODE = bv.VOUCHER_CODE
        WHERE (@p_status IS NULL OR @p_status = '' OR b.[STATUS] = @p_status)
          AND (@p_from IS NULL OR b.CHECK_IN_DATE >= @p_from)
          AND (@p_to IS NULL OR b.CHECK_IN_DATE <= @p_to)
          AND (@p_keyword IS NULL OR LTRIM(RTRIM(@p_keyword)) = ''
               OR CHARINDEX(@p_keyword,u.FULL_NAME) > 0
               OR CHARINDEX(@p_keyword,a.[NAME]) > 0
               OR CHARINDEX(@p_keyword,b.BOOKING_CODE) > 0
               OR EXISTS (
                   SELECT 1
                   FROM dbo.BOOKING_ROOM_TYPE AS br
                   JOIN dbo.ROOM_TYPE AS r
                     ON r.ACCOMMODATION_ID = br.ACCOMMODATION_ID
                    AND r.ROOM_NAME = br.ROOM_NAME
                   WHERE br.BOOKING_ID = b.BOOKING_ID
                     AND CHARINDEX(@p_keyword,r.ROOM_NAME) > 0
               ))
    )
    SELECT *
    FROM BookingList
    -- Dùng CASE thay vì nối chuỗi SQL từ tham số sắp xếp.
    ORDER BY
        CASE WHEN @p_sort = 'total_amount' THEN TOTAL_AMOUNT END ASC,
        CASE WHEN @p_sort = 'guest_name' THEN GUEST_NAME END ASC,
        CHECK_IN_DATE ASC, BOOKING_ID ASC;
END;
GO

-- 2. Doanh thu theo cơ sở. Khoảng ngày tính theo ngày thanh toán.
-- Thống kê riêng từng loại tiền.
CREATE OR ALTER PROCEDURE dbo.sp_Revenue_By_Accommodation
    @p_city NVARCHAR(100) = NULL,
    @p_from DATE = NULL,
    @p_to DATE = NULL,
    @p_min_revenue DECIMAL(28,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT a.ACCOMMODATION_ID, a.[NAME] AS ACCOMMODATION_NAME, a.CITY,
           p.CURRENCY,
           COUNT(DISTINCT b.BOOKING_ID) AS BOOKING_COUNT,
           SUM(p.AMOUNT) AS TOTAL_REVENUE,
           CAST(AVG(p.AMOUNT) AS DECIMAL(28,2)) AS AVG_PAYMENT_AMOUNT
    FROM dbo.PAYMENT AS p
    JOIN dbo.BOOKING AS b ON b.BOOKING_ID = p.BOOKING_ID
    JOIN dbo.ACCOMMODATION AS a ON a.ACCOMMODATION_ID = b.ACCOMMODATION_ID
    WHERE p.PAYMENT_STATUS = 'PAID'
      AND (@p_city IS NULL OR LTRIM(RTRIM(@p_city)) = '' OR a.CITY = @p_city)
      AND (@p_from IS NULL OR CONVERT(DATE,p.PAYMENT_DATE) >= @p_from)
      AND (@p_to IS NULL OR CONVERT(DATE,p.PAYMENT_DATE) <= @p_to)
    GROUP BY a.ACCOMMODATION_ID, a.[NAME], a.CITY, p.CURRENCY
    HAVING (@p_min_revenue IS NULL OR SUM(p.AMOUNT) >= @p_min_revenue)
    ORDER BY TOTAL_REVENUE DESC, a.ACCOMMODATION_ID ASC, p.CURRENCY ASC;
END;
GO
