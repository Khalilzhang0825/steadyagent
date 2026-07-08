# Security Policy

SteadyAgent is a workflow harness, not a security product. Its hooks and scripts reduce common local workflow mistakes, but they cannot guarantee complete secret detection or command safety.

## Supported Versions

The current public v1 line is the only supported release line.

## Reporting A Security Issue

Do not open a public issue with exploit details, private tokens, credentials, or sensitive local paths. Use a private reporting channel if one is available on the repository, or contact the maintainer through the GitHub profile.

## Scope

Useful reports include:

- guardrail hooks that fail to block a documented dangerous action
- scripts that can accidentally stage or publish private files
- documentation that encourages unsafe setup
- examples that include secrets, credentials, or private machine paths

Out of scope:

- model jailbreaks unrelated to this repository
- requests for guaranteed secret detection
- attacks that require a malicious local user with full filesystem access

## Local Safety Boundary

Always review generated install plans before applying them. SteadyAgent defaults to dry-run installation and refuses to overwrite existing targets unless `-Overwrite` is explicitly passed.
