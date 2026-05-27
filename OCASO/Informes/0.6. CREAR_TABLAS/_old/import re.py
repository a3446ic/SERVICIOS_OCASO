import re

def find_test_strings_from_file(file_path):
    with open(file_path, 'r') as file:
        text = file.read()
    
    # Use regex to find words containing "test" (case-insensitive)
    pattern = r'\b[\w\.]*test[\w\.]*\b'
    matches = re.findall(pattern, text, re.IGNORECASE)
    return matches

# Example usage
file_path = 'crear.txt'  # Replace with your actual file name
result = find_test_strings_from_file(file_path)

print(result)
