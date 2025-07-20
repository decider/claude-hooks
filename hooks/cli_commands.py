#!/usr/bin/env python3
"""Command implementations for Claude Hooks CLI."""

import json
import os
from pathlib import Path
from typing import List, Dict, Any

from config_loader import HierarchicalConfigLoader
from cli_utils import Colors, print_warning, print_success, print_error
from hook_validator import validate_config_file, find_all_config_files


def cmd_validate(args):
    """Validate all configuration files."""
    loader = HierarchicalConfigLoader()
    root = Path(loader.project_root)
    config_files = find_all_config_files(root)
    
    if not config_files:
        print_warning("No configuration files found")
        return 1
    
    print(f"\n{Colors.BOLD}Validating hook configurations...{Colors.ENDC}\n")
    
    # Collect all errors and warnings
    all_errors, all_warnings = _validate_all_configs(config_files, root)
    
    print()
    
    # Report results
    _display_validation_results(all_errors, all_warnings)
    
    return 1 if all_errors else 0


def _validate_all_configs(config_files: List[Path], root: Path):
    """Validate all configuration files and collect results."""
    all_errors = []
    all_warnings = []
    
    for config_path in config_files:
        errors, warnings = validate_config_file(config_path, root)
        
        rel_path = config_path.relative_to(root)
        
        if errors:
            print(f"  {Colors.FAIL}✗{Colors.ENDC} {rel_path}")
            all_errors.extend(errors)
        else:
            print(f"  {Colors.GREEN}✓{Colors.ENDC} {rel_path}")
        
        all_warnings.extend(warnings)
    
    return all_errors, all_warnings


def _display_validation_results(errors: List[str], warnings: List[str]):
    """Display validation results."""
    if errors:
        print(f"{Colors.FAIL}Errors found:{Colors.ENDC}")
        for error in errors:
            print(f"  • {error}")
        print()
    
    if warnings:
        print(f"{Colors.WARNING}Warnings:{Colors.ENDC}")
        for warning in warnings:
            print(f"  • {warning}")
        print()
    
    if not errors and not warnings:
        print_success("All configurations are valid!")