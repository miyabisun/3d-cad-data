# Contributing Guide

This document outlines the contribution guidelines and coding standards for this project.

## Coding Style

To maintain a consistent codebase, we adhere to the following styling rules. An automated formatting process is set up to enforce these rules.

### Indentation

- **Indent Style**: space
- **Indent Size**: 2 spaces

This is configured in the `.editorconfig` file and should be respected by your editor.

### Formatting

- **OpenSCAD Files (`.scad`)**:
  - All `.scad` files are formatted using `openscad-format`.
  - This is automatically enforced by a `pre-commit` hook using `husky` and `lint-staged`. There is no need to run the formatter manually.

- **Other Files**:
  - Other text-based files (like `.js`, `.json`, `.md`) should be formatted using Prettier, according to the `.prettierrc` configuration.
