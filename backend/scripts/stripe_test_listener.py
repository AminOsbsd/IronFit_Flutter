"""Local Sandbox listener. Reads backend/.env and redacts signing secrets from output."""
import os, pathlib, re, subprocess
root = pathlib.Path(__file__).resolve().parents[1]
config = dict(line.split("=", 1) for line in (root / ".env").read_text(encoding="utf-8").splitlines() if "=" in line and not line.startswith("#"))
env = os.environ.copy()
env["STRIPE_API_KEY"] = config["STRIPE_SECRET_KEY"].strip()
if not env["STRIPE_API_KEY"].startswith("sk_test_"):
    raise SystemExit("Sandbox key required")
cli = pathlib.Path(os.environ["LOCALAPPDATA"]) / "Microsoft/WinGet/Links/stripe.exe"
process = subprocess.Popen([str(cli), "listen", "--events", "checkout.session.completed,checkout.session.async_payment_succeeded,checkout.session.async_payment_failed,checkout.session.expired,invoice.paid,invoice.payment_failed,customer.subscription.updated,customer.subscription.deleted", "--forward-to", "http://localhost:8080/api/payments/stripe/webhook"], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
for line in process.stdout:
    print(re.sub(r"(?:whsec_|sk_test_|rk_test_)[A-Za-z0-9]+", "[REDACTED]", line), end="", flush=True)
raise SystemExit(process.wait())
