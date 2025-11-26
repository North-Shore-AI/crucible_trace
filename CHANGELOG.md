# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2025-11-25

### Added
- **Chain Comparison & Diffing** - Compare two reasoning chains to identify differences
  - `CrucibleTrace.diff_chains/3` - Compare chains and generate diff structure
  - `CrucibleTrace.diff_to_text/1` - Export diff as human-readable text
  - `CrucibleTrace.diff_to_html/3` - Generate HTML visualization of chain differences
  - Similarity scoring to quantify how similar two chains are
  - Confidence delta tracking to see how confidence changes between versions
  - Side-by-side comparison in HTML viewer
- **Mermaid Diagram Export** - Export chains as Mermaid diagrams for documentation
  - `CrucibleTrace.export_mermaid/3` - Export to flowchart, sequence, timeline, or graph formats
  - `CrucibleTrace.Mermaid` module with specialized formatters
  - Color-coding by event type
  - Optional confidence level display
  - Label truncation for readability
  - Integration with Storage.export/3 for unified export API
- **New Example Scripts**
  - `examples/chain_comparison.exs` - Demonstrates diff functionality with A/B testing scenarios
  - `examples/mermaid_export.exs` - Shows all Mermaid export formats with documentation integration
- **Documentation Enhancements**
  - Comprehensive design document in `docs/20251125/enhancement_design.md`
  - Updated API documentation for all new functions
  - Examples of GitHub/GitLab compatible diagram embedding

### Changed
- Extended `Storage.export/3` to support Mermaid formats (`:mermaid_flowchart`, `:mermaid_sequence`, `:mermaid_timeline`, `:mermaid_graph`)
- Updated README with new feature descriptions and examples
- Enhanced main module documentation with diff and Mermaid examples

### Technical Details
- New modules: `CrucibleTrace.Diff` and `CrucibleTrace.Mermaid`
- Comprehensive test suites for new functionality (30+ new tests)
- All new features are backward compatible with v0.1.0
- Zero breaking changes - purely additive enhancements

## [0.1.0] - 2025-10-07

### Added
- Initial release
- Structured causal reasoning chain logging for LLM code generation
- Event tracking with six event types (hypothesis_formed, alternative_rejected, constraint_evaluated, pattern_applied, ambiguity_flagged, confidence_updated)
- LLM integration with XML-based event parsing
- Chain management for organizing reasoning events
- Persistent storage with JSON format and search capabilities
- Interactive HTML visualization with filtering and statistics
- Analysis tools for querying events, calculating statistics, and finding decision points
- Multiple export formats (JSON, Markdown, CSV)

### Documentation
- Comprehensive README with examples
- API documentation for all modules
- Usage examples for LLM integration and debugging
- Best practices for transparency in AI code generation
