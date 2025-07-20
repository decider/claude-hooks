#!/usr/bin/env python3
"""Argument parser for Claude Hooks CLI."""

import argparse


def create_parser():
    """Create the argument parser."""
    parser = argparse.ArgumentParser(
        description='Claude Hooks CLI - Introspection and management tool',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    subparsers = parser.add_subparsers(dest='command', required=True)
    
    # List command
    _add_list_parser(subparsers)
    
    # Explain command
    _add_explain_parser(subparsers)
    
    # Validate command
    _add_validate_parser(subparsers)
    
    return parser


def _add_list_parser(subparsers):
    """Add the list command parser."""
    list_parser = subparsers.add_parser(
        'list', 
        help='List all hooks in the repository'
    )
    list_parser.add_argument(
        '--json', 
        action='store_true', 
        help='Output as JSON'
    )
    list_parser.add_argument(
        '-v', '--verbose', 
        action='store_true', 
        help='Show detailed information'
    )


def _add_explain_parser(subparsers):
    """Add the explain command parser."""
    explain_parser = subparsers.add_parser(
        'explain', 
        help='Show effective hooks for a file'
    )
    explain_parser.add_argument('file', help='File path to explain')
    explain_parser.add_argument(
        '-v', '--verbose', 
        action='store_true', 
        help='Show detailed information'
    )


def _add_validate_parser(subparsers):
    """Add the validate command parser."""
    validate_parser = subparsers.add_parser(
        'validate', 
        help='Validate all configuration files'
    )