from flask import Flask, render_template, request
import subprocess
import socket

app = Flask(__name__)


@app.route("/")
def index():
    return render_template(
        "index.html",
        hostname=socket.gethostname()
    )


@app.route("/diagnostics", methods=["GET", "POST"])
def diagnostics():
    result = None
    target = ""

    if request.method == "POST":
        target = request.form.get("target", "").strip()

        if target:
            # INTENTIONALLY VULNERABLE
            #
            # This application is part of the Enterprise Pivot Lab.
            # User-controlled input is passed directly to a shell command
            # so the lab can demonstrate command injection.
            command = f"ping -c 2 {target}"

            try:
                result = subprocess.check_output(
                    command,
                    shell=True,
                    stderr=subprocess.STDOUT,
                    text=True,
                    timeout=10
                )
            except subprocess.CalledProcessError as exc:
                result = exc.output
            except subprocess.TimeoutExpired:
                result = "Diagnostic timed out."

    return render_template(
        "diagnostics.html",
        target=target,
        result=result
    )


@app.route("/health")
def health():
    return {
        "status": "ok",
        "service": "opscheck",
        "version": "1.0.3"
    }


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
