#!/bin/bash

####################################
# Combine TypeScript Files

# Variable to store the combined content of all .ts and .tsx files
PROJECT_FILES=""
# Function to process each file
process_file() {
    local file="$1"
    local relative_path="${file#./}"
    
    # Add a comment with the file's relative path
    PROJECT_FILES+="// File: $relative_path\n"
    
    # Add the file's content to the combined_content variable
    PROJECT_FILES+="$(cat "$file")\n\n"
}

# Find all .ts and .tsx files in the current directory and its subdirectories
while IFS= read -r -d $'\0' file; do
    process_file "$file"
done < <(find ./app -type f \( -name "*.ts" -o -name "*.tsx" \) -print0)

####################################
# OpenAI API Request

# File path where the results will be saved
ORIGINAL_OUTPUT_FILE="$1"

# Command to be sent to the OpenAI API, including additional context
COMMAND="$2"

# Replace YOUR_API_KEY with your actual OpenAI API key
API_KEY="{{OPEN_API_KEY}}"

# The OpenAI endpoint you want to hit, e.g., for completions
ENDPOINT="https://api.openai.com/v1/completions"

# Prefix the output file path with ./app/routes/
mkdir -p "./app/routes/${ORIGINAL_OUTPUT_FILE}"
OUTPUT_FILE="./app/routes/${ORIGINAL_OUTPUT_FILE}/route.tsx"

# Function to escape special characters for JSON strings and compact to one line
escape_json() {
  local string=$1
  # Escape backslashes, double quotes, control characters
  # Replace newlines with \n, then remove all leading/trailing whitespace globally
  echo "$string" | sed -e ':a' -e 'N' -e '$!ba' -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/\\t/g' -e 's/\r/\\r/g' -e 's/\n/\\n/g' -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g'
}

# Escape the project files and command before using them in the prompt
escaped_project_files=$(escape_json "$PROJECT_FILES")
escaped_command=$(escape_json "$COMMAND")

# Construct the prompt with additional context and specific instructions
PROMPT="# We're working with a Remix Application ## You can see here: START_SRC_CODE $escaped_project_files END_SRC_CODE The output will be saved in a file named '${OUTPUT_FILE}'. Given that context, $escaped_command. Provide the response as code only."

# Using curl to make a request to the OpenAI API
curl -s -X POST $ENDPOINT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    --data '{
        "model": "gpt-4-turbo",
        "prompt": "'"$PROMPT"'",
        "temperature": 0.6,
        "max_tokens": 4000,
        "top_p": 1,
        "frequency_penalty": 0,
        "presence_penalty": 0
    }' | jq -r '.choices[0].text' > "$OUTPUT_FILE"

echo "Results saved to $OUTPUT_FILE"



#### I had to dish this to file and add the -d command to curl. 
#### I had exceeded curl's command input limit
#### It turned out that i was importing node modules which inflated the context
#### See: https://preview.redd.it/tfugj4n3l6ez.png?auto=webp&s=b8163176d8482d5e78ac631e16b7973a52e3b188
# echo '{
#         "model": "text-davinci-003",
#         "prompt": "'"$PROMPT"'",
#         "temperature": 0.5,
#         "max_tokens": 150,
#         "top_p": 1,
#         "frequency_penalty": 0,
#         "presence_penalty": 0
#     }' > requestData.txt

# -d @requestData.txt \
