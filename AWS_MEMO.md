# Linux Server Health Auditor — AWS Memo

## Introduction

The Linux Server Health Auditor is a Bash script that monitors the health of a Linux server by checking three critical system metrics — CPU usage, memory usage and disk usage. It reads data directly from the Linux kernel files `/proc/stat` and `/proc/meminfo` and uses the `df` command for disk. Results are output in JSON format with timestamps and categorised into three status levels: **OK, WARNING, and CRITICAL.**

This memo explains how this tool would be deployed and integrated with AWS services when running on EC2 instances in a cloud environment.

---

## 1. Running the Script on EC2

On AWS, the health audit script runs on **EC2 instances** hosted inside a **private subnet within a VPC (Virtual Private Cloud).** A private subnet means the instances are not directly exposed to the internet, which improves security.

Multiple EC2 instances are grouped inside an **Auto Scaling Group.** This means AWS can automatically add or remove instances based on demand. Every instance runs the same `audit.sh` script on a cron schedule and has the **CloudWatch Agent** installed to ship metrics to AWS monitoring services.

For on-demand audit runs without needing SSH access, **AWS Systems Manager (SSM)** is used. SSM can send a Run Command to any instance in the group to trigger the audit script immediately.

The script reads thresholds from a `threshold.env` configuration file. In an AWS environment this config file would be stored in **AWS Systems Manager Parameter Store**; a secure central location for configuration values accessible by all instances.

---

## 2. Monitoring Flow

Once the script runs on an EC2 instance it produces a JSON report. This is what happens to that report on AWS:

**Step 1. CloudWatch Logs**
The JSON audit report is shipped to **CloudWatch Logs** which stores all audit reports centrally. Every instance sends its report here so you have one place to view results from all servers.

**Step 2. CloudWatch Metrics**
The CPU, memory and disk numbers from the script are published to **CloudWatch Metrics.** This allows AWS to track these values over time and display them as graphs.

**Step 3. CloudWatch Alarms**
CloudWatch Alarms monitor the metric values against the thresholds defined in the script. This maps directly to our two threshold levels:

- When a value crosses the **WARNING threshold** → Alarm enters warning state
- When a value crosses the **CRITICAL threshold** → Alarm enters alarm state and triggers an alert

---

## 3. Alerting

When CloudWatch Alarm detects a **CRITICAL** status it publishes a notification to **Amazon SNS (Simple Notification Service).** SNS then immediately notifies the on-call engineer via:

- Email
- SMS
- Pager

This means no one needs to manually check logs. The system automatically pages the right person the moment something goes wrong — exactly replicating what our script's CRITICAL status detection does locally.

---

## 4. Backup and Disaster Recovery

The backup script (`backup.sh`) creates compressed archives of audit logs and configuration files. On AWS these archives are sent to an **S3 Bucket** for storage. S3 provides:

- Virtually unlimited storage
- 99.999999999% durability
- Easy retrieval for the restore script

For deeper disaster recovery, **AWS Backup** takes automatic **EBS (Elastic Block Store)** snapshots of the EC2 instances. This means if an instance is completely lost, it can be fully restored from a snapshot including all scripts, logs and configuration.

---

## 5. How Our 3 Checks Map to AWS Services

| Script Check | How It Works Locally | AWS Equivalent |
|---|---|---|
| CPU | Reads `/proc/stat` | CloudWatch Agent + CloudWatch Metrics |
| Memory | Reads `/proc/meminfo` | CloudWatch Agent custom metric |
| Disk | Reads `df /` command | CloudWatch Agent custom metric |
| WARNING threshold | Script status level | CloudWatch Alarm warning state |
| CRITICAL threshold | Script status level | CloudWatch Alarm + SNS alert |
| JSON log output | Saved to local file | Shipped to CloudWatch Logs |
| `backup.sh` archives | Saved locally | Stored in S3 Bucket |
| Full server recovery | Manual restore | AWS Backup EBS snapshots |

---

## 6. Conclusion

Running the Linux Health Auditor on AWS transforms it from a single server tool into an enterprise-grade monitoring system. The core logic of the script remains the same — check CPU, memory and disk against thresholds and report status. But AWS adds:

- **Scale**: monitor dozens of EC2 instances from one dashboard
- **Automation**: alerts fire automatically without anyone checking logs
- **Reliability**: S3 and AWS Backup ensure no data is ever lost
- **Security**: private subnet VPC keeps instances protected

The same script, the same checks, the same thresholds, just supercharged by AWS managed services.

---

## Reference
See AWS Architecture Diagram in the project repository.

---

*Prepared by: Rosemary Edem*

*Team: Documentation & AWS Memo*

*Project: Linux Server Health Auditor*

*DevOps SCA Learning Group*
