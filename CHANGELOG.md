# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-01-XX

### Added
- Initial release of cellcast-sms gem
- SMS sending functionality (single and bulk messages)
- Sender ID management (business names and custom numbers)
- Webhook configuration and management
- Token verification and usage tracking
- Comprehensive error handling
- Ruby 3.3+ support with minimal dependencies
- Following Sandi Metz rules for clean object-oriented design

### Features
- Send individual SMS messages
- Send bulk SMS messages
- Check message status and delivery reports
- List sent messages with filtering
- Register and verify business name sender IDs
- Register and verify custom number sender IDs
- Configure webhooks for event notifications
- Test webhook configurations
- Verify API tokens and get usage statistics
- Detailed error handling with specific exception classes