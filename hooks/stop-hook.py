#!/usr/bin/env python3
import json
import sys
import subprocess

def main():
    input_text = sys.stdin.read()
    try:
        input_data = json.loads(input_text)
    except:
        return
    
    if input_data.get('hook_event_name') == 'Stop':
        try:
            result = subprocess.run(
                ['python3', 'portable-quality-validator.py'],
                input=input_text,
                capture_output=True,
                text=True
            )
            if result.stdout:
                print(result.stdout.strip())
        except:
            pass

if __name__ == '__main__':
    main()