require 'serverspec'

# Required by serverspec
set :backend, :exec

describe package("nmap") do
  it { should be_installed }
end

describe package("strace") do
  it { should be_installed }
end

describe file("/root/example.conf") do
  it { should exist }
end
