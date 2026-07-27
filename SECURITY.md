# Security Policy

## Overview

The CubeNet AI Squad project takes security and stability seriously. As a system that interacts with server memory, player data, and filesystem persistence, maintaining a secure environment is paramount to ensuring a fair and stable experience for all users.

This document outlines our policy for reporting vulnerabilities and the process we follow to address them.

## Reporting a Vulnerability

**Please do not report security vulnerabilities via public GitHub Issues.** 

To protect the users of this software and prevent the exploitation of bugs before a patch is available, we request that you report security flaws privately.

### How to Report
Please send a detailed report to the project maintainer via the designated private contact channel. Your report should include:

1. **Description:** A clear explanation of the vulnerability.
2. **Impact:** What an attacker could achieve (e.g., unauthorized data access, server crash, privilege escalation).
3. **Steps to Reproduce:** A minimal, step-by-step guide or a Proof of Concept (PoC) to trigger the flaw.
4. **Suggested Fix:** If you have identified a solution, we welcome your suggestions for the patch.

## Scope

This policy applies to all components of the CubeNet AI Squad ecosystem, including:
- The Core Plugin (`cubenet_ai_core.sp`)
- The AFK and Voice modules
- SQLite database interactions and data persistence logic
- Configuration file parsing and administrative command handling

## Our Process

Once a report is received, we follow these steps:

1. **Acknowledgment:** We will acknowledge receipt of your report within 3–5 business days.
2. **Triage & Validation:** Our team will investigate the report to determine the severity and validity of the flaw.
3. **Remediation:** A patch will be developed and tested to resolve the issue without introducing regressions.
4. **Disclosure:** Once the fix is deployed or a stable update is released, we may provide a public security advisory detailing the change.

## Recognition

We appreciate the efforts of security researchers who help us keep the project safe. Depending on the severity of the vulnerability and the quality of the report, contributors may be credited in our `CONTQIBUTORSlist or release notes upon mutual agreement.
