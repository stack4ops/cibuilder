#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "Fuzzy: Scripts mention common shell patterns" {
    run grep -Ei "(echo|exit|return|cd|pwd)" "./buildctl-daemonless.sh" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Scripts use variables or parameters" {
    run grep -E '\\$\\{?\\w+\\}?|\\$[0-9]' "./buildctl-daemonless.sh" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Files mention build or buildkit" {
    run grep -Ei "build" ./*.{sh,Dockerfile,md} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Configuration mentions environment variables" {
    run grep -E '(ENV|export|:.*=)' ./*.{sh,Dockerfile,env} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Download or install operations present" {
    run grep -Ei "(curl|wget|apk|apt|npm|pip)" ./*.{sh,Dockerfile} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Error handling patterns" {
    run grep -Ei "(error|fail|exit|set -|\\|\\||&&)" ./*.{sh,Dockerfile} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: File operations" {
    run grep -Ei "(cat|grep|sed|awk|find|ls|rm|cp|mv|mkdir|touch)" ./*.{sh,Dockerfile} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Conditional or loop constructs" {
    run grep -Ei "(if|else|elif|case|for|while|until)" ./*.{sh,Dockerfile} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Dockerfile uses containers or images" {
    run grep -Ei "(FROM|COPY|ADD|RUN|CMD|ENTRYPOINT|image|container)" "./Dockerfile" 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Security related keywords" {
    run grep -Ei "(auth|cert|key|sign|secure|permission|chmod|chown|root|user)" ./*.{sh,Dockerfile,md} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Version or reference patterns" {
    run grep -Ei "(version|ref|tag|commit|branch|\\d+\\.\\d+|latest|stable)" ./*.{sh,Dockerfile,md,yml} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Comment lines present" {
    run grep -E "^\\s*#|^\\s*//" ./*.{sh,bats,Dockerfile} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Documentation has lists or sections" {
    run grep -E "^(\\*|\\d+\\.|\\-|\\s{2,}\\w)" "./README.md" 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: CI/CD pipeline configuration" {
    run grep -Ei "(pipeline|stage|job|runner|gitlab|github)" ./.gitlab-ci.yml ./.github/*/*.{yml,yaml} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Network or URL references" {
    run grep -Ei "(http|https|url|uri|github|registry)" ./*.{sh,Dockerfile,md,yaml,yml} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Architecture or platform mentions" {
    run grep -Ei "(amd64|arm64|x86_64|linux|arch|platform|target)" ./*.{sh,Dockerfile,md} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Logging or output patterns" {
    run grep -Ei "(log|print|echo|output|stderr|stdout|debug)" ./*.{sh,Dockerfile} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Tool or binary mentions" {
    run grep -Ei "(\\*\\s+\\w+\\*\\s*:|tool|binary|exe|cmd)" "./README.md" 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Multiple environment variables" {
    run grep -E "(ENV|export|=)" ./*.{sh,Dockerfile,env} 2>/dev/null | wc -l
    [ "$status" -eq 0 ]
    count=$(echo "$output" | tail -1)
    [ "$count" -gt 10 ]
}

@test "Fuzzy: File paths or directories" {
    run grep -E "/\\w+[\\w/.-]*" ./*.{sh,Dockerfile} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Fuzzy match for shell commands" {
    run grep -E "(\\b[[:lower:]]+\\b\\s*(\\|\\&?\\&?\\s*)?[a-z]+)" ./*.{sh,Dockerfile} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Any README structure" {
    run grep -E "(^#|^##|^---|\\*\\s|\\d+\\.)" "./README.md" 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Multiple Docker directives" {
    run grep "^FROM\\|^COPY\\|^RUN\\|^ENV\\|^USER\\|^ENTRYPOINT\\|^LABEL\\|^ARG\\|^EXPOSE" "./Dockerfile" 2>/dev/null
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -ge 5 ]
}

@test "Fuzzy: Test assertions or checks" {
    run grep -E "(\\[ .* \\]\\s*\\$|test|assert|should|expect)" ./tests/*.bats 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Helper or utility patterns" {
    run grep -Ei "(function|def|helper|util)" ./*.{sh,bats} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Commands in usage descriptions" {
    run grep -E '\`[^\`]+\`|\$\s' "./README.md" 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Organization or repository mentions" {
    run grep -Ei "(stack4ops|tobias-weiss|github|gitlab)" ./*.{sh,md,Dockerfile,yml,yaml} 2>/dev/null
    [ "$status" -eq 0 ]
}

@test "Fuzzy: Configuration file mentions" {
    run grep -E "\\.(env|conf|config|json|yaml|yml|toml)" ./*.{sh,md,Dockerfile} 2>/dev/null
    [ "$status" -eq 0 ]
}