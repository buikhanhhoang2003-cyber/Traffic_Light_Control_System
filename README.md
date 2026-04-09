# Traffic_Light_Control_System

## Overview

This repository contains a traffic light control system design targeting FPGA implementation. The design appears to use a modular Verilog-based approach with separate controllers for timing, input handling, and state management.

## Contents

- `docs/` - design documentation and requirement analysis.
- `script/` - Verilog modules and top-level integration files.
- `output/` - generated Quartus project files, synthesis outputs, and board database files.
- `pin_assign/` - pin assignment file for FPGA constraints.

## Key Files

- `script/traffic_light_top.v` - top-level Verilog integration module.
- `script/clk_div.v` - clock divider module.
- `script/conflict_monitor.v` - conflict detection logic.
- `script/direction_sm.v` - direction state machine module.
- `docs/Part-1-Requirement-Analysis.md` - requirements and design goals.

## Usage

1. Open the Quartus project or use the provided scripts in `output/`.
2. Review the documentation in `docs/` for design behavior and testing.
3. Modify source files in `script/` as needed and rerun synthesis/place-and-route.

## Notes

This repository contains generated Quartus database files in `output/` and `output/board/`. Those files are typically not modified manually.
