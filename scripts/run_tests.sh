#!/bin/bash

# Test Runner Script for SignSync
# Runs all tests with coverage reporting

set -e

echo "========================================="
echo "  SignSync Test Suite"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse arguments
RUN_UNIT=true
RUN_WIDGET=true
RUN_INTEGRATION=false
RUN_ACCESSIBILITY=true
RUN_COVERAGE=true
WATCH=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --unit-only)
      RUN_WIDGET=false
      RUN_INTEGRATION=false
      RUN_ACCESSIBILITY=false
      shift
      ;;
    --widget-only)
      RUN_UNIT=false
      RUN_INTEGRATION=false
      RUN_ACCESSIBILITY=false
      shift
      ;;
    --integration)
      RUN_INTEGRATION=true
      shift
      ;;
    --no-coverage)
      RUN_COVERAGE=false
      shift
      ;;
    --watch)
      WATCH=true
      shift
      ;;
    --help)
      echo "Usage: ./run_tests.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --unit-only      Run only unit tests"
      echo "  --widget-only    Run only widget tests"
      echo "  --integration    Run integration tests"
      echo "  --no-coverage    Skip coverage report"
      echo "  --watch          Watch mode for development"
      echo "  --help           Show this help message"
      echo ""
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Clean previous coverage
if [ "$RUN_COVERAGE" = true ]; then
  echo -e "${YELLOW}Cleaning previous coverage data...${NC}"
  rm -rf coverage/
  mkdir -p coverage/
  echo ""
fi

# Function to run tests
run_tests() {
  local test_type=$1
  local test_path=$2
  local coverage_flag="--coverage"

  if [ "$RUN_COVERAGE" = false ]; then
    coverage_flag=""
  fi

  local watch_flag=""
  if [ "$WATCH" = true ]; then
    watch_flag="--watch"
  fi

  echo -e "${YELLOW}Running $test_type tests...${NC}"

  if flutter test $test_path $coverage_flag $watch_flag --reporter github; then
    echo -e "${GREEN}✓ $test_type tests passed${NC}"
    return 0
  else
    echo -e "${RED}✗ $test_type tests failed${NC}"
    return 1
  fi
}

# Track results
FAILED=0

# Run unit tests
if [ "$RUN_UNIT" = true ]; then
  echo "========================================="
  echo "  Unit Tests"
  echo "========================================="
  echo ""

  if ! run_tests "Unit" "test/"; then
    FAILED=1
  fi
  echo ""
fi

# Run widget tests
if [ "$RUN_WIDGET" = true ]; then
  echo "========================================="
  echo "  Widget Tests"
  echo "========================================="
  echo ""

  if ! run_tests "Widget" "test/widgets/"; then
    FAILED=1
  fi
  echo ""
fi

# Run integration tests
if [ "$RUN_INTEGRATION" = true ]; then
  echo "========================================="
  echo "  Integration Tests"
  echo "========================================="
  echo ""

  if ! run_tests "Integration" "integration_test/"; then
    FAILED=1
  fi
  echo ""
fi

# Run accessibility tests
if [ "$RUN_ACCESSIBILITY" = true ]; then
  echo "========================================="
  echo "  Accessibility Tests"
  echo "========================================="
  echo ""

  if ! run_tests "Accessibility" "test/accessibility/"; then
    FAILED=1
  fi
  echo ""
fi

# Generate coverage report
if [ "$RUN_COVERAGE" = true ] && [ "$FAILED" -eq 0 ]; then
  echo "========================================="
  echo "  Coverage Report"
  echo "========================================="
  echo ""

  echo -e "${YELLOW}Generating coverage report...${NC}"
  flutter pub global activate coverage_badge_generator
  coverage_badge_generator --input coverage/lcov.info --output coverage/coverage.svg

  flutter pub global activate test_cov_console
  test_cov_console --lcov=coverage/lcov.info --min-coverage=85

  echo ""
  echo -e "${GREEN}Coverage report generated in coverage/${NC}"
  echo "  - lcov.info: Machine-readable coverage data"
  echo "  - coverage.svg: Coverage badge"
  echo ""
fi

# Summary
echo "========================================="
echo "  Test Summary"
echo "========================================="
echo ""

if [ "$FAILED" -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi
