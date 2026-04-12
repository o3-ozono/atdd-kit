#!/usr/bin/env bats

# Bilingual issue template tests
# Templates exist in templates/issue/ja/ and templates/issue/en/

# --- Issue templates exist in both languages ---

@test "ja issue templates exist for all types" {
  for type in development bug-report research documentation refactoring; do
    [[ -f "templates/issue/ja/${type}.yml" ]]
  done
}

@test "en issue templates exist for all types" {
  for type in development bug-report research documentation refactoring; do
    [[ -f "templates/issue/en/${type}.yml" ]]
  done
}

# --- ja and en templates have distinct name fields ---

@test "ja and en issue templates have distinct name fields" {
  for type in development bug-report research documentation refactoring; do
    ja_name=$(grep '^name:' "templates/issue/ja/${type}.yml")
    en_name=$(grep '^name:' "templates/issue/en/${type}.yml")
    [ "$ja_name" != "$en_name" ]
  done
}

@test "en issue templates have English name fields" {
  for f in templates/issue/en/*.yml; do
    name=$(grep '^name:' "$f" | sed 's/^name: //')
    # Non-ASCII characters should not be present
    ! echo "$name" | LC_ALL=C grep -q '[^[:print:]]'
  done
}

# --- PR template is English-only ---

@test "PR template exists in en" {
  [[ -f "templates/pr/en/pull_request_template.md" ]]
}
