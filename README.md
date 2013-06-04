# naplug

*Naplug* is a Nagios plugin library for Ruby. In its current incantation it only concerns itself with internal aspects of a plugin (i.e., handling status, output and exit codes) vs external aspects (such as option parsers), which will likely be a future feature. It currently does not handle performance data.

*Naplug* introduces the concept of a *plug*, which is a useful abstraction to break up significant tasks the plugin as a whole must perform in order to determine the state of a service or host. Plugs, like plugins, have status and output. 

## Anatomy of a Nagios Plugin

Before writing a plugin, you should read the [Nagios Plugin Developer Guidelines](http://nagiosplug.sourceforge.net/developer-guidelines.html). *Naplug*’s aim is to codify said guidelines to ease the task of writing a plugin in Ruby and _handling the paperwork_. It also aids in writing more complex plugins by allowing _subplugins_ (i.e., plugins within plugins, which produce results that are then evaluated as a whole to generate a _global_ plugin result).

## Overview

A minimal (and admittedly not very useful) example:

    require 'naplug'
    
    class MyPlugin << Nagios::Plugin
    end
    
This, of course, isn't really enough. The plugin needs work to do, which can be accomplished by defining a plug through the `plugin` method. Take, for example, a plugin that checks the staleness of a marker file: 

    require 'naplug'

	class MarkerFilePlugin < Nagios::Plugin

  	  plugin do |plug|
	    if Time.now - File.mtime(plug.args[:marker_file]) > plug.args[:critical]
	      plug = :critical
	      plug = 'marker mtime greater than 60 seconds'
  	    else
  	      plug = :ok
  	      plug = 'marker up to date'
  	    end
      end
	end

	plugin = MarkerFilePlugin.new :marker_file => '/tmp/my_marker', :critical => 120
	plugin.exec!    

A `plugin` can be defined in an aribitrary fashion, accepting whatever arguments are necessary. Let's make the above example a little more flexible and robust:

    require 'naplug'

	class MarkerFilePlugin < Nagios::Plugin

  	  plugin do |plug|
        begin
          delta = Time.now - File.mtime(plug.args[:marker_file])
          plug = 'marker file is %d seconds out of date' % [delta]
          case
            when delta < plug.args[:w_seconds]
              plug.status = :ok
              plug.output = 'marker file %s is up to date' % [args[:marker_file]]
            when (plug.args[:w_seconds]..plug.args[:c_seconds]).include?(delta)
              plug.status = :warning
            when delta >= args[:c_seconds]
              plug.status = :critical
          end
        rescue Errno::ENOENT => e
          plug.status = :unknown
          plug.output = 'marker file %s does not exist' % [args[:marker_file]]
          plug.payload = e
        end
      end
    end

    plugin = MarkerFilePlugin.new :marker_file => '/tmp/my_marker', :c_seconds => 120, :w_seconds => 60
    plugin.exec!

Some interesting observations about the above code:

* The case where the marker file is missing is handled, resulting in an `unknown` status
* The exception is saved as the `plug.payload`, in case this is useful to the caller
* The `exec!` call is used, which instructs the plugin to execute, output and exit in a single call

### Helpers

Plugins sometimes need helpers, and this can be accomplished by defining `private` methods in the class, which can then be used by the plugin. `Nagios::Plugin` does not enforce the privacy of the said helpers, but it's good form to make them so.
   
    class HelpedPlugin < Nagios::Plugin
    
      plugin do |plug|
        size, mtime = file_mtime_and_size plug.args[:market_file]
        ... 
      end
      
      private
      
      def file_mtime_and_size(file)
        fs = File.stat file 
        return fs.size,fs.mtime
      end
      
    end
     
### Plugs
 
Plugins sometimes need to perform a number of possibly independent tasks to reach a final, _aggregated_ status of the check. In *Naplug*, these tasks are referred to as *plugs*, and they are identified by *tags*. When `plugin` is called as shown in the examples above, a *plug* is created with an implicit _tag_ `:main`.

Tags can be explicitly defined, which is handy in order to pass them the right set of arguments to the right plug:

    require 'naplug'
    
    class MultiPlugin < Nagios::Plugin
    
      plugin :plug1 do |plug|
        ...
      end
      
      plugin :plug2 do |plug|
        ...
      end
      
    end

While it is possible to create a single *plug* that handles all the tasks, it is far cleaner to define multiple `plugs` and let `Nagios::Plugin` do the aggregation work.

Tags are used internally to keep track of different bits of data relevant to each plug. On the outside, tags are how arguments are passed on to the appropriate sub-plugin:

	multiplugin = MultiPlugin.new(:plug1 => { :critical => 120, :warning => 60 }, 
                                  :plug2 => { :ok => 0, :warning => 5, :critical => 10 })

When the plugin is instantiated, an argument key that matches a `plug` tag is assumed to contain arguments for said plug.

#### Shared Arguments

In some cases, it may be desirable to provide shared arguments. This is done by passing arguments keys that do not match any of the plug tags.

	multiplugin = MultiPlugin.new(:file => '/tmp/file',
	                              :plug1 => { :critical => 120, :warning => 60 }, 
                                  :plug2 => { :ok => 0, :warning => 5, :critical => 10 })

Thus, when the actual calls are made, the argument hashes are merged. Thus, in the above example, the following calls will take place:

    plugin_plug1 :file => '/tmp/file', :critical => 120, :warning => 60

and

    plugin_plug2 :file => '/tmp/file', :ok => 0, :warning => 5, :critical => 10

Arguments can be overwritten:

    multiplugin = MultiPlugin.new(:file => '/tmp/file', 
                                  :plug1 => { :file => '/var/tmp/file', :critical => 120 },
                                  :plug2 => { :ok => 0, :warning => 5, :critical => 10 })

 
                                 

      
  