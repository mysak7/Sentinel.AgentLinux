[SERVICE]
    Flush        5
    Daemon       Off
    Log_Level    info

[INPUT]
    Name         tail
    Path         /var/log/syslog
    Tag          linux.sysmon

[OUTPUT]
    Name        kafka
    Match       *
    Brokers     {{BROKER_URL}}
    Topics      linux-logs
    Timestamp_Key @timestamp
    Retry_Limit 5
    rdkafka.security.protocol SASL_SSL
    rdkafka.sasl.mechanism    PLAIN
    rdkafka.sasl.username     {{KAFKA_USER}}
    rdkafka.sasl.password     {{KAFKA_PASS}}
