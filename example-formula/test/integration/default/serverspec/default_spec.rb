require 'serverspec'

# Required by serverspec
set :backend, :exec

describe package("vim") do
  it { should be_installed }
end

describe package("htop") do
  it { should be_installed }
end

describe file("/root/example.conf") do
  it { should exist }
end
