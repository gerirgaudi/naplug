# Naplug

*Naplug* is a [Nagios plugin](http://nagiosplug.sourceforge.net/developer-guidelines.html) library for Ruby focused on plugin internals: organization, status, performance data, output and exit code handling. It does not implement any functionality related to option and argument parsing, as there are fine tools already available for this purpose. It aims to ease the task of writing Nagios plugins in Ruby and _handling the paperwork_, allowing the plugin developer to concentrate on the test logic of the plugin. Its internal design is largely modeled after the very excellent [Worlkflow](https://github.com/geekq/workflow) library.

*Naplug* allows plugins to contain other plugins (referred to as *plugs*), which are a useful abstraction to break up significant tasks that the plugin as a whole must perform in order to determine the state of a service or host. The status and output of these plugs is thus used to determine the overall status of the plugin and build the output depending on said status.

While *Naplug* handles the nitty-gritty of Nagios plugins, it is important to have familiarity with the [Nagios Plugin Developer Guidelines](http://nagiosplug.sourceforge.net/developer-guidelines.html).

#### Note

* *Naplug* `1.x` is incompatible with *Naplug* `0.x` (`0.x` was never released as a Gem)
* *Naplug* `1.x` is only supported on Ruby 1.9 and above; it will not be backported to 1.8

## Overview

Naplug approaches Nagios plugins as Ruby classes (note that `plugin` is a reserved keyword at both the class and instance levels). To use *Naplug*, install the gem and:

    #!/usr/bin/end ruby -rubygems
    require 'naplug'
    
    class MyPlugin
      include Naplug
      plugin do |p|
        ...
      end  
    end
    
    MyPlugin.new.exec!
    
    
All examples will omit the `require`s for readability.
 
A very simple plugin that always returns an OK status:
    
    class AlwaysOkPlugin

      include Naplug

      plugin do |p|
        p.status.ok!
        p.output! "Optimism level: 100%"
      end
    end

    AlwaysOkPlugin.new.exec!

In the above example, a new class `AlwaysOkPlugin` is defined (the class name is arbitrary), and within this class, a plugin is created, which performs some work to set the status and output of the plugin. Once the class is defined, a new instance of the plugin is created and executed. The `exec!` method executes the plugin, evaluates status, produces correctly formatted output, and exits with the appropriate exit code:

    naplug@plugin:~: alwaysok 
    OK: Optimism level: 100%
    naplug@plugin:~: echo $?
    0 

A less optimistic example, this time with arguments:

    class AlmostAlwaysOkPlugin

      include Naplug

      plugin do |p|

        p.output! "Optimism level: #{p[:optimism]}%"

        case p[:optimism]
          when 23..100 then p.status.ok!
          when 6..22   then p.status.warning!
          when 0..5    then p.status.critical!
          else
            p.output! "utterly confused"
        end

      end
    end

    plugin = AlmostAlwaysOkPlugin.new :optimism => Random.rand(100)
    plugin.exec!
    
Which yields:

    naplug@plugin:~: almostalwaysok 
    OK: Optimism level: 96%
    naplug@plugin:~: echo $?
    0
    
And

    naplug@plugin:~: almostalwaysok 
    WARNING: Optimism level: 9%
    naplug@plugin:~: echo $?
    1

## Plugins

*Plugins* are defined inside a new class with the `plugin` keyword. Plugins are always initialized in an `UNKNOWN` state and with their output set to `uninitialized plugin`, since at that point, the status of the plugin has not been determined. This ensures that misbehaved plugins correctly notify Nagios that they are failing in some way (for instance, if there's an unhandled exception, at which point the output will be set to useful information about the exception).

### Tags

Plugins can be tagged, and tags *must* be unique within a class. Tags are used to identify a plugin, which is useful when multiple plugins are defined in a single class, which may be necessary in cases where several implementations of tests are required. A plugin's tag defaults to `main` when not specified.

Plugins can be accessed through _tag_ methods, and executed through _tag!_ methods.

    class MultiPlugin
    
      include Naplug
      
      plugin :foo do |p|
        ...
      end
    
      plugin :bar do |p|
        ...
      end
      
    end
    
    plugin = MultiPlugin.new
    case condition
      when true then plugin.foo!
      else plugin.bar!
    end
    
When defining multiple plugins, invoking `exec!` will execute the `main` plugin (if defined; otherwise, `exec!` is unable to decide which one to execute). When defining a single plugin, `exec!` will execute it regardess of tag.


### Arguments

A plugin can accept [mostly] arbitrary arguments, which are entirely optional and are available through the *[]* notation. *Naplug* (again, mostly) attaches no special meaning to them, i.e., they can be used in any way they need to be used.
    
A more realistic example that checks the staleness of a marker file:

    class MarkerFilePlugin

      include Naplug

      plugin do |p|
	      if Time.now - File.mtime(p[:marker_file]) > p[:critical]
	        p.status.critical!
	        p.output! "marker file #{p[:marker_file]} mtime greater than #{p[:critical]} seconds"
  	      else
  	        p.status.ok!
  	        p.output! "marker #{p[:marker_file]} is up to date"
  	      end
      end
    end

    plugin = MarkerFilePlugin.new :marker_file => '/tmp/my_marker', :critical => 120
    plugin.exec!    

There are some worthwhile observations about the above example. A missing marker file prevents determining the stalesness of said file (infinite staleness?), implicitly resulting in an `UNKNOWN` status and output corresponding to the message of the exception. For finer control of this behavior, exceptions can be raised inside the plugin, which will be handled internally:

    plugin do |p|
      raise Errno::ENOENT, p[:marker_file] unless File.exists? p[:marker_file]
      ...
    end

The exception object is available through the `payload`. This only applies to exceptions raised *inside* the `plugin` block.

Arguments can also be specified via the `args!` method:

    class ArgumentsPlugin
    
      include Naplug
      
      plugin do |p|
        ...
      end
      
    end
    
    plugin = ArgumentsPlugin.new :foo => 'old argument'
    plugin.args! :foo => 'new argument'
    
The above code will override the `:foo` argument with a value of `new argument`.

### Exceptions and `eject!`

Plugins operate in restricted runtime environments: Nagios expects the proper exit code and output. Naplug makes every effort to properly handle unexpected exceptions when executing plugins, and where it can't, it propagates them bundled in the `Naplug::Error` exception, which is about the only exception (from Naplug's point of view) that needs to be handled:

    class ExceptionPlugin
    
      include Naplug
      
      plugin do |p|
        raise p[:exception], "raised exception: #{p[:exception]}"
      end
      
    end
    
    begin
      plugin = ExceptionPlugin.new :exception => StandardError
      plugin.exec!
    rescue Naplug::Error => e
      plugin.eject! e
    end
    
Which produces:

    naplug@plugin:~: examples/exception 
    UNKNOWN: exception:18: raised exception: StandardError
    naplug@plugin:~: echo $?
    3

The `eject!` method, which accepts a message string or an exception object as an argument, provides a last-ditch effort, out-of-band, escape hatch to bail out of executing a plugin, producing an `UNKNOWN` status and output from the message string or exception object.

While Naplug will internally handle exceptions within a plugin, it may be desirable to handle them especifically:

    class ExceptionPlusPlugin

      include Naplug

      EXCEPTIONS = [ ArgumentError, ZeroDivisionError, TypeError ]

      plugin do |p|

        exception = EXCEPTIONS[p[:exception]]

        begin
          raise exception, "raising exception: #{exception}"
        rescue ArgumentError => e
          raise
        rescue ZeroDivisionError => e
          p.status.ok!
          p.output! "divided by zero is infinity"
        rescue => e
          p.status.critical!
          p.output! "got exception #{e.class}"
        end

      end

    end
    
    begin
      plugin = ExceptionPluginPlus.new :exception => Random.rand(3)
      plugin.exec!
    rescue Naplug::Error => e
      plugin.eject! e
    end
    
Which produces:

    naplug@plugin:~: examples/exception+
    UNKNOWN: exception+:24: raising exception: ArgumentError
    naplug@plugin:~: examples/exception+
    CRITICAL: got exception TypeError
    naplug@plugin:~: examples/exception+
    OK: divided by zero is infinity

### Plugs: Plugins within Plugins 

Up until now, *Naplug* has essentially provided *syntactic sugar* to define and use what amounts to single-purpose plugins, along with some convenience methods to represent status and produce output. But plugins sometimes need to perform a number of possibly independent tasks to reach a final, _aggregated_ status.

In *Naplug*, these tasks are _nested plugins_ or _subplugins_, and are referred to as *plugs* scoped to a _parent_ plugin. When a plugin is created, we can define *plugs* inside the plugin through the `plugin` instance method. Again, these can be tagged, and plug tags must be unique, this time within a plugin.

    class PlugPlugin
    
      include Naplug
    
      plugin do |p|
    
        plugin :plug1 do |p1|
          ...
        end
      
        plugin :plug2 do |p2|
          ...
        end
      
      end
    end
    
Defining plugs imposes one important limitation: no other code besides plug definitions is allowed (in reality, it is allowed, just never really during executed).

    class PluggedPlugin
    
      include Naplug
      
      plugin do |p|
      
        <do something here>     # will not be executed
      
        plugin :plug1 do |p1|
          ...
        end
        
        plugin :plug2 do |p2|
          ...
        end
        
        <do somthing else here>  # will not be executed
      end
      
    end
    
#### Order of Execution

When `exec!` is invoked on a plugin, plugs are executed in the order in which they are defined, which is a side-effect of the fact that plugs are inserted into a Hash to keep track of them: [Hashes enumerate their values in the order that the corresponding keys were inserted](http://www.ruby-doc.org/core-1.9.3/Hash.html). Execution order can only be controlled manually:

    plugin.exec :plug2
    plugin.exex :plug1

#### Arguments

With the introduction of *plugs*, arguments do become more structured, as arguments keys are matched to plugin and plug tags to route them appropriately.

    plugin = PlugPlugin.new(:plug1 => { :critical => 120, :warning => 60 },
                            :plug2 => { :ok => 0, :warning => 5, :critical => 10 })

Any keys not matching plug tags are considered to be shared among all plugs:

    plugin = PlugPlugin.new(:file => '/tmp/file',
	                        :plug1 => { :critical => 120, :warning => 60 }, 
                            :plug2 => { :ok => 0, :warning => 5, :critical => 10 })
                                  
Tagged arguments have priority over shared ones.

    plugin = PlugPlugin.new(:file => '/tmp/file', 
                            :plug1 => { :file => '/var/tmp/file', :critical => 120 },
                            :plug2 => { :ok => 0, :warning => 5, :critical => 10 })
                            
#### A Plugged Plugin Example

Take a service for which we wish to monitor three conditions:

* that the service is running one and only one process
* that the log file has seen activity within the last 60 seconds
* that some metric related to the service (number of files in a queue) is within acceptable thresholds

Each of these tasks can be a plug, and Naplug will take care of aggregating the statuses to yield a plugin status (worst always wins).

    require 'sys/proctable'
    require 'naplug'
    
    class MultiPlugServicePlugin
    
        include Naplug
        
        plugin do |p|
        
          plug :proc_count do |p1|
            pids = Sys::ProcTable.ps.each do |ps|...
            case pids.size
              when 1
                p1.status.ok
                p1.output "process #{p1[:name]} running with pid #{pids[0]}"
              when 0
                p1.status.critical
                p1.output "process #{p1[:name]} not running"
              else
                p1.status.critical
                p1.output "multiple #{p1[:name]} processes found, pids #{pids.join(',')}"
            end
          end
        
          plug :log_mtime do |p2|
            delta = Time.now - File.mtime(p2[:log_file])
            if delta > p2[:critical]
	            p2.status.critical
	            p2.output "p2[:name] log file #{p2[:log_file]} mtime greater than #{p2[:critical]} seconds"
  	          else
  	            p2.status.ok
  	            p2.output "marker #{p2[:log_file]} is up to date"
  	          end
          end
          
          plug :queue_depth do |p3|
            num_files = Dir.entries(p3[:dir]).length - 2
            p3.output "queue depth: #{num_files} items"
            
            case num_files
              when 0..100    then p3.status.ok
              when 101..1000 then p3.status.warning
              else                p3.status.critical
             end          
          end
          
        end        
    end
    
    plugin = MultiPlugServicePlugin.new :name => 'foobard'
    plugin[:log_mtime] = { :log_file => '/var/log/foobard.log' }
    plugin[:queue_depth] = { :dir => '/var/spool/foobard' }
    plugin.exec!

## Naplug Methods

### Class Methods

Whenever Naplug in included in a class, the following class methods are available:

* `plugin`, which is used to create plugins
* `tags`, which returns an array of defined plugin tags

### Instance Methods

In addition to the above class methods, the followingh instance methods are available:

* `args` and `args!` to retrieve and set arguments
* `exec!`, `exec` and `eval` to exec-to-exit, exec and evaluate plugins, respectively
* `has_plugins?`, which evaluates to true if a plugin has plugs
* `[]` and `[]=` to get and set specific arguments
* `to_str` to produce formatted plugin output
* `eject!`, to quickly bail out
* `enable!` and `enabled?`, `disable!` and `disabled?`, for enable and disabled plugs

Overriding these will likely cause *Naplug* to misbehave, to say the least.

Other methods can be defined in the class as necessary, and they can be used in the defined plugins or plugs, generally to provide helpers services. These should be defined as `private` or `protected` as necessary.
     
### Status

Status is a special object that represent the status of a plugin for each of the defined states in the [Nagios Plugin Guidelines](http://nagiosplug.sourceforge.net/developer-guidelines.html): `OK`, `WARNING`, `CRITICAL` and `UNKNOWN`. Each of these states is itself an instance method which sets the state, and you can obtain the string and numeric representation through the usual methods `to_s` and `to_i`. The initial (and default) status of a `Status` object is `UNKNOWN`. Statuses are comparable in that larger statuses represent worse states, a feature that will come handy shortly.

    require 'naplug/status'

    puts "All statuses:"
    Naplug::Status.states.each do |state|
      status = Naplug::Status.new state
      puts "  status #{status} has exit code #{status.to_i}"
    end

    puts "Working with a status:"
    status = Naplug::Status.new
    puts "  status #{status} has exit code #{status.to_i}"
    status.ok!
    puts "  status #{status} has exit code #{status.to_i}"
    
    puts "Comparing statuses:"
    status1 = Naplug::Status.new :warning
    if status < status1
      puts "  status [#{status}] < status1 [#{status1}] is true"
    end

which produces

    naplug@plugin:~: status 
    All statuses:
      status OK has exit code 0
      status WARNING has exit code 1
      status CRITICAL has exit code 2
      status UNKNOWN has exit code 3
    Working with a status:
      status UNKNOWN has exit code 3 after initialization
      status OK has exit code 0 after status.ok
    Comparing statuses:
      status [OK] < status1 [WARNING] is true

# Futures

There following are some ideas on future Naplug features.

### Order of Execution

A future release will allow the execution order to be changed through an `order!` instance method, which will accept a list of tags in the desired order of execution.

    plugin.order! :plug2, :plug1
    
If tags are omitted from the list, the missing plugs are pushed to the end of the line in the last order set.

#### Enabling and Disabling Plugs

Currently, when plugs are defined, they are assumed to be enabled and will be executed when `exec!` is invoked. There may be cases when it may be desirable or necessary to disable specific plugins, which will be accomplished through the `disable!` instance method. A disabled plug can be re-enabled via the `enable!` plugin method:

    plugin.disable! :plug2
    
Disabled plugs will not be executed and will not be taken into account when evaluating status. The active state of a plugin can be queried via the `enabled?` and `disabled?` methods.

    plugin.enabled? :plug2 => false
    plugin.disabled? :plug2 => true
    
Aditionally, `is_<tag>_enabled?` and `is_<tag>_disabled?` methods will be available for each plug.
