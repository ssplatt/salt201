# Salt 201 - Introduction to Salt Formulas and Unit Tests

Building on [Salt 101](https://github.com/ssplatt/salt101/blob/master/README.md), this class is an introduction to creating formulas for Salt. We will explore tools that will help us quickly develop salt states and test different pillar configurations. At the end of this class, you will have a unit of code that can be automatically tested by your continuous integration server when you push updates to git.

## Table of Contents

  * [Prerequisites](#prerequisites)
  * [References](#references)
  * [Why Formulas?](#why-formulas)
  * [Why Test-Kitchen?](#why-test-kitchen)
  * [Getting Started with Kitchen](#getting-started-with-kitchen)
     * [Initializing the test environment](#initializing-the-test-environment)
     * [The .kitchen.yml file](#the-kitchenyml-file)
     * [Introduction to kitchen converge](#introduction-to-kitchen-converge)
     * [Initializing the Salt Formula](#initializing-the-salt-formula)
  * [Introduction to Applying Real Changes](#introduction-to-applying-real-changes)
     * [Explanation of map.jinja](#explanation-of-mapjinja)
     * [Explanation of defaults.yml](#explanation-of-defaultsyml)
     * [Explanation of init.sls](#explanation-of-initsls)
     * [Explanation of install.sls](#explanation-of-installsls)
  * [Manually Verifying the Changes](#manually-verifying-the-changes)
  * [Introduction to kitchen verify](#introduction-to-kitchen-verify)
  * [Creating a Serverspec Test](#creating-a-serverspec-test)
  * [Introduction to kitchen test](#introduction-to-kitchen-test)
  * [Introduction to kitchen destroy](#introduction-to-kitchen-destroy)
  * [Test Driven Development](#test-driven-development)
     * [Write a failing test](#write-a-failing-test)
     * [Write configuration to make the test pass](#write-configuration-to-make-the-test-pass)
  * [Add a new suite](#add-a-new-suite)
     * [Create the new suite definition](#create-the-new-suite-definition)
     * [Create tests for the new suite](#create-tests-for-the-new-suite)
  * [Other Kitchen Configs](#other-kitchen-configs)
    * [Create a Kitchen CI Config](#create-a-kitchen-ci-config)
  * [CI Automation Concepts](#ci-automation-concepts)

## Prerequisites
First and foremost, ensure you have the required pieces of software installed to have a proper local testing environment. This class assumes you are familiar with Salt, Yaml, and Jinja. If you need a refresher, please review [Salt 101](https://github.com/ssplatt/salt101/blob/master/README.md).

  - Virtualbox
    - https://www.virtualbox.org/wiki/Downloads
    - Install with brew on Mac OS: `brew cask install virtualbox`
  - Vagrant
    - https://www.vagrantup.com/downloads.html
    - Install with brew on Mac OS: `brew cask install vagrant`
  - Bento Boxes
    - https://app.vagrantup.com/bento
    - Pull down the Debian 8 Image: `vagrant box add bento/debian-8.8`
      - If you choose not to use Debian 8, you may have to change some of the provided directions to fit your environment
  - Test-Kitchen
    - `gem install test-kitchen`
    - kitchen-salt
      - the Salt provisioner for Kitchen
      - `gem install kitchen-salt`
    - kitchen-vagrant
      - the Vagrant driver for Kitchen
      - `gem install kitchen-vagrant`
    - kitchen-linode
      - the Linode driver for Kitchen
      - `gem install kitchen-linode`

## References
These are a few sites that are useful for more details and further documentation of the concepts introduced in this class. You may wish to leave some of these open while following along with this class.

 - [kitchen-salt provisioner options](https://github.com/saltstack/kitchen-salt/blob/master/provisioner_options.md)
 - [kitchen-vagrant driver settings](https://github.com/test-kitchen/kitchen-vagrant#-default-configuration)
 - [serverspec resource types](http://serverspec.org/resource_types.html)
 - [test-kitchen getting started](http://kitchen.ci/docs/getting-started/)
 - [chef test-kitchen docs](https://docs.chef.io/kitchen.html)

## Why Formulas?
The main idea of writing formulas is to keep many individual chunks of code that can be developed separately from each other. There are many benefits to following this model including allowing team members to work on different parts of the environment at the same time without blocking each other or stepping on toes. Formulas also reduce complexity and keep logical portions of code together so they are easier to understand and improve in the future. These smaller units of code also allow us to take advantage of CI/CD pipelines and test driven development methodologies to be more confident that we are catching errors as early as possible.

## Why Test-Kitchen?
Test-kitchen is a piece of software that is designed specifically for developing and testing units of code for configuration management systems. While it is maintained by Chef, it is not limited to only supporting Chef. There are many different driver, provisioner, and verifier plugins so it fits many different environments. It is quicker and easier to use than Vagrant itself because the main configuration is in Yaml as opposed to Ruby. The commands to create virtual machines, apply configuration, and test the results are also abstracted so you spend more time working on code rather than the tooling.

## Getting Started with Kitchen

### Initializing the test environment
Setting up the test environment is quite painless but does require a couple steps. Although I have provided the `example-formula` directory as a part of this repository, you will get the most out of this class if you follow along with the examples provided and create it all from scratch.

  1. Create a new folder for the formula, i.e. `example-formula`, and enter the directory

```
$ mkdir example-formula
$ cd example-formula
```

  2. Initialize the directory, `kitchen init`.

```
$ kitchen init
      create  .kitchen.yml
      create  chefignore
      create  test/integration/default
Fetching: kitchen-vagrant-1.1.1.gem (100%)
Successfully installed kitchen-vagrant-1.1.1
Parsing documentation for kitchen-vagrant-1.1.1
Installing ri documentation for kitchen-vagrant-1.1.1
Done installing documentation for kitchen-vagrant after 0 seconds
1 gem installed
```

  3. Run `kitchen list` to see the default configuration

```
$ kitchen list
Instance             Driver   Provisioner  Verifier  Transport  Last Action    Last Error
default-ubuntu-1404  Vagrant  ChefSolo     Busser    Ssh        <Not Created>  <None>
default-centos-72    Vagrant  ChefSolo     Busser    Ssh        <Not Created>  <None>
```
  4. Edit the `.kitchen.yml` file and ensure it has this data in it:

```
---
driver:
  name: vagrant

provisioner:
  name: salt_solo
  formula: example
  state_top:
    base:
      "*":
        - example

platforms:
  - name: bento/debian-8.8

suites:
  - name: default
```

  5. Confirm the settings by typing `kitchen list`

```
$ kitchen list
Instance                 Driver   Provisioner  Verifier  Transport  Last Action    Last Error
default-bento-debian-88  Vagrant  SaltSolo     Busser    Ssh        <Not Created>  <None>
```

The main things to notice in the initialization is that a `.kitchen.yml` file is created and a `test/integration/default` directory is created. The `chefignore` file is extraneous for our purposes and can be deleted. It will not harm anything if you cool to leave it.

### The .kitchen.yml file
The `.kitchen.yml` file is where the test environments are defined.

  - **driver**
    - defined which Driver to use.
    - define Global settings for the driver
      - number of CPUs
      - amount of RAM
  - **provisioner**
    - define which Provisioner to use
    - define Global settings for the provisioner
      - the name of the formula
      - State Top File
      - Pillar Top File
  - **platforms**
    - which Operating Systems or Distributions to use
    - can define `driver` and `provisioner` settings locally for each platform
  - **suites**
    - the names of the different Salt configurations to test
    - can define `driver` and `provisioner` settings locally for each suite
      - custom pillar files
      - can `exclude` certain platforms
        - legacy OS testing
        - Pre-release OS testing
  - Kitchen will create a matrix based on the `platforms` and `suites` so multiple Salt configurations can be run against multiple OSes.

In the previous section, [Initializing the test environment](#Initializing-the-test-environment), you should have noticed a difference between the `kitchen list` before and after editing the `.kitchen.yml` file. Mainly, there were two instances, `default-ubuntu-1404` and `default-centos-72`, which both had `ChefSolo` under the Provisioner column. After editing the file, you'll see we only have one instance, `default-bento-debian-88` and the Provisioner is SaltSolo.  The name of the instance is created by combining the **provisioner** and **suite** names, i.e. `default` and `bento-debian-88`.

### Introduction to kitchen converge
`kitchen converge` is one of the main commands you will use while developing a formula. It does two major things: it will create the instance and then it will apply the configuration to it. If the instance is already created, it will simply apply the configuration to it.

Give `kitchen converge` a try now:

```
$ kitchen converge
-----> Starting Kitchen (v1.16.0)
-----> Creating <default-bento-debian-88>...
       Bringing machine 'default' up with 'virtualbox' provider...
       ==> default: Importing base box 'bento/debian-8.8'...
==> default: Matching MAC address for NAT networking...
       ==> default: Checking if box 'bento/debian-8.8' is up to date...

...cut...

       [SSH] Established
       Vagrant instance <default-bento-debian-88> created.
       Finished creating <default-bento-debian-88> (0m42.55s).
-----> Converging <default-bento-debian-88>...
       Preparing files for transfer
       Preparing salt-minion
       Preparing pillars into /srv/pillar
       Preparing formula: example from /Users/btaylor/src/salt201/example-formula
>>>>>> ------Exception-------
>>>>>> Class: Kitchen::ActionFailed
>>>>>> Message: 1 actions failed.
>>>>>>     Failed to complete #converge action: [No such file or directory - /Users/btaylor/src/salt201/example-formula/example] on default-bento-debian-88
>>>>>> ----------------------
>>>>>> Please see .kitchen/logs/kitchen.log for more details
>>>>>> Also try running `kitchen diagnose --all` for configuration
```

You should run into an error highlighted by red text, similar to `Failed to complete #converge action: [No such file or directory - /Users/btaylor/src/salt201/example-formula/example] on default-bento-debian-88`, which is telling us that we have not created a configuration to apply to the instance. If you run `kitchen list`, you'll see two columns have changed: Last Action and Last Error.

```
$ kitchen list
Instance                 Driver   Provisioner  Verifier  Transport  Last Action  Last Error
default-bento-debian-88  Vagrant  SaltSolo     Busser    Ssh        Created      Errno::ENOENT
```

### Initializing the Salt Formula
Now that we are able to create a testing instance, we can create the file we need to begin configuring that instance.

  1. Make a new directory, `example`
  2. Make a new file inside that directory: `init.sls`
  3. Edit `init.sls` to have this content:
  
```
{% from "example/map.jinja" import example with context %}

example_formula_init:
  test.succeed_without_changes
```
    
  4. Create a new file inside the example directory, `map.jinja`
  5. Edit `map.jinja` to include this content:
  
```
{#
This file handles the merging of pillar data with the data from defaults
Start with defaults from defaults.yml
#}
{% import_yaml 'example/defaults.yml' as default_settings %}

{#
Setup variable using grains['os_family'] based logic, only add key:values here
that differ from whats in defaults.yml
#}
{% set os_family_map = salt['grains.filter_by']({
        'Debian': {},
        'Suse': {},
        'Arch': {},
        'RedHat': {},
  }
  , grain="os_family"
  , merge=salt['pillar.get']('example:lookup'))
%}

{#
Merge the flavor_map to the default settings
#}
{% do default_settings.example.update(os_family_map) %}

{#
Merge in template:lookup pillar
#}
{% set example = salt['pillar.get'](
        'example',
        default=default_settings.example,
        merge=True
    )
%}
```
    
  6. Create a new file inside the example directory, `defaults.yml`
  7. Edit `defaults.yml` to have this content:
  
```
example:
  enabled: false
```
    
  8. From the base `example-formula` directory, run `kitchen converge`

This `converge` should download and install Salt, then install some Ruby dependencies, then apply the Salt configuration. `converge` essentially runs `salt-call --local state.highstate` inside the instance.  The final output should be something similar to:

```
...cut...
       local:
         Name: example_formula_init - Function: test.succeed_without_changes - Result: Clean Started: - 13:22:48.700379 Duration: 0.618 ms

       Summary for local
       ------------
       Succeeded: 1
       Failed:    0
       ------------
       Total states run:     1
       Total run time:   0.618 ms
       Finished converging <default-bento-debian-88> (1m25.54s).
-----> Kitchen is finished. (1m25.96s)
```

Note that the we have a couple of lines of text that are green. This is complimentary to the error we ran into earlier which was highlighted in red text. Obviously, red is bad and green is good. Our first process to testing our configuration is to get all of our states to be green during a `converge`. Using `test.succeed_without_changes` is a very simple way to illustrate that our state applies but it doesn't actually change anything inside the instance. Let's move on to create some real changes.

## Introduction to Applying Real Changes

You may have noticed that our `defaults.yml` includes a line `enabled: false`. We did this on purpose to introduce the concept of a [feature toggle](https://en.wikipedia.org/wiki/Feature_toggle). In our state files, we can write simple `if` statements to see if certain things are enabled or not and apply different configurations accordingly. This main toggle is useful to protect us from unwhittingly applying destructive actions by using "two keys to launch a missle" logic. With that, the first thing we should do is check whether the formula is enabled.

  1. Edit the `example/init.sls` file
  2. Create an if statement to check if our formula is enabled by our pillar:
  
```
{% from "example/map.jinja" import example with context %}

{% if example.enabled %}
include:
  - example.install
{% else %}
example_formula_disabled:
  test.succeed_without_changes
{% endif %}
```

  3. Create a new file in the example directory, `install.sls`
  4. Edit the install.sls file to include this:
  
```
{% from "example/map.jinja" import example with context %}

example_install_dependent_pkgs:
  pkg.installed:
    - pkgs: {{ example.dep_pkgs }}
```

  5. Edit the defaults.yml file to define the dep_pkgs:
  
```
example:
  enabled: false
  dep_pkgs:
    - vim
    - htop
```

  6. Run `kitchen converge`, and you'll see that we didn't actually install any packages because we left `enabled: false`

```
Name: example_formula_disabled - Function: test.succeed_without_changes - Result: Clean Started: - 14:15:50.050452 Duration: 0.32 ms
```

  7. Edit the defaults.yml file to change `enabled` to `true`:

```
example:
  enabled: true
  dep_pkgs:
    - vim
    - htop
```

  8. Run `kitchen converge` and you should see some changes:

```
...cut...
       local:
       ----------
                 ID: example_install_dependent_pkgs
           Function: pkg.installed
             Result: True
            Comment: The following packages were installed/updated: htop, vim
            Started: 14:21:38.334174
           Duration: 19843.209 ms
            Changes:
              ----------
              htop:
                  ----------
                  new:
                      1.0.3-1
                  old:
              vim:
                  ----------
                  new:
                      2:7.4.488-7+deb8u3
                  old:
              vim-runtime:
                  ----------
                  new:
                      2:7.4.488-7+deb8u3
                  old:

       Summary for local
       ------------
       Succeeded: 1 (changed=1)
       Failed:    0
       ------------
       Total states run:     1
       Total run time:  19.843 s
       Finished converging <default-bento-debian-88> (0m30.48s).
-----> Kitchen is finished. (0m30.90s)
```

### Explanation of map.jinja
The most confusing of files we've created so far is certainly the `map.jinja`. There is a lot going on in this file but you should generally never have to edit it so it mostly suffices to understand the outcome without looking under the hood. This file references the `defaults.yml` file and merges the values with pillar that is defined elsewhere. This allows you to override the values which are present in `defaults.yml` without modifying the formula itself.

### Explanation of defaults.yml
This file is used to define sane defaults for the basic usage of the formula. Generally, when the formula is enabled, the these values should produce a state that is exactly the same as if you had manually run `apt install <program>`, or similar, and did no further modification. Usually, you'll want to define all toggles as `false` in this file, only overriding those values in other pillar files when necessary.

### Explanation of init.sls
This file is used to aggregate the sub-states that are available in the formula. In our simple example, we are only telling Salt "if the pillar value for 'enabled' is 'true' then run the things in the install.sls file". Additional state files would be referenced here as well. You can nest if statements here, too, if you need to only run certain state files if certain toggles are true.

### Explanation of install.sls
It's best to break up the configuration steps into separate files that are grouped into similar stages or functions. For instance, a typical workflow for installing a new piece of software is: install, configure, start the service. So, a typical formula would have `install.sls`, `configure.sls`, and `service.sls`.  The install steps would all be in the install.sls, all configuration steps would be in configure.sls, and any steps that would enable or restart a service would live in service.sls. Some applications may themselves be broken up into server and client packages, or even more packages, so it may make sense to create state files that match these different parts of the application.

## Manually Verifying the Changes

We successfully applied some changes to our instance and if we run `kitchen converge` again, Salt will tell us there are no new changes (our state is [idempotent](http://www.dictionary.com/browse/idempotent)). But, how can we be sure that our instance is actually in the state Salt says it is? Let's double-check the old school way: manually.

  1. Run `kitchen login`, this will log you into the instance. You should see a prompt like:

```
vagrant@default-bento-debian-88:~$
```

  2. We can use `dpkg` to check if our packages have been installed:

```
vagrant@default-bento-debian-88:~$ dpkg -l | grep vim
ii  vim                            2:7.4.488-7+deb8u3                 amd64        Vi IMproved - enhanced vi editor
ii  vim-common                     2:7.4.488-7+deb8u3                 amd64        Vi IMproved - Common files
ii  vim-runtime                    2:7.4.488-7+deb8u3                 all          Vi IMproved - Runtime files
ii  vim-tiny                       2:7.4.488-7+deb8u3                 amd64        Vi IMproved - enhanced vi editor - compact version
vagrant@default-bento-debian-88:~$ dpkg -l | grep htop
ii  htop                           1.0.3-1                            amd64        interactive processes viewer
```

  3. We can also use `which` to find the location of the binaries:

```
vagrant@default-bento-debian-88:~$ which vim
/usr/bin/vim
vagrant@default-bento-debian-88:~$ which htop
/usr/bin/htop
```

Great, Salt wasn't lying to us. Manually verifying our configuration isn't extremely difficult with only one state being applied but it can quickly become tedious if we have many states and many changes being applied to many instances. Wouldn't it be great if we could programatically verify our instance state?

## Introduction to kitchen verify

We successfully **provisioned** our instance and manually **verified** the changes. However, we can do better. As I mentioned before, one of the reasons we're using kitchen is because it is simple to write code to verify our instances which will be very useful when we start to automate our deployment process. When you run `kitchen list` you'll see `Busser` listed under the `Verifier` column. [Busser](https://github.com/test-kitchen/busser) is a framework that can use several plugins, but for our purposes we only need to know that [Serverspec](https://github.com/test-kitchen/busser-serverspec) is the default plugin. [Serverspec](http://serverspec.org/) is a special flavor of Rspec intended for verifying the configuration of servers. In order to use it, we will be writing Ruby code, but you'll see it can be quite simple and no prior knowledge of Ruby is necessary.

Run `kitchen verify`. You will see some Ruby gems get installed and then kitchen will attempt to run any Serverspec tests it can find. We haven't written any tests so your output will be similar to:

```
...cut...
       No examples found.

       Finished in 0.00027 seconds (files took 0.06029 seconds to load)
       0 examples, 0 failures

       Finished verifying <default-bento-debian-88> (3m20.20s).
-----> Kitchen is finished. (3m20.64s)
```

`verify` will always leave the instance running when it finishes. If you run `kitchen verify` when an instance is not running, it will create it, apply the configuration, test it, and leave it running whether it was successful or not.

## Creating a Serverspec Test

We need to create the proper directories in the form of [FORMULA]/test/integration/[SUITES]/serverspec/. Currently, we only have the `default` suite and the `kitchen init` command created most of this path for us. Serverspec also looks for specific files in these directories in the form of `*_spec.rb`.

  1. Create the `serverspec` directory under `example-formula/test/integration/default`
  2. Create a file in that directory, `default_spec.rb`
  3. Edit the default_spec.rb file to include this data:

```
require 'serverspec'

# Required by serverspec
set :backend, :exec

describe package("vim") do
  it { should be_installed }
end

describe package("htop") do
  it { should be_installed }
end
```

  4. From the base `example-formula` directory, run `kitchen verify`:

```
...cut...
       Package "vim"
         should be installed

       Package "htop"
         should be installed

       Finished in 0.08374 seconds (files took 0.30371 seconds to load)
       2 examples, 0 failures

       Finished verifying <default-bento-debian-88> (0m9.27s).
-----> Kitchen is finished. (0m9.70s)
```

You should see that our two tests have passed.

## Introduction to kitchen test
Now that we have successfully configured our instance and verified it's running state, we should ensure these things are true from a fresh start. The command `kitchen test` will do just that. It will clean up any running instances, recreate them, apply the configuration, verify the configuration, then destroy the instances when they are successful. If there is an error during the run, the instance will remain running so you can inspect it and fix your code. When `kitchen test` passes, you should have high confidence that your code is ready to be checked into your version control system.

  - Give `kitchen test` a try now.

Your tests should pass and `kitchen list` should confirm that there are no running instances as shown by "Not Created" under the "Last Action" column.

On your CI server, you will most likely want to use `kitchen test -d always` as the test command. The `-d always` option tells kitchen to always destroy the instances even if they fail. This will keep your CI environment clean.

## Introduction to kitchen destroy
`kitchen destroy` will destroy any running instances. You can use it before a `kitchen converge` to start fresh or to simply clean up when you are done coding. If there are no running intances, running `destroy` will simply confirm that.

## Test Driven Development
Now that we know how to write tests, we can create them first so they fail. Then we can write the code to apply configuration that will allow them to pass.

### Write a failing test

  1. Edit the `test/integration/default/serverspec/default_spec.rb` file to have this data:

```
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
```

  2. Run `kitchen verify`, this should fail.

```
       Package "vim"
         should be installed

       Package "htop"
         should be installed

       File "/root/example.conf"
         should exist (FAILED - 1)

       Failures:

         1) File "/root/example.conf" should exist
            Failure/Error: it { should exist }
              expected File "/root/example.conf" to exist
              /bin/sh -c test\ -e\ /root/example.conf

            # /tmp/verifier/suites/serverspec/default_spec.rb:15:in `block (2 levels) in <top (required)>'

       Finished in 0.1042 seconds (files took 0.31661 seconds to load)
       3 examples, 1 failure

       Failed examples:

       rspec /tmp/verifier/suites/serverspec/default_spec.rb:15 # File "/root/example.conf" should exist

       /usr/bin/ruby2.1 -I/tmp/verifier/suites/serverspec -I/tmp/verifier/gems/gems/rspec-support-3.6.0/lib:/tmp/verifier/gems/gems/rspec-core-3.6.0/lib /tmp/verifier/gems/bin/rspec --pattern /tmp/verifier/suites/serverspec/\*\*/\*_spec.rb --color --format documentation --default-path /tmp/verifier/suites/serverspec failed
       !!!!!! Ruby Script [/tmp/verifier/gems/gems/busser-serverspec-0.5.10/lib/busser/runner_plugin/../serverspec/runner.rb /tmp/verifier/suites/serverspec] exit code was 1
>>>>>> ------Exception-------
>>>>>> Class: Kitchen::ActionFailed
>>>>>> Message: 1 actions failed.
>>>>>>     Verify failed on instance <default-bento-debian-88>.  Please see .kitchen/logs/default-bento-debian-88.log for more details
>>>>>> ----------------------
>>>>>> Please see .kitchen/logs/kitchen.log for more details
>>>>>> Also try running `kitchen diagnose --all` for configuration
```

### Write configuration to make the test pass

  1. Create a new file, `example/config.sls`
  2. Edit `config.sls` to have this data:

```
{% from "example/map.jinja" import example with context %}

example_configure_file:
  file.managed:
    - name: /root/example.conf
    - user: root
    - group: root
    - mode: 644
    - contents:
      - This is the contents of the file
```

  3. Edit `example/init.sls` to include the new config.sls file:

```
{% from "example/map.jinja" import example with context %}

{% if example.enabled %}
include:
  - example.install
  - example.config
{% else %}
example_formula_disabled:
  test.succeed_without_changes
{% endif %}
```

  4. Run `kitchen converge` to apply the new configuration.

```
...cut...
       local:
         Name: example_install_dependent_pkgs - Function: pkg.installed - Result: Clean Started: - 19:53:26.591894 Duration: 300.801 ms
       ----------
                 ID: example_configure_file
           Function: file.managed
               Name: /root/example.conf
             Result: True
            Comment: File /root/example.conf updated
            Started: 19:53:26.895476
           Duration: 6.417 ms
            Changes:
              ----------
              diff:
                  New file
              mode:
                  0644

       Summary for local
       ------------
       Succeeded: 2 (changed=1)
       Failed:    0
       ------------
       Total states run:     2
       Total run time: 307.218 ms
       Finished converging <default-bento-debian-88> (0m11.04s).
-----> Kitchen is finished. (0m11.46s)
```

  5. Run `kitchen verify` to see if our tests pass

```
...cut...
       Package "vim"
         should be installed

       Package "htop"
         should be installed

       File "/root/example.conf"
         should exist

       Finished in 0.10839 seconds (files took 0.29366 seconds to load)
       3 examples, 0 failures

       Finished verifying <default-bento-debian-88> (0m9.44s).
-----> Kitchen is finished. (0m9.89s)
```

## Add a new suite
We can add a new suite with it's own pillar definition that will override the default settings.

### Create the new suite definition

  1. Create a new file in the base directory called `pillar-custom.sls`
  2. Edit `pillar-custom.sls` to have the following data:

```
example:
  dep_pkgs:
    - nmap
    - strace
```

  3. Edit `.kitchen.yml` to define the new suite:

```
---
driver:
  name: vagrant

provisioner:
  name: salt_solo
  formula: example
  state_top:
    base:
      "*":
        - example

platforms:
  - name: bento/debian-8.8

suites:
  - name: default
  
  - name: custom
    provisioner:
      pillars-from-files:
        example.sls: pillar-custom.sls
      pillars:
        top.sls:
          base:
            "*":
              - example
```

  4. Run `kitchen list` to see the new `custom-bento-debian-88` instance listed

```
$ kitchen list
Instance                 Driver   Provisioner  Verifier  Transport  Last Action    Last Error
default-bento-debian-88  Vagrant  SaltSolo     Busser    Ssh        Verified       <None>
custom-bento-debian-88   Vagrant  SaltSolo     Busser    Ssh        <Not Created>  <None>
```

  5. Run `kitchen converge` to create the new instance and apply the configuration. You should see several packages get installed and the example.conf file created.

```
...cut...
       local:
       ----------
                 ID: example_install_dependent_pkgs
           Function: pkg.installed
             Result: True
            Comment: The following packages were installed/updated: nmap, strace
            Started: 20:25:22.617590
           Duration: 20052.332 ms
            Changes:
              ----------
              ...cut...
              nmap:
                  ----------
                  new:
                      6.47-3+deb8u2
                  old:
              strace:
                  ----------
                  new:
                      4.9-2
                  old:
       ----------
                 ID: example_configure_file
           Function: file.managed
               Name: /root/example.conf
             Result: True
            Comment: File /root/example.conf updated
            Started: 20:25:42.672789
           Duration: 12.178 ms
            Changes:
              ----------
              diff:
                  New file
              mode:
                  0644

       Summary for local
       ------------
       Succeeded: 2 (changed=2)
       Failed:    0
       ------------
       Total states run:     2
       Total run time:  20.065 s
       Finished converging <custom-bento-debian-88> (1m48.08s).
-----> Kitchen is finished. (2m31.51s)
```

You'll notice that `kitchen converge` now runs through both instances one after the other and shows their output in different colors. If you want to target one specific instance, you can add it's name onto the end or part of the name as shorthand: `kitchen converge custom`.

### Create tests for the new suite

  1. Copy the `test/integration/default` directory to `test/integration/custom`

```
$ cp -R test/integration/default test/integration/custom
```

  2. Edit the `test/integration/custom/serverspec/default_spec.rb` file to include this data:

```
require 'serverspec'

# Required by serverspec
set :backend, :exec

describe package("vim") do
  it { should be_installed }
end

describe package("htop") do
  it { should be_installed }
end

describe package("nmap") do
  it { should be_installed }
end

describe package("strace") do
  it { should be_installed }
end

describe file("/root/example.conf") do
  it { should exist }
end
```

  3. Run `kitchen verify` and the test should fail because we did not install vim or htop. The `dep_pkgs` pillar value was overriden in our pillar-custom.sls.

```
...cut...
       Package "vim"
         should be installed (FAILED - 1)

       Package "htop"
         should be installed (FAILED - 2)

       Package "nmap"
         should be installed

       Package "strace"
         should be installed

       File "/root/example.conf"
         should exist

       Failures:

         1) Package "vim" should be installed
            Failure/Error: it { should be_installed }
              expected Package "vim" to be installed
              /bin/sh -c dpkg-query\ -f\ \'\$\{Status\}\'\ -W\ vim\ \|\ grep\ -E\ \'\^\(install\|hold\)\ ok\ installed\$\'

            # /tmp/verifier/suites/serverspec/default_spec.rb:7:in `block (2 levels) in <top (required)>'

         2) Package "htop" should be installed
            Failure/Error: it { should be_installed }
              expected Package "htop" to be installed
              /bin/sh -c dpkg-query\ -f\ \'\$\{Status\}\'\ -W\ htop\ \|\ grep\ -E\ \'\^\(install\|hold\)\ ok\ installed\$\'

            # /tmp/verifier/suites/serverspec/default_spec.rb:11:in `block (2 levels) in <top (required)>'

       Finished in 0.1395 seconds (files took 0.32726 seconds to load)
       5 examples, 2 failures

       Failed examples:

       rspec /tmp/verifier/suites/serverspec/default_spec.rb:7 # Package "vim" should be installed
       rspec /tmp/verifier/suites/serverspec/default_spec.rb:11 # Package "htop" should be installed

       /usr/bin/ruby2.1 -I/tmp/verifier/suites/serverspec -I/tmp/verifier/gems/gems/rspec-support-3.6.0/lib:/tmp/verifier/gems/gems/rspec-core-3.6.0/lib /tmp/verifier/gems/bin/rspec --pattern /tmp/verifier/suites/serverspec/\*\*/\*_spec.rb --color --format documentation --default-path /tmp/verifier/suites/serverspec failed
       !!!!!! Ruby Script [/tmp/verifier/gems/gems/busser-serverspec-0.5.10/lib/busser/runner_plugin/../serverspec/runner.rb /tmp/verifier/suites/serverspec] exit code was 1
>>>>>> ------Exception-------
>>>>>> Class: Kitchen::ActionFailed
>>>>>> Message: 1 actions failed.
>>>>>>     Verify failed on instance <custom-bento-debian-88>.  Please see .kitchen/logs/custom-bento-debian-88.log for more details
>>>>>> ----------------------
>>>>>> Please see .kitchen/logs/kitchen.log for more details
>>>>>> Also try running `kitchen diagnose --all` for configuration
```

  4. Edit the `test/integration/custom/serverspec/default_spec.rb` file and remove the tests for vim and htop:

```
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
```

  5. Run `kitchen verify` and all of the tests should pass.

```
       Package "nmap"
         should be installed

       Package "strace"
         should be installed

       File "/root/example.conf"
         should exist

       Finished in 0.08544 seconds (files took 0.30702 seconds to load)
       3 examples, 0 failures

       Finished verifying <custom-bento-debian-88> (0m8.90s).
-----> Kitchen is finished. (0m18.71s)
```

## Other Kitchen Configs
Typically, it is quicker to develop locally using things like Vagrant and Virtualbox but the production environment will most likely be slightly different, running in a Cloud or with Docker. It is possible to configure more than one `.kitchen.yml` file to use a different driver to deploy to these other environments.

  - Environment Variables
    - `KITCHEN_YAML` defaults to `.kitchen.yml`
    - `KITCHEN_LOCAL_YAML` defaults to `.kitchen.local.yml`
      - typically added to `.gitignore` so as to not upload local configuration to public repositories
    - `KITCHEN_GLOBAL_YAML` defaults to `$HOME/.kitchen/config.yml`
  - The `.kitchen-ci.yml` file
    - define a new driver and settings for use in the CI system
    - can use for local testing too
      - `KITCHEN_YAML=./.kitchen-ci.yml kitchen converge`

### Create a Kitchen CI Config
In this example, we will use the `kitchen-linode` driver, but [many more drivers are available](https://docs.chef.io/kitchen.html#drivers) (ec2, docker, openstack, digital ocean, etc.).

  1. In the base directory, `example-formula`, copy `.kitchen.yml` to `.kitchen-ci.yml`
  2. Edit the `.kitchen-ci.yml` file, change the Driver and Platform names
  
```
---
driver:
  name: linode

provisioner:
  name: salt_solo
  formula: example
  state_top:
    base:
      "*":
        - example

platforms:
  - name: debian-8

suites:
  - name: default
  
  - name: custom
    provisioner:
      pillars-from-files:
        example.sls: pillar-custom.sls
      pillars:
        top.sls:
          base:
            "*":
              - example
```

  3. Save and exit the file
  4. Ensure your `LINODE_API_KEY` environment variable is set
  5. run `KITCHEN_YAML=./.kitchen-ci.yml kitchen converge`. You should see log lines like:

```
-----> Creating <default-debian-8>...
       Creating Linode - kitchen-example-formula-defaul12
       Got data center: Atlanta, GA, USA...
       Got flavor: Linode 1024...
       Got image: Debian 8...
       Got kernel: Latest 64 bit (4.9.36-x86_64-linode85)...
       Linode <3466956> created.
       Waiting for linode to boot...
```

  6. Log into the Linode Manager to see two new instances listed
  7. run `KITCHEN_YAML=./.kitchen-ci.yml kitchen destroy` to clean up

So, using this example, the CI server will need the `test-kitchen`, `kitchen-salt`, and `kitchen-linode` gems installed. You'll need to define a Linode API Key to use. Then you'll need to define a command like `KITCHEN_YAML=./.kitchen-ci.yml kitchen test -d always` for the test or build step of the CI run.

  1. Run `KITCHEN_YAML=./.kitchen-ci.yml kitchen test -d always` to fully simulate a CI test
  2. All configuration should apply successfully and all tests should pass. Kitchen should fully clean up after itself.
  3. Check the Linode Manager to verify that there are no test instances still running.

## CI Automation Concepts
The exact steps for automating CI steps depends on your specific tooling but the concepts for triggering automation are the same. You can utilize APIs to trigger events in other systems. Very simply, the steps are:

  1. On code commit or PR opening in Github, a webhook is sent to Jenkins
  2. Jenkins pulls the code and runs the tests
  3. When the tests pass, a webhook is sent to the Salt Master (running salt-api)
  4. The Salt Master performs a git pull to get the new code
  5. A Highstate is performed to deploy the changes to the fleet

If you have all of these steps configured to be automated, you can honestly say that you are practicing [Continuous Deployment](https://en.wikipedia.org/wiki/Continuous_delivery#Relationship_to_continuous_deployment), at least for a small part of your environment. Depending on which of the steps require manual approval, you may only be practicing Continuous Integration or Continuous Delivery.

Configuring version control, a CI server, and Salt API are outside the scope of this class but are presented here to illustrate how kitchen tests fit into the equation.

**Congratulations! You can now create test driven formulas for Salt and Continous Integration!**
