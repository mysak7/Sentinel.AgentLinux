import os
import json
import socket
import select
import subprocess
import time
import sys
import fcntl
import signal
from datetime import datetime
from dotenv import load_dotenv
from confluent_kafka import Producer

# Load environment variables
load_dotenv(dotenv_path=".env")

def get_linux_distro():
    """Reads /etc/os-release to identify the Linux distribution."""
    try:
        # Check both standard locations
        for path in ["/etc/os-release", "/usr/lib/os-release"]:
            if os.path.exists(path):
                with open(path) as f:
                    data = {}
                    for line in f:
                        if "=" in line:
                            k, v = line.strip().split("=", 1)
                            data[k] = v.strip('"')
                    return data.get("PRETTY_NAME") or data.get("NAME") or "Linux"
    except Exception:
        pass
    return "Linux"

# Configuration
KAFKA_TOPIC = "threats"
HOSTNAME = socket.gethostname()
LINUX_DISTRO = get_linux_distro()
# Debian/Ubuntu defaults. Change to /var/log/secure and /var/log/messages for RHEL/CentOS.
# Modern systems with systemd-journald might not have these enabled by default.
# Fallback to journal/dpkg/alternatives if standard syslog files are missing.
LOG_FILES = [
    "/var/log/auth.log",
    "/var/log/syslog",
    "/var/log/kern.log",
    "/var/log/dpkg.log",        # Added: Package management logs
    "/var/log/alternatives.log" # Added: Update alternatives logs
]

def get_kafka_config():
    """Maps .env variables to confluent-kafka configuration dict."""
    return {
        'bootstrap.servers': os.getenv('BOOTSTRAP_SERVER'),
        'security.protocol': 'SASL_SSL',
        'sasl.mechanism': 'PLAIN',
        'sasl.username': os.getenv('PRODUCER_API_KEY'),
        'sasl.password': os.getenv('PRODUCER_API_SECRET'),
        'client.id': f'linux-agent-{HOSTNAME}',
    }

def delivery_report(err, msg):
    """Optional callback for delivery success/failure."""
    if err is not None:
        print(f"Message delivery failed: {err}")

def tail_logs(files):
    """
    Tails multiple files using subprocess and monitors them via select.
    Yields tuple: (source_filename, log_line)
    """
    poll_obj = select.poll()
    file_map = {}
    
    # Check if we're on a systemd system without rsyslog
    has_journalctl = False
    try:
        subprocess.check_call(['which', 'journalctl'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        has_journalctl = True
    except subprocess.CalledProcessError:
        pass

    # Start a tail subprocess for each file
    for filepath in files:
        if not os.path.exists(filepath):
            print(f"Warning: {filepath} not found. Skipping.")
            continue
            
        # -F handles log rotation (file rename/creation)
        proc = subprocess.Popen(
            ['tail', '-F', '-n', '0', filepath],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        poll_obj.register(proc.stdout, select.POLLIN)
        file_map[proc.stdout.fileno()] = (filepath, proc.stdout)
        print(f"Monitoring {filepath}...")
    
    # If no files were found and we have journalctl, try monitoring journal
    if not file_map and has_journalctl:
        pass # User requested to remove journalctl fallback

    while True:
        # Poll for new data (timeout 1000ms)
        events = poll_obj.poll(1000)
        for fd, event in events:
            source, pipe = file_map[fd]
            line = pipe.readline().decode('utf-8').strip()
            if line:
                yield source, line

def main():
    # Singleton pattern: Ensure only one instance runs
    pid_file = '/tmp/sentinel_agent.pid'
    fp = open(pid_file, 'w')
    try:
        fcntl.lockf(fp, fcntl.LOCK_EX | fcntl.LOCK_NB)
        fp.write(str(os.getpid()))
        fp.flush()
    except IOError:
        print("Another instance of the agent is already running. Exiting.")
        sys.exit(1)

    # Handle SIGTERM for systemd service shutdown
    def signal_handler(sig, frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, signal_handler)

    try:
        producer = Producer(get_kafka_config())
        print(f"Agent started on {HOSTNAME}. Sending to {KAFKA_TOPIC}...")
        
        current_pid = str(os.getpid())
        for source, line in tail_logs(LOG_FILES):
            if f"[{current_pid}]" in line:
                continue

            payload = {
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "hostname": HOSTNAME,
                "ProviderName": "Linux",
                "Distro": LINUX_DISTRO,
                "log_source": source,
                "message": line
            }
            
            # Asynchronous produce
            json_payload = json.dumps(payload)
            print(f"Sending to {KAFKA_TOPIC}: {json_payload}")
            producer.produce(
                KAFKA_TOPIC,
                key=HOSTNAME,
                value=json_payload,
                on_delivery=delivery_report
            )
            # Serve delivery callback queue occasionally
            producer.poll(0)

    except KeyboardInterrupt:
        print("Stopping agent...")
    finally:
        # Check if producer was initialized before flushing
        if 'producer' in locals():
            producer.flush()

if __name__ == "__main__":
    main()
