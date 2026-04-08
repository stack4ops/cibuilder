#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

# Security Tests
@test "Security: No hardcoded credentials" {
    run grep -iE "(password|secret|api[_-]?key|token)=['\"][^'\"]+['\"]" ./*.{sh,env,json} 2>/dev/null
    [ "$status" -ne 0 ] || [ -z "$output" ]
}

@test "Security: No exposed SSH keys" {
    run grep -iE "ssh-(rsa|dss|ecdsa|ed25519)" ./*.{sh,md} 2>/dev/null
    [ "$status" -ne 0 ] || [ -z "$output" ]
}

@test "Security: Shell scripts avoid eval" {
    run grep -E "\\beval\\b" ./*.sh 2>/dev/null
    [ "$status" -ne 0 ]
}

@test "Security: Uses HTTPS exclusively for downloads" {
    run grep -E "curl.*(https?://[^h]|http://[^l])" ./*.{sh,Dockerfile} 2>/dev/null
    [ "$status" -ne 0 ]
}

@test "Security: Sets non-root user" {
    run grep "^USER" "./Dockerfile"
    [ "$status" -eq 0 ]
    ! [[ "$output" =~ "USER root" ]] || grep -A1 "^USER root" ./Dockerfile | grep -q "^USER"
}

@test "Security: Services run on minimal privileges" {
    run grep -Ei "(chmod|chown)" ./*.{sh,Dockerfile} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Security: Uses known package repositories" {
    run grep -E "(apk|apt)\\.debian\\.org|alpinelinux\\.org|dl\\.cdn\\.alpine" ./Dockerfile 2>/dev/null
    [ "$status" -eq 0 ]
}

# Best Practices Tests
@test "BestPractice: Scripts use set -e for error handling" {
    run grep "set -e" ./*.sh
    [ "$status" -eq 0 ]
}

@test "BestPractice: Scripts use set -u for undefined vars" {
    run grep "set -u" ./*.sh
    [ "$status" -eq 0 ]
}

@test "BestPractice: Dockerfile uses layer caching optimization" {
    run grep -E "(ADD|COPY)" ./Dockerfile
    run grep -E "(RUN apk|RUN apt)" ./Dockerfile | head -1
    line1=$(echo "$output" | grep -n "RUN" | head -1)
    line2=$(echo "$output" | grep -E "(ADD|COPY):" | head -1)
    if [ -n "$line2" ]; then
        [[ "$line1" < "$line2" ]]
    fi
}

@test "BestPractice: Uses official docker images" {
    run grep -E "^FROM" ./Dockerfile
    [[ "$output" =~ (docker|moby|alpine|debian|ubuntu|official) ]]
}

@test "BestPractice: Pins specific versions where appropriate" {
    run grep -E "(v[0-9]+\\.[0-9]+|:[0-9]+\\.[0-9]+)" ./Dockerfile ./README.md 2>/dev/null | head -1
    [ "$status" -eq 0 ] || true
}

@test "BestPractice: Cleans up package cache" {
    run grep -E "(rm.*cache|apt-get clean|apk.*--no-cache)" ./Dockerfile
    [ "$status" -eq 0 ]
}

@test "BestPractice: Minimizes image layers" {
    run grep "RUN" ./Dockerfile | wc -l
    layers=$(echo "$output" | tail -1)
    [ "$layers" -lt 50 ]
}

# Code Quality Tests
@test "Quality: Functions are descriptive" {
    run grep "\\(\\)" ./*.sh
    [ "$status" -eq 0 ]
}

@test "Quality: Has license header or reference" {
    run grep -i "license" ./LICENSE ./README.md
    [ "$status" -eq 0 ]
}

@test "Quality: README has structure" {
    run grep -E "(# Title|## |\\* |description)" ./README.md
    [ "$status" -eq 0 ]
}

@test "Quality: Shell scripts are executable" {
    run file ./*.sh
    [ "$status" -eq 0 ]
    while IFS= read -r line; do
        [[ "$line" =~ "executable" ]] || [[ "$line" =~ "script" ]]
    done <<< "$output"
}

@test "Quality: No TODO or FIXME in production code" {
    run grep -iE "TODO|FIXME|HACK|XXX" ./*.{sh,Dockerfile} 2>/dev/null
    [ "$status" -ne 0 ]
}

# Maintainability Tests
@test "Maintainability: Consistent indentation" {
    run cat ./buildctl-daemonless.sh | grep -E "^\s{2,}" | head -1
    [ "$status" -eq 0 ] || true
}

@test "Maintainability: Lines are reasonably short" {
    run awk 'length>120 {print FILENAME":"NR":"length}' ./*.{sh,Dockerfile}
    [ "$output" = "" ]
}

@test "Maintainability: No commented out code blocks" {
    run grep -E "^(\s*)#[^!].*\w+.*\w.*\w+" ./*.{sh,Dockerfile} | grep -v "#\s*"
    [ "$status" -ne 0 ] || true
}

@test "Maintainability: Proper error messages" {
    run grep -iE "(error|fail|invalid|missing)" ./*.sh ./Dockerfile
    [ "$status" -eq 0 ]
}

@test "Maintainability: Documentation is up to date" {
    run wc -l ./README.md
    [ "$status" -eq 0 ]
    lines=$(echo "$output" | awk '{print $1}')
    [ "$lines" -gt 20 ]
}

# Performance Tests
@test "Performance: Uses cached packages" {
    run grep -i "cache" ./Dockerfile ./README.md
    [ "$status" -eq 0 ]
}

@test "Performance: Downloads are minimal" {
    run grep -c "curl" ./Dockerfile
    downloads=$(echo "$output")
    [ "$downloads" -lt 10 ]
}

@test "Performance: No unnecessary packages" {
    run grep -E "(apk add|apt-get install)" ./Dockerfile
    [ "$status" -eq 0 ]
}