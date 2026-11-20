/*
 BTL2 - Nhóm 5
 Phần 2.1: Thủ tục thêm / sửa / xóa trên bảng BOOKING
 Chạy sau 01_schema.sql và 02_seed.sql. Chạy lại nhiều lần được (CREATE OR ALTER).

 Điều chỉnh theo schema thực tế của nhóm:
 - Đơn đặt theo HẠNG PHÒNG (BOOKING_ROOM_TYPE + RESERVED_QUANTITY), chưa gán phòng cụ thể.
   "Phòng sẵn sàng" = phòng của hạng đó không ở trạng thái MAINTENANCE.
   "Trùng lịch"     = số phòng đã đặt trùng ngày + số phòng đặt thêm > số phòng sẵn sàng.
 - Sức chứa = ROOM_TYPE.ADULTS / (ADULTS + CHILDREN) nhân với số phòng đặt.
 - BOOKING.STATUS chỉ có PENDING, CONFIRMED, COMPLETED, CANCELLED (không có CHECKED_IN):
   PENDING -> CONFIRMED -> COMPLETED; PENDING/CONFIRMED -> CANCELLED.
 - Mã khuyến mãi = VOUCHER (bảng BOOKING_VOUCHER). Schema không có BOOKING_SERVICE/BOOKING_PROMOTION;
   bảng con xóa kèm: BOOKING_ROOM_TYPE, BOOKING_VOUCHER, PAYMENT, CANCELLATION, MESSAGE, MESSAGE_REPLY.
 - GUEST không có cột trạng thái hoạt động nên chỉ kiểm tra USER có vai trò GUEST.
 Mã lỗi: 511xx kiểm tra chung, 5112x thêm, 512xx sửa, 513xx xóa.
*/
USE [BTL2_Booking_Nhom5];
GO

-- Kiểm tra dùng chung cho thêm và sửa: hạng phòng, ngày ở, số khách, trùng lịch; trả về giá phòng.
CREATE OR ALTER PROCEDURE dbo.sp_Booking_ValidateStay
    @AccommodationId  INT,
    @RoomName         NVARCHAR(100),
    @Quantity         SMALLINT,
    @CheckIn          DATE,
    @CheckOut         DATE,
    @Adults           SMALLINT,
    @Children         SMALLINT,
    @ExcludeBookingId INT = NULL,            -- đơn đang sửa, không tính trùng với chính nó
    @UnitPrice        DECIMAL(18,2) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @today DATE = CAST(GETDATE() AS DATE), @msg NVARCHAR(2048),
            @maxAdults INT, @maxChildren INT, @rooms INT, @booked INT, @nights INT;
    SET @UnitPrice = NULL;

    IF NOT EXISTS (SELECT 1 FROM dbo.ACCOMMODATION WHERE ACCOMMODATION_ID = @AccommodationId)
        THROW 51101, N'ACCOMMODATION_ID: cơ sở lưu trú không tồn tại.', 1;

    SELECT @maxAdults = ADULTS, @maxChildren = CHILDREN
    FROM dbo.ROOM_TYPE
    WHERE ACCOMMODATION_ID = @AccommodationId AND ROOM_NAME = @RoomName;
    IF @maxAdults IS NULL
        THROW 51102, N'ROOM_NAME: hạng phòng không tồn tại trong cơ sở lưu trú này.', 1;

    SELECT @rooms = COUNT(*)
    FROM dbo.ROOM
    WHERE ACCOMMODATION_ID = @AccommodationId AND ROOM_NAME = @RoomName
      AND AVAILABILITY_STATUS <> 'MAINTENANCE';
    IF @rooms = 0
        THROW 51103, N'ROOM: hạng phòng không có phòng nào sẵn sàng (chưa có phòng hoặc tất cả đang bảo trì).', 1;

    IF @CheckIn IS NULL OR @CheckOut IS NULL
        THROW 51104, N'CHECK_IN_DATE/CHECK_OUT_DATE: không được để trống.', 1;
    IF @CheckIn < @today
    BEGIN
        SET @msg = CONCAT(N'CHECK_IN_DATE: ngày nhận phòng ', @CheckIn, N' đã qua, phải từ hôm nay (', @today, N') trở đi.');
        THROW 51105, @msg, 1;
    END;
    IF @CheckOut <= @CheckIn
        THROW 51106, N'CHECK_OUT_DATE: ngày trả phòng phải sau ngày nhận phòng.', 1;
    SET @nights = DATEDIFF(DAY, @CheckIn, @CheckOut);
    IF @nights > 30
    BEGIN
        SET @msg = CONCAT(N'CHECK_OUT_DATE: mỗi đơn tối đa 30 đêm, đơn này ', @nights, N' đêm.');
        THROW 51107, @msg, 1;
    END;

    IF ISNULL(@Quantity, 0) < 1
        THROW 51108, N'RESERVED_QUANTITY: số phòng đặt phải từ 1 trở lên.', 1;
    IF ISNULL(@Adults, 0) < 1
        THROW 51109, N'ADULTS: phải có ít nhất 1 người lớn.', 1;
    IF @Children IS NULL OR @Children < 0
        THROW 51110, N'CHILDREN: số trẻ em không được để trống hoặc âm.', 1;
    IF @Adults > @maxAdults * @Quantity OR @Adults + @Children > (@maxAdults + @maxChildren) * @Quantity
    BEGIN
        SET @msg = CONCAT(N'ADULTS/CHILDREN: vượt sức chứa. ', @Quantity, N' phòng "', @RoomName, N'" nhận tối đa ',
                          @maxAdults * @Quantity, N' người lớn và ', (@maxAdults + @maxChildren) * @Quantity,
                          N' khách; đơn có ', @Adults, N' người lớn + ', @Children, N' trẻ em.');
        THROW 51111, @msg, 1;
    END;

    -- UPDLOCK + HOLDLOCK: hai giao dịch đặt cùng lúc không thể cùng vượt qua kiểm tra trùng lịch.
    SELECT @booked = ISNULL(SUM(brt.RESERVED_QUANTITY), 0)
    FROM dbo.BOOKING_ROOM_TYPE brt WITH (UPDLOCK, HOLDLOCK)
    JOIN dbo.BOOKING b ON b.BOOKING_ID = brt.BOOKING_ID
    WHERE brt.ACCOMMODATION_ID = @AccommodationId AND brt.ROOM_NAME = @RoomName
      AND b.[STATUS] <> 'CANCELLED'
      AND b.CHECK_IN_DATE < @CheckOut AND @CheckIn < b.CHECK_OUT_DATE
      AND b.BOOKING_ID <> ISNULL(@ExcludeBookingId, 0);
    IF @booked + @Quantity > @rooms
    BEGIN
        SET @msg = CONCAT(N'Trùng lịch: hạng phòng "', @RoomName, N'" có ', @rooms, N' phòng, đã được đặt ', @booked,
                          N' phòng trong khoảng ', @CheckIn, N' - ', @CheckOut, N'; không đủ thêm ', @Quantity, N' phòng.');
        THROW 51112, @msg, 1;
    END;

    SELECT TOP (1) @UnitPrice = UNIT_PRICE
    FROM dbo.ROOM_RATE
    WHERE ACCOMMODATION_ID = @AccommodationId AND ROOM_NAME = @RoomName AND EFFECTIVE_DATE <= @CheckIn
    ORDER BY EFFECTIVE_DATE DESC, ROOM_RATE_ID DESC;
    IF @UnitPrice IS NULL
        THROW 51113, N'ROOM_RATE: hạng phòng chưa có giá áp dụng cho ngày nhận phòng.', 1;
END;
GO

/* ---------------------------------------------------------------------------
 THÊM: tạo đơn PENDING + 1 dòng BOOKING_ROOM_TYPE (+ BOOKING_VOUCHER nếu có mã).
 Mã đơn sinh theo mẫu dữ liệu: BK + năm + số thứ tự đơn; PIN 4 chữ số ngẫu nhiên.
--------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Booking_Insert
    @UserId               INT,
    @AccommodationId      INT,
    @RoomName             NVARCHAR(100),
    @CheckIn              DATE,
    @CheckOut             DATE,
    @Adults               SMALLINT,
    @Children             SMALLINT = 0,
    @Quantity             SMALLINT = 1,
    @VoucherCode          VARCHAR(50) = NULL,
    @EstimatedArrivalTime TIME(0) = NULL,
    @SpecialRequests      NVARCHAR(1000) = NULL,
    @BookingId            INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @today DATE = CAST(GETDATE() AS DATE), @price DECIMAL(18,2),
            @vOwner INT, @vStatus VARCHAR(10), @vExpiry DATE;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM dbo.GUEST WHERE USER_ID = @UserId)
            THROW 51121, N'USER_ID: khách hàng không tồn tại hoặc tài khoản không có vai trò GUEST.', 1;

        EXEC dbo.sp_Booking_ValidateStay @AccommodationId, @RoomName, @Quantity, @CheckIn, @CheckOut,
                                         @Adults, @Children, NULL, @price OUTPUT;

        IF @VoucherCode IS NOT NULL
        BEGIN
            SELECT @vOwner = USER_ID, @vStatus = [STATUS], @vExpiry = EXPIRY_DATE
            FROM dbo.VOUCHER WITH (UPDLOCK)
            WHERE VOUCHER_CODE = @VoucherCode;
            IF @vOwner IS NULL
                THROW 51122, N'VOUCHER_CODE: mã khuyến mãi không tồn tại.', 1;
            IF @vOwner <> @UserId
                THROW 51123, N'VOUCHER_CODE: mã khuyến mãi không thuộc khách hàng này.', 1;
            IF @vStatus = 'USED'
                THROW 51124, N'VOUCHER_CODE: mã khuyến mãi đã được sử dụng.', 1;
            IF @vStatus = 'EXPIRED' OR @vExpiry < @today
                THROW 51125, N'VOUCHER_CODE: mã khuyến mãi đã hết hạn.', 1;
        END;

        INSERT INTO dbo.BOOKING ([STATUS], ADULTS, CHILDREN, BOOKING_CODE, PIN_CODE, BOOKING_DATE,
                                 CHECK_IN_DATE, CHECK_OUT_DATE, ESTIMATED_ARRIVAL_TIME, SPECIAL_REQUESTS,
                                 USER_ID, ACCOMMODATION_ID)
        VALUES ('PENDING', @Adults, @Children, LEFT(CONVERT(VARCHAR(36), NEWID()), 30),
                RIGHT(CONCAT('000', ABS(CHECKSUM(NEWID()) % 10000)), 4), @today,
                @CheckIn, @CheckOut, @EstimatedArrivalTime, @SpecialRequests, @UserId, @AccommodationId);
        SET @BookingId = SCOPE_IDENTITY();
        UPDATE dbo.BOOKING
        SET BOOKING_CODE = CONCAT('BK', YEAR(@today), FORMAT(@BookingId, '0000'))
        WHERE BOOKING_ID = @BookingId;

        INSERT INTO dbo.BOOKING_ROOM_TYPE (BOOKING_ID, ACCOMMODATION_ID, ROOM_NAME, ROOM_PRICE_AT_BOOKING, RESERVED_QUANTITY)
        VALUES (@BookingId, @AccommodationId, @RoomName, @price, @Quantity);

        IF @VoucherCode IS NOT NULL
        BEGIN
            INSERT INTO dbo.BOOKING_VOUCHER (BOOKING_ID, VOUCHER_CODE) VALUES (@BookingId, @VoucherCode);
            UPDATE dbo.VOUCHER SET [STATUS] = 'USED' WHERE VOUCHER_CODE = @VoucherCode;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------------------------------------------------------------------------
 SỬA: tham số NULL = giữ nguyên giá trị cũ.
 - Đơn COMPLETED / CANCELLED: không được sửa.
 - Đổi phòng, ngày ở, số khách: chỉ đơn PENDING, và không có PAYMENT đang PAID (phải hoàn tiền trước).
 - Đổi trạng thái theo luồng PENDING -> CONFIRMED -> COMPLETED; PENDING/CONFIRMED -> CANCELLED.
--------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Booking_Update
    @BookingId            INT,
    @Status               VARCHAR(12) = NULL,
    @RoomName             NVARCHAR(100) = NULL,
    @Quantity             SMALLINT = NULL,
    @CheckIn              DATE = NULL,
    @CheckOut             DATE = NULL,
    @Adults               SMALLINT = NULL,
    @Children             SMALLINT = NULL,
    @EstimatedArrivalTime TIME(0) = NULL,
    @SpecialRequests      NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @msg NVARCHAR(2048), @cur VARCHAR(12), @accom INT, @price DECIMAL(18,2),
            @curRoom NVARCHAR(100), @curQty SMALLINT, @curIn DATE, @curOut DATE,
            @curAdults SMALLINT, @curChildren SMALLINT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ponytail: mỗi đơn 1 hạng phòng (sp_Booking_Insert chỉ tạo 1 dòng BOOKING_ROOM_TYPE).
        SELECT @cur = b.[STATUS], @accom = b.ACCOMMODATION_ID, @curIn = b.CHECK_IN_DATE, @curOut = b.CHECK_OUT_DATE,
               @curAdults = b.ADULTS, @curChildren = b.CHILDREN,
               @curRoom = brt.ROOM_NAME, @curQty = brt.RESERVED_QUANTITY
        FROM dbo.BOOKING b WITH (UPDLOCK)
        LEFT JOIN dbo.BOOKING_ROOM_TYPE brt ON brt.BOOKING_ID = b.BOOKING_ID
        WHERE b.BOOKING_ID = @BookingId;

        IF @cur IS NULL
            THROW 51201, N'BOOKING_ID: đơn đặt phòng không tồn tại.', 1;
        IF @cur IN ('COMPLETED', 'CANCELLED')
        BEGIN
            SET @msg = CONCAT(N'STATUS: đơn đang ở trạng thái ', @cur, N', không được sửa.');
            THROW 51202, @msg, 1;
        END;

        SELECT @RoomName = ISNULL(@RoomName, @curRoom), @Quantity = ISNULL(@Quantity, @curQty),
               @CheckIn  = ISNULL(@CheckIn, @curIn),    @CheckOut = ISNULL(@CheckOut, @curOut),
               @Adults   = ISNULL(@Adults, @curAdults), @Children = ISNULL(@Children, @curChildren);

        IF @RoomName <> @curRoom OR @Quantity <> @curQty OR @CheckIn <> @curIn OR @CheckOut <> @curOut
           OR @Adults <> @curAdults OR @Children <> @curChildren
        BEGIN
            IF @cur <> 'PENDING'
            BEGIN
                SET @msg = CONCAT(N'STATUS: đơn ', @cur, N' không được đổi phòng, ngày ở hoặc số khách; chỉ đơn PENDING mới được đổi.');
                THROW 51203, @msg, 1;
            END;
            IF EXISTS (SELECT 1 FROM dbo.PAYMENT WHERE BOOKING_ID = @BookingId AND PAYMENT_STATUS = 'PAID')
                THROW 51204, N'PAYMENT: đơn đã thanh toán (PAID), phải hoàn tiền trước khi đổi phòng hoặc ngày ở.', 1;

            EXEC dbo.sp_Booking_ValidateStay @accom, @RoomName, @Quantity, @CheckIn, @CheckOut,
                                             @Adults, @Children, @BookingId, @price OUTPUT;
        END;

        IF @Status IS NOT NULL AND @Status <> @cur
        BEGIN
            IF NOT (   (@cur = 'PENDING'   AND @Status IN ('CONFIRMED', 'CANCELLED'))
                    OR (@cur = 'CONFIRMED' AND @Status IN ('COMPLETED', 'CANCELLED')))
            BEGIN
                SET @msg = CONCAT(N'STATUS: không được chuyển từ ', @cur, N' sang ', @Status,
                                  N'. Luồng hợp lệ: PENDING -> CONFIRMED -> COMPLETED; PENDING/CONFIRMED -> CANCELLED.');
                THROW 51205, @msg, 1;
            END;
            IF @Status = 'COMPLETED' AND CAST(GETDATE() AS DATE) < @CheckIn
                THROW 51206, N'STATUS: chưa đến ngày nhận phòng, không thể chuyển sang COMPLETED.', 1;
        END;

        UPDATE dbo.BOOKING
        SET [STATUS] = ISNULL(@Status, [STATUS]),
            CHECK_IN_DATE = @CheckIn, CHECK_OUT_DATE = @CheckOut,
            ADULTS = @Adults, CHILDREN = @Children,
            ESTIMATED_ARRIVAL_TIME = ISNULL(@EstimatedArrivalTime, ESTIMATED_ARRIVAL_TIME),
            SPECIAL_REQUESTS = ISNULL(@SpecialRequests, SPECIAL_REQUESTS)
        WHERE BOOKING_ID = @BookingId;

        -- Cập nhật chi tiết phòng SAU khi BOOKING đã có ngày mới: trigger sức chứa
        -- đọc CHECK_IN_DATE/CHECK_OUT_DATE từ BOOKING nên phải thấy khoảng ngày cuối
        -- cùng, tránh chặn nhầm khi một lần sửa vừa đổi ngày vừa đổi số lượng.
        IF @RoomName <> @curRoom OR @Quantity <> @curQty OR @CheckIn <> @curIn OR @CheckOut <> @curOut
           OR @Adults <> @curAdults OR @Children <> @curChildren
        BEGIN
            UPDATE dbo.BOOKING_ROOM_TYPE
            SET ROOM_NAME = @RoomName, RESERVED_QUANTITY = @Quantity, ROOM_PRICE_AT_BOOKING = @price
            WHERE BOOKING_ID = @BookingId;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------------------------------------------------------------------------
 XÓA: mục đích là dọn đơn rác (đơn nháp PENDING, đơn CANCELLED chưa phát sinh tiền).
 - Chỉ xóa đơn PENDING hoặc CANCELLED.
 - Cấm xóa đơn CONFIRMED / COMPLETED và đơn có PAYMENT PAID hoặc REFUNDED
   (đã có giao dịch tiền -> giữ lại làm lịch sử giao dịch).
 - Xóa bảng con trong cùng transaction trước khi xóa BOOKING (schema không dùng CASCADE).
   Voucher đã gắn vào đơn được trả lại ACTIVE (hoặc EXPIRED nếu đã quá hạn).
--------------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_Booking_Delete
    @BookingId INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @msg NVARCHAR(2048), @cur VARCHAR(12), @pay VARCHAR(10);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @cur = [STATUS] FROM dbo.BOOKING WITH (UPDLOCK) WHERE BOOKING_ID = @BookingId;
        IF @cur IS NULL
            THROW 51301, N'BOOKING_ID: đơn đặt phòng không tồn tại.', 1;
        IF @cur NOT IN ('PENDING', 'CANCELLED')
        BEGIN
            SET @msg = CONCAT(N'STATUS: không được xóa đơn ', @cur,
                              N'. Chỉ xóa đơn PENDING (nháp) hoặc CANCELLED; đơn đã xác nhận/hoàn thành phải giữ lại.');
            THROW 51302, @msg, 1;
        END;

        SELECT @pay = PAYMENT_STATUS FROM dbo.PAYMENT WHERE BOOKING_ID = @BookingId;
        IF @pay IN ('PAID', 'REFUNDED')
        BEGIN
            SET @msg = CONCAT(N'PAYMENT: đơn đã phát sinh giao dịch thanh toán (', @pay,
                              N'), không được xóa để giữ lịch sử giao dịch.');
            THROW 51303, @msg, 1;
        END;

        UPDATE v
        SET [STATUS] = CASE WHEN v.EXPIRY_DATE < CAST(GETDATE() AS DATE) THEN 'EXPIRED' ELSE 'ACTIVE' END
        FROM dbo.VOUCHER v
        JOIN dbo.BOOKING_VOUCHER bv ON bv.VOUCHER_CODE = v.VOUCHER_CODE
        WHERE bv.BOOKING_ID = @BookingId;

        DELETE FROM dbo.MESSAGE_REPLY
        WHERE MESSAGE_ID IN (SELECT MESSAGE_ID FROM dbo.[MESSAGE] WHERE BOOKING_ID = @BookingId)
           OR REPLIED_TO_MESSAGE_ID IN (SELECT MESSAGE_ID FROM dbo.[MESSAGE] WHERE BOOKING_ID = @BookingId);
        DELETE FROM dbo.[MESSAGE]          WHERE BOOKING_ID = @BookingId;
        DELETE FROM dbo.BOOKING_VOUCHER    WHERE BOOKING_ID = @BookingId;
        DELETE FROM dbo.BOOKING_ROOM_TYPE  WHERE BOOKING_ID = @BookingId;
        DELETE FROM dbo.CANCELLATION       WHERE BOOKING_ID = @BookingId;
        DELETE FROM dbo.PAYMENT            WHERE BOOKING_ID = @BookingId;
        DELETE FROM dbo.BOOKING            WHERE BOOKING_ID = @BookingId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

PRINT N'Đã tạo sp_Booking_ValidateStay, sp_Booking_Insert, sp_Booking_Update, sp_Booking_Delete.';
GO
