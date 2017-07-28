{% from "example/map.jinja" import example with context %}

example_configure_file:
  file.managed:
    - name: /root/example.conf
    - user: root
    - group: root
    - mode: 644
    - contents:
      - This is the contents of the file
