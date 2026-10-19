import sqlite3
import tempfile
import unittest
from pathlib import Path
from ledger import Ledger


class FixtureProvider:
    """Tests only. Production needs a server-side platform API adapter."""
    def __init__(self, receipt): self.receipt = receipt
    def query(self, order_id): return self.receipt.copy()


class LedgerTests(unittest.TestCase):
    def setUp(self):
        workspace = Path(__file__).resolve().parents[2] / "work"
        workspace.mkdir(exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(prefix="commerce-test-", dir=workspace)
        self.catalog = {"night": {"enabled": True, "amount_minor": 199, "currency": "USD", "cosmetics": ["sail_night"]}, "unconfigured": {"enabled": False}}
        self.ledger = Ledger(Path(self.directory.name) / "ledger.sqlite3", self.catalog)
        self.order = self.ledger.create_order("account-a", "night", "click-1")
        self.receipt = {"order_id": self.order["id"], "account_id": "account-a", "amount_minor": 199, "currency": "USD", "status": "paid", "transaction_id": "provider-1"}

    def tearDown(self): self.directory.cleanup()

    def test_idempotent_order_and_confirmation(self):
        self.assertEqual(self.order, self.ledger.create_order("account-a", "night", "click-1"))
        for _ in range(3): self.ledger.settle(self.order["id"], FixtureProvider(self.receipt))
        self.assertEqual(self.ledger.restore("account-a"), ["sail_night"])
        self.assertEqual(self.ledger.restore("account-b"), [])

    def test_unverified_mismatched_and_disabled_orders_are_rejected(self):
        with self.assertRaises(ValueError): self.ledger.create_order("a", "unconfigured", "x")
        for field, value in [("account_id", "thief"), ("amount_minor", 1), ("currency", "EUR"), ("status", "pending"), ("transaction_id", "")]:
            receipt = self.receipt | {field: value}
            with self.assertRaises(ValueError): self.ledger.settle(self.order["id"], FixtureProvider(receipt))
        self.assertEqual(self.ledger.restore("account-a"), [])

    def test_provider_transaction_cannot_be_reused(self):
        self.ledger.settle(self.order["id"], FixtureProvider(self.receipt))
        second = self.ledger.create_order("account-b", "night", "click-2")
        receipt = self.receipt | {"order_id": second["id"], "account_id": "account-b"}
        with self.assertRaises(sqlite3.IntegrityError): self.ledger.settle(second["id"], FixtureProvider(receipt))
        self.assertEqual(self.ledger.restore("account-b"), [])

    def test_refund_revoke_is_durable_and_cannot_regrant(self):
        self.ledger.settle(self.order["id"], FixtureProvider(self.receipt))
        self.ledger.settle(self.order["id"], FixtureProvider(self.receipt | {"status": "refunded"}))
        self.assertEqual(self.ledger.restore("account-a"), [])
        with self.assertRaises(ValueError): self.ledger.settle(self.order["id"], FixtureProvider(self.receipt))

    def test_refund_arriving_before_payment_is_terminal(self):
        refunded = self.receipt | {"status": "refunded"}
        self.assertEqual(self.ledger.settle(self.order["id"], FixtureProvider(refunded))["status"], "refunded")
        with self.assertRaises(ValueError): self.ledger.settle(self.order["id"], FixtureProvider(self.receipt))
        self.assertEqual(self.ledger.restore("account-a"), [])
        second = self.ledger.create_order("account-b", "night", "click-2")
        reused = self.receipt | {"order_id": second["id"], "account_id": "account-b"}
        with self.assertRaises(sqlite3.IntegrityError): self.ledger.settle(second["id"], FixtureProvider(reused))


if __name__ == "__main__": unittest.main()
