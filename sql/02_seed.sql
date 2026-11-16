/*
 BTL2 - Nhóm 5
 Phần 1.2: Dữ liệu mẫu (Seed Data) cho toàn bộ 36 bảng
 Tuân thủ đầy đủ quy ước trong 01_schema.sql và README.txt:
 - Tất cả 36/36 bảng đều có >= 5 dòng dữ liệu (chèn theo thứ tự bảng cha -> bảng con).
 - 15 USER chia tách biệt: 5 GUEST (1-5), 5 HOST (6-10), 5 ADMIN (11-15) không trùng vai trò.
 - 20 ACCOMMODATION chia tách biệt cho 4 loại hình: 5 HOTEL (1-5), 5 RESORT (6-10), 5 APARTMENT (11-15), 5 HOMESTAY (16-20).
 - 10 PHOTO chia tách biệt: 5 ảnh cơ sở (1-5) và 5 ảnh hạng phòng (6-10).
 - 12 ROOM thực tế (>= 10 phòng) thuộc 6 ROOM_TYPE.
 - 12 BOOKING gồm: 5 đơn COMPLETED (để tạo 5 REVIEW hợp lệ sau ngày trả phòng), 5 đơn CANCELLED (để tạo 5 CANCELLATION hợp lệ), 1 đơn CONFIRMED, 1 đơn PENDING.
 - Voucher đúng chủ sở hữu; Phí hủy + Tiền hoàn khớp số tiền thanh toán; Host phản hồi đúng cơ sở mình quản lý.
*/
USE [BTL2_Booking_Nhom5];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (SELECT 1 FROM dbo.[USER])
    THROW 51002, N'Database da co du lieu mau. Khong chay de len du lieu cu.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- =========================================================================
    -- 1. Bảng USER (15 dòng: 1..5 là GUEST, 6..10 là HOST, 11..15 là ADMIN)
    -- =========================================================================
    SET IDENTITY_INSERT dbo.[USER] ON;
    INSERT INTO dbo.[USER] (USER_ID, EMAIL, [PASSWORD], FULL_NAME, PHONE_NUMBER, PROFILE_IMAGE, CREATED_DATE, STREET_ADDRESS, WARD, DISTRICT, CITY)
    VALUES
        (1,  N'guest1@gmail.com',  'hash_pw_01', N'Nguyễn Văn An',     '0901000001', N'https://img.booking.vn/u1.jpg',  '2026-01-10 08:00:00', N'12 Lê Lợi',              N'Bến Nghé',     N'Quận 1',        N'TP.HCM'),
        (2,  N'guest2@gmail.com',  'hash_pw_02', N'Trần Thị Bình',     '0901000002', N'https://img.booking.vn/u2.jpg',  '2026-01-12 09:30:00', N'45 Nguyễn Huệ',          N'Bến Nghé',     N'Quận 1',        N'TP.HCM'),
        (3,  N'guest3@gmail.com',  'hash_pw_03', N'Lê Hoàng Cường',    '0901000003', N'https://img.booking.vn/u3.jpg',  '2026-01-15 10:15:00', N'78 Trần Phú',            N'Hải Châu 1',   N'Hải Châu',      N'Đà Nẵng'),
        (4,  N'guest4@gmail.com',  'hash_pw_04', N'Phạm Minh Dung',    '0901000004', N'https://img.booking.vn/u4.jpg',  '2026-01-18 14:20:00', N'23 Hàng Bài',            N'Hàng Bài',     N'Hoàn Kiếm',     N'Hà Nội'),
        (5,  N'guest5@gmail.com',  'hash_pw_05', N'Hoàng Gia Bảo',     '0901000005', N'https://img.booking.vn/u5.jpg',  '2026-01-20 16:45:00', N'90 Nguyễn Văn Cừ',       N'An Hòa',       N'Ninh Kiều',     N'Cần Thơ'),
        (6,  N'host1@gmail.com',   'hash_pw_06', N'Đỗ Thành Đạt',      '0902000001', N'https://img.booking.vn/u6.jpg',  '2026-01-05 08:00:00', N'100 Đồng Khởi',          N'Bến Nghé',     N'Quận 1',        N'TP.HCM'),
        (7,  N'host2@gmail.com',   'hash_pw_07', N'Vũ Thị Hoa',        '0902000002', N'https://img.booking.vn/u7.jpg',  '2026-01-06 08:30:00', N'200 Võ Nguyên Giáp',     N'Phước Mỹ',     N'Sơn Trà',       N'Đà Nẵng'),
        (8,  N'host3@gmail.com',   'hash_pw_08', N'Bùi Văn Hùng',      '0902000003', N'https://img.booking.vn/u8.jpg',  '2026-01-07 09:00:00', N'50 Trần Hưng Đạo',       N'Phường 10',    N'Đà Lạt',        N'Lâm Đồng'),
        (9,  N'host4@gmail.com',   'hash_pw_09', N'Đặng Ngọc Lan',     '0902000004', N'https://img.booking.vn/u9.jpg',  '2026-01-08 09:30:00', N'15 Trần Hưng Đạo',       N'Dương Đông',   N'Phú Quốc',      N'Kiên Giang'),
        (10, N'host5@gmail.com',   'hash_pw_10', N'Ngô Quang Minh',    '0902000005', N'https://img.booking.vn/u10.jpg', '2026-01-09 10:00:00', N'88 Lý Thường Kiệt',      N'Cửa Nam',      N'Hoàn Kiếm',     N'Hà Nội'),
        (11, N'admin1@booking.vn', 'hash_pw_11', N'Trương Quản Trị 1', '0903000001', N'https://img.booking.vn/u11.jpg', '2026-01-01 08:00:00', N'01 Võ Văn Ngân',         N'Linh Chiểu',   N'Thủ Đức',       N'TP.HCM'),
        (12, N'admin2@booking.vn', 'hash_pw_12', N'Phan Quản Trị 2',   '0903000002', N'https://img.booking.vn/u12.jpg', '2026-01-01 08:05:00', N'268 Lý Thường Kiệt',     N'Phường 14',    N'Quận 10',       N'TP.HCM'),
        (13, N'admin3@booking.vn', 'hash_pw_13', N'Lý Quản Trị 3',     '0903000003', N'https://img.booking.vn/u13.jpg', '2026-01-01 08:10:00', N'03 Điện Biên Phủ',       N'Đa Kao',       N'Quận 1',        N'TP.HCM'),
        (14, N'admin4@booking.vn', 'hash_pw_14', N'Dương Quản Trị 4',  '0903000004', N'https://img.booking.vn/u14.jpg', '2026-01-01 08:15:00', N'04 Cách Mạng Tháng 8',   N'Phường 11',    N'Quận 3',        N'TP.HCM'),
        (15, N'admin5@booking.vn', 'hash_pw_15', N'Mai Quản Trị 5',    '0903000005', N'https://img.booking.vn/u15.jpg', '2026-01-01 08:20:00', N'05 Nguyễn Thị Minh Khai',N'Bến Thành',    N'Quận 1',        N'TP.HCM');
    SET IDENTITY_INSERT dbo.[USER] OFF;

    -- =========================================================================
    -- 2. Bảng REFER (5 dòng: người giới thiệu khác người được giới thiệu)
    -- =========================================================================
    INSERT INTO dbo.REFER (REFERRED_USER_ID, REFERRER_ID)
    VALUES
        (2, 1),
        (3, 1),
        (4, 2),
        (5, 3),
        (7, 6);

    -- =========================================================================
    -- 3-5. Bảng GUEST (5 dòng), HOST (5 dòng), ADMIN (5 dòng) - Không trùng vai trò
    -- =========================================================================
    INSERT INTO dbo.GUEST (USER_ID, BIRTH_DATE, GENDER)
    VALUES
        (1, '1998-05-12', 'MALE'),
        (2, '2000-08-20', 'FEMALE'),
        (3, '1995-11-03', 'MALE'),
        (4, '2002-01-15', 'FEMALE'),
        (5, '1999-07-30', 'OTHER');

    INSERT INTO dbo.HOST (USER_ID, TAX_CODE, BUSINESS_NAME, BANK_ACCOUNT)
    VALUES
        (6,  '0312345601', N'Công ty TNHH Khách Sạn Sài Gòn Star',      '1903000111222 - Techcombank'),
        (7,  '0402345602', N'Doanh nghiệp Tư nhân Biển Xanh Đà Nẵng',    '0041000222333 - Vietcombank'),
        (8,  '5802345603', N'Hộ Kinh Doanh Lưu Trú Rừng Thông Đà Lạt',   '101000333444 - VietinBank'),
        (9,  '1702345604', N'Công ty CP Nghỉ Dưỡng Đảo Ngọc Phú Quốc',   '2151000444555 - BIDV'),
        (10, '0102345605', N'Công ty TNHH Khách Sạn & Căn Hộ Hà Nội Cổ', '0011000555666 - Vietcombank');

    INSERT INTO dbo.[ADMIN] (USER_ID, ADMIN_ROLE)
    VALUES
        (11, N'Super Admin'),
        (12, N'Content Moderator'),
        (13, N'Finance & Payment Manager'),
        (14, N'Customer Support Specialist'),
        (15, N'Host Verification Officer');

    -- =========================================================================
    -- 6-7. Bảng WALLET (5 dòng cho 5 GUEST) & WALLET_TRANSACTION (5 dòng)
    -- =========================================================================
    INSERT INTO dbo.WALLET (USER_ID, BALANCE, LOYALTY_POINTS)
    VALUES
        (1, 2500000.00, 150),
        (2, 1200000.00, 80),
        (3, 500000.00,  40),
        (4, 3800000.00, 320),
        (5, 150000.00,  10);

    INSERT INTO dbo.WALLET_TRANSACTION (USER_ID, TRANSACTION_HISTORY)
    VALUES
        (1, N'2026-08-01 09:00: Nạp 2,500,000 VND từ thẻ Visa 4111'),
        (2, N'2026-08-05 14:30: Nhận hoàn tiền 1,200,000 VND vào ví'),
        (3, N'2026-08-10 10:15: Nạp 500,000 VND qua ngân hàng liên kết'),
        (4, N'2026-08-15 16:00: Tích lũy 320 điểm thưởng khách hàng thân thiết'),
        (5, N'2026-08-20 11:20: Nạp 150,000 VND và nhận 10 điểm mở ví');

    -- =========================================================================
    -- 8. Bảng COMPANION (5 dòng: đánh số riêng theo từng khách)
    -- =========================================================================
    INSERT INTO dbo.COMPANION (USER_ID, COMPANION_NO, FULL_NAME, BIRTH_DATE, PHONE_NUMBER)
    VALUES
        (1, 1, N'Nguyễn Thị Mai',  '2000-03-10', '0911111111'),
        (1, 2, N'Nguyễn Bé Bi',    '2020-06-01', NULL),
        (2, 1, N'Trần Văn Nam',    '1997-12-12', '0922222222'),
        (3, 1, N'Lê Thị Hương',    '1996-04-25', '0933333333'),
        (4, 1, N'Phạm Quốc Khánh', '2001-09-02', '0944444444');

    -- =========================================================================
    -- 9. Bảng PAYMENT_CARD (5 dòng: thẻ giả lập cho 5 GUEST)
    -- =========================================================================
    INSERT INTO dbo.PAYMENT_CARD (CARD_NUMBER, CARDHOLDER_NAME, EXPIRY_DATE, CARD_TYPE, USER_ID)
    VALUES
        ('4111222233334441', N'NGUYEN VAN AN',  '2028-12-31', 'VISA',       1),
        ('5111222233334442', N'TRAN THI BINH',  '2027-08-31', 'MASTERCARD', 2),
        ('4111222233334443', N'LE HOANG CUONG', '2029-05-31', 'VISA',       3),
        ('3566222233334444', N'PHAM MINH DUNG', '2028-03-31', 'JCB',        4),
        ('5111222233334445', N'HOANG GIA BAO',  '2027-11-30', 'MASTERCARD', 5);

    -- =========================================================================
    -- 10. Bảng VOUCHER (6 dòng: phủ đủ USED, ACTIVE, EXPIRED; gắn đúng GUEST)
    -- =========================================================================
    INSERT INTO dbo.VOUCHER (VOUCHER_CODE, DISCOUNT_VALUE, APPLICABLE_CONDITIONS, EXPIRY_DATE, [STATUS], USER_ID)
    VALUES
        ('VC_GUEST1_100K', 100000.00, N'Giảm 100,000 VND cho đơn từ 1,000,000 VND', '2026-12-31', 'USED',    1),
        ('VC_GUEST2_200K', 200000.00, N'Giảm 200,000 VND cho đơn từ 2,000,000 VND', '2026-12-31', 'USED',    2),
        ('VC_GUEST3_150K', 150000.00, N'Giảm 150,000 VND cho đơn từ 1,500,000 VND', '2026-12-31', 'USED',    3),
        ('VC_GUEST4_300K', 300000.00, N'Giảm 300,000 VND cho đơn từ 3,000,000 VND', '2026-12-31', 'USED',    4),
        ('VC_GUEST5_50K',  50000.00,  N'Giảm 50,000 VND cho mọi đơn đặt phòng',     '2026-12-31', 'USED',    5),
        ('VC_EXPIRED_99K', 99000.00,  N'Voucher sự kiện mùa hè (đã hết hạn)',       '2026-06-30', 'EXPIRED', 1),
        ('VC_ACTIVE_500K', 500000.00, N'Voucher ưu đãi cuối năm (chưa sử dụng)',    '2026-12-31', 'ACTIVE',  2);

    -- =========================================================================
    -- 11. Bảng ACCOMMODATION (20 cơ sở lưu trú:
    --     1-5: HOTEL | 6-10: RESORT | 11-15: APARTMENT | 16-20: HOMESTAY)
    -- =========================================================================
    SET IDENTITY_INSERT dbo.ACCOMMODATION ON;
    INSERT INTO dbo.ACCOMMODATION (ACCOMMODATION_ID, [NAME], [DESCRIPTION], STAR_RATING, CHECK_IN_TIME, CHECK_OUT_TIME, CANCELLATION_POLICY, PET_POLICY, CHILD_POLICY, CONTACT_EMAIL, PHONE_NUMBER, STREET_ADDRESS, WARD, DISTRICT, CITY, LONGITUDE, LATITUDE, USER_ID)
    VALUES
        -- 1..5: HOTEL (chủ cơ sở lần lượt là HOST 6, 7, 8, 9, 10)
        (1,  N'Saigon Majestic Hotel',       N'Khách sạn 5 sao trung tâm Quận 1',       5, '14:00:00', '12:00:00', N'Hủy miễn phí trước 24h', N'Không mang thú cưng',   N'Trẻ dưới 6 tuổi miễn phí',   N'info@majestic.vn',     '02838225555', N'01 Đồng Khởi',          N'Bến Nghé',          N'Quận 1',       N'TP.HCM',     106.7068500, 10.7731200, 6),
        (2,  N'Danang Han River Hotel',      N'Khách sạn 4 sao view cầu Rồng',          4, '14:00:00', '12:00:00', N'Hủy miễn phí trước 48h', N'Không mang thú cưng',   N'Trẻ em tính phụ phí ăn sáng', N'contact@hanhotel.vn',  '02363888999', N'12 Bạch Đằng',          N'Thạch Thang',       N'Hải Châu',     N'Đà Nẵng',    108.2240100, 16.0716800, 7),
        (3,  N'Dalat Palace Heritage Hotel', N'Khách sạn cổ điển nhìn ra Hồ Xuân Hương',5, '14:00:00', '11:30:00', N'Hủy trước 72h',          N'Không mang thú cưng',   N'Nhận trẻ em mọi lứa tuổi',    N'book@dalatpalace.vn',  '02633825444', N'02 Trần Phú',           N'Phường 3',          N'Đà Lạt',       N'Lâm Đồng',   108.4385000, 11.9362000, 8),
        (4,  N'Phu Quoc Ocean Pearl Hotel',  N'Khách sạn gần chợ đêm Dương Đông',       4, '14:00:00', '12:00:00', N'Hủy miễn phí trước 24h', N'Không mang thú cưng',   N'Miễn phí 1 trẻ dưới 12 tuổi', N'stay@oceanpearl.vn',   '02973999111', N'99 Trần Hưng Đạo',      N'Dương Đông',        N'Phú Quốc',     N'Kiên Giang', 103.9632000, 10.2115000, 9),
        (5,  N'Hanoi Old Quarter Boutique',  N'Khách sạn phố cổ Hà Nội ấm cúng',        4, '14:00:00', '12:00:00', N'Hủy miễn phí trước 24h', N'Không mang thú cưng',   N'Trẻ dưới 6 tuổi miễn phí',   N'hello@hanoiboutique.vn','02439261111', N'36 Hàng Đào',           N'Hàng Đào',          N'Hoàn Kiếm',    N'Hà Nội',     105.8516000, 21.0335000, 10),
        -- 6..10: RESORT
        (6,  N'Can Gio Mangrove Resort',     N'Resort sinh thái rừng ngập mặn Cần Giờ', 4, '15:00:00', '12:00:00', N'Hủy trước 72h',          N'Cho phép thú cưng nhỏ', N'Có khu vui chơi trẻ em',      N'res1@resort.vn',       '02838881111', N'Đường Thạnh Thới',      N'Long Hòa',          N'Cần Giờ',      N'TP.HCM',     106.8901000, 10.3852000, 6),
        (7,  N'My Khe Beachfront Resort',    N'Resort 5 sao sát bãi biển Mỹ Khê',       5, '15:00:00', '12:00:00', N'Hủy trước 7 ngày',       N'Không mang thú cưng',   N'Miễn phí 2 trẻ dưới 6 tuổi',  N'res2@resort.vn',       '02363999222', N'88 Võ Nguyên Giáp',     N'Mỹ An',             N'Ngũ Hành Sơn', N'Đà Nẵng',    108.2485000, 16.0402000, 7),
        (8,  N'Tuyen Lam Pine Resort',       N'Resort nghỉ dưỡng ven hồ Tuyền Lâm',     5, '14:00:00', '12:00:00', N'Hủy trước 3 ngày',       N'Không mang thú cưng',   N'Trẻ em có giường phụ riêng',  N'res3@resort.vn',       '02633777333', N'Phân khu 7 Tuyền Lâm',  N'Phường 4',          N'Đà Lạt',       N'Lâm Đồng',   108.4301000, 11.8954000, 8),
        (9,  N'Bai Kem Emerald Resort',      N'Resort biệt thự biển Bãi Kem Phú Quốc',  5, '15:00:00', '12:00:00', N'Không hoàn hủy',         N'Không mang thú cưng',   N'Tặng vé khu vui chơi trẻ em', N'res4@resort.vn',       '02973888444', N'Bãi Kem',               N'An Thới',           N'Phú Quốc',     N'Kiên Giang', 104.0251000, 10.0385000, 9),
        (10, N'Ba Vi Mountain Retreat',      N'Resort nghỉ dưỡng núi Ba Vì xanh mát',   4, '14:00:00', '12:00:00', N'Hủy trước 48h',          N'Cho phép thú cưng',     N'Trẻ dưới 10 tuổi miễn phí',   N'res5@resort.vn',       '02436665555', N'Km 12 Vườn Quốc Gia',   N'Tản Lĩnh',          N'Ba Vì',        N'Hà Nội',     105.3782000, 21.0765000, 10),
        -- 11..15: APARTMENT
        (11, N'Landmark 81 Sky Apartment',   N'Căn hộ cao cấp view sông Sài Gòn',       5, '14:00:00', '12:00:00', N'Hủy miễn phí trước 24h', N'Cho phép thú cưng',     N'Phù hợp gia đình có trẻ nhỏ', N'apt1@stay.vn',         '0908111001',  N'720A Điện Biên Phủ',    N'Phường 22',         N'Bình Thạnh',   N'TP.HCM',     106.7218000, 10.7948000, 6),
        (12, N'Son Tra Ocean Apartment',     N'Căn hộ đầy đủ bếp gần biển Sơn Trà',     4, '14:00:00', '12:00:00', N'Hủy miễn phí trước 24h', N'Không mang thú cưng',   N'Có nôi trẻ em miễn phí',      N'apt2@stay.vn',         '0908111002',  N'15 Phạm Văn Đồng',      N'An Hải Bắc',        N'Sơn Trà',      N'Đà Nẵng',    108.2412000, 16.0701000, 7),
        (13, N'Dalat Valley View Condo',     N'Căn hộ yên tĩnh nhìn ra thung lũng',     3, '14:00:00', '12:00:00', N'Hủy trước 48h',          N'Không mang thú cưng',   N'Trẻ em ở chung giường bố mẹ', N'apt3@stay.vn',         '0908111003',  N'28 Khởi Nghĩa Bắc Sơn', N'Phường 10',         N'Đà Lạt',       N'Lâm Đồng',   108.4521000, 11.9388000, 8),
        (14, N'Sunset Town Studio Phu Quoc', N'Căn hộ ngắm hoàng hôn Cầu Hôn',         4, '14:00:00', '12:00:00', N'Hủy trước 24h',          N'Cho phép mèo nhỏ',      N'Nhận gia đình có trẻ em',     N'apt4@stay.vn',         '0908111004',  N'Thị trấn Hoàng Hôn',    N'An Thới',           N'Phú Quốc',     N'Kiên Giang', 104.0065000, 10.0321000, 9),
        (15, N'West Lake Serviced Residence',N'Căn hộ dịch vụ ven Hồ Tây lộng gió',    4, '14:00:00', '12:00:00', N'Hủy trước 48h',          N'Cho phép thú cưng',     N'Miễn phí trẻ dưới 12 tuổi',   N'apt5@stay.vn',         '0908111005',  N'58 Quảng An',           N'Quảng An',          N'Tây Hồ',       N'Hà Nội',     105.8234000, 21.0642000, 10),
        -- 16..20: HOMESTAY
        (16, N'Saigon Vintage Homestay',     N'Homestay phong cách Sài Gòn xưa',        3, '14:00:00', '12:00:00', N'Hủy miễn phí trước 24h', N'Cho phép thú cưng',     N'Trẻ em được chào đón',        N'home1@stay.vn',        '0909222001',  N'14 Tôn Thất Đạm',       N'Nguyễn Thái Bình',  N'Quận 1',       N'TP.HCM',     106.7041000, 10.7705000, 6),
        (17, N'An Thuong Boho Homestay',     N'Homestay khu phố Tây An Thượng',         3, '14:00:00', '12:00:00', N'Hủy miễn phí trước 24h', N'Cho phép chó mèo',      N'Trẻ dưới 6 tuổi miễn phí',    N'home2@stay.vn',        '0909222002',  N'05 An Thượng 2',        N'Mỹ An',             N'Ngũ Hành Sơn', N'Đà Nẵng',    108.2468000, 16.0504000, 7),
        (18, N'Dalat Cloud Hunting Home',    N'Homestay săn mây Cầu Đất Đà Lạt',        3, '13:00:00', '11:00:00', N'Hủy trước 48h',          N'Cho phép chó mèo',      N'Có sân vườn cho trẻ chơi',    N'home3@stay.vn',        '0909222003',  N'Thôn Cầu Đất',          N'Xuân Trường',       N'Đà Lạt',       N'Lâm Đồng',   108.5412000, 11.8721000, 8),
        (19, N'Ham Ninh Fishing Homestay',   N'Homestay làng chài Hàm Ninh mộc mạc',    3, '14:00:00', '12:00:00', N'Hủy miễn phí trước 24h', N'Không mang thú cưng',   N'Trẻ em trải nghiệm câu cá',   N'home4@stay.vn',        '0909222004',  N'Ấp Rạch Hàm',           N'Hàm Ninh',          N'Phú Quốc',     N'Kiên Giang', 104.0482000, 10.1823000, 9),
        (20, N'Hanoi Alley Garden Homestay', N'Homestay sân vườn yên tĩnh giữa phố cổ', 3, '14:00:00', '12:00:00', N'Hủy miễn phí trước 24h', N'Cho phép thú cưng',     N'Phù hợp gia đình nhỏ',        N'home5@stay.vn',        '0909222005',  N'12 Ngõ Huyện',          N'Hàng Trống',        N'Hoàn Kiếm',    N'Hà Nội',     105.8489000, 21.0287000, 10);
    SET IDENTITY_INSERT dbo.ACCOMMODATION OFF;

    -- =========================================================================
    -- 12. Bảng WISHLIST (5 dòng: mỗi cặp khách - cơ sở là duy nhất)
    -- =========================================================================
    SET IDENTITY_INSERT dbo.WISHLIST ON;
    INSERT INTO dbo.WISHLIST (WISHLIST_ID, SAVED_DATE, USER_ID, ACCOMMODATION_ID)
    VALUES
        (1, '2026-08-01 10:00:00', 1, 2),
        (2, '2026-08-02 11:00:00', 2, 3),
        (3, '2026-08-03 12:00:00', 3, 7),
        (4, '2026-08-04 13:00:00', 4, 9),
        (5, '2026-08-05 14:00:00', 5, 11);
    SET IDENTITY_INSERT dbo.WISHLIST OFF;

    -- =========================================================================
    -- 13-17. Các bảng loại hình: HOTEL (1-5), HOTEL_FACILITIES, RESORT (6-10),
    --        APARTMENT (11-15), HOMESTAY (16-20) -> Phân loại hoàn toàn tách biệt
    -- =========================================================================
    INSERT INTO dbo.HOTEL (ACCOMMODATION_ID, NUMBER_OF_FLOORS)
    VALUES
        (1, 12),
        (2, 15),
        (3, 5),
        (4, 10),
        (5, 8);

    INSERT INTO dbo.HOTEL_FACILITIES (ACCOMMODATION_ID, COMMON_FACILITIES)
    VALUES
        (1, N'Hồ bơi vô cực tầng thượng'),
        (1, N'Phòng hội nghị 500 khách'),
        (2, N'Quầy Bar Sky Lounge'),
        (3, N'Sân Golf & Spa cổ điển'),
        (4, N'Nhà hàng Buffet Hải sản'),
        (5, N'Dịch vụ đưa đón sân bay Nội Bài');

    INSERT INTO dbo.RESORT (ACCOMMODATION_ID, PROPERTY_AREA)
    VALUES
        (6,  15000.00),
        (7,  32000.50),
        (8,  45000.00),
        (9,  60000.00),
        (10, 28500.00);

    INSERT INTO dbo.APARTMENT (ACCOMMODATION_ID, NUMBER_OF_BEDROOMS)
    VALUES
        (11, 3),
        (12, 2),
        (13, 2),
        (14, 1),
        (15, 2);

    INSERT INTO dbo.HOMESTAY (ACCOMMODATION_ID, HOUSE_TYPE, NUMBER_OF_RENTAL_ROOMS)
    VALUES
        (16, N'Nhà phố cổ Sài Gòn',   4),
        (17, N'Biệt thự sân vườn',    6),
        (18, N'Nhà gỗ đồi thông',     5),
        (19, N'Nhà sàn ven biển',     4),
        (20, N'Nhà cổ Hà Nội 2 tầng', 3);

    -- =========================================================================
    -- 18-19. Bảng AMENITY (6 dòng) & ACCOMMODATION_AMENITY (6 dòng)
    -- =========================================================================
    INSERT INTO dbo.AMENITY (AMENITY_NAME, AMENITY_GROUP)
    VALUES
        (N'Wi-Fi tốc độ cao miễn phí', N'Internet'),
        (N'Hồ bơi ngoài trời',          N'Thư giãn & Giải trí'),
        (N'Bãi đỗ xe miễn phí',         N'Phương tiện đi lại'),
        (N'Nhà hàng & Quầy Bar',        N'Ẩm thực'),
        (N'Phòng tập Gym & Spa',        N'Sức khỏe'),
        (N'Lễ tân 24/7',                N'Dịch vụ lễ tân');

    INSERT INTO dbo.ACCOMMODATION_AMENITY (ACCOMMODATION_ID, AMENITY_NAME)
    VALUES
        (1, N'Wi-Fi tốc độ cao miễn phí'),
        (1, N'Hồ bơi ngoài trời'),
        (2, N'Wi-Fi tốc độ cao miễn phí'),
        (3, N'Bãi đỗ xe miễn phí'),
        (4, N'Nhà hàng & Quầy Bar'),
        (5, N'Lễ tân 24/7');

    -- =========================================================================
    -- 20-23. ROOM_TYPE (6 dòng), ROOM_TYPE_AMENITIES (6 dòng),
    --        ROOM (12 phòng thực tế >= 10), ROOM_RATE (6 dòng)
    -- =========================================================================
    INSERT INTO dbo.ROOM_TYPE (ACCOMMODATION_ID, ROOM_NAME, AREA, NUMBER_OF_BEDS, BED_TYPE, ADULTS, CHILDREN, [VIEW])
    VALUES
        (1, N'Deluxe River View',      38.50, 1, N'1 Giường King',    2, 1, N'Hướng sông Sài Gòn'),
        (1, N'Executive Suite',        65.00, 2, N'2 Giường Queen',   4, 2, N'Hướng toàn cảnh thành phố'),
        (2, N'Superior Ocean View',    32.00, 1, N'1 Giường Queen',   2, 1, N'Hướng biển Mỹ Khê'),
        (3, N'Classic Pine Room',      40.00, 2, N'2 Giường Đơn',     2, 1, N'Hướng rừng thông & Hồ'),
        (4, N'Family Sunset Bungalow', 55.00, 2, N'2 Giường King',    4, 2, N'Hướng hoàng hôn biển'),
        (5, N'Old Quarter Studio',     28.00, 1, N'1 Giường Đôi Lớn', 2, 0, N'Hướng phố cổ Hà Nội');

    INSERT INTO dbo.ROOM_TYPE_AMENITIES (ACCOMMODATION_ID, ROOM_NAME, IN_ROOM_AMENITIES)
    VALUES
        (1, N'Deluxe River View',      N'Bồn tắm nằm Jacuzzi'),
        (1, N'Executive Suite',        N'Máy pha cà phê Espresso'),
        (2, N'Superior Ocean View',    N'Ban công riêng hướng biển'),
        (3, N'Classic Pine Room',      N'Hệ thống sưởi ấm & Lò sưởi'),
        (4, N'Family Sunset Bungalow', N'Smart TV 65 inch Netflix'),
        (5, N'Old Quarter Studio',     N'Két sắt an toàn & Minibar');

    INSERT INTO dbo.ROOM (ACCOMMODATION_ID, ROOM_NAME, ROOM_NUMBER, AVAILABILITY_STATUS)
    VALUES
        (1, N'Deluxe River View',      '101', 'AVAILABLE'),
        (1, N'Deluxe River View',      '102', 'BOOKED'),
        (1, N'Executive Suite',        '201', 'AVAILABLE'),
        (1, N'Executive Suite',        '202', 'MAINTENANCE'),
        (2, N'Superior Ocean View',    '301', 'AVAILABLE'),
        (2, N'Superior Ocean View',    '302', 'BOOKED'),
        (3, N'Classic Pine Room',      '105', 'AVAILABLE'),
        (3, N'Classic Pine Room',      '106', 'AVAILABLE'),
        (4, N'Family Sunset Bungalow', 'B01', 'BOOKED'),
        (4, N'Family Sunset Bungalow', 'B02', 'AVAILABLE'),
        (5, N'Old Quarter Studio',     '401', 'AVAILABLE'),
        (5, N'Old Quarter Studio',     '402', 'AVAILABLE');

    INSERT INTO dbo.ROOM_RATE (ACCOMMODATION_ID, ROOM_NAME, ROOM_RATE_ID, UNIT_PRICE, FREE_CANCELLATION, EFFECTIVE_DATE, CHILD_PRICE, BREAKFAST_INCLUDED)
    VALUES
        (1, N'Deluxe River View',      1, 2500000.00, 1, '2026-01-01', 250000.00, 1),
        (1, N'Executive Suite',        1, 4200000.00, 1, '2026-01-01', 350000.00, 1),
        (2, N'Superior Ocean View',    1, 1500000.00, 1, '2026-01-01', 150000.00, 1),
        (3, N'Classic Pine Room',      1, 2800000.00, 0, '2026-01-01', 200000.00, 1),
        (4, N'Family Sunset Bungalow', 1, 3200000.00, 1, '2026-01-01', 300000.00, 1),
        (5, N'Old Quarter Studio',     1, 1200000.00, 1, '2026-01-01', 0.00,      0);

    -- =========================================================================
    -- 24-26. PHOTO (10 ảnh): 1..5 là ACCOMMODATION_PHOTO, 6..10 là ROOM_TYPE_PHOTO
    -- =========================================================================
    SET IDENTITY_INSERT dbo.PHOTO ON;
    INSERT INTO dbo.PHOTO (PHOTO_ID, URL, [DESCRIPTION], UPLOAD_DATE)
    VALUES
        (1,  N'https://img.booking.vn/accom1_main.jpg',  N'Mặt tiền Saigon Majestic Hotel',    '2026-02-01 08:00:00'),
        (2,  N'https://img.booking.vn/accom2_main.jpg',  N'Toàn cảnh Danang Han River Hotel',  '2026-02-01 08:05:00'),
        (3,  N'https://img.booking.vn/accom3_main.jpg',  N'Khuôn viên Dalat Palace Heritage',  '2026-02-01 08:10:00'),
        (4,  N'https://img.booking.vn/accom4_main.jpg',  N'Hồ bơi Phu Quoc Ocean Pearl',       '2026-02-01 08:15:00'),
        (5,  N'https://img.booking.vn/accom5_main.jpg',  N'Sảnh lễ tân Hanoi Boutique',        '2026-02-01 08:20:00'),
        (6,  N'https://img.booking.vn/room1_deluxe.jpg', N'Không gian phòng Deluxe River View','2026-02-02 09:00:00'),
        (7,  N'https://img.booking.vn/room2_ocean.jpg',  N'Không gian phòng Superior Ocean',   '2026-02-02 09:05:00'),
        (8,  N'https://img.booking.vn/room3_pine.jpg',   N'Không gian phòng Classic Pine Room','2026-02-02 09:10:00'),
        (9,  N'https://img.booking.vn/room4_family.jpg', N'Không gian Bungalow Family Sunset', '2026-02-02 09:15:00'),
        (10, N'https://img.booking.vn/room5_studio.jpg', N'Không gian phòng Old Quarter Studio','2026-02-02 09:20:00');
    SET IDENTITY_INSERT dbo.PHOTO OFF;

    INSERT INTO dbo.ACCOMMODATION_PHOTO (PHOTO_ID, ACCOMMODATION_ID)
    VALUES
        (1, 1),
        (2, 2),
        (3, 3),
        (4, 4),
        (5, 5);

    INSERT INTO dbo.ROOM_TYPE_PHOTO (PHOTO_ID, ACCOMMODATION_ID, ROOM_NAME)
    VALUES
        (6,  1, N'Deluxe River View'),
        (7,  2, N'Superior Ocean View'),
        (8,  3, N'Classic Pine Room'),
        (9,  4, N'Family Sunset Bungalow'),
        (10, 5, N'Old Quarter Studio');

    -- =========================================================================
    -- 27. Bảng BOOKING (12 đơn đặt phòng:
    --     1..5: COMPLETED (để có 5 REVIEW hợp lệ sau ngày trả phòng)
    --     6..10: CANCELLED (để có 5 CANCELLATION hợp lệ)
    --     11: CONFIRMED | 12: PENDING)
    -- =========================================================================
    SET IDENTITY_INSERT dbo.BOOKING ON;
    INSERT INTO dbo.BOOKING (BOOKING_ID, [STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE, CHECK_IN_DATE, CHECK_OUT_DATE, ESTIMATED_ARRIVAL_TIME, SPECIAL_REQUESTS, USER_ID, ACCOMMODATION_ID)
    VALUES
        -- 5 đơn COMPLETED
        (1,  'COMPLETED', 2, 1, 'BK20260001', '1001', '2026-09-01', '2026-09-05', '2026-09-07', '14:00:00', N'Phòng tầng cao, yên tĩnh',          1, 1),
        (2,  'COMPLETED', 2, 0, 'BK20260002', '1002', '2026-09-05', '2026-09-10', '2026-09-12', '14:30:00', N'Chuẩn bị hoa kỷ niệm ngày cưới',    2, 2),
        (3,  'COMPLETED', 2, 1, 'BK20260003', '1003', '2026-09-10', '2026-09-15', '2026-09-18', '15:00:00', N'Nhận phòng sớm nếu có thể',         3, 3),
        (4,  'COMPLETED', 4, 2, 'BK20260004', '1004', '2026-09-12', '2026-09-20', '2026-09-22', '14:00:00', N'Cần thêm 2 gối nằm mềm',            4, 4),
        (5,  'COMPLETED', 2, 0, 'BK20260005', '1005', '2026-09-18', '2026-09-25', '2026-09-27', '13:30:00', N'Phòng không hút thuốc',             5, 5),
        -- 5 đơn CANCELLED
        (6,  'CANCELLED', 2, 0, 'BK20260006', '1006', '2026-10-01', '2026-10-10', '2026-10-12', '14:00:00', NULL,                                 1, 2),
        (7,  'CANCELLED', 2, 1, 'BK20260007', '1007', '2026-10-02', '2026-10-15', '2026-10-17', '15:00:00', NULL,                                 2, 3),
        (8,  'CANCELLED', 4, 1, 'BK20260008', '1008', '2026-10-03', '2026-10-18', '2026-10-20', '16:00:00', NULL,                                 3, 4),
        (9,  'CANCELLED', 2, 0, 'BK20260009', '1009', '2026-10-04', '2026-10-22', '2026-10-24', '14:00:00', NULL,                                 4, 5),
        (10, 'CANCELLED', 2, 0, 'BK20260010', '1010', '2026-10-05', '2026-10-25', '2026-10-27', '14:00:00', NULL,                                 5, 1),
        -- 1 đơn CONFIRMED & 1 đơn PENDING
        (11, 'CONFIRMED', 2, 1, 'BK20260011', '1011', '2026-11-01', '2026-11-20', '2026-11-22', '14:00:00', N'Có trẻ nhỏ đi cùng',                1, 3),
        (12, 'PENDING',   2, 0, 'BK20260012', '1012', '2026-11-10', '2026-12-01', '2026-12-03', '15:00:00', N'Thanh toán tại khách sạn khi đến',  2, 1);
    SET IDENTITY_INSERT dbo.BOOKING OFF;

    -- =========================================================================
    -- 28. Bảng BOOKING_ROOM_TYPE (12 dòng: khớp đúng cơ sở của từng đơn)
    -- =========================================================================
    INSERT INTO dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
    VALUES
        (1,  1, N'Deluxe River View',      2500000.00, 1),
        (2,  2, N'Superior Ocean View',    1500000.00, 1),
        (3,  3, N'Classic Pine Room',      2800000.00, 1),
        (4,  4, N'Family Sunset Bungalow', 3200000.00, 1),
        (5,  5, N'Old Quarter Studio',     1200000.00, 1),
        (6,  2, N'Superior Ocean View',    1500000.00, 1),
        (7,  3, N'Classic Pine Room',      2800000.00, 1),
        (8,  4, N'Family Sunset Bungalow', 3200000.00, 1),
        (9,  5, N'Old Quarter Studio',     1200000.00, 1),
        (10, 1, N'Deluxe River View',      2500000.00, 1),
        (11, 3, N'Classic Pine Room',      2800000.00, 1),
        (12, 1, N'Deluxe River View',      2500000.00, 1);

    -- =========================================================================
    -- 29. Bảng BOOKING_VOUCHER (5 dòng: khách nào dùng đúng voucher của khách đó)
    -- =========================================================================
    INSERT INTO dbo.BOOKING_VOUCHER (BOOKING_ID, VOUCHER_CODE)
    VALUES
        (1, 'VC_GUEST1_100K'),
        (2, 'VC_GUEST2_200K'),
        (3, 'VC_GUEST3_150K'),
        (4, 'VC_GUEST4_300K'),
        (5, 'VC_GUEST5_50K');

    -- =========================================================================
    -- 30. Bảng PAYMENT (12 dòng: khớp 1:1 với 12 BOOKING, đủ PAID/REFUNDED/FAILED/PENDING,
    --     tổng tiền khớp chính xác: Số đêm * Giá phòng * Số lượng - Voucher)
    -- =========================================================================
    SET IDENTITY_INSERT dbo.PAYMENT ON;
    INSERT INTO dbo.PAYMENT (PAYMENT_ID, TRANSACTION_CODE, CURRENCY, PAYMENT_DATE, PAYMENT_METHOD, AMOUNT, PAYMENT_STATUS, BOOKING_ID, CARD_NUMBER)
    VALUES
        (1,  'TXN20260001', 'VND', '2026-09-01 10:15:00', 'CARD',        4900000.00, 'PAID',     1,  '4111222233334441'),
        (2,  'TXN20260002', 'VND', '2026-09-05 14:20:00', 'CARD',        2800000.00, 'PAID',     2,  '5111222233334442'),
        (3,  'TXN20260003', 'VND', '2026-09-10 09:30:00', 'CARD',        8250000.00, 'PAID',     3,  '4111222233334443'),
        (4,  'TXN20260004', 'VND', '2026-09-12 16:45:00', 'CARD',        6100000.00, 'PAID',     4,  '3566222233334444'),
        (5,  'TXN20260005', 'VND', '2026-09-18 11:00:00', 'CARD',        2350000.00, 'PAID',     5,  '5111222233334445'),
        (6,  'TXN20260006', 'VND', '2026-10-01 08:30:00', 'CARD',        3000000.00, 'REFUNDED', 6,  '4111222233334441'),
        (7,  'TXN20260007', 'VND', '2026-10-02 10:00:00', 'CARD',        5600000.00, 'REFUNDED', 7,  '5111222233334442'),
        (8,  'TXN20260008', 'VND', '2026-10-03 15:10:00', 'CARD',        6400000.00, 'PAID',     8,  '4111222233334443'),
        (9,  'TXN20260009', 'VND', '2026-10-04 19:20:00', 'CARD',        2400000.00, 'FAILED',   9,  '3566222233334444'),
        (10, NULL,          'VND', NULL,                  'AT_PROPERTY', 5000000.00, 'PENDING',  10, NULL),
        (11, 'TXN20260011', 'VND', '2026-11-01 12:00:00', 'CARD',        5600000.00, 'PAID',     11, '4111222233334441'),
        (12, NULL,          'VND', NULL,                  'AT_PROPERTY', 5000000.00, 'PENDING',  12, NULL);
    SET IDENTITY_INSERT dbo.PAYMENT OFF;

    -- =========================================================================
    -- 31. Bảng CANCELLATION (5 dòng cho đúng 5 đơn CANCELLED 6..10;
    --     Tiền hoàn + Phí hủy khớp đúng số tiền đã thanh toán ở PAYMENT)
    -- =========================================================================
    INSERT INTO dbo.CANCELLATION (BOOKING_ID, CANCELLATION_ID, CANCELLATION_DATE, REASON, REFUND_STATUS, REFUND_AMOUNT, CANCELLATION_FEE)
    VALUES
        (6,  1, '2026-10-05 09:00:00', N'Thay đổi lịch công tác, hủy trước hạn miễn phí', 'COMPLETED',    3000000.00, 0.00),
        (7,  1, '2026-10-13 14:00:00', N'Có việc gia đình đột xuất, chịu phí hủy 600k',   'COMPLETED',    5000000.00, 600000.00),
        (8,  1, '2026-10-16 10:30:00', N'Hoãn chuyến bay do thời tiết, đang chờ hoàn',    'PENDING',      6000000.00, 400000.00),
        (9,  1, '2026-10-04 19:25:00', N'Giao dịch thẻ thất bại nên hệ thống hủy đơn',    'NOT_REQUIRED', 0.00,       0.00),
        (10, 1, '2026-10-20 08:00:00', N'Khách hủy đơn trả tại khách sạn trước ngày đến', 'NOT_REQUIRED', 0.00,       0.00);

    -- =========================================================================
    -- 32. Bảng REVIEW (5 dòng cho đúng 5 đơn COMPLETED 1..5;
    --     REVIEW_DATE sau ngày CHECK_OUT_DATE; điểm trải rộng từ thấp đến cao)
    -- =========================================================================
    SET IDENTITY_INSERT dbo.REVIEW ON;
    INSERT INTO dbo.REVIEW (REVIEW_ID, TITLE, POSITIVE_COMMENT, NEGATIVE_COMMENT, REVIEW_DATE, IS_VERIFIED_STAY, CLEANLINESS, COMFORT, [LOCATION], FACILITIES, STAFF, VALUE_FOR_MONEY, BOOKING_ID)
    VALUES
        (1, N'Kỳ nghỉ 5 sao hoàn hảo',        N'Phòng cực kỳ sạch sẽ, view sông Sài Gòn tuyệt đẹp', N'Không có điểm gì để chê',            '2026-09-08', 1, 9.5, 9.5, 10.0, 9.0, 10.0, 9.5, 1),
        (2, N'Khách sạn tốt, đáng tiền',      N'Ngay gần cầu Rồng, nhân viên thân thiện',           N'Thang máy hơi đông vào giờ ăn sáng', '2026-09-13', 1, 8.0, 8.5, 9.0,  8.0, 8.5,  8.5, 2),
        (3, N'Trải nghiệm mức trung bình khá',N'Không khí Đà Lạt mát mẻ, khuôn viên cổ điển',       N'Phòng cách âm chưa thực sự tốt',     '2026-09-19', 1, 6.5, 7.0, 8.0,  6.5, 7.0,  6.5, 3),
        (4, N'Dịch vụ cần cải thiện thêm',    N'Gần biển và chợ đêm Dương Đông',                    N'Máy lạnh kêu hơi ồn vào ban đêm',    '2026-09-23', 1, 4.5, 4.0, 6.0,  4.5, 5.0,  4.5, 4),
        (5, N'Chưa hài lòng về phòng ở',      N'Vị trí ngay trung tâm phố cổ dễ đi lại',            N'Phòng nhỏ, hơi ẩm và Wifi chập chờn','2026-09-28', 1, 2.5, 2.0, 5.0,  2.0, 3.0,  2.5, 5);
    SET IDENTITY_INSERT dbo.REVIEW OFF;

    -- =========================================================================
    -- 33. Bảng REVIEW_PHOTOS (5 dòng)
    -- =========================================================================
    INSERT INTO dbo.REVIEW_PHOTOS (REVIEW_ID, PHOTO_URL)
    VALUES
        (1, 'https://img.booking.vn/rev1_photo1.jpg'),
        (2, 'https://img.booking.vn/rev2_photo1.jpg'),
        (3, 'https://img.booking.vn/rev3_photo1.jpg'),
        (4, 'https://img.booking.vn/rev4_photo1.jpg'),
        (5, 'https://img.booking.vn/rev5_photo1.jpg');

    -- =========================================================================
    -- 34. Bảng RESPONSE (5 dòng: đúng HOST sở hữu cơ sở của đơn đó đứng ra phản hồi)
    -- =========================================================================
    INSERT INTO dbo.RESPONSE (REVIEW_ID, RESPONSE_DATE, RESPONSE_CONTENT, USER_ID)
    VALUES
        (1, '2026-09-09 09:00:00', N'Cảm ơn anh An đã dành lời khen tuyệt vời cho Saigon Majestic Hotel!',      6),
        (2, '2026-09-14 10:00:00', N'Cảm ơn chị Bình, khách sạn sẽ điều phối thêm thang máy giờ cao điểm ạ.',   7),
        (3, '2026-09-20 11:00:00', N'Cảm ơn anh Cường góp ý, chúng tôi đang nâng cấp hệ thống cửa cách âm.',    8),
        (4, '2026-09-24 14:00:00', N'Xin lỗi chị Dung, bộ phận kỹ thuật đã bảo trì lại máy lạnh ngay lập tức.', 9),
        (5, '2026-09-29 15:00:00', N'Chân thành xin lỗi anh Bảo, khách sạn đã xử lý chống ẩm và thay Router.',  10);

    -- =========================================================================
    -- 35-36. Bảng MESSAGE (10 dòng) & MESSAGE_REPLY (5 dòng)
    --        (Đúng cặp Guest đặt phòng và Host chủ cơ sở của cùng BOOKING_ID)
    -- =========================================================================
    SET IDENTITY_INSERT dbo.[MESSAGE] ON;
    INSERT INTO dbo.[MESSAGE] (MESSAGE_ID, CONTENT, SENT_TIME, IS_READ, ATTACHMENT_URL, SENDER_ID, BOOKING_ID)
    VALUES
        (1,  N'Chào khách sạn, tôi có thể nhận phòng lúc 13h30 ngày 05/09 không?', '2026-09-04 09:00:00', 1, NULL, 1,  1),
        (2,  N'Dạ chào anh An, Saigon Majestic hỗ trợ anh nhận phòng sớm miễn phí ạ!', '2026-09-04 09:15:00', 1, NULL, 6,  1),
        (3,  N'Khách sạn có hỗ trợ trang trí hoa tươi kỷ niệm ngày cưới không?', '2026-09-08 14:00:00', 1, NULL, 2,  2),
        (4,  N'Dạ có ạ, nhân viên buồng phòng sẽ chuẩn bị sẵn hoa hồng trong phòng chị.', '2026-09-08 14:20:00', 1, NULL, 7,  2),
        (5,  N'Thời tiết Đà Lạt giữa tháng 9 có lạnh lắm không khách sạn ơi?', '2026-09-13 10:00:00', 1, NULL, 3,  3),
        (6,  N'Dạ nhiệt độ ban đêm khoảng 16 độ C, trong phòng đã có sẵn máy sưởi ấm ạ.', '2026-09-13 10:10:00', 1, NULL, 8,  3),
        (7,  N'Gia đình mình có 2 bé nhỏ, bungalow có sẵn áo phao trẻ em không?', '2026-09-18 16:00:00', 1, NULL, 4,  4),
        (8,  N'Dạ khu vực hồ bơi và bungalow đều trang bị sẵn áo phao cho các bé ạ.', '2026-09-18 16:30:00', 1, NULL, 9,  4),
        (9,  N'Từ khách sạn đi bộ ra Hồ Gươm mất khoảng bao nhiêu phút vậy ạ?', '2026-09-23 08:00:00', 1, NULL, 5,  5),
        (10, N'Dạ chỉ mất đúng 3 phút đi bộ qua phố Hàng Đào là tới bờ hồ anh nhé!', '2026-09-23 08:12:00', 1, NULL, 10, 5);
    SET IDENTITY_INSERT dbo.[MESSAGE] OFF;

    INSERT INTO dbo.MESSAGE_REPLY (MESSAGE_ID, REPLIED_TO_MESSAGE_ID)
    VALUES
        (2,  1),
        (4,  3),
        (6,  5),
        (8,  7),
        (10, 9);

    COMMIT TRANSACTION;
    PRINT N'Da insert thanh cong du lieu mau cho toan bo 36 bang (>= 5 dong/bang)!';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
