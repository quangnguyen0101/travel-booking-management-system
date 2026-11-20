/*
 BTL2 - Nhóm 5 | Việc 7 (app) - Phạm Nhật Quang
 Tài khoản CSDL riêng cho ứng dụng, không dùng sa.
 Chạy sau 03, 06, 07 (cần các thủ tục và hàm đã tồn tại). Chạy lại được nhiều lần.

 Quyền cấp:
 - db_datareader: SELECT để đổ dropdown (khách, cơ sở, hạng phòng) và đọc đơn khi mở form sửa.
 - EXECUTE trên schema dbo: gọi sp_Booking_*, sp_Revenue_By_Accommodation, fn_GuestTier, fn_CancelRefund.
 Không cấp INSERT/UPDATE/DELETE: app không tự ghi bảng được, mọi thay đổi bắt buộc đi qua thủ tục
 (thủ tục và bảng cùng chủ sở hữu dbo nên ownership chaining cho phép thủ tục ghi thay app).

 Đổi mật khẩu bên dưới trước khi dùng chung, và sửa DB_PASSWORD trong app/.env cho khớp.
 Server phải bật SQL Server Authentication (Mixed Mode).
*/
USE [master];
GO
IF SUSER_ID(N'btl2_app') IS NULL
    CREATE LOGIN btl2_app WITH PASSWORD = N'Btl2App@2026!', DEFAULT_DATABASE = [BTL2_Booking_Nhom5], CHECK_POLICY = ON;
GO
USE [BTL2_Booking_Nhom5];
GO
IF USER_ID(N'btl2_app') IS NULL
    CREATE USER btl2_app FOR LOGIN btl2_app;
GO
ALTER ROLE db_datareader ADD MEMBER btl2_app;
GRANT EXECUTE ON SCHEMA::dbo TO btl2_app;
GO
PRINT N'Đã tạo/cập nhật tài khoản btl2_app (SELECT + EXECUTE, không có quyền ghi trực tiếp).';
GO
