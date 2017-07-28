{% from "example/map.jinja" import example with context %}

{% if example.enabled %}
include:
  - example.install
  - example.config
{% else %}
example_formula_disabled:
  test.succeed_without_changes
{% endif %}
