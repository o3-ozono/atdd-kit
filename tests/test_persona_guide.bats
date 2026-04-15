#!/usr/bin/env bats

# Issue #65: ペルソナガイドの策定と docs/personas/ の導入

# AC1: persona-guide.md に Cooper の Goal-Directed Design と Elastic User Problem に言及した定義

@test "AC1: docs/methodology/persona-guide.md exists" {
  [ -f "docs/methodology/persona-guide.md" ]
}

@test "AC1: persona-guide.md mentions Cooper's Goal-Directed Design" {
  grep -qi "Cooper" docs/methodology/persona-guide.md
  grep -qi "Goal-Directed" docs/methodology/persona-guide.md
}

@test "AC1: persona-guide.md mentions Elastic User Problem" {
  grep -qi "Elastic User" docs/methodology/persona-guide.md
}

# AC2: フォーマット定義 — Name, Role/Job title, Goals (Primary/Secondary), Context, Quote

@test "AC2: persona-guide.md defines Name field" {
  grep -q "Name" docs/methodology/persona-guide.md
}

@test "AC2: persona-guide.md defines Role field" {
  grep -q "Role" docs/methodology/persona-guide.md
}

@test "AC2: persona-guide.md defines Goals with Primary and Secondary" {
  grep -q "Goals" docs/methodology/persona-guide.md
  grep -q "Primary" docs/methodology/persona-guide.md
  grep -q "Secondary" docs/methodology/persona-guide.md
}

@test "AC2: persona-guide.md defines Context field" {
  grep -q "Context" docs/methodology/persona-guide.md
}

@test "AC2: persona-guide.md defines Quote field" {
  grep -q "Quote" docs/methodology/persona-guide.md
}

# AC3: ペルソナ種類 — Primary, Secondary, Negative の定義と使い分け

@test "AC3: persona-guide.md defines Primary persona type" {
  grep -q "Primary" docs/methodology/persona-guide.md
}

@test "AC3: persona-guide.md defines Secondary persona type" {
  grep -q "Secondary" docs/methodology/persona-guide.md
}

@test "AC3: persona-guide.md defines Negative persona type" {
  grep -q "Negative" docs/methodology/persona-guide.md
}

# AC4: 作成プロセス + anti-pattern

@test "AC4: persona-guide.md has creation process section" {
  grep -qi "creation\|when to create\|who creates\|update" docs/methodology/persona-guide.md
}

@test "AC4: persona-guide.md includes anti-pattern warning for persona without research" {
  grep -qi "anti-pattern\|without research\|no research" docs/methodology/persona-guide.md
}

@test "AC4: persona-guide.md includes anti-pattern warning for persona proliferation" {
  grep -qi "proliferation\|too many persona\|persona sprawl" docs/methodology/persona-guide.md
}

# AC5: TEMPLATE.md — AC2 と一致するプレースホルダー

@test "AC5: docs/personas/TEMPLATE.md exists" {
  [ -f "docs/personas/TEMPLATE.md" ]
}

@test "AC5: TEMPLATE.md has Name placeholder" {
  grep -q "Name" docs/personas/TEMPLATE.md
}

@test "AC5: TEMPLATE.md has Role placeholder" {
  grep -q "Role" docs/personas/TEMPLATE.md
}

@test "AC5: TEMPLATE.md has Goals placeholder" {
  grep -q "Goals" docs/personas/TEMPLATE.md
}

@test "AC5: TEMPLATE.md has Primary and Secondary goals" {
  grep -q "Primary" docs/personas/TEMPLATE.md
  grep -q "Secondary" docs/personas/TEMPLATE.md
}

@test "AC5: TEMPLATE.md has Context placeholder" {
  grep -q "Context" docs/personas/TEMPLATE.md
}

@test "AC5: TEMPLATE.md has Quote placeholder" {
  grep -q "Quote" docs/personas/TEMPLATE.md
}

# AC6: ディレクトリ構成とドキュメント整合性

@test "AC6: docs/personas/ directory exists" {
  [ -d "docs/personas" ]
}

@test "AC6: docs/personas/README.md exists" {
  [ -f "docs/personas/README.md" ]
}

@test "AC6: personas/README.md describes directory purpose" {
  grep -qi "persona\|purpose\|directory" docs/personas/README.md
}

@test "AC6: personas/README.md mentions template usage" {
  grep -qi "template\|TEMPLATE" docs/personas/README.md
}

@test "AC6: personas/README.md mentions one-file-per-persona convention" {
  grep -qi "one.*per\|1.*per\|file.*persona\|per.*persona" docs/personas/README.md
}

@test "AC6: docs/README.md includes personas/ category" {
  grep -q "personas" docs/README.md
}

@test "AC6: docs/README.md personas section has table format" {
  grep -q "personas/README.md" docs/README.md
}

# AC7: discover スキル参照方法

@test "AC7: persona-guide.md documents docs/personas/ path convention" {
  grep -q "docs/personas" docs/methodology/persona-guide.md
}

@test "AC7: persona-guide.md has reference method section" {
  grep -qi "reference\|discover\|user story" docs/methodology/persona-guide.md
}

@test "AC7: persona-guide.md notes SKILL.md changes deferred to Issue F" {
  grep -qi "Issue F\|deferred\|SKILL.md" docs/methodology/persona-guide.md
}

# Language policy: no *.ja.md in docs/personas/

@test "Language policy: no *.ja.md files in docs/personas/" {
  ! find docs/personas/ -name "*.ja.md" | grep -q .
}

# Language policy: no *.ja.md in docs/methodology/persona-guide context

@test "Language policy: persona-guide.md is English only (no Japanese characters)" {
  ! grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/persona-guide.md
}
