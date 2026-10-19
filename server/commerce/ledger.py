"""Platform-neutral server ledger. No listener, payment keys or client-side grants.

The authenticated server supplies account_id; a trusted platform adapter queries
the payment provider. Never construct verification results from a client receipt.
"""
from __future__ import annotations

import json
import sqlite3
import time
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Protocol


class Provider(Protocol):
    def query(self, order_id: str) -> dict: ...


class Ledger:
    def __init__(self, path: str | Path, catalog: dict):
        self.path = str(path)
        self.catalog = catalog
        with self._db() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS orders (
                    id TEXT PRIMARY KEY, account TEXT NOT NULL, request TEXT NOT NULL,
                    product TEXT NOT NULL, amount INTEGER NOT NULL, currency TEXT NOT NULL,
                    grants TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending',
                    provider_txn TEXT UNIQUE, created INTEGER NOT NULL,
                    UNIQUE(account, request)
                );
                CREATE TABLE IF NOT EXISTS grants (
                    order_id TEXT NOT NULL REFERENCES orders(id), account TEXT NOT NULL,
                    item TEXT NOT NULL, revoked INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY(order_id, item)
                );
                CREATE TABLE IF NOT EXISTS audit (
                    sequence INTEGER PRIMARY KEY AUTOINCREMENT, order_id TEXT NOT NULL,
                    event TEXT NOT NULL, at INTEGER NOT NULL
                );
            """)

    @contextmanager
    def _db(self):
        db = sqlite3.connect(self.path, timeout=10)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys=ON")
        try:
            with db:
                yield db
        finally:
            db.close()

    def create_order(self, account_id: str, product_id: str, request_id: str) -> dict:
        if not account_id or not request_id or len(request_id) > 128:
            raise ValueError("Authenticated account and idempotency key required")
        item = self.catalog.get(product_id, {})
        amount = item.get("amount_minor")
        currency = item.get("currency", "")
        if (not item.get("enabled", False) or type(amount) is not int or amount <= 0
                or not isinstance(currency, str) or len(currency) != 3 or currency != currency.upper()):
            raise ValueError("Product is not configured for real payments")
        grants = item.get("cosmetics", [])
        if not grants or not all(isinstance(value, str) and value for value in grants):
            raise ValueError("Only explicitly configured permanent cosmetics are supported")
        with self._db() as db:
            db.execute("BEGIN IMMEDIATE")
            existing = db.execute("SELECT * FROM orders WHERE account=? AND request=?", (account_id, request_id)).fetchone()
            if existing:
                if existing["product"] != product_id:
                    raise ValueError("Idempotency key belongs to a different product")
                return self._public(existing)
            order_id = uuid.uuid4().hex
            db.execute("INSERT INTO orders(id,account,request,product,amount,currency,grants,created) VALUES(?,?,?,?,?,?,?,?)",
                       (order_id, account_id, request_id, product_id, amount, currency, json.dumps(grants), int(time.time())))
            db.execute("INSERT INTO audit(order_id,event,at) VALUES(?,?,?)", (order_id, "created", int(time.time())))
            return self._public(db.execute("SELECT * FROM orders WHERE id=?", (order_id,)).fetchone())

    def settle(self, order_id: str, provider: Provider) -> dict:
        verified = provider.query(order_id)  # Server-to-provider verification only.
        with self._db() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT * FROM orders WHERE id=?", (order_id,)).fetchone()
            if row is None:
                raise ValueError("Unknown order")
            if (verified.get("order_id") != row["id"] or verified.get("account_id") != row["account"]
                    or type(verified.get("amount_minor")) is not int or verified["amount_minor"] != row["amount"]
                    or verified.get("currency") != row["currency"] or not verified.get("transaction_id")):
                raise ValueError("Verified payment does not match the server order")
            transaction = str(verified["transaction_id"])
            if row["provider_txn"] and row["provider_txn"] != transaction:
                raise ValueError("Provider transaction cannot change")
            if verified.get("status") == "refunded":
                # Refund verification may arrive before the paid notification.
                # Keep it terminal and reserve the provider transaction either way.
                if row["status"] != "refunded":
                    db.execute("UPDATE grants SET revoked=1 WHERE order_id=?", (order_id,))
                    db.execute("UPDATE orders SET status='refunded',provider_txn=? WHERE id=?", (transaction, order_id))
                    db.execute("INSERT INTO audit(order_id,event,at) VALUES(?,?,?)", (order_id, "refunded", int(time.time())))
            elif verified.get("status") == "paid":
                if row["status"] == "refunded":
                    raise ValueError("A refunded order cannot grant items again")
                if row["status"] == "pending":
                    db.execute("UPDATE orders SET status='paid',provider_txn=? WHERE id=?", (transaction, order_id))
                    for item in json.loads(row["grants"]):
                        db.execute("INSERT INTO grants(order_id,account,item) VALUES(?,?,?)", (order_id, row["account"], item))
                    db.execute("INSERT INTO audit(order_id,event,at) VALUES(?,?,?)", (order_id, "paid", int(time.time())))
            else:
                raise ValueError("Payment has not been confirmed")
            return self._public(db.execute("SELECT * FROM orders WHERE id=?", (order_id,)).fetchone())

    def restore(self, authenticated_account: str) -> list[str]:
        if not authenticated_account:
            raise ValueError("Authentication required")
        with self._db() as db:
            return [row["item"] for row in db.execute("SELECT DISTINCT item FROM grants WHERE account=? AND revoked=0 ORDER BY item", (authenticated_account,))]

    @staticmethod
    def _public(row) -> dict:
        return {key: row[key] for key in ("id", "product", "amount", "currency", "status")}
