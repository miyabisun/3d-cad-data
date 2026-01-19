# 3D CAD Data (OpenSCAD Projects)

This repository contains parametric 3D CAD models designed using [OpenSCAD](https://openscad.org/).

## Prerequisites

To build and edit these projects, you need the following tools installed on your system:

- **[OpenSCAD](https://openscad.org/downloads.html)**: The core 3D modeling tool. Ensure the `openscad` command is available in your PATH.
- **Node.js**: Required to run the file watcher script (`bin/watch`).
- **Bash**: Required to run the build shell scripts.

## Directory Structure

- **`projects/`**: Source `.scad` files organized by project and size (e.g., `projects/steel-rack/500x400/`).
- **`modules/`**: Shared OpenSCAD modules/libraries (e.g., `bolts.scad`).
- **`dist/`**: Generated `.stl` files. This directory mirrors the structure of `projects/`.
- **`bin/`**: Helper scripts for building and watching files.

## Usage

### 1. Rendering (Build)

To generate STL files for all projects at once, run:

```bash
./bin/render
```

This script scans the `projects/` directory and outputs corresponding STL files to the `dist/` directory.

### 2. Watch Mode (Development)

For a better development experience, use the watch script. It monitors files for changes and automatically re-renders them.

```bash
./bin/watch
```

**Behavior:**
- **Project File Change**: If you edit a file in `projects/`, only that specific file is re-rendered.
- **Module File Change**: If you edit a file in `modules/`, **ALL** project files are re-rendered to ensure the changes are propagated correctly.

## Coding Style

- Indentation: 2 spaces
- Format: Prettier (configured via `.prettierrc` for JavaScript files)
