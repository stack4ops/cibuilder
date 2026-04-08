#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "cibuild.env is a valid env file" {
    [ -f "./cibuild.env" ]
}

@test "cibuild.env has expected format" {
    run grep -E "^[A-Z_]+=" "./cibuild.env"
    [ "$status" -eq 0 ]
}

@test "cibuild.env contains CIBUILD_RUN" {
    run grep "CIBUILD" "./cibuild.env"
    [ "$status" -eq 0 ]
}

@test "cibuild.test.json is valid JSON" {
    run jq empty "./cibuild.test.json"
    [ "$status" -eq 0 ]
}

@test "cibuild.test.json has structure" {
    run jq 'keys' "./cibuild.test.json"
    [ "$status" -eq 0 ]
}

@test "localregistry directory exists" {
    [ -d "./localregistry" ]
}

@test "localregistry contains certificate files" {
    run ls -1 ./localregistry/
    [ "$status" -eq 0 ]
    [[ "$output" =~ "pem" ]] || [[ "$output" =~ "crt" ]] || [[ "$output" =~ "key" ]]
}

@test "cosign.pub is a public key file" {
    [ -f "./cosign.pub" ]
}

@test "cosign.pub has expected format" {
    run grep -E "(BEGIN PUBLIC KEY|-----BEGIN)" "./cosign.pub"
    [ "$status" -eq 0 ]
}

@test ".gitlab-ci.yml exists" {
    [ -f "./.gitlab-ci.yml" ]
}

@test ".gitlab-ci.yml is valid YAML" {
    run awk 'BEGIN{FS=":"} $1 ~ /^[[:space:]]*[a-zA-Z]/{exit 0} END{exit 1}' "./.gitlab-ci.yml"
    [ "$status" -eq 0 ]
}

@test "GitLab CI mentions image" {
    run grep -i "image:" "./.gitlab-ci.yml"
    [ "$status" -eq 0 ]
}

@test "GitLab CI has stages or jobs" {
    run grep -E "(stages:|\\w+:)" "./.gitlab-ci.yml"
    [ "$status" -eq 0 ]
}

@test "LICENSE file exists" {
    [ -f "./LICENSE" ]
}

@test "LICENSE contains Apache" {
    run grep -i "apache" "./LICENSE"
    [ "$status" -eq 0 ]
}

@test ".github directory exists" {
    [ -d "./.github" ]
}

@test ".github has workflows or actions" {
    run find "./.github" -type f 2>/dev/null | grep -v "^$"
    [ "$status" -eq 0 ]
}

@test "Project structure is organized" {
    run ls -1 | grep -E "^\\."
    [ "$status" -eq 0 ]
}

@test "No trailing whitespace in scripts" {
    run grep -E "\\s+$" "./buildctl-daemonless.sh" | grep -v "^#" | head -1
    [ "$status" -ne 0 ]
}

@test "Scripts use Unix line endings" {
    run file "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
    [[ "$output" != *"CRLF"* ]]
}

@test "Dockerfile has no trailing whitespace" {
    run grep -E "\\s+$" "./Dockerfile" | head -1
    [ "$status" -ne 0 ]
}

@test "README has no huge blank lines" {
    run cat "./README.md" | grep -n "^$"
    count=$(echo "$output" | wc -l)
    [ "$count" -lt 10 ]
}

@test "Files are not too large" {
    run wc -l "./Dockerfile" "./buildctl-daemonless.sh" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
    while IFS= read -r line; do
        lines=$(echo "$line" | awk '{print $1}')
        [ "$lines" -lt 200 ]
    done <<< "$output"
}

@test "Repository has consistent naming" {
    run grep -i "cibuilder\\|cibuild" "./README.md" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Test files are in tests directory" {
    [ -d "./tests" ]
    [ -f "./tests/buildctl-daemonless.bats" ]
}

@test "Bats files have correct extension" {
    run find ./tests -name "*.bats" -type f
    [ "$status" -eq 0 ]
    count=$(echo "$output" | wc -l)
    [ "$count" -gt 0 ]
}

@test "No sensitive data in scripts" {
    run grep -i "(password|secret|key.*=.*'[\"a-z]" "./buildctl-daemonless.sh" "./cibuild_entrypoint.sh"
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
}

@test "Scripts use standard error redirection" {
    run grep -E "\\>(\\|\\&)?2" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "Scripts use proper quoting" {
    run grep -E '"[^"]*\\$[^"]*"' "./buildctl-daemonless.sh" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "GitHub workflows directories exist" {
    run ls -1 .github/ | grep -i "workflows?\\|actions"
    [ "$status" -eq 0 ]
}

@test "Project has documentation" {
    [ -f "./README.md" ]
    wc -w "./README.md"
    [ "$status" -eq 0 ]
}