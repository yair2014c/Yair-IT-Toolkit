# Security

Thank you for reviewing Yair IT Toolkit. Security is important: this tool performs system-level changes and may reveal sensitive information if run on production machines without review.

Reporting a vulnerability
- If you find a security issue, please open a private issue if the repository is public, or email the project maintainer (use the GitHub contact shown on the profile) with details and an optional PoC.
- Do not post exploit details publicly before a fix is available.

Before making repository public
- Remove secrets from code and git history (API tokens, certificates, private keys).
- Use `git-secrets`, `truffleHog`, or `git-filter-repo` to scan and clean history if needed.

Runtime security notes
- The toolkit elevates to Administrator for many operations. Verify scripts (especially those that call `Remove-Item`, `Add-AppxPackage`, `dism.exe`, or `Checkpoint-Computer`) before running on production.
- Use Simulation Mode (`[S]`) to preview destructive operations.
