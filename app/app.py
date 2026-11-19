"""BTL2 Nhóm 5 - Việc 7: ứng dụng 3 màn hình trên CSDL BTL2_Booking_Nhom5.

3.1  /bookings/new, /bookings/<id>/edit, nút xóa -> sp_Booking_Insert / sp_Booking_Update / sp_Booking_Delete
3.2  /bookings                                   -> sp_Booking_List
3.3  /dashboard                                  -> sp_Revenue_By_Accommodation + fn_GuestTier
App không tự viết INSERT/UPDATE/DELETE. SELECT trực tiếp chỉ để đổ dropdown và nạp dữ liệu form sửa.
"""
import os
from collections import Counter
from datetime import date
from decimal import Decimal, InvalidOperation

import pymssql
from dotenv import load_dotenv
from flask import Flask, flash, redirect, render_template, render_template_string, request, url_for

load_dotenv(os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env'))
DB = dict(server=os.getenv('DB_SERVER', 'localhost'), port=os.getenv('DB_PORT', '1433'),
          database=os.getenv('DB_NAME', 'BTL2_Booking_Nhom5'),
          user=os.getenv('DB_USER', ''), password=os.getenv('DB_PASSWORD', ''),
          charset='UTF-8', autocommit=True, login_timeout=5)

app = Flask(__name__)
app.secret_key = os.getenv('SECRET_KEY') or os.urandom(16)

STATUSES = ('PENDING', 'CONFIRMED', 'COMPLETED', 'CANCELLED')
SORTS = {'check_in': 'Ngày nhận phòng', 'total_amount': 'Tổng tiền', 'guest_name': 'Tên khách'}
PAGE_SIZE = 10
# Thông báo THROW của thủ tục 2.1 bắt đầu bằng tên trường sai -> ô cần tô đỏ trên form.
FIELD_OF = {'USER_ID': 'user_id', 'ACCOMMODATION_ID': 'room', 'ROOM_NAME': 'room', 'ROOM': 'room',
            'ROOM_RATE': 'room', 'CHECK_IN_DATE': 'check_in', 'CHECK_IN_DATE/CHECK_OUT_DATE': 'check_in',
            'CHECK_OUT_DATE': 'check_out', 'Trùng lịch': 'check_in', 'RESERVED_QUANTITY': 'quantity',
            'ADULTS': 'adults', 'ADULTS/CHILDREN': 'adults', 'CHILDREN': 'children',
            'VOUCHER_CODE': 'voucher_code', 'STATUS': 'status', 'PAYMENT': 'status'}
app.jinja_env.globals.update(STATUSES=STATUSES, SORTS=SORTS, PAGE_SIZE=PAGE_SIZE)


def query(sql, params=None):
    """Chạy 1 batch T-SQL, trả list dict (rỗng nếu batch không trả result set)."""
    # ponytail: mở kết nối mới mỗi lần gọi; thêm pool nếu app phục vụ nhiều người cùng lúc.
    with pymssql.connect(**DB) as conn, conn.cursor(as_dict=True) as cur:
        cur.execute(sql, params)
        return cur.fetchall() if cur.description else []


def db_message(e):
    """Lỗi pymssql -> (mã, thông báo). THROW cho args = (51105, b'CHECK_IN_DATE: ...DB-Lib error message ...')."""
    code = e.args[0] if e.args and isinstance(e.args[0], int) else None
    raw = e.args[1] if len(e.args) > 1 else str(e)
    raw = raw.decode('utf-8', 'replace') if isinstance(raw, bytes) else str(raw)
    return code, raw.split('DB-Lib error message')[0].strip() or raw.strip()


def flash_db_error(e):
    """Hiện lỗi từ CSDL lên đầu trang; trả tên ô form gây lỗi (nếu nhận ra) để tô đỏ."""
    code, msg = db_message(e)
    flash(f'[{code}] {msg}' if code else msg, 'danger')
    return FIELD_OF.get(msg.split(':')[0].strip())


def to_int(v):
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def to_date(v):
    try:
        return date.fromisoformat(v).isoformat()
    except (TypeError, ValueError):
        return None


def to_decimal(v):
    try:
        return Decimal(v) if v else None
    except InvalidOperation:
        return None


def safe_next():
    """Trang quay về sau khi sửa/xóa (giữ bộ lọc của danh sách); chỉ nhận đường dẫn nội bộ."""
    nxt = request.values.get('next', '')
    return nxt if nxt.startswith('/') and not nxt.startswith(('//', '/\\')) else url_for('booking_list')


@app.template_filter()
def money(v):
    return '—' if v is None else f'{v:,.0f}'.replace(',', '.')


@app.errorhandler(pymssql.Error)
def db_unavailable(e):
    code, msg = db_message(e)
    return render_template_string(
        '{% extends "base.html" %}{% block content %}<div class="alert alert-danger"><h1 class="h5">'
        'Không truy vấn được CSDL</h1><p class="mb-1">[{{ code }}] {{ msg }}</p><p class="mb-0 small">'
        'Kiểm tra SQL Server đang chạy và cấu hình trong <code>app/.env</code>.</p></div>{% endblock %}',
        code=code, msg=msg), 503


def guests():
    return query('SELECT g.USER_ID, u.FULL_NAME FROM dbo.GUEST g '
                 'JOIN dbo.[USER] u ON u.USER_ID = g.USER_ID ORDER BY u.USER_ID')


def room_types(accom_id=None):
    return query('''SELECT rt.ACCOMMODATION_ID, a.[NAME] AS ACCOMMODATION_NAME, a.CITY,
                           rt.ROOM_NAME, rt.ADULTS, rt.CHILDREN
                    FROM dbo.ROOM_TYPE rt
                    JOIN dbo.ACCOMMODATION a ON a.ACCOMMODATION_ID = rt.ACCOMMODATION_ID
                    WHERE %(a)s IS NULL OR rt.ACCOMMODATION_ID = %(a)s
                    ORDER BY a.ACCOMMODATION_ID, rt.ROOM_NAME''', {'a': accom_id})


def read_form():
    """Lớp kiểm tra phía server trước khi gọi thủ tục: chỉ ép kiểu; nghiệp vụ do thủ tục THROW."""
    f = request.form
    accom, _, room = f.get('room', '').partition('|')
    return dict(user_id=to_int(f.get('user_id')), accom_id=to_int(accom), room_name=room or None,
                check_in=to_date(f.get('check_in')), check_out=to_date(f.get('check_out')),
                adults=to_int(f.get('adults')), children=to_int(f.get('children')),
                quantity=to_int(f.get('quantity')), voucher=f.get('voucher_code', '').strip() or None,
                arrival=f.get('arrival_time') or None, requests=f.get('special_requests', '').strip() or None,
                status=f.get('status') if f.get('status') in STATUSES else None)


def form_values(b=None):
    """Giá trị điền sẵn: dữ liệu đơn (sửa) hoặc mặc định (thêm), đè bằng dữ liệu vừa gửi nếu bị lỗi."""
    v = {'adults': 1, 'children': 0, 'quantity': 1}
    if b:
        v = dict(user_id=b['USER_ID'], room=f"{b['ACCOMMODATION_ID']}|{b['ROOM_NAME']}" if b['ROOM_NAME'] else '',
                 check_in=b['CHECK_IN_DATE'].isoformat(), check_out=b['CHECK_OUT_DATE'].isoformat(),
                 adults=b['ADULTS'], children=b['CHILDREN'], quantity=b['RESERVED_QUANTITY'],
                 arrival_time=b['ARRIVAL_TIME'], special_requests=b['SPECIAL_REQUESTS'], status=b['STATUS'])
    v.update(request.form.to_dict())
    return {k: '' if x is None else str(x) for k, x in v.items()}


@app.route('/')
def index():
    return redirect(url_for('booking_list'))


# ---------- 3.2 Danh sách booking ----------
@app.route('/bookings')
def booking_list():
    args = {k: v.strip() for k, v in request.args.items() if v.strip()}
    d_from, d_to = to_date(args.get('from')), to_date(args.get('to'))
    if d_from and d_to and d_from > d_to:
        flash('Khoảng ngày bị ngược: "Nhận phòng từ" phải trước hoặc bằng "đến ngày".', 'warning')
    sort = args.get('sort') if args.get('sort') in SORTS else 'check_in'
    rows = query('EXEC dbo.sp_Booking_List @p_keyword=%s, @p_status=%s, @p_from=%s, @p_to=%s, @p_sort=%s',
                 (args.get('keyword'), args.get('status') if args.get('status') in STATUSES else None,
                  d_from, d_to, sort))
    # ponytail: phân trang trong app trên kết quả của proc; thêm OFFSET/FETCH vào proc nếu dữ liệu lớn.
    pages = max(1, -(-len(rows) // PAGE_SIZE))
    page = min(max(to_int(args.get('page')) or 1, 1), pages)
    return render_template('list.html', rows=rows[(page - 1) * PAGE_SIZE:page * PAGE_SIZE], total=len(rows),
                           page=page, pages=pages, args=args, sort=sort, counts=Counter(r['STATUS'] for r in rows))


# ---------- 3.1 Form thêm / sửa / xóa ----------
@app.route('/bookings/new', methods=['GET', 'POST'])
def booking_new():
    err_field = None
    if request.method == 'POST':
        try:
            new = query('''DECLARE @id INT;
                EXEC dbo.sp_Booking_Insert @UserId=%(user_id)s, @AccommodationId=%(accom_id)s,
                     @RoomName=%(room_name)s, @CheckIn=%(check_in)s, @CheckOut=%(check_out)s,
                     @Adults=%(adults)s, @Children=%(children)s, @Quantity=%(quantity)s,
                     @VoucherCode=%(voucher)s, @EstimatedArrivalTime=%(arrival)s,
                     @SpecialRequests=%(requests)s, @BookingId=@id OUTPUT;
                SELECT BOOKING_ID, BOOKING_CODE FROM dbo.BOOKING WHERE BOOKING_ID = @id;''', read_form())[0]
            flash(f"Đã tạo đơn {new['BOOKING_CODE']} (PENDING).", 'success')
            return redirect(url_for('booking_list', keyword=new['BOOKING_CODE']))
        except pymssql.Error as e:
            err_field = flash_db_error(e)
    return render_template('form.html', booking=None, v=form_values(), err_field=err_field,
                           guests=guests(), rooms=room_types(), today=date.today().isoformat())


BOOKING_SQL = '''SELECT b.BOOKING_ID, b.BOOKING_CODE, b.[STATUS], b.USER_ID, u.FULL_NAME,
       b.ACCOMMODATION_ID, a.[NAME] AS ACCOMMODATION_NAME, brt.ROOM_NAME, brt.RESERVED_QUANTITY, brt.ROOM_PRICE_AT_BOOKING,
       DATEDIFF(DAY, b.CHECK_IN_DATE, b.CHECK_OUT_DATE) AS NIGHTS, b.BOOKING_DATE,
       b.CHECK_IN_DATE, b.CHECK_OUT_DATE, b.ADULTS, b.CHILDREN,
       CONVERT(CHAR(5), b.ESTIMATED_ARRIVAL_TIME, 108) AS ARRIVAL_TIME, b.SPECIAL_REQUESTS,
       p.PAYMENT_STATUS, p.AMOUNT, dbo.fn_CancelRefund(b.BOOKING_ID) AS REFUND
FROM dbo.BOOKING b
JOIN dbo.[USER] u ON u.USER_ID = b.USER_ID
JOIN dbo.ACCOMMODATION a ON a.ACCOMMODATION_ID = b.ACCOMMODATION_ID
LEFT JOIN dbo.BOOKING_ROOM_TYPE brt ON brt.BOOKING_ID = b.BOOKING_ID
LEFT JOIN dbo.PAYMENT p ON p.BOOKING_ID = b.BOOKING_ID
WHERE b.BOOKING_ID = %s'''


@app.route('/bookings/<int:booking_id>/edit', methods=['GET', 'POST'])
def booking_edit(booking_id):
    rows = query(BOOKING_SQL, (booking_id,))
    if not rows:
        flash(f'Không tìm thấy đơn #{booking_id}.', 'warning')
        return redirect(safe_next())
    b, err_field = rows[0], None
    if request.method == 'POST':
        try:
            query('''EXEC dbo.sp_Booking_Update @BookingId=%(id)s, @Status=%(status)s, @RoomName=%(room_name)s,
                     @Quantity=%(quantity)s, @CheckIn=%(check_in)s, @CheckOut=%(check_out)s,
                     @Adults=%(adults)s, @Children=%(children)s,
                     @EstimatedArrivalTime=%(arrival)s, @SpecialRequests=%(requests)s''',
                  dict(read_form(), id=booking_id))
            flash(f"Đã lưu đơn {b['BOOKING_CODE']}.", 'success')
            return redirect(safe_next())
        except pymssql.Error as e:
            err_field = flash_db_error(e)
    return render_template('form.html', booking=b, v=form_values(b), err_field=err_field,
                           rooms=room_types(b['ACCOMMODATION_ID']), back=safe_next())


@app.post('/bookings/<int:booking_id>/status')
def booking_status(booking_id):
    status = request.form.get('status')
    try:
        query('EXEC dbo.sp_Booking_Update @BookingId=%s, @Status=%s', (booking_id, status))
        flash(f'Đơn #{booking_id}: đã chuyển trạng thái sang {status}.', 'success')
    except pymssql.Error as e:
        flash_db_error(e)
    return redirect(safe_next())


@app.post('/bookings/<int:booking_id>/delete')
def booking_delete(booking_id):
    try:
        query('EXEC dbo.sp_Booking_Delete @BookingId=%s', (booking_id,))
        flash(f'Đã xóa đơn #{booking_id}.', 'success')
    except pymssql.Error as e:
        flash_db_error(e)
    return redirect(safe_next())


# ---------- 3.3 Dashboard ----------
@app.route('/dashboard')
def dashboard():
    args = {k: v.strip() for k, v in request.args.items() if v.strip()}
    d_from, d_to = to_date(args.get('from')), to_date(args.get('to'))
    if d_from and d_to and d_from > d_to:
        flash('Khoảng ngày bị ngược: "Từ ngày" phải trước hoặc bằng "Đến ngày".', 'warning')
    rows = query('EXEC dbo.sp_Revenue_By_Accommodation @p_city=%s, @p_from=%s, @p_to=%s, @p_min_revenue=%s',
                 (args.get('city'), d_from, d_to, to_decimal(args.get('min_revenue'))))
    totals = {}
    for r in rows:
        t = totals.setdefault(r['CURRENCY'], {'revenue': 0, 'bookings': 0, 'places': 0})
        t['revenue'] += r['TOTAL_REVENUE']
        t['bookings'] += r['BOOKING_COUNT']
        t['places'] += 1
    chart = [{'label': r['ACCOMMODATION_NAME'] + (f" ({r['CURRENCY']})" if len(totals) > 1 else ''),
              'value': float(r['TOTAL_REVENUE']), 'currency': r['CURRENCY']} for r in rows]

    year = to_int(args.get('year'))
    year = date.today().year if year is None else year
    guest = to_int(args.get('guest'))
    tiers = query('''SELECT u.USER_ID, u.FULL_NAME, dbo.fn_GuestTier(u.USER_ID, %(y)s) AS TIER
                     FROM dbo.GUEST g JOIN dbo.[USER] u ON u.USER_ID = g.USER_ID
                     WHERE %(g)s IS NULL OR g.USER_ID = %(g)s
                     ORDER BY u.USER_ID''', {'y': year, 'g': guest})
    return render_template('dashboard.html', rows=rows, totals=totals, chart=chart, args=args,
                           cities=query('SELECT DISTINCT CITY FROM dbo.ACCOMMODATION ORDER BY CITY'),
                           guests=guests(), tiers=tiers, year=year, guest=guest)


if __name__ == '__main__':
    app.run(debug=os.getenv('FLASK_DEBUG') == '1', port=int(os.getenv('PORT', '5000')))
