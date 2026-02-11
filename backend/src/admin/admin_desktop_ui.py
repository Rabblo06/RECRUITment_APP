import sys
import csv
from datetime import datetime, timedelta

from PySide6.QtWidgets import QLineEdit, QCompleter
from PySide6.QtCore import Qt, QStringListModel
from PySide6.QtCore import Qt, QTimer, QPoint
from PySide6.QtGui import QFont
from PySide6.QtWidgets import QComboBox, QCheckBox
from PySide6.QtWidgets import (
    QApplication, QWidget,QSizePolicy, QMainWindow, QHBoxLayout, QVBoxLayout, QLabel,
    QPushButton, QLineEdit, QStackedWidget, QListWidget, QListWidgetItem,
    QFrame, QMessageBox, QGridLayout, QScrollArea, QTextEdit, QInputDialog, QFileDialog, QDialog, QTableWidget, QTableWidgetItem
)

from api_client import ApiClient

BASE_URL = "http://localhost:4000"


# ----------------- Helpers -----------------
def card_title(text):
    lab = QLabel(text)
    lab.setStyleSheet("font-size: 22px; font-weight: 900;")
    return lab


def section_label(text):
    lab = QLabel(text)
    lab.setStyleSheet("font-size: 14px; font-weight: 800; color: #333;")
    return lab


def value_label(text=""):
    lab = QLabel(text)
    lab.setStyleSheet("font-size: 14px; font-weight: 600; color: #111;")
    lab.setTextInteractionFlags(Qt.TextSelectableByMouse)
    return lab


def input_box(placeholder=""):
    e = QLineEdit()
    e.setPlaceholderText(placeholder)
    e.setStyleSheet("""
        QLineEdit {
            background: white;
            border: 1px solid rgba(0,0,0,0.12);
            border-radius: 12px;
            padding: 10px 12px;
            font-size: 13px;
        }
        QLineEdit:focus { border: 1px solid #5B5CE5; }
    """)
    return e


def primary_btn(text):
    b = QPushButton(text)
    b.setCursor(Qt.PointingHandCursor)
    b.setStyleSheet("""
        QPushButton {
            background: #5B5CE5;
            color: white;
            border: none;
            border-radius: 14px;
            padding: 10px 14px;
            font-weight: 800;
        }
        QPushButton:hover { background: #4B4BD6; }
        QPushButton:pressed { background: #3E3EBF; }
    """)
    return b


def ghost_btn(text):
    b = QPushButton(text)
    b.setCursor(Qt.PointingHandCursor)
    b.setStyleSheet("""
        QPushButton {
            background: rgba(255,255,255,0.65);
            color: #222;
            border: 1px solid rgba(0,0,0,0.12);
            border-radius: 14px;
            padding: 10px 14px;
            font-weight: 800;
        }
        QPushButton:hover { background: rgba(255,255,255,0.85); }
        QPushButton:pressed { background: rgba(255,255,255,0.95); }
    """)
    return b


def make_search_row(placeholder: str):
    """
    Returns (layout, lineedit, clear_button, timer)
    timer is not started automatically; caller connects textChanged to start it.
    """
    row = QHBoxLayout()
    row.setSpacing(10)

    search = input_box(placeholder)
    clear_btn = ghost_btn("Clear")
    clear_btn.setFixedWidth(90)

    row.addWidget(search, 1)
    row.addWidget(clear_btn)

    timer = QTimer()
    timer.setSingleShot(True)

    clear_btn.clicked.connect(lambda: search.setText(""))

    return row, search, clear_btn, timer

class DropUpComboBox(QComboBox):
    def showPopup(self):
        super().showPopup()

        # The popup is a separate window created by the combo's view
        popup = self.view().window()
        if not popup:
            return

        # Current popup geometry (after Qt sized it)
        popup_geo = popup.geometry()

        # Global position of the combo box
        combo_top_left = self.mapToGlobal(QPoint(0, 0))

        # Move popup so it opens ABOVE the combo box
        new_x = combo_top_left.x()
        new_y = combo_top_left.y() - popup_geo.height()

        popup.move(new_x, new_y)


# ----------------- Login Page -----------------
class LoginPage(QWidget):
    def __init__(self, api: ApiClient, on_success):
        super().__init__()
        self.api = api
        self.on_success = on_success

        root = QVBoxLayout(self)
        root.setContentsMargins(36, 36, 36, 36)
        root.setSpacing(16)

        title = QLabel("Admin Login")
        title.setStyleSheet("font-size: 26px; font-weight: 900; color: #111;")
        root.addWidget(title)

        self.user = input_box("Username")
        self.passw = input_box("Password")
        self.passw.setEchoMode(QLineEdit.Password)

        root.addWidget(section_label("Username"))
        root.addWidget(self.user)
        root.addWidget(section_label("Password"))
        root.addWidget(self.passw)

        self.btn = primary_btn("Login")
        self.btn.clicked.connect(self.login)
        root.addWidget(self.btn)

        root.addStretch(1)

    def login(self):
        u = self.user.text().strip()
        p = self.passw.text().strip()
        if not u or not p:
            QMessageBox.warning(self, "Missing fields", "Enter username and password.")
            return
        try:
            data = self.api.login(u, p)
            role = (data.get("user") or {}).get("role")
            if role not in ("admin", "manager"):
                QMessageBox.warning(self, "Access denied", "This portal is for admin/manager only.")
                return
            self.on_success()
        except Exception as e:
            QMessageBox.critical(self, "Login failed", str(e))


# ----------------- Dashboard Page -----------------
class DashboardPage(QWidget):
    def __init__(self, api: ApiClient):
        super().__init__()
        self.api = api

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)

        root.addWidget(card_title("Dashboard"))

        self.stats_grid = QGridLayout()
        self.stats_grid.setHorizontalSpacing(16)
        self.stats_grid.setVerticalSpacing(10)

        self.lbl_total_staff = value_label("0")
        self.lbl_pending = value_label("0")
        self.lbl_accepted = value_label("0")
        self.lbl_completed = value_label("0")

        self._stat_card(0, "Total Staff", self.lbl_total_staff)
        self._stat_card(1, "Pending Offers", self.lbl_pending)
        self._stat_card(2, "Accepted", self.lbl_accepted)
        self._stat_card(3, "Completed", self.lbl_completed)

        stats_wrap = QFrame()
        stats_wrap.setStyleSheet("background: rgba(255,255,255,0.55); border-radius: 22px;")
        stats_wrap.setLayout(self.stats_grid)

        root.addWidget(stats_wrap)

        self.refresh_btn = ghost_btn("Refresh")
        self.refresh_btn.clicked.connect(self.load)
        root.addWidget(self.refresh_btn, alignment=Qt.AlignLeft)

        root.addStretch(1)

        self.load()

    def _stat_card(self, col, label, value):
        card = QFrame()
        card.setStyleSheet("background: white; border-radius: 18px;")
        lay = QVBoxLayout(card)
        lay.setContentsMargins(14, 12, 14, 12)
        lay.setSpacing(4)
        l1 = QLabel(label)
        l1.setStyleSheet("color: #444; font-weight: 800;")
        lay.addWidget(l1)
        lay.addWidget(value)

        self.stats_grid.addWidget(card, 0, col)

    def load(self):
        try:
            data = self.api.admin_dashboard()
            self.lbl_total_staff.setText(str(data.get("totalStaff", 0)))
            self.lbl_pending.setText(str(data.get("pendingOffers", 0)))
            self.lbl_accepted.setText(str(data.get("acceptedOffers", 0)))
            self.lbl_completed.setText(str(data.get("completedOffers", 0)))
        except Exception as e:
            QMessageBox.critical(self, "Dashboard error", str(e))


# ----------------- New User Page -----------------
class NewUserPage(QWidget):
    def __init__(self, api: ApiClient):
        super().__init__()
        self.api = api

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)

        root.addWidget(card_title("Create New User"))

        form = QFrame()
        form.setStyleSheet("background: rgba(255,255,255,0.55); border-radius: 22px;")
        form_l = QGridLayout(form)
        form_l.setContentsMargins(18, 18, 18, 18)
        form_l.setHorizontalSpacing(14)
        form_l.setVerticalSpacing(10)

        self.fullName = input_box("Full name")
        self.email = input_box("Email")
        self.dob = input_box("YYYY-MM-DD")
        self.username = input_box("Username")
        self.password = input_box("Password")
        self.password.setEchoMode(QLineEdit.Password)

        form_l.addWidget(section_label("Full name"), 0, 0)
        form_l.addWidget(self.fullName, 0, 1)
        form_l.addWidget(section_label("Email"), 1, 0)
        form_l.addWidget(self.email, 1, 1)
        form_l.addWidget(section_label("Date of birth"), 2, 0)
        form_l.addWidget(self.dob, 2, 1)
        form_l.addWidget(section_label("Username"), 3, 0)
        form_l.addWidget(self.username, 3, 1)
        form_l.addWidget(section_label("Password"), 4, 0)
        form_l.addWidget(self.password, 4, 1)

        root.addWidget(form)

        btns = QHBoxLayout()
        self.btn_create_staff = primary_btn("Create Staff")
        self.btn_create_manager = ghost_btn("Create Manager")
        self.btn_create_staff.clicked.connect(self.create_staff)
        self.btn_create_manager.clicked.connect(self.create_manager)

        btns.addWidget(self.btn_create_staff)
        btns.addWidget(self.btn_create_manager)
        btns.addStretch(1)

        root.addLayout(btns)
        root.addStretch(1)

    def _get_payload(self):
        return {
            "fullName": self.fullName.text().strip(),
            "email": self.email.text().strip(),
            "dob": self.dob.text().strip(),
            "username": self.username.text().strip(),
            "password": self.password.text().strip(),
        }

    def create_staff(self):
        payload = self._get_payload()
        if not payload["username"] or not payload["password"]:
            QMessageBox.warning(self, "Missing fields", "Username and password are required.")
            return
        try:
            self.api.create_staff(payload)
            QMessageBox.information(self, "Success", "Staff created.")
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))

    def create_manager(self):
        payload = self._get_payload()
        if not payload["username"] or not payload["password"]:
            QMessageBox.warning(self, "Missing fields", "Username and password are required.")
            return
        try:
            self.api.create_manager(payload)
            QMessageBox.information(self, "Success", "Manager created.")
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))


class OfferEditDialog(QDialog):
    """
    Edit Placement details in a separate window.
    Returns patch dict via self.patch on accept.
    """
    def __init__(self, parent=None, title="Edit Offer", placement=None):
        super().__init__(parent)
        self.setWindowTitle(title)
        self.setMinimumWidth(520)
        self.patch = None

        placement = placement or {}

        root = QVBoxLayout(self)
        root.setContentsMargins(18, 18, 18, 18)
        root.setSpacing(12)

        header = QLabel(title)
        header.setStyleSheet("font-size: 18px; font-weight: 900;")
        root.addWidget(header)

        form = QFrame()
        form.setStyleSheet("background: rgba(255,255,255,0.75); border-radius: 18px;")
        gl = QGridLayout(form)
        gl.setContentsMargins(16, 16, 16, 16)
        gl.setHorizontalSpacing(12)
        gl.setVerticalSpacing(10)

        # fields
        self.venue = input_box("Hotel / Venue")
        self.position = input_box("Position")
        self.date = input_box("YYYY-MM-DD")
        self.start = input_box("HH:MM")
        self.end = input_box("HH:MM")
        self.rate = input_box("Hourly rate (e.g. 12.21)")
        self.hours = input_box("Total hours (auto)")
        self.hours.setReadOnly(True)

        self.address = input_box("Address line")
        self.city = input_box("City")
        self.postcode = input_box("Postcode")
        self.notes = input_box("Notes")

        # prefill (support both roleTitle + position)
        self.venue.setText(str(placement.get("venue", "") or ""))
        self.position.setText(str(placement.get("roleTitle") or placement.get("position") or ""))
        self.date.setText(str(placement.get("date", ""))[:10])
        self.start.setText(str(placement.get("startTime", "") or ""))
        self.end.setText(str(placement.get("endTime", "") or ""))
        self.rate.setText(str(placement.get("hourlyRate", "") or ""))

        self.address.setText(str(placement.get("addressLine", "") or ""))
        self.city.setText(str(placement.get("city", "") or ""))
        self.postcode.setText(str(placement.get("postcode", "") or ""))
        self.notes.setText(str(placement.get("notes") or placement.get("note") or ""))

        # layout rows
        r = 0
        gl.addWidget(section_label("Venue"), r, 0); gl.addWidget(self.venue, r, 1); r += 1
        gl.addWidget(section_label("Position"), r, 0); gl.addWidget(self.position, r, 1); r += 1
        gl.addWidget(section_label("Date"), r, 0); gl.addWidget(self.date, r, 1); r += 1
        gl.addWidget(section_label("Start time"), r, 0); gl.addWidget(self.start, r, 1); r += 1
        gl.addWidget(section_label("End time"), r, 0); gl.addWidget(self.end, r, 1); r += 1
        gl.addWidget(section_label("Hourly rate"), r, 0); gl.addWidget(self.rate, r, 1); r += 1
        gl.addWidget(section_label("Total hours"), r, 0); gl.addWidget(self.hours, r, 1); r += 1
        gl.addWidget(section_label("Address"), r, 0); gl.addWidget(self.address, r, 1); r += 1
        gl.addWidget(section_label("City"), r, 0); gl.addWidget(self.city, r, 1); r += 1
        gl.addWidget(section_label("Postcode"), r, 0); gl.addWidget(self.postcode, r, 1); r += 1
        gl.addWidget(section_label("Notes"), r, 0); gl.addWidget(self.notes, r, 1); r += 1

        root.addWidget(form)

        # buttons
        btns = QHBoxLayout()
        self.btn_calc = ghost_btn("Recalculate hours")
        self.btn_cancel = ghost_btn("Close")
        self.btn_save = primary_btn("Save Changes")

        self.btn_calc.clicked.connect(self.recalc_hours)
        self.btn_cancel.clicked.connect(self.reject)
        self.btn_save.clicked.connect(self.on_save)

        btns.addWidget(self.btn_calc)
        btns.addStretch(1)
        btns.addWidget(self.btn_cancel)
        btns.addWidget(self.btn_save)
        root.addLayout(btns)

        # initial calc
        self.recalc_hours()

    def recalc_hours(self):
        start = self.start.text().strip()
        end = self.end.text().strip()
        hrs = 0.0
        try:
            t1 = datetime.strptime(start, "%H:%M")
            t2 = datetime.strptime(end, "%H:%M")
            if t2 < t1:
                t2 = t2 + timedelta(days=1)
            hrs = (t2 - t1).total_seconds() / 3600.0
        except Exception:
            hrs = 0.0
        self.hours.setText(str(round(hrs, 2)))

    def on_save(self):
        venue = self.venue.text().strip()
        pos = self.position.text().strip()
        date = self.date.text().strip()
        start = self.start.text().strip()
        end = self.end.text().strip()

        if not venue or not pos or not date:
            QMessageBox.warning(self, "Missing fields", "Venue, Position and Date are required.")
            return

        # hours
        self.recalc_hours()
        try:
            total_hours = float(self.hours.text().strip() or "0")
        except Exception:
            total_hours = 0.0

        # rate
        try:
            hourly_rate = float(self.rate.text().strip())
        except Exception:
            hourly_rate = 0.0

        self.patch = {
            "venue": venue,
            "position": pos,
            "roleTitle": pos,
            "date": date,
            "startTime": start,
            "endTime": end,
            "hourlyRate": hourly_rate,
            "totalHours": round(total_hours, 2),
            "addressLine": self.address.text().strip(),
            "city": self.city.text().strip(),
            "postcode": self.postcode.text().strip(),
            "notes": self.notes.text().strip(),
        }

        self.accept()


class PendingApprovalsPage(QWidget):
    def __init__(self, api: ApiClient):
        super().__init__()
        self.api = api
        self.selected_offer_id = None
        self.offers = []

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)

        root.addWidget(card_title("Pending Approvals"))

        self.list = QListWidget()
        self.list.setStyleSheet("""
    QListWidget {
        background: rgba(255,255,255,0.55);
        border: none;
        border-radius: 18px;
        padding: 8px;
        selection-background-color: transparent;
        selection-color: #000;
        outline: 0px;
    }
    QListWidget::item {
        background: white;
        margin: 6px;
        padding: 14px;
        border-radius: 14px;
        font-weight: 700;
    }
    QListWidget::item:selected {
        background: white;
        border: 2px solid #5B5CE5;
    }
    QListWidget::item:selected:!active {
        background: white;
        border: 2px solid #5B5CE5;
    }""")
        self.list.itemClicked.connect(self.pick_offer)
        root.addWidget(self.list, stretch=1)

        btns = QHBoxLayout()
        self.btn_refresh = ghost_btn("Refresh")
        self.btn_edit = ghost_btn("Edit")
        self.btn_approve = primary_btn("Approve")
        self.btn_reject = ghost_btn("Reject")

        self.btn_refresh.clicked.connect(self.load)
        self.btn_edit.clicked.connect(self.edit_offer)
        self.btn_approve.clicked.connect(lambda: self.decide("approve"))
        self.btn_reject.clicked.connect(lambda: self.decide("reject"))

        btns.addWidget(self.btn_refresh)
        btns.addSpacing(10)
        btns.addWidget(self.btn_edit)
        btns.addWidget(self.btn_approve)
        btns.addWidget(self.btn_reject)
        btns.addStretch(1)

        root.addLayout(btns)

        self.load()

    def edit_offer(self):
        if not self.selected_offer_id:
            QMessageBox.warning(self, "Pick offer", "Select an offer first.")
            return

        offer = next((o for o in self.offers if str(o.get("_id")) == str(self.selected_offer_id)), None)
        if not offer:
            QMessageBox.warning(self, "Not found", "Offer not found.")
            return

        placement = offer.get("placementId") or {}
        if not isinstance(placement, dict):
            QMessageBox.warning(self, "Not loaded", "Placement details not loaded. Click Refresh.")
            return

        dlg = OfferEditDialog(self, title="Edit Pending Offer", placement=placement)
        if dlg.exec() == QDialog.Accepted and dlg.patch:
            try:
                self.api.admin_edit_offer(self.selected_offer_id, dlg.patch)
                QMessageBox.information(self, "Saved", "Offer updated ✅")
                self.load()
            except Exception as e:
                QMessageBox.critical(self, "Edit error", str(e))

    def load(self):
        try:
            self.selected_offer_id = None
            self.list.clear()

            self.offers = self.api.pending_offers()
            for o in self.offers:
                user = o.get("userId") or {}
                placement = o.get("placementId") or {}

                username = user.get("username", "staff")
                venue = placement.get("venue", "")
                date = placement.get("date", "")
                start = placement.get("startTime", "")
                end = placement.get("endTime", "")
                rate = placement.get("hourlyRate", "")

                item = QListWidgetItem(
                    f"@{username}\n{venue} | {date} | {start}-{end} | £{rate}/hr"
                )
                item.setData(Qt.UserRole, str(o.get("_id")))
                self.list.addItem(item)

        except Exception as e:
            QMessageBox.critical(self, "Pending load error", str(e))

    def pick_offer(self, item: QListWidgetItem):
        self.selected_offer_id = item.data(Qt.UserRole)

    def decide(self, decision: str):
        if not self.selected_offer_id:
            QMessageBox.warning(self, "Pick offer", "Select a pending offer first.")
            return
        try:
            self.api.offer_decision(self.selected_offer_id, decision)
            QMessageBox.information(self, "Done", f"{decision.title()} successful.")
            self.load()
        except Exception as e:
            QMessageBox.critical(self, "Decision error", str(e))


# ----------------- Schedule List Page (with Search) -----------------
class ScheduleListPage(QWidget):
    def __init__(self, api: ApiClient, on_pick_staff):
        super().__init__()
        self.api = api
        self.on_pick_staff = on_pick_staff

        self.all_staff = []
        self.filtered_staff = []

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)

        root.addWidget(card_title("Staff List"))

        # ✅ Search row
        search_row, self.search_input, self.btn_clear_search, self._search_timer = make_search_row(
            "Search staff (name or username)…"
        )
        root.addLayout(search_row)
        self._search_timer.timeout.connect(self.apply_search)
        self.search_input.textChanged.connect(lambda: self._search_timer.start(250))

        self.list = QListWidget()
        self.list.setStyleSheet("""
    QListWidget {
        background: rgba(255,255,255,0.55);
        border: none;
        border-radius: 18px;
        padding: 8px;
        selection-background-color: transparent;
        selection-color: #000;
        outline: 0px;
    }
    QListWidget::item {
        background: white;
        margin: 6px;
        padding: 14px;
        border-radius: 14px;
        font-weight: 700;
    }
    QListWidget::item:selected {
        background: white;
        border: 2px solid #5B5CE5;
    }
    QListWidget::item:selected:!active {
        background: white;
        border: 2px solid #5B5CE5;
    }
        """)
        self.list.itemClicked.connect(self.pick)
        root.addWidget(self.list, stretch=1)

        btns = QHBoxLayout()
        self.refresh_btn = ghost_btn("Refresh")
        self.refresh_btn.clicked.connect(self.load)
        btns.addWidget(self.refresh_btn)
        btns.addStretch(1)
        root.addLayout(btns)

        self.load()

    def load(self):
        try:
            self.list.clear()
            self.all_staff = self.api.admin_staff() or []
            self.apply_search()  # render with current search
        except Exception as e:
            QMessageBox.critical(self, "Load staff error", str(e))

    def apply_search(self):
        q = (self.search_input.text() or "").strip().lower()
        if not q:
            self.filtered_staff = self.all_staff[:]
        else:
            out = []
            for s in self.all_staff:
                name = (s.get("fullName") or s.get("username") or "Staff")
                username = (s.get("username") or "")
                hay = f"{name} {username}".lower()
                if q in hay:
                    out.append(s)
            self.filtered_staff = out

        self.render()

    def render(self):
        self.list.clear()
        for s in self.filtered_staff:
            name = s.get("fullName") or s.get("username") or "Staff"
            active = bool(s.get("isActive", True))
            badge = "" if active else "\n⛔ SUSPENDED"
            item = QListWidgetItem(f"{name}\n@{s.get('username','')}{badge}")
            item.setData(Qt.UserRole, (str(s.get("_id")), name))
            self.list.addItem(item)

    def pick(self, item: QListWidgetItem):
        staff_id, staff_name = item.data(Qt.UserRole)
        if self.on_pick_staff:
            self.on_pick_staff(staff_id, staff_name)


# ----------------- Schedule Detail Page (history Search added) -----------------
class ScheduleDetailPage(QWidget):
    def __init__(self, api: ApiClient):
        super().__init__()
        self.api = api
        self.staff_id = None
        self.staff_name = ""
        self.offer_id = None
        self.offers_cache = []
        self.filtered_offers = []
        self.selected_offer = None

        # venue templates cache
        self.venues_cache = []  # list of dicts {name,address,note}

        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        outer.addWidget(scroll)

        content = QWidget()
        scroll.setWidget(content)

        root = QVBoxLayout(content)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)


        self.title = card_title("Schedule")
        root.addWidget(self.title)

        # ---------- top row ----------
        top_row = QHBoxLayout()
        self.lbl_staff = QLabel("")
        self.lbl_staff.setStyleSheet("font-size: 16px; font-weight: 900;")
        top_row.addWidget(self.lbl_staff)
        top_row.addStretch(1)

        # ✅ Top-right venue search (Google-style suggestions)
        self.venue_quick = QLineEdit()
        self.venue_quick.setPlaceholderText("Select Hotel/venue")
        self.venue_quick.setMinimumWidth(280)
        self.venue_quick.setStyleSheet("""
            QLineEdit {
                background: white;
                border-radius: 16px;
                padding: 10px 14px;
                border: 1px solid rgba(0,0,0,0.10);
                font-size: 13px;
                min-height: 36px;
            }
        """)
        top_row.addWidget(self.venue_quick)

        # completer model
        self._venue_names = []
        self._venue_model = QStringListModel(self._venue_names, self)
        self._venue_completer = QCompleter(self._venue_model, self)
        self._venue_completer.setCompletionMode(QCompleter.PopupCompletion)
        self._venue_completer.setFilterMode(Qt.MatchContains)  # match any part of name
        self._venue_completer.setCaseSensitivity(Qt.CaseInsensitive)
        self.venue_quick.setCompleter(self._venue_completer)

        # when user picks a suggestion
        self._venue_completer.activated.connect(self._on_quick_text_selected)

        # if user types a full name and presses Enter / leaves field
        self.venue_quick.editingFinished.connect(self._apply_quick_text)

        self.profile_btn = ghost_btn("Profile")
        self.profile_btn.clicked.connect(self.open_profile)
        top_row.addWidget(self.profile_btn)

        root.addLayout(top_row)

        # ---------- form card ----------
        form = QFrame()
        form.setStyleSheet("background: rgba(255,255,255,0.55); border-radius: 22px;")
        gl = QGridLayout(form)
        gl.setContentsMargins(18, 18, 18, 18)
        gl.setHorizontalSpacing(14)
        gl.setVerticalSpacing(10)

        # ✅ Venue (form) = type-only
        self.venue_box = input_box("Hotel/venue")

        # other fields (admin types)
        self.position = input_box("Position")
        self.date = input_box("YYYY-MM-DD")
        self.start = input_box("HH:MM")
        self.end = input_box("HH:MM")
        self.rate = input_box("Hourly rate (e.g. 12.21)")

        # autofill fields from venue template
        self.address = input_box("Address")
        self.note = QTextEdit()
        self.note.setPlaceholderText("Note")
        self.note.setFixedHeight(90)
        self.note.setStyleSheet("""
            QTextEdit{
                background: white;
                border-radius: 14px;
                padding: 10px;
                border: 1px solid rgba(0,0,0,0.10);
                font-size: 13px;
            }
        """)

        r = 0
        gl.addWidget(section_label("Venue"), r, 0); gl.addWidget(self.venue_box, r, 1); r += 1
        gl.addWidget(section_label("Position"), r, 0); gl.addWidget(self.position, r, 1); r += 1
        gl.addWidget(section_label("Date"), r, 0); gl.addWidget(self.date, r, 1); r += 1
        gl.addWidget(section_label("Start time"), r, 0); gl.addWidget(self.start, r, 1); r += 1
        gl.addWidget(section_label("End time"), r, 0); gl.addWidget(self.end, r, 1); r += 1
        gl.addWidget(section_label("Hourly rate"), r, 0); gl.addWidget(self.rate, r, 1); r += 1
        gl.addWidget(section_label("Address"), r, 0); gl.addWidget(self.address, r, 1); r += 1
        gl.addWidget(section_label("Note"), r, 0); gl.addWidget(self.note, r, 1); r += 1

        root.addWidget(form)

        # ---------- buttons ----------
        btns = QHBoxLayout()
        self.btn_send = primary_btn("Send Offer")
        self.btn_save = ghost_btn("Save Offer")
        self.btn_send.clicked.connect(self.send_offer)
        self.btn_save.clicked.connect(self.save_offer)
        btns.addWidget(self.btn_send)
        btns.addWidget(self.btn_save)
        btns.addStretch(1)
        root.addLayout(btns)

        # ---------- History ----------
        root.addWidget(card_title("Schedule History"))

        search_row, self.history_search, self.btn_clear_history_search, self._history_search_timer = make_search_row(
            "Search history (venue/date/status/time/rate)…"
        )
        root.addLayout(search_row)
        self._history_search_timer.timeout.connect(self.apply_history_search)
        self.history_search.textChanged.connect(lambda: self._history_search_timer.start(250))

        self.history = QListWidget()
        self.history.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.history.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.history.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        self.history.setMinimumHeight(260)
        self.history.setStyleSheet("""
            QListWidget {
                background: rgba(255,255,255,0.55);
                border: none;
                border-radius: 18px;
                padding: 8px;
                selection-background-color: transparent;
                selection-color: #000;
                outline: 0px;
            }
            QListWidget::item {
                background: white;
                margin: 6px;
                padding: 14px;
                border-radius: 14px;
                font-weight: 700;
            }
            QListWidget::item:selected {
                background: white;
                border: 2px solid #5B5CE5;
            }
        """)
        form.setMaximumHeight(450)  # try 380–450
        self.history.itemClicked.connect(self.pick_offer)
        self.history.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        root.addWidget(self.history)

        actions = QHBoxLayout()
        self.btn_complete = primary_btn("Mark Completed")
        self.btn_cancel = ghost_btn("Cancel")
        self.btn_export = ghost_btn("Export CSV")

        self.btn_complete.clicked.connect(self.mark_completed)
        self.btn_cancel.clicked.connect(self.cancel_offer)
        self.btn_export.clicked.connect(self.export_csv)

        actions.addWidget(self.btn_complete)
        actions.addWidget(self.btn_cancel)
        actions.addWidget(self.btn_export)
        actions.addStretch(1)
        root.addLayout(actions)

        # initial load for suggestions/templates
        self.reload_venues_dropdown()

    def set_staff(self, staff_id, staff_name):
        self.staff_id = staff_id
        self.staff_name = staff_name
        self.lbl_staff.setText(f"{staff_name}  (ID: {staff_id})")
        self.load_history()
        self.reload_venues_dropdown()

    # -------- venue templates -> suggestions ----------
    def reload_venues_dropdown(self):
        try:
            self.venues_cache = self.api.venues_list() or []
        except Exception:
            self.venues_cache = []

        names = [v.get("name", "").strip() for v in self.venues_cache if v.get("name")]
        self._venue_names = names
        self._venue_model.setStringList(self._venue_names)

    def _find_venue_by_name(self, name: str):
        if not name:
            return None
        target = name.strip().lower()
        for v in self.venues_cache:
            if (v.get("name", "") or "").strip().lower() == target:
                return v
        return None

    def _on_quick_text_selected(self, name: str):
        name = (name or "").strip()
        if not name:
            return
        v = self._find_venue_by_name(name)

        # fill form fields
        self.venue_box.setText(name)
        if isinstance(v, dict):
            self.address.setText(v.get("address", ""))
            self.note.setPlainText(v.get("note", ""))

    def _apply_quick_text(self):
        # called when user presses Enter or leaves field
        text = (self.venue_quick.text() or "").strip()
        if not text:
            return

        # if exact match exists, apply it
        v = self._find_venue_by_name(text)
        if isinstance(v, dict):
            self.venue_box.setText(v.get("name", ""))
            self.address.setText(v.get("address", ""))
            self.note.setPlainText(v.get("note", ""))

    # -------- existing functions ----------
    def open_profile(self):
        if not self.staff_id:
            QMessageBox.warning(self, "Select staff", "Pick a staff member first.")
            return
        if hasattr(self, "on_open_profile"):
            self.on_open_profile(self.staff_id, self.staff_name or "")

    def _placement_payload(self):
        venue_name = (self.venue_box.text() or "").strip()

        return {
            "venue": venue_name,
            "position": self.position.text().strip(),
            "roleTitle": self.position.text().strip(),
            "date": self.date.text().strip(),
            "startTime": self.start.text().strip(),
            "endTime": self.end.text().strip(),
            "hourlyRate": float(self.rate.text().strip() or 0),
            "addressLine": self.address.text().strip(),
            "notes": (self.note.toPlainText() or "").strip(),
        }

    # ---------------- Actions ----------------
    def send_offer(self):
        if not self.staff_id:
            QMessageBox.warning(self, "Select staff", "Pick a staff member first.")
            return

        placement = self._placement_payload()
        if not placement["venue"] or not placement["position"] or not placement["date"]:
            QMessageBox.warning(self, "Missing fields", "Venue, Position and Date are required.")
            return

        try:
            self.api.send_offer(self.staff_id, placement, force=False)
            QMessageBox.information(self, "Sent", "Offer sent.")
            self.load_history()
            return
        
        except Exception as e:
            status = None
            data = None
            msg = str(e)

            # Try to extract HTTP status + JSON from requests HTTPError
            r = getattr(e, "response", None)
            if r is not None:
                status = r.status_code
                try:
                    data = r.json()
                except Exception:
                    data = None

              # ✅ Conflict detection
            if status == 409 and isinstance(data, dict) and data.get("code") == "CONFLICT":
                ok = QMessageBox.question(
                    self,
                    "Conflict detected",
                    "This staff already has a booking that overlaps this time.\n\nSend offer anyway?",
                    QMessageBox.Yes | QMessageBox.No,
                )
                if ok == QMessageBox.Yes:
                    try:
                        self.api.send_offer(self.staff_id, placement, force=True)
                        QMessageBox.information(self, "Sent", "Offer sent (forced).")
                        self.load_history()
                        return
                    except Exception as e2:
                        QMessageBox.critical(self, "Send failed", str(e2))
                        return
                else:
                # ✅ If admin clicks NO, just stop quietly (no error popup)
                     return

            QMessageBox.critical(self, "Send failed", msg)


        
    def save_offer(self):
        QMessageBox.information(self, "Saved", "Save Offer is currently a placeholder.")

    # ---------------- History ----------------
    def load_history(self):
        if not self.staff_id:
            return
        try:
            self.history.clear()
            self.offers_cache = self.api.admin_offers_by_staff(self.staff_id) or []
            self.apply_history_search()
        except Exception as e:
            QMessageBox.critical(self, "History error", str(e))

    def _offer_search_text(self, o: dict) -> str:
        placement = o.get("placementId")
        if isinstance(placement, dict):
            venue = placement.get("venue", "")
            date = str(placement.get("date", ""))[:10]
            start = placement.get("startTime", "")
            end = placement.get("endTime", "")
            rate = str(placement.get("hourlyRate", ""))
        else:
            venue, date, start, end, rate = "", "", "", "", ""
        status = str(o.get("status", ""))
        return f"{venue} {date} {start} {end} {rate} {status}".lower()

    def apply_history_search(self):
        q = (self.history_search.text() or "").strip().lower()
        if not q:
            self.filtered_offers = self.offers_cache[:]
        else:
            self.filtered_offers = [o for o in self.offers_cache if q in self._offer_search_text(o)]
        self.render_history_list()

    def render_history_list(self):
        self.history.clear()
        for o in self.filtered_offers:
            placement = o.get("placementId")
            if isinstance(placement, dict):
                venue = placement.get("venue", "")
                date = str(placement.get("date", ""))[:10]
                rate = placement.get("hourlyRate", 0)
                start = placement.get("startTime", "")
                end = placement.get("endTime", "")
            else:
                venue, date, rate, start, end = "", "", 0, "", ""

            status = o.get("status", "")

            item = QListWidgetItem(f"{venue}  |  {date}  |  {start}-{end}  |  £{rate}/hr\nStatus: {status}")
            item.setData(Qt.UserRole, o)
            self.history.addItem(item)
            # auto adjust height so page scroll is used instead of list scroll
            row_h = 70   # adjust if needed
            count = self.history.count()
            self.history.setFixedHeight(max(260, min(900, count * row_h + 20)))


    def pick_offer(self, item: QListWidgetItem):
        self.selected_offer = item.data(Qt.UserRole)

    def mark_completed(self):
        if not self.selected_offer:
            QMessageBox.warning(self, "Pick shift", "Select a shift first.")
            return
        offer_id = str(self.selected_offer.get("_id"))
        try:
            self.api.admin_complete_offer(offer_id)
            QMessageBox.information(self, "Done", "Marked as completed ✅")
            self.load_history()
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))

    def cancel_offer(self):
        if not self.selected_offer:
            QMessageBox.warning(self, "Pick shift", "Select a shift first.")
            return
        offer_id = str(self.selected_offer.get("_id"))
        try:
            self.api.admin_cancel_offer(offer_id, "")
            QMessageBox.information(self, "Cancelled", "Cancelled ✅")
            self.load_history()
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))

    def export_csv(self):
        if not self.staff_id:
            QMessageBox.warning(self, "Select staff", "Pick a staff member first.")
            return
        path, _ = QFileDialog.getSaveFileName(self, "Export CSV", "schedule_history.csv", "CSV Files (*.csv)")
        if not path:
            return
        try:
            import csv
            with open(path, "w", newline="", encoding="utf-8") as f:
                w = csv.writer(f)
                w.writerow(["Venue", "Date", "Start", "End", "Rate", "Status"])
                for o in self.filtered_offers:
                    p = o.get("placementId") if isinstance(o.get("placementId"), dict) else {}
                    w.writerow([
                        p.get("venue", ""),
                        str(p.get("date", ""))[:10],
                        p.get("startTime", ""),
                        p.get("endTime", ""),
                        p.get("hourlyRate", ""),
                        o.get("status", ""),
                    ])
            QMessageBox.information(self, "Exported", f"Saved to {path}")
        except Exception as e:
            QMessageBox.critical(self, "Export failed", str(e))


# ----------------- Staff Profile Page -----------------
class StaffProfilePage(QWidget):
    def __init__(self, api: ApiClient, on_back=None):
        super().__init__()
        self.api = api

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)

        top = QHBoxLayout()
        self.back_btn = ghost_btn("← Back")
        top.addWidget(self.back_btn, alignment=Qt.AlignLeft)

        self.title = card_title("Staff Profile")
        top.addWidget(self.title)
        top.addStretch(1)
        root.addLayout(top)

        wrap = QFrame()
        wrap.setStyleSheet("background: rgba(255,255,255,0.55); border-radius: 22px;")
        gl = QGridLayout(wrap)
        gl.setContentsMargins(18, 18, 18, 18)
        gl.setHorizontalSpacing(14)
        gl.setVerticalSpacing(10)

        self.v_name = value_label("")
        self.v_email = value_label("")
        self.v_dob = value_label("")
        self.v_username = value_label("")
        self.v_created = value_label("")
        self.v_jobs = value_label("")
        self.v_hours = value_label("")
        self.v_earnings = value_label("")

        labels = [
            ("Full name", self.v_name),
            ("Email", self.v_email),
            ("Date of birth", self.v_dob),
            ("Username", self.v_username),
            ("Account created", self.v_created),
            ("Total jobs worked", self.v_jobs),
            ("Total hours worked", self.v_hours),
            ("Total earnings", self.v_earnings),
        ]

        for r, (lab, val) in enumerate(labels):
            gl.addWidget(section_label(lab), r, 0)
            gl.addWidget(val, r, 1)

        root.addWidget(wrap)
        # --- status + suspend controls ---
        self._staff_id = None
        self._is_active = True

        self.lbl_status = QLabel("")
        self.lbl_status.setStyleSheet("font-weight: 800; font-size: 14px;")
        root.addWidget(self.lbl_status)

        actions = QHBoxLayout()
        self.btn_suspend = ghost_btn("Suspend")
        self.btn_unsuspend = primary_btn("Un-suspend")
        actions.addWidget(self.btn_suspend)
        actions.addWidget(self.btn_unsuspend)
        actions.addStretch(1)
        root.addLayout(actions)

        self.btn_suspend.clicked.connect(lambda: self.set_active(False))
        self.btn_unsuspend.clicked.connect(lambda: self.set_active(True))

        root.addStretch(1)

    def load_staff(self, staff_id, staff_name=""):
        self._staff_id = staff_id
        try:
            data = self.api.admin_staff_profile(staff_id)
            
            self.title.setText(f"Staff Profile — {staff_name or data.get('username','')}")
            self.v_name.setText(data.get("fullName", ""))
            self.v_email.setText(data.get("email", ""))
            self.v_dob.setText(str(data.get("dob", "")))
            self.v_username.setText(data.get("username", ""))
            self.v_created.setText(str(data.get("createdAt", "")))
            self.v_jobs.setText(str(data.get("totalJobsWorked", 0)))
            self.v_hours.setText(str(data.get("totalHoursWorked", 0)))
            self.v_earnings.setText(f"£{data.get('totalEarnings', 0)}")
            self._is_active = bool(data.get("isActive", True))
            if self._is_active:
               self.lbl_status.setText("Status: ✅ Active")
               self.btn_suspend.show()
               self.btn_unsuspend.hide()
            else:
               self.lbl_status.setText("Status: ⛔ Suspended")
               self.btn_suspend.hide()
               self.btn_unsuspend.show()
        except Exception as e:
            QMessageBox.critical(self, "Profile error", str(e))
            
    def set_active(self, active: bool):
        if not self._staff_id:
            return

        if not active:
             ok = QMessageBox.question(
                  self,
                  "Suspend staff",
                  "Suspend this staff?\nThey will NOT be able to login or receive offers.",
                  QMessageBox.Yes | QMessageBox.No,
             )
             if ok != QMessageBox.Yes:
                 return

        try:
            self.api.admin_set_staff_active(self._staff_id, active)
            self.load_staff(self._staff_id)
            QMessageBox.information(self, "Done", "Staff status updated")
        except Exception as e:
            QMessageBox.critical(self, "Failed", str(e))



# ----------------- Calendar Page -----------------
class CalendarPage(QWidget):
    def __init__(self, api: ApiClient):
        super().__init__()
        self.api = api

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)

        root.addWidget(card_title("Calendar"))
        lab = QLabel("Calendar feature coming soon.")
        lab.setStyleSheet("font-weight: 700;")
        root.addWidget(lab)
        root.addStretch(1)


# ----------------- Payroll Page -----------------
class StaffPayrollCard(QFrame):
    def __init__(self, username: str, hours: float, pay: float):
        super().__init__()
        self.username = username
        self.setStyleSheet("""
            QFrame {
                background: #ffffff;
                border-radius: 16px;
                padding: 12px;
            }
            QFrame:hover { background: #f2f6ff; }
        """)
        self.setCursor(Qt.PointingHandCursor)

        row = QHBoxLayout(self)
        row.setContentsMargins(14, 10, 14, 10)

        name = QLabel(username)
        name.setStyleSheet("font-size: 14px; font-weight: 600;")

        hrs = QLabel(f"{hours:.2f}")
        hrs.setAlignment(Qt.AlignCenter)
        hrs.setFixedWidth(60)

        pay_lbl = QLabel(f"{pay:.2f}")
        pay_lbl.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        pay_lbl.setFixedWidth(70)

        row.addWidget(name, 1)
        row.addWidget(hrs)
        row.addWidget(pay_lbl)

class ShiftRowCard(QFrame):
    def __init__(self, venue: str, time_txt: str, date_txt: str, hours: float, pay: float):
        super().__init__()
        self.setStyleSheet("""
            QFrame {
                background: #ffffff;
                border-radius: 14px;
                padding: 10px;
            }
        """)

        row = QHBoxLayout(self)
        row.setContentsMargins(14, 8, 14, 8)

        c1 = QLabel(venue); c1.setFixedWidth(90)
        c2 = QLabel(time_txt); c2.setFixedWidth(120)
        c3 = QLabel(date_txt); c3.setFixedWidth(90)
        c4 = QLabel(f"{hours:.1f}"); c4.setFixedWidth(80); c4.setAlignment(Qt.AlignCenter)
        c5 = QLabel(f"{pay:.2f}"); c5.setFixedWidth(80); c5.setAlignment(Qt.AlignRight | Qt.AlignVCenter)

        row.addWidget(c1)
        row.addWidget(c2)
        row.addWidget(c3)
        row.addWidget(c4)
        row.addWidget(c5)
        row.addStretch(1)


class PayrollPage(QWidget):
    def __init__(self, api):
        super().__init__()
        self.api = api
        self.current_period = None
        self.current_staff = None
        self.current_shifts = []

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)

        root.addWidget(card_title("Payroll"))

        # ===== Top bar card =====
        top_card = QFrame()
        top_card.setStyleSheet("background: rgba(255,255,255,0.55); border-radius: 18px;")
        top_l = QHBoxLayout(top_card)
        top_l.setContentsMargins(14, 10, 14, 10)
        top_l.setSpacing(10)

        top_l.addWidget(QLabel("Pay date:"))

        self.period_box = QComboBox()
        self.period_box.setMinimumWidth(180)
        self.period_box.setSizeAdjustPolicy(QComboBox.AdjustToContents)
        self.period_box.view().setMinimumWidth(240)
        self.period_box.setStyleSheet("""
            QComboBox {
                background: white;
                border-radius: 10px;
                padding: 8px 10px;
                border: 1px solid rgba(0,0,0,0.08);
                font-size: 13px;
                min-height: 34px;
            }
            QComboBox::drop-down { border: none; width: 28px; }
        """)

        self.btn_load = primary_btn("Load")
        self.btn_export = ghost_btn("Export CSV")

        top_l.addWidget(self.period_box)
        top_l.addWidget(self.btn_load)
        top_l.addWidget(self.btn_export)
        top_l.addStretch(1)
        root.addWidget(top_card)

        # ===== Main panels =====
        body = QHBoxLayout()
        body.setSpacing(14)
        root.addLayout(body, 1)

        # ----- Left panel (staff list) -----
        left = QFrame()
        left.setStyleSheet("background: rgba(255,255,255,0.35); border-radius: 18px;")
        left_l = QVBoxLayout(left)
        left_l.setContentsMargins(14, 14, 14, 14)
        left_l.setSpacing(10)

        header = QHBoxLayout()
        h1 = QLabel("Staff"); h1.setStyleSheet("font-weight:600;")
        h2 = QLabel("hour"); h2.setStyleSheet("font-weight:600;"); h2.setFixedWidth(60); h2.setAlignment(Qt.AlignCenter)
        h3 = QLabel("pay");  h3.setStyleSheet("font-weight:600;"); h3.setFixedWidth(70); h3.setAlignment(Qt.AlignRight | Qt.AlignVCenter)
        header.addWidget(h1, 1); header.addWidget(h2); header.addWidget(h3)
        left_l.addLayout(header)

        self.staff_list = QListWidget()
        self.staff_list.setSpacing(10)
        self.staff_list.setStyleSheet("QListWidget{background: transparent; border:none;}")
        left_l.addWidget(self.staff_list, 1)

        left.setFixedWidth(320)
        body.addWidget(left)

        # ----- Right panel (details) -----
        right = QFrame()
        right.setStyleSheet("background: rgba(255,255,255,0.35); border-radius: 18px;")
        right_l = QVBoxLayout(right)
        right_l.setContentsMargins(14, 14, 14, 14)
        right_l.setSpacing(10)

        self.lbl_staff = QLabel("")
        self.lbl_staff.setStyleSheet("font-size: 16px; font-weight: 700;")
        right_l.addWidget(self.lbl_staff)

        self.lbl_summary = QLabel("Select a staff member")
        self.lbl_summary.setStyleSheet("color:#555; font-size:13px;")
        right_l.addWidget(self.lbl_summary)

        # Column header for shift rows
        cols = QHBoxLayout()
        def col(txt, w, align=None):
            l = QLabel(txt); l.setFixedWidth(w); l.setStyleSheet("font-weight:600; color:#333;")
            if align: l.setAlignment(align)
            return l
        cols.addWidget(col("Venue", 90))
        cols.addWidget(col("start /End time", 120))
        cols.addWidget(col("Date", 90))
        cols.addWidget(col("Total Hour", 80, Qt.AlignCenter))
        cols.addWidget(col("Total Pay", 80, Qt.AlignRight | Qt.AlignVCenter))
        cols.addStretch(1)
        right_l.addLayout(cols)

        # Scroll area of shift cards
        self.shift_container = QWidget()
        self.shift_v = QVBoxLayout(self.shift_container)
        self.shift_v.setContentsMargins(0, 0, 0, 0)
        self.shift_v.setSpacing(10)
        self.shift_v.addStretch(1)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setWidget(self.shift_container)
        right_l.addWidget(scroll, 1)

        body.addWidget(right, 1)

        # signals
        self.btn_load.clicked.connect(self.load_staff_summary)
        self.btn_export.clicked.connect(self.export_csv)
        self.staff_list.itemClicked.connect(self.on_staff_clicked)
        self.period_box.currentIndexChanged.connect(lambda *_: self.load_staff_summary())

        self.load_pay_dates()
        if self.period_box.count() > 0:
            self.load_staff_summary()

    def load_pay_dates(self):
        self.period_box.clear()
        for p in self.api.payroll_periods():
            self.period_box.addItem(p["payDate"])

    def load_staff_summary(self):
        self.staff_list.clear()
        self.current_staff = None
        self.current_shifts = []
        self.lbl_staff.setText("")
        self.lbl_summary.setText("Select a staff member")
        self._render_shift_cards([])

        pay_date = self.period_box.currentText().strip()
        if not pay_date:
            return

        data = self.api.payroll_by_paydate(pay_date)
        self.current_period = data.get("period")

        for s in data.get("staff", []):
            username = s.get("username", "Unknown")
            hours = float(s.get("totalHours", 0) or 0)
            pay = float(s.get("totalPay", 0) or 0)

            item = QListWidgetItem()
            item.setData(Qt.UserRole, username)

            card = StaffPayrollCard(username, hours, pay)
            item.setSizeHint(card.sizeHint())

            self.staff_list.addItem(item)
            self.staff_list.setItemWidget(item, card)

    def on_staff_clicked(self, item: QListWidgetItem):
        username = item.data(Qt.UserRole)
        pay_date = self.period_box.currentText().strip()
        if not username or not pay_date:
            return

        data = self.api.payroll_staff_detail(pay_date, username)
        period = data.get("period") or self.current_period or {"from": "", "to": ""}
        shifts = data.get("shifts", [])

        self.current_staff = username
        self.current_shifts = shifts

        total_h = sum(float(s.get("hours", 0) or 0) for s in shifts)
        total_p = sum(float(s.get("pay", 0) or 0) for s in shifts)

        self.lbl_staff.setText(username)
        self.lbl_summary.setText(
            f"Period: {period.get('from','')} → {period.get('to','')}    "
            f"Total hours: {total_h:.2f}    Total pay: £{total_p:.2f}"
        )

        self._render_shift_cards(shifts)

    def _render_shift_cards(self, shifts):
        # Clear previous cards
        while self.shift_v.count():
            item = self.shift_v.takeAt(0)
            w = item.widget()
            if w:
                w.deleteLater()

        for s in shifts:
            venue = str(s.get("venue", ""))
            time_txt = f"{s.get('startTime','')}-{s.get('endTime','')}"
            date_txt = str(s.get("date", ""))
            hours = float(s.get("hours", 0) or 0)
            pay = float(s.get("pay", 0) or 0)
            self.shift_v.addWidget(ShiftRowCard(venue, time_txt, date_txt, hours, pay))

        self.shift_v.addStretch(1)

    def export_csv(self):
        path, _ = QFileDialog.getSaveFileName(self, "Export Payroll CSV", "payroll.csv", "CSV Files (*.csv)")
        if not path:
            return

        pay_date = self.period_box.currentText().strip()
        data = self.api.payroll_by_paydate(pay_date)
        period = data.get("period", {})
        staff = data.get("staff", [])

        with open(path, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["payDate", "periodFrom", "periodTo", "username", "totalHours", "totalPay"])
            for s in staff:
                w.writerow([
                    pay_date,
                    period.get("from", ""),
                    period.get("to", ""),
                    s.get("username", ""),
                    s.get("totalHours", 0),
                    f"{float(s.get('totalPay',0) or 0):.2f}",
                ])

class VenueTemplatesPage(QWidget):
    def __init__(self, api: ApiClient):
        super().__init__()
        self.api = api
        self.selected_id = None
        self.venues_cache = []
        self.filtered = []

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)

        root.addWidget(card_title("Save Offer"))

        # ---- form card ----
        form = QFrame()
        form.setStyleSheet("background: rgba(255,255,255,0.55); border-radius: 22px;")
        gl = QGridLayout(form)
        gl.setContentsMargins(18, 18, 18, 18)
        gl.setHorizontalSpacing(14)
        gl.setVerticalSpacing(10)

        self.v_name = input_box("Venue name (e.g. Royal)")
        self.v_address = input_box("Address")

        self.v_note = QTextEdit()
        self.v_note.setPlaceholderText("Note")
        self.v_note.setFixedHeight(90)
        self.v_note.setStyleSheet("""
            QTextEdit{
                background: white;
                border-radius: 14px;
                padding: 10px;
                border: 1px solid rgba(0,0,0,0.10);
                font-size: 13px;
            }
        """)

        gl.addWidget(section_label("Venue"), 0, 0)
        gl.addWidget(self.v_name, 0, 1)
        gl.addWidget(section_label("Address"), 1, 0)
        gl.addWidget(self.v_address, 1, 1)
        gl.addWidget(section_label("Note"), 2, 0)
        gl.addWidget(self.v_note, 2, 1)

        root.addWidget(form)

        # ---- buttons ----
        btns = QHBoxLayout()
        self.btn_save_new = primary_btn("Save New")
        self.btn_update = ghost_btn("Update")
        self.btn_delete = ghost_btn("Delete")
        self.btn_clear = ghost_btn("Clear")

        self.btn_save_new.clicked.connect(self.save_new)
        self.btn_update.clicked.connect(self.update_selected)
        self.btn_delete.clicked.connect(self.delete_selected)
        self.btn_clear.clicked.connect(self.clear_form)

        btns.addWidget(self.btn_save_new)
        btns.addWidget(self.btn_update)
        btns.addWidget(self.btn_delete)
        btns.addStretch(1)
        btns.addWidget(self.btn_clear)

        root.addLayout(btns)

        root.addWidget(card_title("Saved Venues"))

        search_row, self.search_input, self.btn_clear_search, self._timer = make_search_row("Search venues…")
        root.addLayout(search_row)
        self._timer.timeout.connect(self.apply_search)
        self.search_input.textChanged.connect(lambda: self._timer.start(250))

        self.list = QListWidget()
        self.list.setStyleSheet("""
            QListWidget {
                background: rgba(255,255,255,0.55);
                border: none;
                border-radius: 18px;
                padding: 8px;
                selection-background-color: transparent;
                selection-color: #000;
                outline: 0px;
            }
            QListWidget::item {
                background: white;
                margin: 6px;
                padding: 14px;
                border-radius: 14px;
                font-weight: 700;
            }
            QListWidget::item:selected {
                background: white;
                border: 2px solid #5B5CE5;
            }
        """)
        self.list.itemClicked.connect(self.pick_item)
        root.addWidget(self.list, 1)

        self.load()

    def clear_form(self):
        self.selected_id = None
        self.v_name.setText("")
        self.v_address.setText("")
        self.v_note.setPlainText("")
        self.btn_update.setEnabled(False)
        self.btn_delete.setEnabled(False)

    def _payload(self):
        return {
            "name": (self.v_name.text() or "").strip(),
            "address": (self.v_address.text() or "").strip(),
            "note": (self.v_note.toPlainText() or "").strip(),
        }

    def load(self):
        try:
            self.venues_cache = self.api.venues_list() or []
            self.apply_search()
            self.clear_form()
        except Exception as e:
            QMessageBox.critical(self, "Error", str(e))

    def apply_search(self):
        q = (self.search_input.text() or "").strip().lower()
        if not q:
            self.filtered = self.venues_cache[:]
        else:
            self.filtered = [v for v in self.venues_cache if q in (v.get("name", "").lower())]

        self.list.clear()
        for v in self.filtered:
            vid = v.get("_id") or v.get("id")
            name = v.get("name", "")
            addr = v.get("address", "")
            item = QListWidgetItem(f"{name}\n{addr}")
            item.setData(Qt.UserRole, {"id": vid, "venue": v})
            self.list.addItem(item)

    def pick_item(self, item: QListWidgetItem):
        data = item.data(Qt.UserRole) or {}
        v = data.get("venue") or {}
        self.selected_id = data.get("id")

        self.v_name.setText(v.get("name", ""))
        self.v_address.setText(v.get("address", ""))
        self.v_note.setPlainText(v.get("note", ""))

        self.btn_update.setEnabled(True)
        self.btn_delete.setEnabled(True)

    def save_new(self):
        payload = self._payload()
        if not payload["name"]:
            QMessageBox.warning(self, "Missing", "Venue name is required.")
            return
        try:
            self.api.venues_create(payload)
            QMessageBox.information(self, "Saved", "Venue template saved.")
            self.load()
            if hasattr(self, "on_changed") and callable(self.on_changed):
                self.on_changed()
        except Exception as e:
            QMessageBox.critical(self, "Save failed", str(e))

    def update_selected(self):
        if not self.selected_id:
            QMessageBox.warning(self, "Select", "Select a saved venue first.")
            return
        payload = self._payload()
        if not payload["name"]:
            QMessageBox.warning(self, "Missing", "Venue name is required.")
            return
        try:
            self.api.venues_update(self.selected_id, payload)
            QMessageBox.information(self, "Updated", "Venue updated.")
            self.load()
            if hasattr(self, "on_changed") and callable(self.on_changed):
                self.on_changed()
        except Exception as e:
            QMessageBox.critical(self, "Update failed", str(e))

    def delete_selected(self):
        if not self.selected_id:
            QMessageBox.warning(self, "Select", "Select a saved venue first.")
            return

        ok = QMessageBox.question(
            self, "Delete", "Delete this saved venue template?",
            QMessageBox.Yes | QMessageBox.No
        )
        if ok != QMessageBox.Yes:
            return

        try:
            self.api.venues_delete(self.selected_id)
            QMessageBox.information(self, "Deleted", "Venue deleted.")
            self.load()
            if hasattr(self, "on_changed") and callable(self.on_changed):
                self.on_changed()
        except Exception as e:
            QMessageBox.critical(self, "Delete failed", str(e))


# ----------------- History List Page (staff picker with Search) -----------------
class HistoryListPage(QWidget):
    def __init__(self, api: ApiClient, on_pick):
        super().__init__()
        self.api = api
        self.on_pick = on_pick

        self.all_staff = []
        self.filtered_staff = []

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)

        root.addWidget(card_title("Schedule History"))

        # ✅ Search
        search_row, self.search_input, self.btn_clear_search, self._search_timer = make_search_row(
            "Search staff (name or username)…"
        )
        root.addLayout(search_row)
        self._search_timer.timeout.connect(self.apply_search)
        self.search_input.textChanged.connect(lambda: self._search_timer.start(250))

        self.list = QListWidget()
        self.list.setStyleSheet("""
    QListWidget {
        background: rgba(255,255,255,0.55);
        border: none;
        border-radius: 18px;
        padding: 8px;
        selection-background-color: transparent;
        selection-color: #000;
        outline: 0px;
    }
    QListWidget::item {
        background: white;
        margin: 6px;
        padding: 14px;
        border-radius: 14px;
        font-weight: 700;
    }
    QListWidget::item:selected {
        background: white;
        border: 2px solid #5B5CE5;
    }
    QListWidget::item:selected:!active {
        background: white;
        border: 2px solid #5B5CE5;
    }""")
        self.list.itemClicked.connect(self.pick)
        root.addWidget(self.list, stretch=1)

        self.btn_refresh = ghost_btn("Refresh")
        self.btn_refresh.clicked.connect(self.load)
        root.addWidget(self.btn_refresh)

        self.load()

    def load(self):
        try:
            self.list.clear()
            self.all_staff = self.api.admin_staff() or []
            self.apply_search()
        except Exception as e:
            QMessageBox.critical(self, "Load staff error", str(e))

    def apply_search(self):
        q = (self.search_input.text() or "").strip().lower()
        if not q:
            self.filtered_staff = self.all_staff[:]
        else:
            out = []
            for st in self.all_staff:
                name = st.get("fullName") or st.get("username") or "Staff"
                username = st.get("username", "")
                if q in f"{name} {username}".lower():
                    out.append(st)
            self.filtered_staff = out
        self.render()

    def render(self):
        self.list.clear()
        for st in self.filtered_staff:
            name = st.get("fullName") or st.get("username") or "Staff"
            username = st.get("username", "")
            active = bool(st.get("isActive", True))
            badge = "" if active else "\n⛔ SUSPENDED"
            item = QListWidgetItem(f"{name}\n@{username}{badge}")
            item.setData(Qt.UserRole, (str(st.get("_id")), name))
            self.list.addItem(item)

    def pick(self, item: QListWidgetItem):
        staff_id, staff_name = item.data(Qt.UserRole)
        self.on_pick(staff_id, staff_name)


class HistoryPage(QWidget):
    def __init__(self, api: ApiClient):
        super().__init__()
        self.api = api

        self.selected = None
        self.staff_id = None
        self.staff_name = ""

        self.all_items = []
        self.items = []
        self.display_items = []
        self.current_filter = "all"

        root = QVBoxLayout(self)
        root.setContentsMargins(14, 14, 14, 14)
        root.setSpacing(14)

        self.title = card_title("History")
        root.addWidget(self.title)

        # Week filters
        filters = QHBoxLayout()
        self.btn_this_week = ghost_btn("This week")
        self.btn_last_week = ghost_btn("Last week")
        self.btn_all = ghost_btn("All")

        self.btn_this_week.clicked.connect(lambda: self.apply_week_filter("this"))
        self.btn_last_week.clicked.connect(lambda: self.apply_week_filter("last"))
        self.btn_all.clicked.connect(lambda: self.apply_week_filter("all"))

        filters.addWidget(self.btn_this_week)
        filters.addWidget(self.btn_last_week)
        filters.addWidget(self.btn_all)
        filters.addStretch(1)
        root.addLayout(filters)

        # ✅ Search bar (applies after week filter)
        search_row, self.search_input, self.btn_clear_search, self._search_timer = make_search_row(
            "Search history (venue/date/status/time/rate)…"
        )
        root.addLayout(search_row)
        self._search_timer.timeout.connect(self.apply_search)
        self.search_input.textChanged.connect(lambda: self._search_timer.start(250))

        # --- split view: list (left) + details (right) ---
        row = QHBoxLayout()
        row.setSpacing(14)

        self.list = QListWidget()
        self.list.setStyleSheet("""
    QListWidget {
        background: rgba(255,255,255,0.55);
        border: none;
        border-radius: 18px;
        padding: 8px;
        selection-background-color: transparent;
        selection-color: #000;
        outline: 0px;
    }
    QListWidget::item {
        background: white;
        margin: 6px;
        padding: 14px;
        border-radius: 14px;
        font-weight: 700;
    }
    QListWidget::item:selected {
        background: white;
        border: 2px solid #5B5CE5;
    }
    QListWidget::item:selected:!active {
        background: white;
        border: 2px solid #5B5CE5;
    }""")
        self.list.itemClicked.connect(self.pick_offer)
        row.addWidget(self.list, stretch=2)

        self.detail = QFrame()
        self.detail.setStyleSheet("background: rgba(255,255,255,0.55); border-radius: 22px;")
        d = QVBoxLayout(self.detail)
        d.setContentsMargins(18, 18, 18, 18)
        d.setSpacing(10)

        d.addWidget(card_title("Booking Details"))

        self.d_venue = value_label("")
        self.d_role = value_label("")
        self.d_date = value_label("")
        self.d_time = value_label("")
        self.d_hours = value_label("")
        self.d_rate = value_label("")
        self.d_earn = value_label("")
        self.d_status = value_label("")
        self.d_created = value_label("")
        self.d_updated = value_label("")
        self.d_notes = value_label("")

        grid = QGridLayout()
        grid.setHorizontalSpacing(14)
        grid.setVerticalSpacing(8)

        rows = [
            ("Venue", self.d_venue),
            ("Role/Position", self.d_role),
            ("Date", self.d_date),
            ("Time", self.d_time),
            ("Total hours", self.d_hours),
            ("Hourly rate", self.d_rate),
            ("Total earnings", self.d_earn),
            ("Status", self.d_status),
            ("Created", self.d_created),
            ("Updated", self.d_updated),
            ("Notes", self.d_notes),
        ]
        for r, (lab, val) in enumerate(rows):
            grid.addWidget(section_label(lab), r, 0)
            grid.addWidget(val, r, 1)

        d.addLayout(grid)
        d.addStretch(1)

        row.addWidget(self.detail, stretch=3)
        root.addLayout(row, stretch=1)

        # bottom buttons
        btns = QHBoxLayout()
        self.btn_refresh = ghost_btn("Refresh")
        self.btn_cancel = ghost_btn("Cancel shift")
        self.btn_export = ghost_btn("Export CSV")
        self.btn_refresh.clicked.connect(self.load)
        self.btn_cancel.clicked.connect(self.cancel_selected)
        self.btn_export.clicked.connect(self.export_csv)

        btns.addWidget(self.btn_refresh)
        btns.addWidget(self.btn_cancel)
        btns.addWidget(self.btn_export)
        btns.addStretch(1)
        root.addLayout(btns)

    def set_staff(self, staff_id: str, staff_name: str):
        self.staff_id = staff_id
        self.staff_name = staff_name
        self.title.setText(f"History — {staff_name} (ID: {staff_id})")
        self.load()

    def load(self):
        try:
            if not self.staff_id:
                return

            self.selected = None
            self._clear_detail()

            data = self.api.admin_offers_by_staff(self.staff_id)
            offers = data.get("offers") if isinstance(data, dict) else data
            offers = offers or []

            self.all_items = offers[:]
            self.apply_week_filter(self.current_filter or "all")

        except Exception as e:
            QMessageBox.critical(self, "History load error", str(e))

    def cancel_selected(self):
        if not self.selected:
            QMessageBox.warning(self, "Pick shift", "Select a shift first.")
            return

        offer_id = str(self.selected.get("_id"))
        reason, ok = QInputDialog.getText(self, "Cancel shift", "Reason (optional):")
        if not ok:
            return

        try:
            self.api.admin_cancel_offer(offer_id, reason.strip())
            QMessageBox.information(self, "Cancelled", "Shift cancelled ✅")
            self.load()
        except Exception as e:
            QMessageBox.critical(self, "Cancel error", str(e))

    def apply_week_filter(self, mode: str):
        self.current_filter = mode

        if mode == "all":
            filtered = self.all_items
        else:
            today = datetime.now().date()
            this_monday = today - timedelta(days=today.weekday())

            if mode == "this":
                start = this_monday
                end = this_monday + timedelta(days=7)
            else:  # last
                start = this_monday - timedelta(days=7)
                end = this_monday

            filtered = []
            for o in self.all_items:
                p = o.get("placementId") if isinstance(o.get("placementId"), dict) else {}
                d = str(p.get("date", ""))[:10]
                try:
                    dt = datetime.strptime(d, "%Y-%m-%d").date()
                except Exception:
                    continue

                if start <= dt < end:
                    filtered.append(o)

        self.items = filtered
        self.apply_search()

    def _offer_search_text(self, o: dict) -> str:
        p = o.get("placementId") if isinstance(o.get("placementId"), dict) else {}
        venue = p.get("venue", "")
        date = str(p.get("date", ""))[:10]
        st = p.get("startTime", "")
        en = p.get("endTime", "")
        status = str(o.get("status", ""))
        rate = str(p.get("hourlyRate", ""))
        return f"{venue} {date} {st} {en} {status} {rate}".lower()

    def apply_search(self):
        q = (self.search_input.text() or "").strip().lower()
        if not q:
            self.display_items = self.items[:]
        else:
            self.display_items = [o for o in self.items if q in self._offer_search_text(o)]
        self.render_list()

    def render_list(self):
        self.list.clear()
        self._clear_detail()

        for o in self.display_items:
            p = o.get("placementId") if isinstance(o.get("placementId"), dict) else {}
            venue = p.get("venue", "")
            date = str(p.get("date", ""))[:10]
            st = p.get("startTime", "")
            en = p.get("endTime", "")
            status = o.get("status", "")
            rate = p.get("hourlyRate", "")

            text = f"{venue} | {date} | {st}-{en}\nStatus: {status} | £{rate}/hr"
            item = QListWidgetItem(text)
            item.setData(Qt.UserRole, str(o.get("_id")))
            self.list.addItem(item)

    def pick_offer(self, item: QListWidgetItem):
        offer_id = item.data(Qt.UserRole)
        offer = next((x for x in self.display_items if str(x.get("_id")) == str(offer_id)), None)
        if not offer:
            return
        self.selected = offer
        self._fill_detail(offer)

    def _clear_detail(self):
        self.d_venue.setText("")
        self.d_role.setText("")
        self.d_date.setText("")
        self.d_time.setText("")
        self.d_hours.setText("")
        self.d_rate.setText("")
        self.d_earn.setText("")
        self.d_status.setText("")
        self.d_created.setText("")
        self.d_updated.setText("")
        self.d_notes.setText("")

    def _fill_detail(self, offer: dict):
        p = offer.get("placementId") if isinstance(offer.get("placementId"), dict) else {}

        venue = p.get("venue", "")
        role = p.get("roleTitle") or p.get("position", "")
        date = str(p.get("date", ""))[:10]
        st = p.get("startTime", "")
        en = p.get("endTime", "")
        hours = p.get("totalHours", "")
        rate = p.get("hourlyRate", "")
        notes = p.get("notes") or p.get("note") or ""

        status = offer.get("status", "")
        created = str(offer.get("createdAt", ""))
        updated = str(offer.get("updatedAt", ""))

        try:
            earn = float(hours) * float(rate)
        except Exception:
            earn = 0.0

        self.d_venue.setText(str(venue))
        self.d_role.setText(str(role))
        self.d_date.setText(str(date))
        self.d_time.setText(f"{st} - {en}")
        self.d_hours.setText(str(hours))
        self.d_rate.setText(str(rate))
        self.d_earn.setText(f"£{earn:.2f}")
        self.d_status.setText(str(status))
        self.d_created.setText(created)
        self.d_updated.setText(updated)
        self.d_notes.setText(str(notes))

    def export_csv(self):
        if not self.display_items:
            QMessageBox.information(self, "Export", "No history to export.")
            return

        path, _ = QFileDialog.getSaveFileName(
            self, "Save CSV", f"{self.staff_name}_history.csv", "CSV Files (*.csv)"
        )
        if not path:
            return

        with open(path, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["venue", "roleTitle/position", "date", "start", "end", "hourlyRate", "totalHours", "status"])
            for o in self.display_items:
                p = o.get("placementId") if isinstance(o.get("placementId"), dict) else {}
                w.writerow([
                    p.get("venue", ""),
                    p.get("roleTitle") or p.get("position", ""),
                    str(p.get("date", ""))[:10],
                    p.get("startTime", ""),
                    p.get("endTime", ""),
                    p.get("hourlyRate", ""),
                    p.get("totalHours", ""),
                    o.get("status", ""),
                ])

        QMessageBox.information(self, "Export", "CSV exported successfully.")


# ----------------- Main Window -----------------
class MainWindow(QMainWindow):
    def __init__(self, api: ApiClient):
        super().__init__()
        self.api = api

        self.setWindowTitle("Adolphus - Admin Portal")
        self.resize(1200, 720)

        root = QWidget()
        root_layout = QVBoxLayout(root)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(0)

        # Top bar
        topbar = QFrame()
        topbar.setFixedHeight(56)
        topbar.setStyleSheet("background: #5B5CE5;")
        top_layout = QHBoxLayout(topbar)
        title = QLabel("Adolphus")
        title.setStyleSheet("color: white; font-size: 18px; padding-left: 16px; font-weight: 900;")
        top_layout.addWidget(title)
        top_layout.addStretch(1)
        root_layout.addWidget(topbar)

        # Body
        body = QWidget()
        body_layout = QHBoxLayout(body)
        body_layout.setContentsMargins(24, 24, 24, 24)
        body_layout.setSpacing(24)

        # Sidebar
        self.sidebar = QFrame()
        self.sidebar.setFixedWidth(170)
        self.sidebar.setStyleSheet("background: #DDEAF6; border-radius: 24px;")

        sb = QVBoxLayout(self.sidebar)
        sb.setContentsMargins(18, 18, 18, 18)
        sb.setSpacing(14)

        portal = QLabel("Admin\nPortal")
        portal.setAlignment(Qt.AlignCenter)
        portal.setStyleSheet("font-size: 22px; font-weight: 900;")
        sb.addWidget(portal)
        sb.addSpacing(10)

        self.btn_dash = self._nav_button("📊", "Dashboard")
        self.btn_new = self._nav_button("👤", "New User")
        self.btn_sched = self._nav_button("📅", "Schedule")
        self.btn_venues = self._nav_button("🏨", "Save Offer")
        self.btn_history = self._nav_button("🕘", "History")
        self.btn_pending = self._nav_button("⏳", "Pending")
        self.btn_profile = self._nav_button("🪪", "Profile")
        self.btn_payroll = self._nav_button("💷", "Payroll")
        self.btn_cal = self._nav_button("📆", "Calendar")

        sb.addWidget(self.btn_dash)
        sb.addWidget(self.btn_venues)
        sb.addWidget(self.btn_pending)
        sb.addWidget(self.btn_new)
        sb.addWidget(self.btn_sched)
        sb.addWidget(self.btn_history)
        sb.addWidget(self.btn_profile)
        sb.addWidget(self.btn_payroll)
        sb.addWidget(self.btn_cal)
        sb.addStretch(1)

        # Main card
        self.card = QFrame()
        self.card.setStyleSheet("background: #DDEAF6; border-radius: 36px;")
        card_layout = QVBoxLayout(self.card)
        card_layout.setContentsMargins(24, 24, 24, 24)

        # Pages stack
        self.stack = QStackedWidget()

        self.history_page = HistoryPage(self.api)
        self.venues_page = VenueTemplatesPage(self.api)
        self.history_list_page = HistoryListPage(self.api, self.open_history_for_staff)
        self.dashboard_page = DashboardPage(self.api)
        self.new_user_page = NewUserPage(self.api)
        self.schedule_list_page = ScheduleListPage(self.api, on_pick_staff=self.open_detail)
        self.detail_page = ScheduleDetailPage(self.api)
        self.venues_page.on_changed = self.detail_page.reload_venues_dropdown


        # Profile list uses same ScheduleListPage => already has search ✅
        self.profile_list_page = ScheduleListPage(self.api, on_pick_staff=self.open_profile_from_list)
        self.profile_page = StaffProfilePage(self.api)
        self.calendar_page = CalendarPage(self.api)
        self.payroll_page = PayrollPage(self.api)
        self.pending_page = PendingApprovalsPage(self.api)

        self.detail_page.on_open_profile = self.open_profile
        self.profile_page.back_btn.clicked.connect(self.back_from_profile)

        # Stack order
        self.stack.addWidget(self.history_list_page)
        self.stack.addWidget(self.history_page)
        self.stack.addWidget(self.venues_page)
        self.stack.addWidget(self.dashboard_page)
        self.stack.addWidget(self.pending_page)
        self.stack.addWidget(self.new_user_page)
        self.stack.addWidget(self.schedule_list_page)
        self.stack.addWidget(self.detail_page)
        self.stack.addWidget(self.profile_list_page)
        self.stack.addWidget(self.profile_page)
        self.stack.addWidget(self.calendar_page)
        self.stack.addWidget(self.payroll_page)

        card_layout.addWidget(self.stack)

        # Wire sidebar
        self.btn_dash.clicked.connect(lambda: self.stack.setCurrentWidget(self.dashboard_page))
        self.btn_venues.clicked.connect(lambda: self.stack.setCurrentWidget(self.venues_page))
        self.btn_pending.clicked.connect(lambda: self.stack.setCurrentWidget(self.pending_page))
        self.btn_new.clicked.connect(lambda: self.stack.setCurrentWidget(self.new_user_page))
        self.btn_sched.clicked.connect(lambda: self.stack.setCurrentWidget(self.schedule_list_page))
        self.btn_profile.clicked.connect(lambda: self.stack.setCurrentWidget(self.profile_list_page))
        self.btn_cal.clicked.connect(lambda: self.stack.setCurrentWidget(self.calendar_page))
        self.btn_payroll.clicked.connect(lambda: self.stack.setCurrentWidget(self.payroll_page))
        self.btn_history.clicked.connect(lambda: self.stack.setCurrentWidget(self.history_list_page))

        body_layout.addWidget(self.sidebar)
        body_layout.addWidget(self.card, stretch=1)

        root_layout.addWidget(body, stretch=1)
        self.setCentralWidget(root)

        self.stack.setCurrentWidget(self.dashboard_page)

    def _nav_button(self, icon_text, label):
        b = QPushButton(f"{icon_text}\n{label}")
        b.setCursor(Qt.PointingHandCursor)
        b.setFixedHeight(74)
        b.setStyleSheet("""
            QPushButton {
                background: rgba(255,255,255,0.65);
                border: 1px solid rgba(0,0,0,0.10);
                border-radius: 18px;
                font-weight: 900;
                padding: 10px 8px;
            }
            QPushButton:hover {
                background: rgba(255,255,255,0.85);
            }
            QPushButton:pressed {
                background: rgba(255,255,255,0.95);
            }
        """)
        return b

    def open_history_for_staff(self, staff_id, staff_name):
        self.history_page.set_staff(staff_id, staff_name)
        self.stack.setCurrentWidget(self.history_page)

    def open_detail(self, staff_id, staff_name):
        self.detail_page.reload_venues_dropdown()   # ✅ refresh latest venues
        self.detail_page.set_staff(staff_id, staff_name)
        self.stack.setCurrentWidget(self.detail_page)

    def open_profile_from_list(self, staff_id, staff_name):
        self.profile_from = "list"
        self.profile_page.load_staff(staff_id, staff_name)
        self.stack.setCurrentWidget(self.profile_page)

    def open_profile(self, staff_id, staff_name):
        self.profile_from = "detail"
        self.profile_page.load_staff(staff_id, staff_name)
        self.stack.setCurrentWidget(self.profile_page)

    def back_from_profile(self):
        if getattr(self, "profile_from", "detail") == "list":
            self.stack.setCurrentWidget(self.profile_list_page)
        else:
            self.stack.setCurrentWidget(self.detail_page)


def main():
    app = QApplication(sys.argv)
    app.setFont(QFont("Segoe UI", 10))

    api = ApiClient(BASE_URL)
    main_win = None

    def start_admin():
        nonlocal main_win
        main_win = MainWindow(api)
        main_win.show()

    login = LoginPage(api, on_success=start_admin)
    login.setWindowTitle("Admin Login")
    login.resize(420, 380)
    login.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
