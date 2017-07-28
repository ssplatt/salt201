{% from "example/map.jinja" import example with context %}

example_install_dependent_pkgs:
  pkg.installed:
    - pkgs: {{ example.dep_pkgs }}
