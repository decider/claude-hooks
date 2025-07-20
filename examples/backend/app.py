# Example backend file to demonstrate hook functionality

def process_user_data(user_id: int, data: dict) -> dict:
    """Process user data with validation."""
    if not user_id or user_id < 0:
        raise ValueError("Invalid user ID")
    
    # This would trigger hooks when edited
    result = {
        "user_id": user_id,
        "processed": True,
        "data": data
    }
    
    return result