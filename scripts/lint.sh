#!/usr/bin/env bash
set -euo pipefail

# Determine diff base for PR / push.
if [[ -n "${GITHUB_BASE_REF:-}" ]]; then
  git fetch --no-tags --depth=1 origin "${GITHUB_BASE_REF}"
  BASE_SHA="$(git merge-base "origin/${GITHUB_BASE_REF}" HEAD)"
else
  BASE_SHA="${GITHUB_EVENT_BEFORE:-}"
  if [[ -z "${BASE_SHA}" || "${BASE_SHA}" == "0000000000000000000000000000000000000000" ]]; then
    BASE_SHA="$(git rev-parse HEAD~1)"
  fi
fi

CHANGED_SWIFT_FILES=()
while IFS= read -r file; do
  [[ -n "${file}" ]] && CHANGED_SWIFT_FILES+=("${file}")
done < <(git diff --name-only "${BASE_SHA}"...HEAD -- "*.swift")

if [[ ${#CHANGED_SWIFT_FILES[@]} -eq 0 ]]; then
  echo "No changed Swift files. Skip lint."
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

PATCH_FILE="${TMP_DIR}/swift.diff"
VIOLATIONS_JSON="${TMP_DIR}/violations.json"

git diff --unified=0 "${BASE_SHA}"...HEAD -- "*.swift" > "${PATCH_FILE}"

echo "Linting changed Swift files (${#CHANGED_SWIFT_FILES[@]}) and gating only touched lines"
for i in "${!CHANGED_SWIFT_FILES[@]}"; do
  export "SCRIPT_INPUT_FILE_${i}=${CHANGED_SWIFT_FILES[$i]}"
done
export SCRIPT_INPUT_FILE_COUNT="${#CHANGED_SWIFT_FILES[@]}"

if ! swiftlint lint --strict --use-script-input-files --reporter json > "${VIOLATIONS_JSON}"; then
  echo "SwiftLint reported violations; filtering to changed lines..."
fi

ruby - "${PATCH_FILE}" "${VIOLATIONS_JSON}" <<'RUBY'
require "json"

patch_path = ARGV.fetch(0)
violations_path = ARGV.fetch(1)

unless File.exist?(patch_path) && File.exist?(violations_path)
  warn "lint gating input files missing"
  exit 1
end

changed_lines = Hash.new { |h, k| h[k] = [] }
current_file = nil

File.foreach(patch_path) do |line|
  if line.start_with?("+++ ")
    path = line.sub("+++ ", "").strip
    if path == "/dev/null"
      current_file = nil
    else
      current_file = path.sub(%r{\Ab/}, "")
    end
    next
  end

  next unless current_file
  next unless line.start_with?("@@")

  m = line.match(/\+(\d+)(?:,(\d+))?/)
  next unless m

  start_line = m[1].to_i
  length = (m[2] || "1").to_i
  next if length <= 0

  changed_lines[current_file] << (start_line..(start_line + length - 1))
end

violations = JSON.parse(File.read(violations_path))
violations = [] unless violations.is_a?(Array)

matched = violations.select do |v|
  rule_id = v["rule_id"].to_s
  next false if %w[cyclomatic_complexity function_body_length].include?(rule_id)

  file = v["file"].to_s
  line = v["line"].to_i
  file = file.sub(%r{\A\./}, "")

  # SwiftLint often returns absolute paths in CI/local runs.
  rel = file
  pwd_prefix = "#{Dir.pwd}/"
  rel = rel.start_with?(pwd_prefix) ? rel[pwd_prefix.length..] : rel

  ranges = changed_lines[rel]
  next false if ranges.nil? || ranges.empty?

  ranges.any? { |r| r.cover?(line) }
end

if matched.empty?
  puts "No lint violations on changed lines."
  exit 0
end

puts "Lint violations on changed lines:"
matched.each do |v|
  puts "#{v['file']}:#{v['line']}: #{v['reason']} (#{v['rule_id']})"
end
exit 1
RUBY
