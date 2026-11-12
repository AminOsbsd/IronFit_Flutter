import smtplib, ssl
from email.message import EmailMessage

env = {}
for line in open(".env", encoding="utf-8"):
    line = line.strip()
    if line and not line.startswith("#") and "=" in line:
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip()

user = env["spring.mail.username"]
pwd = env["spring.mail.password"].replace(" ", "")

msg = EmailMessage()
msg["From"] = user
msg["To"] = "hazemmah3@gmail.com"
msg["Subject"] = "Test IronFit SMTP"
msg.set_content("Si vous lisez ceci, le SMTP Gmail fonctionne.")

with smtplib.SMTP("smtp.gmail.com", 587, timeout=20) as s:
    s.starttls(context=ssl.create_default_context())
    s.login(user, pwd)
    s.send_message(msg)
print("OK : mail envoye")