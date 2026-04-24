#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: Scripts/validate-rules.sh [all|cleanup|uninstall]

Validates Gargantua rule YAML without requiring the app repository.
EOF
}

mode="${1:-all}"

case "$mode" in
    all|cleanup|uninstall)
        ;;
    -h|--help|help)
        usage
        exit 0
        ;;
    *)
        usage
        exit 1
        ;;
esac

ruby - "$REPO_ROOT" "$mode" <<'RUBY'
require "yaml"

root = ARGV.fetch(0)
mode = ARGV.fetch(1)
valid_safety = %w[safe review protected]
errors = []
ids = {}

def yaml_files(dir)
  return [] unless Dir.exist?(dir)

  Dir.glob(File.join(dir, "**", "*.{yaml,yml}")).sort
end

def blank?(value)
  value.nil? || (value.respond_to?(:empty?) && value.empty?)
end

def require_field!(errors, rule, field, context)
  errors << "#{context}: missing #{field}" if blank?(rule[field])
end

def require_string!(errors, value, context)
  errors << "#{context}: must be a non-empty string" unless value.is_a?(String) && !value.empty?
end

def validate_source!(errors, rule, context)
  source = rule["source"]
  unless source.is_a?(Hash)
    errors << "#{context}: source must be a mapping"
    return
  end

  require_string!(errors, source["name"], "#{context}: source.name")
  validate_optional_string!(errors, source["bundle_id"], "#{context}: source.bundle_id")
  validate_optional_bool!(errors, source["verify_signature"], "#{context}: source.verify_signature")
end

def validate_confidence!(errors, rule, context)
  confidence = rule["confidence"]
  unless confidence.is_a?(Integer) && confidence.between?(0, 100)
    errors << "#{context}: confidence must be an integer from 0 to 100"
  end
end

def validate_rule_ids!(errors, ids, rule, context)
  id = rule["id"]
  require_string!(errors, id, "#{context}: id")
  return unless id.is_a?(String) && !id.empty?

  if ids.key?(id)
    errors << "#{context}: duplicate id #{id.inspect}; first seen at #{ids[id]}"
  else
    ids[id] = context
  end
end

def validate_string_array!(errors, value, context)
  unless value.is_a?(Array) && value.any? && value.all? { |item| item.is_a?(String) && !item.empty? }
    errors << "#{context}: must be a non-empty array of strings"
  end
end

def validate_optional_string!(errors, value, context)
  return if value.nil?

  require_string!(errors, value, context)
end

def validate_optional_bool!(errors, value, context)
  return if value.nil?

  errors << "#{context}: must be true or false" unless [true, false].include?(value)
end

def validate_optional_string_array!(errors, value, context)
  return if value.nil?

  validate_string_array!(errors, value, context)
end

def validate_safety_overrides!(errors, rule, valid_safety, context)
  overrides = rule["safety_overrides"]
  return if overrides.nil?

  unless overrides.is_a?(Array)
    errors << "#{context}: safety_overrides must be an array"
    return
  end

  overrides.each_with_index do |override, index|
    override_context = "#{context}: safety_overrides[#{index}]"
    unless override.is_a?(Hash)
      errors << "#{override_context}: must be a mapping"
      next
    end

    require_string!(errors, override["condition"], "#{override_context}: condition")
    safety = override["safety"]
    errors << "#{override_context}: safety must be one of #{valid_safety.join(", ")}" unless valid_safety.include?(safety)

    confidence = override["confidence"]
    if confidence && !(confidence.is_a?(Integer) && confidence.between?(0, 100))
      errors << "#{override_context}: confidence must be an integer from 0 to 100 when present"
    end

    validate_optional_string!(errors, override["explanation_suffix"], "#{override_context}: explanation_suffix")
    validate_optional_string_array!(errors, override["profiles"], "#{override_context}: profiles")
  end
end

def validate_guard_scope!(errors, value, context)
  return if value.nil?

  errors << "#{context}: scope must be candidate or absolute" unless %w[candidate absolute].include?(value)
end

def validate_presence_guards!(errors, rule, context)
  guards = rule["presence_guards"]
  return if guards.nil?

  unless guards.is_a?(Array)
    errors << "#{context}: presence_guards must be an array"
    return
  end

  guards.each_with_index do |guard, index|
    guard_context = "#{context}: presence_guards[#{index}]"
    unless guard.is_a?(Hash)
      errors << "#{guard_context}: must be a mapping"
      next
    end

    require_string!(errors, guard["path"], "#{guard_context}: path")
    validate_guard_scope!(errors, guard["scope"], guard_context)
  end
end

def validate_content_guards!(errors, rule, context)
  guards = rule["content_guards"]
  return if guards.nil?

  unless guards.is_a?(Array)
    errors << "#{context}: content_guards must be an array"
    return
  end

  guards.each_with_index do |guard, index|
    guard_context = "#{context}: content_guards[#{index}]"
    unless guard.is_a?(Hash)
      errors << "#{guard_context}: must be a mapping"
      next
    end

    require_string!(errors, guard["path"], "#{guard_context}: path")
    contains = guard["contains"]
    unless (contains.is_a?(String) && !contains.empty?) ||
           (contains.is_a?(Array) && contains.any? && contains.all? { |item| item.is_a?(String) && !item.empty? })
      errors << "#{guard_context}: contains must be a non-empty string or non-empty array of strings"
    end
    validate_guard_scope!(errors, guard["scope"], guard_context)
  end
end

def validate_app_scope!(errors, rule, context)
  scope = rule["applies_to"]
  return if scope.nil?

  unless scope.is_a?(Hash)
    errors << "#{context}: applies_to must be a mapping"
    return
  end

  validate_optional_string_array!(errors, scope["bundle_ids"], "#{context}: applies_to.bundle_ids")
  validate_optional_string_array!(errors, scope["exclude_bundle_ids"], "#{context}: applies_to.exclude_bundle_ids")
end

def validate_cleanup_file!(errors, ids, valid_safety, file)
  doc = YAML.safe_load(File.read(file), permitted_classes: [], permitted_symbols: [], aliases: false) || {}
  rules = doc["rules"]
  unless rules.is_a?(Array)
    errors << "#{file}: top-level rules must be an array"
    return 0
  end

  rules.each_with_index do |rule, index|
    context = "#{file}: rules[#{index}]"
    unless rule.is_a?(Hash)
      errors << "#{context}: must be a mapping"
      next
    end

    validate_rule_ids!(errors, ids, rule, context)
    %w[name explanation category].each { |field| require_field!(errors, rule, field, context) }
    validate_string_array!(errors, rule["paths"], "#{context}: paths")
    validate_source!(errors, rule, context)
    validate_confidence!(errors, rule, context)
    validate_optional_string!(errors, rule["pattern"], "#{context}: pattern")
    validate_optional_string_array!(errors, rule["exclude"], "#{context}: exclude")
    validate_optional_string_array!(errors, rule["skip_if_process_running"], "#{context}: skip_if_process_running")
    validate_presence_guards!(errors, rule, context)
    validate_content_guards!(errors, rule, context)
    validate_optional_string_array!(errors, rule["match_filters"], "#{context}: match_filters")
    validate_optional_string!(errors, rule["regenerate_command"], "#{context}: regenerate_command")
    validate_optional_string_array!(errors, rule["tags"], "#{context}: tags")
    validate_safety_overrides!(errors, rule, valid_safety, context)

    safety = rule["safety"]
    errors << "#{context}: safety must be one of #{valid_safety.join(", ")}" unless valid_safety.include?(safety)

    unless [true, false].include?(rule["regenerates"])
      errors << "#{context}: regenerates must be true or false"
    end
  end

  rules.length
rescue Psych::Exception => error
  errors << "#{file}: invalid YAML: #{error.message}"
  0
end

def validate_uninstall_file!(errors, ids, valid_safety, file)
  doc = YAML.safe_load(File.read(file), permitted_classes: [], permitted_symbols: [], aliases: false) || {}
  rules = doc["remnant_rules"]
  unless rules.is_a?(Array)
    errors << "#{file}: top-level remnant_rules must be an array"
    return 0
  end

  rules.each_with_index do |rule, index|
    context = "#{file}: remnant_rules[#{index}]"
    unless rule.is_a?(Hash)
      errors << "#{context}: must be a mapping"
      next
    end

    validate_rule_ids!(errors, ids, rule, context)
    %w[name explanation category].each { |field| require_field!(errors, rule, field, context) }
    validate_string_array!(errors, rule["path_templates"], "#{context}: path_templates")
    validate_source!(errors, rule, context)
    validate_confidence!(errors, rule, context)
    validate_optional_string!(errors, rule["pattern"], "#{context}: pattern")
    validate_optional_string_array!(errors, rule["exclude"], "#{context}: exclude")
    validate_app_scope!(errors, rule, context)
    validate_optional_string_array!(errors, rule["tags"], "#{context}: tags")

    safety = rule["safety"]
    if safety && !valid_safety.include?(safety)
      errors << "#{context}: safety must be one of #{valid_safety.join(", ")} when present"
    end

    unless [true, false].include?(rule["regenerates"])
      errors << "#{context}: regenerates must be true or false"
    end
  end

  rules.length
rescue Psych::Exception => error
  errors << "#{file}: invalid YAML: #{error.message}"
  0
end

cleanup_files = yaml_files(File.join(root, "rules", "cleanup"))
uninstall_files = yaml_files(File.join(root, "rules", "uninstall"))
cleanup_count = 0
uninstall_count = 0

if %w[all cleanup].include?(mode)
  cleanup_files.each do |file|
    cleanup_count += validate_cleanup_file!(errors, ids, valid_safety, file)
  end
end

if %w[all uninstall].include?(mode)
  uninstall_files.each do |file|
    uninstall_count += validate_uninstall_file!(errors, ids, valid_safety, file)
  end
end

puts "==> Cleanup rules: #{cleanup_files.length} files / #{cleanup_count} rules" if %w[all cleanup].include?(mode)
puts "==> Uninstall rules: #{uninstall_files.length} files / #{uninstall_count} rules" if %w[all uninstall].include?(mode)

if errors.any?
  warn "Rule validation failed:"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

puts "==> Rule validation passed"
RUBY
