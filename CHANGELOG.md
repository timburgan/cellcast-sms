# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2025-08-12

### Added
- Message lifecycle control methods: `mark_message_read`, `mark_messages_read`, `mark_all_read`
- Comprehensive test coverage for edge cases and error scenarios
- Live API diagnostic tools (`examples/diagnose_cellcast.rb`, `examples/enhanced_diagnostics.rb`)
- API documentation and migration guides

### Fixed
- **Critical**: Response parsing now correctly reads `data.responses` instead of `data.messages`
- Enhanced date parsing to handle multiple formats (`2025/08/12`, `2025-08-12`)
- Null safety for malformed API responses
- Empty array handling in convenience methods

### Improved
- Message field mapping with robust fallbacks
- Error handling and graceful degradation
- Documentation with clear API behavior explanations

## [0.1.0] - 2025-08-06

### Added
- Initial release of cellcast-sms gem