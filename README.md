👥 Team Structure & Responsibilities

To ensure balanced workload and efficient collaboration, the project is divided into four functional teams:

🔧 Core Script Development (3 members)

Responsible for building the main health-audit script.

Tasks include:

Collecting system metrics (CPU, memory, disk usage) Implementing threshold logic (OK, WARNING, CRITICAL) Structuring the core script for modular use Ensuring accuracy and reliability of checks

📊 Reporting & Logging (2 members)

Responsible for how results are presented and stored.

Tasks include:

Creating human-readable output Generating machine-readable output (e.g., JSON) Implementing logging to file with timestamps Ensuring output format is consistent and clear

⚙️ Automation & Monitoring (2 members)

Responsible for making the script run automatically and integrating monitoring.

Tasks include:

Setting up scheduled execution (e.g., cron jobs) Testing automated runs (Optional) Exposing metrics for integration with Prometheus Ensuring reliability in repeated executions

Important: use `health-audit-files/install-systemd.sh` to install the systemd units for your local checkout. Do not copy the unit files by hand, because the installer creates portable launcher scripts that point to the correct repo path on each machine.

📝 Documentation & AWS Memo (3 members)

Responsible for documentation and cloud-related explanations.

Tasks include:

Writing and maintaining project documentation Creating a clear setup and usage guide Drafting the AWS memo explaining how the solution applies to Amazon EC2 Explaining how this complements monitoring tools like Amazon CloudWatch 🤝 Collaboration Guidelines Each member must actively contribute within their assigned team Work should be done using feature branches (no direct commits to main)

All changes must go through pull requests and review before merging. Teams should communicate progress and blockers regularly
