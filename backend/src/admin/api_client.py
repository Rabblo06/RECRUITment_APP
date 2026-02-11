import requests


class ApiClient:
    def __init__(self, base_url: str, token: str | None = None):
        self.base_url = base_url.rstrip("/")
        self.token = token
        self.session = requests.Session()

    def set_token(self, token: str | None):
        self.token = token

    def headers(self):
        h = {"Content-Type": "application/json"}
        if self.token:
            h["Authorization"] = f"Bearer {self.token}"  # ✅ USE LOGIN TOKEN
        return h
    

    # ---------- AUTH ----------
    def login(self, username: str, password: str):
        r = self.session.post(
            f"{self.base_url}/auth/login",
            json={"username": username, "password": password},
            headers={"Content-Type": "application/json"},
        )
        r.raise_for_status()
        data = r.json()
        token = data.get("token")
        if not token:
            raise Exception("Login failed: token not returned")
        self.token = token
        return data  # includes user role

    # ---------- EXISTING (your app) ----------
    def create_staff(self, *args, **kwargs):
     """
     Supports BOTH:
       1) create_staff({"username": "...", "password": "...", "fullName": "...", "email": "...", "dob": "..."})
       2) create_staff(username, password)
     """
     if len(args) == 1 and isinstance(args[0], dict):
        payload = args[0]
     elif len(args) >= 2:
         payload = {"username": args[0], "password": args[1]}
     else:
         payload = dict(kwargs)

     r = self.session.post(
        f"{self.base_url}/auth/create-staff",
        json=payload,
        headers=self.headers(),
    )
     r.raise_for_status()
     return r.json()
    
    def create_manager(self, payload: dict):
        # payload: {fullName,email,dob,username,password}
        r = self.session.post(
            f"{self.base_url}/auth/create-manager",
            json=payload,
            headers=self.headers(),
        )
        r.raise_for_status()
        return r.json()

    def list_staff(self):
        r = self.session.get(f"{self.base_url}/admin/staff", headers=self.headers())
        r.raise_for_status()
        return r.json()

    def send_offer(self, staff_id: str, placement: dict, force: bool = False):
        payload = {"userId": staff_id, "placement": placement, "force": bool(force)}
        r = self.session.post(
            f"{self.base_url}/offers/send",
            json=payload,
            headers=self.headers(),
        )
        r.raise_for_status()
        return r.json()



    def pending_offers(self):
        r = self.session.get(f"{self.base_url}/offers/pending", headers=self.headers())
        r.raise_for_status()
        return r.json()

    def offer_decision(self, offer_id: str, decision: str):
        r = self.session.patch(
        f"{self.base_url}/offers/{offer_id}/decision",
        json={"decision": decision},
        headers=self.headers(),
       )
        r.raise_for_status()
        return r.json()



    # ---------- ADMIN ROUTES (from your admin.js) ----------
    def admin_dashboard(self):
            r = self.session.get(f"{self.base_url}/admin/dashboard", headers=self.headers())
            r.raise_for_status()
            return r.json()

    def admin_staff(self):
        # ✅ FIX: this is what your UI calls
        r = self.session.get(f"{self.base_url}/admin/staff", headers=self.headers())
        r.raise_for_status()
        return r.json()
    
    def admin_staff_profile(self, staff_id: str):
        r = self.session.get(f"{self.base_url}/admin/staff/{staff_id}", headers=self.headers())
        r.raise_for_status()
        return r.json()
    def admin_set_staff_active(self, staff_id: str, is_active: bool):
        r = self.session.patch(
        f"{self.base_url}/admin/staff/{staff_id}/active",
        json={"isActive": bool(is_active)},
        headers=self.headers(),
    )
        r.raise_for_status()
        return r.json()


    def admin_offers_by_staff(self, staff_id: str):
        r = self.session.get(
            f"{self.base_url}/admin/offers/by-staff/{staff_id}",
            headers=self.headers()
        )
        r.raise_for_status()
        return r.json()

    def admin_edit_offer(self, offer_id: str, placement_patch: dict):
        r = self.session.put(
            f"{self.base_url}/offers/admin/offers/{offer_id}",  # ✅ FIXED PATH
            json=placement_patch,                               # ✅ correct body
            headers=self.headers()
        )
        r.raise_for_status()
        return r.json()

    
    def admin_update_offer(self, offer_id: str, placement_patch: dict):
        return self.admin_edit_offer(offer_id, placement_patch)

    def admin_delete_offer(self, offer_id: str):
        r = self.session.delete(
        f"{self.base_url}/admin/offers/{offer_id}",
        headers=self.headers(),
        )
        r.raise_for_status()
        return r.json()


    def admin_cancel_offer(self, offer_id: str, reason: str = ""):
        r = self.session.post(
            f"{self.base_url}/admin/offers/{offer_id}/cancel",
            json={"reason": reason},
            headers=self.headers()
        )
        r.raise_for_status()
        return r.json()

    def admin_complete_offer(self, offer_id: str):
        r = self.session.post(
        f"{self.base_url}/admin/offers/{offer_id}/complete",
        headers=self.headers(),
        )
        r.raise_for_status()
        return r.json()

    def admin_mark_completed(self, offer_id: str):
    # alias so UI can call either name
        return self.admin_complete_offer(offer_id)

    def admin_calendar(self, date_from: str, date_to: str):
        r = self.session.get(
            f"{self.base_url}/admin/calendar",
            params={"from": date_from, "to": date_to},
            headers=self.headers()
        )
        r.raise_for_status()
        return r.json()

    def admin_audit(self):
        r = self.session.get(f"{self.base_url}/admin/audit", headers=self.headers())
        r.raise_for_status()
        return r.json()
    
    def payroll_periods(self):
        return self._get("/admin/payroll/periods")

    def payroll_by_paydate(self, pay_date: str):
        return self._get(f"/admin/payroll/period/{pay_date}")

    
        # ---------------- HTTP helpers ----------------
    def _get(self, path: str, params: dict | None = None):
        url = f"{self.base_url}{path}"
        r = self.session.get(url, headers=self.headers(), params=params)
        r.raise_for_status()
        return r.json()

    def _post(self, path: str, payload: dict | None = None):
        url = f"{self.base_url}{path}"
        r = self.session.post(url, headers=self.headers(), json=payload or {})
        r.raise_for_status()
        return r.json()

    def _patch(self, path: str, payload: dict | None = None):
        url = f"{self.base_url}{path}"
        r = self.session.patch(url, headers=self.headers(), json=payload or {})
        r.raise_for_status()
        return r.json()

    def _delete(self, path: str):
        url = f"{self.base_url}{path}"
        r = self.session.delete(url, headers=self.headers())
        r.raise_for_status()
        return r.json()
    
    def payroll_staff_detail(self, pay_date: str, username: str):
        return self._get(f"/admin/payroll/period/{pay_date}/staff/{username}")


    def list_venues(self):
        return self._get("/admin/venues")

    def venues_list(self):
        return self._get("/admin/venues")

    def venues_create(self, payload: dict):
        return self._post("/admin/venues", payload)
    
    def venues_update(self, venue_id: str, payload: dict):
        return self._patch(f"/admin/venues/{venue_id}", payload)

    def venues_delete(self, venue_id: str):
        return self._delete(f"/admin/venues/{venue_id}")



