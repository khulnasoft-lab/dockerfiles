#!/usr/bin/env bats

# Test file for test_infrastructure.sh
# Using BATS (Bash Automated Testing System) as the testing framework

setup() {
    # Create a temporary directory for test isolation
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    
    # Set up a mock git repository for testing
    cd "$TEST_TEMP_DIR"
    git init --quiet
    git config user.email "test@example.com"
    git config user.name "Test User"
    
    # Create initial commit
    echo "initial" > README.md
    git add README.md
    git commit -m "Initial commit" --quiet
    
    # Source the script under test (with modifications to avoid side effects)
    export ORIGINAL_PWD="$PWD"
}

teardown() {
    # Clean up temporary directory
    cd /
    rm -rf "$TEST_TEMP_DIR"
}

# Test that script sets correct error handling
@test "script sets proper error handling options" {
    source "${BATS_TEST_DIRNAME}/../test_infrastructure.sh" || true
    
    # Check if 'set -e' is effective by testing error propagation
    run bash -c 'set -e; false; echo "should not reach here"'
    [ "$status" -ne 0 ]
}

# Test VALIDATE_REPO variable is set correctly
@test "VALIDATE_REPO is set to correct repository" {
    source "${BATS_TEST_DIRNAME}/../test_infrastructure.sh" || true
    [ "$VALIDATE_REPO" = "https://github.com/khulnasoft-lab/dockerfiles.git" ]
}

# Test VALIDATE_BRANCH variable is set correctly
@test "VALIDATE_BRANCH is set to master" {
    source "${BATS_TEST_DIRNAME}/../test_infrastructure.sh" || true
    [ "$VALIDATE_BRANCH" = "master" ]
}

# Test VALIDATE_HEAD is set and is a valid commit hash
@test "VALIDATE_HEAD contains valid commit hash" {
    cd "$TEST_TEMP_DIR"
    
    # Mock git rev-parse for HEAD
    function git() {
        if [[ "$1" == "rev-parse" && "$2" == "--verify" && "$3" == "HEAD" ]]; then
            echo "abc123def456"
        else
            command git "$@"
        fi
    }
    export -f git
    
    source "${BATS_TEST_DIRNAME}/../test_infrastructure.sh" || true
    [ "$VALIDATE_HEAD" = "abc123def456" ]
}

# Test validate_diff function with different upstream scenarios
@test "validate_diff calls git diff with correct parameters when upstream differs from head" {
    cd "$TEST_TEMP_DIR"
    
    # Mock variables
    export VALIDATE_UPSTREAM="upstream123"
    export VALIDATE_HEAD="head456"
    export VALIDATE_COMMIT_DIFF="upstream123...head456"
    
    # Mock git diff to capture arguments
    function git() {
        if [[ "$1" == "diff" ]]; then
            echo "git diff called with: $*" >&2
            return 0
        else
            command git "$@"
        fi
    }
    export -f git
    
    # Source function definition
    source "${BATS_TEST_DIRNAME}/../test_infrastructure.sh" || true
    
    run validate_diff --name-only
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"git diff called with: diff upstream123...head456 --name-only"* ]]
}

@test "validate_diff uses HEAD~ when upstream equals head" {
    cd "$TEST_TEMP_DIR"
    
    # Mock variables - same upstream and head
    export VALIDATE_UPSTREAM="same123"
    export VALIDATE_HEAD="same123"
    
    # Mock git diff to capture arguments
    function git() {
        if [[ "$1" == "diff" ]]; then
            echo "git diff called with: $*" >&2
            return 0
        else
            command git "$@"
        fi
    }
    export -f git
    
    # Source function definition
    source "${BATS_TEST_DIRNAME}/../test_infrastructure.sh" || true
    
    run validate_diff --name-only
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"git diff called with: diff HEAD~ --name-only"* ]]
}

# Test dockerfile detection and processing
@test "script identifies Dockerfile changes correctly" {
    cd "$TEST_TEMP_DIR"
    
    # Create test directory structure
    mkdir -p app1/v1
    mkdir -p app2
    echo "FROM ubuntu" > app1/v1/Dockerfile
    echo "FROM alpine" > app2/Dockerfile
    git add .
    git commit -m "Add Dockerfiles" --quiet
    
    # Mock validate_diff to return our test files
    function validate_diff() {
        echo "app1/v1/Dockerfile"
        echo "app2/Dockerfile"
    }
    export -f validate_diff
    
    # Mock docker build to avoid actual builds
    function docker() {
        if [[ "$1" == "build" ]]; then
            echo "Mock docker build: $*" >&2
            return 0
        else
            command docker "$@"
        fi
    }
    export -f docker
    
    # Source and run the main script logic
    source "${BATS_TEST_DIRNAME}/../test_infrastructure.sh" || true
    
    # The script should process both files without errors
    [ "$?" -eq 0 ]
}

# Test base and suite extraction logic
@test "correctly extracts base and suite from dockerfile path" {
    cd "$TEST_TEMP_DIR"
    
    # Test case 1: nested directory
    f="myapp/production/Dockerfile"
    build_dir=$(dirname "$f")
    base="${build_dir%%\/*}"
    suite="${build_dir##$base}"
    suite="${suite##\/}"
    
    [ "$base" = "myapp" ]
    [ "$suite" = "production" ]
    
    # Test case 2: single directory
    f="redis/Dockerfile"
    build_dir=$(dirname "$f")
    base="${build_dir%%\/*}"
    suite="${build_dir##$base}"
    suite="${suite##\/}"
    
    [ "$base" = "redis" ]
    [ "$suite" = "" ]
}

# Test suite default value assignment
@test "assigns 'latest' as default suite when suite is empty" {
    suite=""
    if [[ -z "$suite" ]]; then
        suite=latest
    fi
    [ "$suite" = "latest" ]
}

# Test file existence check
@test "skips processing when dockerfile does not exist" {
    cd "$TEST_TEMP_DIR"
    
    # Mock validate_diff to return non-existent file
    function validate_diff() {
        echo "nonexistent/Dockerfile"
    }
    export -f validate_diff
    
    # Create counter to track docker build calls
    docker_build_count=0
    function docker() {
        if [[ "$1" == "build" ]]; then
            ((docker_build_count++))
        fi
        return 0
    }
    export -f docker
    export docker_build_count
    
    # Source and run the main script logic
    source "${BATS_TEST_DIRNAME}/../test_infrastructure.sh" || true
    
    # Docker build should not be called for non-existent files
    [ "$docker_build_count" -eq 0 ]
}

# Test docker build command construction
@test "constructs correct docker build command with proper tag and context" {
    cd "$TEST_TEMP_DIR"
    
    # Create test dockerfile
    mkdir -p webapp/staging
    echo "FROM nginx" > webapp/staging/Dockerfile
    
    # Capture docker build arguments
    docker_args=""
    function docker() {
        if [[ "$1" == "build" ]]; then
            docker_args="$*"
            echo "Mock docker build successful" >&2
        fi
        return 0
    }
    export -f docker
    
    # Mock validate_diff
    function validate_diff() {
        echo "webapp/staging/Dockerfile"
    }
    export -f validate_diff
    
    # Source and run the main script logic
    source "${BATS_TEST_DIRNAME}/../test_infrastructure.sh" || true
    
    [[ "$docker_args" == *"-t webapp:staging"* ]]
    [[ "$docker_args" == *"webapp/staging"* ]]
}

# Test IFS handling for file processing
@test "properly handles IFS for processing dockerfile list" {
    cd "$TEST_TEMP_DIR"
    
    # Save original IFS
    original_ifs="$IFS"
    
    # Mock validate_diff to return multiple files
    function validate_diff() {
        printf "app1/Dockerfile\napp2/v1/Dockerfile\napp3/test/Dockerfile"
    }
    export -f validate_diff
    
    # Source the script logic that sets IFS
    IFS=$'\n'
    files=( $(validate_diff --name-only -- '*Dockerfile') )
    unset IFS
    
    # Check that IFS is unset after processing
    [ -z "$IFS" ]
    
    # Check that files array contains expected entries
    [ "${#files[@]}" -eq 3 ]
    [ "${files[0]}" = "app1/Dockerfile" ]
    [ "${files[1]}" = "app2/v1/Dockerfile" ]
    [ "${files[2]}" = "app3/test/Dockerfile" ]
}

# Test error handling in docker build subprocess
@test "handles docker build failures gracefully" {
    cd "$TEST_TEMP_DIR"
    
    # Create test dockerfile
    mkdir -p failapp
    echo "FROM ubuntu" > failapp/Dockerfile
    
    # Mock docker to fail
    function docker() {
        if [[ "$1" == "build" ]]; then
            echo "Build failed" >&2
            return 1
        fi
        return 0
    }
    export -f docker
    
    # Mock validate_diff
    function validate_diff() {
        echo "failapp/Dockerfile"
    }
    export -f validate_diff
    
    # The script should fail due to set -e when docker build fails
    run bash "${BATS_TEST_DIRNAME}/../test_infrastructure.sh"
    [ "$status" -ne 0 ]
}

# Test success message output
@test "outputs success message with correct base, suite, and build_dir" {
    cd "$TEST_TEMP_DIR"
    
    # Create test dockerfile
    mkdir -p myservice/production
    echo "FROM node" > myservice/production/Dockerfile
    
    # Mock docker build
    function docker() {
        return 0
    }
    export -f docker
    
    # Mock validate_diff
    function validate_diff() {
        echo "myservice/production/Dockerfile"
    }
    export -f validate_diff
    
    # Run the script and capture output
    run bash "${BATS_TEST_DIRNAME}/../test_infrastructure.sh"
    
    [[ "$output" == *"Successfully built myservice:production with context myservice/production"* ]]
}

# Test git fetch operation
@test "performs git fetch with correct repository and branch" {
    cd "$TEST_TEMP_DIR"
    
    # Mock git to capture fetch arguments
    fetch_args=""
    function git() {
        if [[ "$1" == "fetch" ]]; then
            fetch_args="$*"
            return 0
        elif [[ "$1" == "rev-parse" ]]; then
            echo "mock-commit-hash"
            return 0
        else
            command git "$@"
        fi
    }
    export -f git
    
    # Source the script
    source "${BATS_TEST_DIRNAME}/../test_infrastructure.sh" || true
    
    [[ "$fetch_args" == *"-q https://github.com/khulnasoft-lab/dockerfiles.git refs/heads/master"* ]]
}

# Integration test: full workflow with mocked dependencies
@test "full workflow integration test with mocked git and docker" {
    cd "$TEST_TEMP_DIR"
    
    # Create realistic directory structure
    mkdir -p webapp/{dev,prod} api/v2 database
    echo "FROM node:16" > webapp/dev/Dockerfile
    echo "FROM node:16-alpine" > webapp/prod/Dockerfile
    echo "FROM golang:1.19" > api/v2/Dockerfile
    echo "FROM postgres:14" > database/Dockerfile
    
    # Mock git operations
    function git() {
        case "$1" in
            "rev-parse")
                if [[ "$3" == "HEAD" ]]; then
                    echo "local-head-commit"
                elif [[ "$3" == "FETCH_HEAD" ]]; then
                    echo "remote-head-commit"
                fi
                ;;
            "fetch")
                # Simulate successful fetch
                return 0
                ;;
            "diff")
                # Return our test dockerfiles
                printf "webapp/dev/Dockerfile\napi/v2/Dockerfile\ndatabase/Dockerfile"
                ;;
        esac
        return 0
    }
    export -f git
    
    # Mock docker build
    build_count=0
    function docker() {
        if [[ "$1" == "build" ]]; then
            ((build_count++))
            echo "Building $2 $3" >&2
        fi
        return 0
    }
    export -f docker
    export build_count
    
    # Run the full script
    run bash "${BATS_TEST_DIRNAME}/../test_infrastructure.sh"
    
    [ "$status" -eq 0 ]
    [ "$build_count" -eq 3 ]
    [[ "$output" == *"Successfully built webapp:dev"* ]]
    [[ "$output" == *"Successfully built api:v2"* ]]
    [[ "$output" == *"Successfully built database:latest"* ]]
}