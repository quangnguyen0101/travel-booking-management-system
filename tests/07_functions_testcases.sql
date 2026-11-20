/* Kiểm thử hai hàm 2.4. Mọi thay đổi dữ liệu được rollback. */
USE [BTL2_Booking_Nhom5];
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF @@TRANCOUNT <> 0
    THROW 57000, N'Chạy file trong cửa sổ không có transaction đang mở.', 1;

DECLARE @Results TABLE (TestName NVARCHAR(100), Result VARCHAR(4));
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ProbeBookingId INT = 1,
            @GuestId INT,
            @Year INT,
            @Nights INT,
            @RoomQuantity INT,
            @Discount DECIMAL(18,2),
            @TargetTotal DECIMAL(18,2),
            @UnitPrice DECIMAL(18,2),
            @Tier VARCHAR(10),
            @ActualTier VARCHAR(10),
            @NonGuestId INT,
            @MissingUserId INT,
            @MissingBookingId INT,
            @RefundBookingId INT = 8,
            @PaidAmount DECIMAL(18,2),
            @RefundAmount DECIMAL(18,2),
            @CaseNo INT = 1,
            @Today DATE = CONVERT(DATE, GETDATE());

    SELECT @GuestId = USER_ID,
           @Year = YEAR(CHECK_OUT_DATE),
           @Nights = DATEDIFF(DAY, CHECK_IN_DATE, CHECK_OUT_DATE)
    FROM dbo.BOOKING
    WHERE BOOKING_ID = @ProbeBookingId
      AND [STATUS] = 'COMPLETED';

    SELECT @RoomQuantity = SUM(RESERVED_QUANTITY)
    FROM dbo.BOOKING_ROOM_TYPE
    WHERE BOOKING_ID = @ProbeBookingId;

    SELECT @Discount = ISNULL(MAX(v.DISCOUNT_VALUE), 0)
    FROM dbo.BOOKING_VOUCHER AS bv
    JOIN dbo.VOUCHER AS v ON v.VOUCHER_CODE = bv.VOUCHER_CODE
    WHERE bv.BOOKING_ID = @ProbeBookingId;

    IF @GuestId IS NULL OR @Year IS NULL OR @Nights <= 0
       OR @RoomQuantity IS NULL OR @RoomQuantity <> 1
        THROW 57001, N'Cần booking 1 COMPLETED có chi tiết phòng để chạy test.', 1;

    -- Đưa tổng booking 1 lần lượt qua từng ngưỡng, không thêm dữ liệu lâu dài.
    DECLARE @TierCases TABLE
    (
        CaseNo INT PRIMARY KEY,
        TargetTotal DECIMAL(18,2),
        ExpectedTier VARCHAR(10)
    );
    INSERT @TierCases (CaseNo, TargetTotal, ExpectedTier)
    VALUES (1, 4999998.00, 'BRONZE'),
           (2, 5000000.00, 'SILVER'),
           (3, 19999998.00, 'SILVER'),
           (4, 20000000.00, 'GOLD'),
           (5, 49999998.00, 'GOLD'),
           (6, 50000000.00, 'PLATINUM');

    WHILE @CaseNo <= (SELECT COUNT(*) FROM @TierCases)
    BEGIN
        SELECT @TargetTotal = TargetTotal,
               @Tier = ExpectedTier
        FROM @TierCases
        WHERE CaseNo = @CaseNo;

        SET @UnitPrice =
            (@TargetTotal + @Discount) / (@Nights * @RoomQuantity);

        UPDATE dbo.BOOKING_ROOM_TYPE
        SET ROOM_PRICE_AT_BOOKING = @UnitPrice
        WHERE BOOKING_ID = @ProbeBookingId;

        SET @ActualTier = dbo.fn_GuestTier(@GuestId, @Year);
        IF ISNULL(@ActualTier, '') <> @Tier
            THROW 57002, N'FAIL: fn_GuestTier sai tại ngưỡng phân hạng.', 1;

        INSERT @Results (TestName, Result)
        VALUES (CONCAT(N'GuestTier ', @TargetTotal), 'PASS');

        SET @CaseNo = @CaseNo + 1;
    END;

    IF dbo.fn_GuestTier(-2147483648, @Year) IS NOT NULL
        THROW 57003, N'FAIL: user_id không hợp lệ phải trả NULL.', 1;
    INSERT @Results VALUES (N'GuestTier user không hợp lệ', 'PASS');

    SELECT @MissingUserId = ISNULL(MAX(USER_ID), 0) + 1
    FROM dbo.[USER];
    IF dbo.fn_GuestTier(@MissingUserId, @Year) IS NOT NULL
        THROW 57015, N'FAIL: user không tồn tại phải trả NULL.', 1;
    INSERT @Results VALUES (N'GuestTier user không tồn tại', 'PASS');

    SELECT @NonGuestId = MIN(u.USER_ID)
    FROM dbo.[USER] AS u
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.GUEST AS g
        WHERE g.USER_ID = u.USER_ID
    );
    IF @NonGuestId IS NULL OR dbo.fn_GuestTier(@NonGuestId, @Year) IS NOT NULL
        THROW 57014, N'FAIL: user không phải GUEST phải trả NULL.', 1;
    INSERT @Results VALUES (N'GuestTier user không phải GUEST', 'PASS');

    IF ISNULL(dbo.fn_GuestTier(@GuestId, 1900), '') <> 'BRONZE'
        THROW 57004, N'FAIL: năm không có booking phải xếp BRONZE.', 1;
    INSERT @Results VALUES (N'GuestTier năm không có booking', 'PASS');

    IF dbo.fn_GuestTier(@GuestId, 10000) IS NOT NULL
        THROW 57005, N'FAIL: năm ngoài miền DATE phải trả NULL.', 1;
    INSERT @Results VALUES (N'GuestTier năm không hợp lệ', 'PASS');

    SELECT @PaidAmount = AMOUNT
    FROM dbo.PAYMENT
    WHERE BOOKING_ID = @RefundBookingId
      AND PAYMENT_STATUS = 'PAID';

    IF @PaidAmount IS NULL
        THROW 57006, N'Cần booking 8 có PAYMENT PAID để chạy test hoàn tiền.', 1;

    -- Dùng booking đã hủy để test các mốc ngày mà không đụng lịch booking hiệu lực.
    UPDATE dbo.BOOKING
    SET CHECK_IN_DATE = DATEADD(DAY, 7, @Today),
        CHECK_OUT_DATE = DATEADD(DAY, 9, @Today)
    WHERE BOOKING_ID = @RefundBookingId;
    SET @RefundAmount = dbo.fn_CancelRefund(@RefundBookingId);
    IF @RefundAmount IS NULL OR @RefundAmount <> @PaidAmount
        THROW 57007, N'FAIL: hủy trước ít nhất 7 ngày phải hoàn 100%.', 1;
    INSERT @Results VALUES (N'CancelRefund từ 7 ngày', 'PASS');

    UPDATE dbo.BOOKING
    SET CHECK_IN_DATE = DATEADD(DAY, 6, @Today),
        CHECK_OUT_DATE = DATEADD(DAY, 8, @Today)
    WHERE BOOKING_ID = @RefundBookingId;
    SET @RefundAmount = dbo.fn_CancelRefund(@RefundBookingId);
    IF @RefundAmount IS NULL OR @RefundAmount <> @PaidAmount * 0.50
        THROW 57008, N'FAIL: hủy trước 3-6 ngày phải hoàn 50%.', 1;
    INSERT @Results VALUES (N'CancelRefund 3-6 ngày', 'PASS');

    UPDATE dbo.BOOKING
    SET CHECK_IN_DATE = DATEADD(DAY, 3, @Today),
        CHECK_OUT_DATE = DATEADD(DAY, 5, @Today)
    WHERE BOOKING_ID = @RefundBookingId;
    SET @RefundAmount = dbo.fn_CancelRefund(@RefundBookingId);
    IF @RefundAmount IS NULL OR @RefundAmount <> @PaidAmount * 0.50
        THROW 57009, N'FAIL: mốc đúng 3 ngày phải hoàn 50%.', 1;
    INSERT @Results VALUES (N'CancelRefund đúng 3 ngày', 'PASS');

    UPDATE dbo.BOOKING
    SET CHECK_IN_DATE = DATEADD(DAY, 2, @Today),
        CHECK_OUT_DATE = DATEADD(DAY, 4, @Today)
    WHERE BOOKING_ID = @RefundBookingId;
    SET @RefundAmount = dbo.fn_CancelRefund(@RefundBookingId);
    IF @RefundAmount IS NULL OR @RefundAmount <> 0
        THROW 57010, N'FAIL: hủy trước dưới 3 ngày phải hoàn 0%.', 1;
    INSERT @Results VALUES (N'CancelRefund dưới 3 ngày', 'PASS');

    SET @RefundAmount = dbo.fn_CancelRefund(10);
    IF @RefundAmount IS NULL OR @RefundAmount <> 0
        THROW 57011, N'FAIL: booking chưa thanh toán phải trả 0.', 1;
    INSERT @Results VALUES (N'CancelRefund chưa thanh toán', 'PASS');

    IF dbo.fn_CancelRefund(@ProbeBookingId) IS NOT NULL
        THROW 57012, N'FAIL: booking COMPLETED không hợp lệ để tính hoàn.', 1;
    INSERT @Results VALUES (N'CancelRefund booking COMPLETED', 'PASS');

    IF dbo.fn_CancelRefund(-1) IS NOT NULL
        THROW 57013, N'FAIL: booking_id không hợp lệ phải trả NULL.', 1;
    INSERT @Results VALUES (N'CancelRefund booking không hợp lệ', 'PASS');

    SELECT @MissingBookingId = ISNULL(MAX(BOOKING_ID), 0) + 1
    FROM dbo.BOOKING;
    IF dbo.fn_CancelRefund(@MissingBookingId) IS NOT NULL
        THROW 57016, N'FAIL: booking không tồn tại phải trả NULL.', 1;
    INSERT @Results VALUES (N'CancelRefund booking không tồn tại', 'PASS');

    ROLLBACK TRANSACTION;
    SELECT TestName, Result FROM @Results;
    PRINT N'Đã rollback toàn bộ dữ liệu thay đổi trong test.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
