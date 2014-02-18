# Naplug

*Naplug* is a [Nagios plugin](http://nagiosplug.sourceforge.net/developer-guidelines.html) library for Ruby focused on plugin internals: organization, status, performance data, output and exit code handling. It does not implement any functionality related to option and argument parsing, as there are a great deal of great resources to do so already. It aims to ease the task of writing Nagios plugins in Ruby and _handling the paperwork_, allowing the plugin developer to concentrate on the test logic of the plugin. It is largely modeled after the very excellent [Worlkflow](https://github.com/geekq/workflow) library.

*Naplug* introduces the concept of a *plug*, which is a useful abstraction to break up significant tasks that the plugin as a whole must perform in order to determine the state of a service or host. Plugs, like plugins, have status and output, which are used to determine the overall status of the plugin and build the output depending on said status.

While *Naplug* handles the nitty-gritty of Nagios plugins, it is important to have familiarity with the [Nagios Plugin Developer Guidelines](http://nagiosplug.sourceforge.net/developer-guidelines.html).

At its core, a Nagios plugin is a program that evaluates test conditions and yields back status and output.  These must be returned correctly formatted so that Nagios can interpret them correctly.

## Overview

Naplug approaches Nagios plugins as Ruby classes. A very simple plugin that always returns an OK status:

    require 'naplug'
    
    class AlwaysOkPlugin

      include Naplug

      plugin do |p|
        p.status.ok!
        p.output! "Optimism level: 100%"
      end
    end

    AlwaysOkPlugin.new.exec!

In the above example, a new class is defined (the class name is arbitrary), and within this class, a plugin is created, which performs some work to set the status and output of the plugin. Once the class is defined, a new instance of the plugin is created and executed. The `exec!` method runs the plugin, evaluates status, formats and produces correctly formatted output, and exits with the appropriate exit code:

    naplug@plugin:~: alwaysok 
    OK: Optimism level: 100%
    naplug@plugin:~: echo $?
    0 

A less optimistic example, this time with arguments:

    require 'naplug'

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

As seen in the examples above, *plugins* are defined inside a new class with `plugin`. Plugins are always initialized with an `UNKNOWN` state and their output set to `uninitialized plugin`, since at that point, the status of the plugin has not been determined. This ensures that misbehaved plugins correctly notify Nagios that they are failing in some way (for instance, if there's an unhandled exception).

### Tags

Plugins can be tagged, which is useful in cases where multiple plugins are defined in a single class. This may be necessary in cases where multiple implementations of tests are required. A plugin's tag defaults to `main` when not specified.

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
    
When defining multiple plugins, it is not possible to use the `exec!` method, since only one plugin can be executed.

### Arguments

A plugin can accept [mostly] arbitrary arguments, which are entirely optional and are available through the *[]* notation. *Naplug* (again, mostly) attaches no special meaning to them, i.e., they can be used in any way they need to be used.
    
A more realistic example that checks the staleness of a marker file:

    require 'naplug'

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

The above example with some added flexibility and robustness:

    require 'naplug'
    
    class MarkerFilePlusPlugin
    
      include Naplug
    
      plugin do |p|
        begin
          delta = Time.now - File.mtime(p[:marker_file])
          p.output! "marker file is %d seconds out of date" % [delta]
          case
            when delta < p[:w_seconds]
              p.status.ok!
              p.output! 'marker file %s is up to date' % [args[:marker_file]]
            when (p[:w_seconds]..p[:c_seconds]).include?(delta)
              p.status.warning!
            when delta >= p[:c_seconds]
              p.status.critical!
            end
          rescue Errno::ENOENT => e
            p.status.unknown!
            p.output! "marker file %s does not exist" % [p[:marker_file]]
            p.payload! e
          end
        end
      end
    end
    
    plugin = MarkerFilePlugin.new :marker_file => '/tmp/my_marker', :c_seconds => 120, :w_seconds => 60
    plugin.exec!

There are some worthwhile observations about the above example. A missing marker file prevents determining the stalesness of said file (infinite staleness?), resulting in an `UNKNOWN` status. Catching this is not strictly necessary, since plugins initially have a `UNKNOWN` status. There are however instances where it may be useful to specifically do this. Note that the entire exception object is available through the `payload`.

## Naplug Methods

Whenever Naplug in included in a class, several methods are available:

* `status`
* `output`
* `payload`
* `performance`
* `exec!`, `exec` and `eval`
* `[]` and `[]=`

Overriding these will likely cause *Naplug* to misbehave, to say the least.

### Helpers

Plugins sometimes need helpers, and this can be accomplished by defining `private` methods in the class, which can then be used by the plugin. `Naplug` does not enforce the privacy of the said helpers, but it's good form to make them so.

    require 'naplug'

    class MarkerFilePlusPlusPlugin

      include Naplug

      plugin do |p|
        delta, size = file_delta_and_size p[:marker_file]
        case
          when (delta < p[:w_secs] and size > p[:c_size])
            p.status.ok!
            p.output! "marker file %s is up to date and not empty" % [p[:marker_file]]
          when ((p[:w_secs]..p[:c_secs]).include?(delta) and size > p[:c_size])
            p.status.warning!
            p.output! "marker file is %d seconds out of date" % [delta]
          when (delta >= p[:c_secs] or size == p[:c_size])
            p.status.critical!
            p.output! "marker file is %d seconds out of date or empty" % [delta]
          else
            p.outout! "marker file is in an inconsistent state"
        end
      end

      private

      def file_delta_and_size(file)
        fs = File.stat file
        return Time.now - fs.mtime,fs.size
      end
    
    end
    
    plugin = MarkerFilePlusPlusPlugin.new :marker_file => '/tmp/my_marker', :c_secs => 120, :w_secs => 60, :c_size => 0
    plugin.exec!
     
### Status

Status is a special object that represent the status of a plugin for each of the defined state in the [Nagios Plugin Guidelines](http://nagiosplug.sourceforge.net/developer-guidelines.html): `OK`, `WARNING`, `CRITICAL` and `UNKNOWN`. Each of these states is itself an instance method which sets the state, and you can obtain the string and numeric representation through the usual methods `to_s` and `to_i`. The initial (and default) status of a `Status` object is `UNKNOWN`. Statuses are comparable in that larger statuses represent worse states, a feature that will come handy shortly.

    require 'naplug/status'

    puts "All statuses:"
    Naplug::Status.states.each do |state|
      status = Naplug::Status.new state
      puts "  status #{status} has exit code #{status.to_i}"
    end

    puts "Working with a status:"
    status = Naplug::Status.new
    puts "  status #{status} has exit code #{status.to_i}"
    status.ok
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

### Plugs
 
Up until now, *Naplug* has essentially provided *syntactic sugar* to define and use plugins, along with some convenience methods to represent status and produce output. But plugins sometimes need to perform a number of possibly independent tasks to reach a final, _aggregated_ status. In *Naplug*, these tasks are referred to as *plugs* are identified by *tags*. Plugs are, in some respects, much like plugins: they have status and output. They're unlike plugins in that they are scoped to a plugin.

When a plugin in created, we can define *plugs* inside the plugin through the `plug` call. A *plug* is created with an implicit _tag_ `:main` if no tah is provided. Tags can be explicitly defined, which is handy in order to pass them the right set of arguments to the right plug:

    require 'naplug'
    
    class PlugPlugin
    
      include Naplug
    
      plugin do |p|
    
        plug :plug1 do |p1|
          ...
        end
      
        plug :plug2 do |p2|
          ...
        end
      
      end
    end

#### Arguments

Earlier it was noted that "a plugin can accept [mostly] arbitrary arguments" and that "*Naplug* (again, mostly) attaches no special meaning to them". Plugs is where "mostly" comes into being. Plugs are tagged, *Naplug* uses these tags to route arguments to the appropriate plug.

    plugin = PlugPlugin.new(:plug1 => { :critical => 120, :warning => 60 },
                            :plug2 => { :ok => 0, :warning => 5, :critical => 10 })

What if we need shared arguments? Any arguments keyed bby anything other than a plug tag are considered shared arguments and passed on to all plugs.

    plugin = PlugPlugin.new(:file => '/tmp/file',
	                          :plug1 => { :critical => 120, :warning => 60 }, 
                            :plug2 => { :ok => 0, :warning => 5, :critical => 10 })
                                  
Tagged arguments have preference over shared ones.

    plugin = PlugPlugin.new(:file => '/tmp/file', 
                            :plug1 => { :file => '/var/tmp/file', :critical => 120 },
                            :plug2 => { :ok => 0, :warning => 5, :critical => 10 })

#### A Plugged Plugin Example

Take a service for which we wish to monitor three conditions:

* that the service is running one and only one process
* that the log file has seen activity within the last 60 seconds
* that some metric related to the service (number of files in a queue) is within acceptable thresholds

Each of these tasks can be a plug, and Naplug will take care of aggregating the statuses to yield a plugin status (worst always wins).

    require 'sys/proctable
    require 'naplug'
    
    class MultiPlugServicePlugin
    
        include Naplug
        
        plugin do |p|
        
          plug :proc_count do |p1|
            pids = process_grokker p1[:name]
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
              when 0..100
                p3.status.ok
              when 101..1000
                p3.status.warning
              else
                p3.status.critical
             end          
          end
          
        end
        
        def process_grokker(p)
          ...
          return pids
        end
        
    end
    
    plugin = MultiPlugServicePlugin.new :name => 'foobard'
    plugin[:log_mtime] = { :log_file => '/var/log/foobard.log' }
    plugin[:queue_depth] = { :dir => '/var/spool/foobard' }
    plugin.exec!
    
    

 
                                 

      
  