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
