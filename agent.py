import os
import json
import socket
import select
import subprocess
import time
from datetime import datetime
from dotenv import load_dotenv
from confluent_kafka import Producer

# Load environment variables
load_dotenv(dotenv_path=".env")

# Configuration
KAFKA_TOPIC = "threats"
HOSTNAME = socket.gethostname()
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
    
    # If no critical files were found and we have journalctl, try monitoring journal
    # This handles cases where minor logs (dpkg, alternatives) exist but main system logs don't
    CRITICAL_LOGS = ["/var/log/auth.log", "/var/log/syslog", "/var/log/kern.log"]
    monitored_paths = [v[0] for v in file_map.values()]
    critical_logs_found = any(f in monitored_paths for f in CRITICAL_LOGS)

    if has_journalctl and not critical_logs_found:
        print("Standard log files missing. Monitoring systemd journal...")
        # Monitor all journal entries (-f for follow, -o cat for plain text)
        proc = subprocess.Popen(
            ['journalctl', '-f', '-o', 'short-iso'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        poll_obj.register(proc.stdout, select.POLLIN)
        file_map[proc.stdout.fileno()] = ("journalctl", proc.stdout)

    while True:
        # Poll for new data (timeout 1000ms)
        events = poll_obj.poll(1000)
        for fd, event in events:
            source, pipe = file_map[fd]
            line = pipe.readline().decode('utf-8').strip()
            if line:
                yield source, line

def main():
    try:
        producer = Producer(get_kafka_config())
        print(f"Agent started on {HOSTNAME}. Sending to {KAFKA_TOPIC}...")
        
        for source, line in tail_logs(LOG_FILES):
            payload = {
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "hostname": HOSTNAME,
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
