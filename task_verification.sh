#!/bin/bash
set -e
export MSYS_NO_PATHCONV=1 # Only for Windows Git Bash

# === Full log capture ===
LOG_FILE="full_task_log.txt"
echo "📝 Logging all output to $LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

IMAGE_NAME=task-verification
CONTAINER_NAME=task-runner
WORKSPACE_DIR=$(pwd)

# 🧹 Clean up any existing container
docker rm -f $CONTAINER_NAME 2>/dev/null || true

echo "🔧 Building Docker image..."
docker build -t $IMAGE_NAME .

echo "🚀 Starting persistent container..."
docker run -dit \
  --name $CONTAINER_NAME \
  --entrypoint /bin/bash \
  -v "$WORKSPACE_DIR:/workspace" \
  $IMAGE_NAME -c "while true; do sleep 60; done"

echo "📦 Running build.sh inside container..."
docker exec $CONTAINER_NAME /bin/bash -c "chmod +x /workspace/build.sh && /workspace/build.sh"

###############################################
# 🧪 1. Run all tests
###############################################
echo "🧪 Running all tests..."
docker exec $CONTAINER_NAME /bin/bash -c "/workspace/run.sh > /workspace/stdout.txt 2> /workspace/stderr.txt"

echo "📊 Parsing results for all tests..."
docker exec $CONTAINER_NAME python3 /workspace/parsing.py \
  /workspace/stdout.txt /workspace/stderr.txt /workspace/test_results.json

echo "📤 Copying test_results.json to host..."
docker cp "$CONTAINER_NAME:/workspace/test_results.json" ./test_results.json

###############################################
# 🧪 2. Run selected tests
###############################################

TEST_ARGS=$1
if [ -z "$TEST_ARGS" ]; then
  echo "❌ You must provide test names as a comma-separated string."
  echo "Usage: ./verify.sh tests/test_file.py::TestClass::test_func,tests/test_other.py::test_simple"
  docker rm -f "$CONTAINER_NAME"
  exit 1
fi

echo "🧪 Running selected tests inside container with args: $TEST_ARGS"
docker exec $CONTAINER_NAME /bin/bash -c "/workspace/run.sh '$TEST_ARGS' > /workspace/stdout_selected.txt 2> /workspace/stderr_selected.txt"

echo "📊 Parsing results for selected tests..."
docker exec $CONTAINER_NAME python3 /workspace/parsing.py \
  /workspace/stdout_selected.txt /workspace/stderr_selected.txt /workspace/test_results_selected_tests.json

echo "📤 Copying test_results_selected_tests.json to host..."
docker cp "$CONTAINER_NAME:/workspace/test_results_selected_tests.json" ./test_results_selected_tests.json

echo "🧹 Cleaning up container..."
docker rm -f "$CONTAINER_NAME"

###############################################
# ✅ Validate both test results files
###############################################

validate_json() {
  FILE=$1
  echo "🔍 Validating format of $FILE..."
  python3 - "$FILE" <<'EOF'
import sys, json, io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

file_path = sys.argv[1]

try:
    with open(file_path, encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data.get("tests"), list):
        raise ValueError("Missing or invalid 'tests' array")

    allowed_statuses = {"PASSED", "FAILED", "SKIPPED", "ERROR"}
    for test in data["tests"]:
        if not isinstance(test, dict):
            raise ValueError("Each test entry must be a JSON object")
        if "name" not in test or "status" not in test:
            raise ValueError("Each test must have 'name' and 'status' keys")
        if not isinstance(test["name"], str):
            raise ValueError("Test 'name' must be a string")
        if "::" not in test["name"]:
            raise ValueError("Test 'name' must include file and test case (e.g., file.py::Class::method)")
        if test["status"] not in allowed_statuses:
            raise ValueError(f"Invalid status: {test['status']}")

    print(f"✅ {file_path} is valid and well-formed!")

except Exception as e:
    print(f"❌ Invalid {file_path} format: {e}")
    sys.exit(1)
EOF
}


for f in test_results.json test_results_selected_tests.json; do
  if [ ! -f $f ]; then
    echo "❌ $f not found."
    exit 1
  fi

  if [ ! -s $f ]; then
    echo "❌ $f is empty."
    exit 1
  fi

  validate_json $f
done
