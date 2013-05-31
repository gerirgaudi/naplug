# naplug

*Naplug* is a Nagios plugin library for Ruby. In its current version it really concerns itself only with internal aspects of the plugins (vs external aspects such as option parsers and such, which will likely be a future feature).

## Overview

A minimal (and admittedly not very useful) example:

    require 'naplug'
    
    class MyPlugin << Nagios::Plugin
    end
    
This, of course, isn't really enough. The plugin needs work to do, which can be accomplished by defining the plugin through the `plugin` method. Take, for example, a plugin that checks the staleness of a marker file: 

    require 'naplug'

	class MarkerFilePlugin < Nagios::Plugin

  	  plugin do |args|
  	    result = Result.new
	    if Time.now - File.mtime(args[:marker_file]) > args[:critical]
	      result.status = :critical
	      result.output = 'marker mtime greater than 60 seconds'
  	    else
  	      result.status = :ok
  	      result.output = 'marker up to date'
  	    end
 	    result
      end
	end

	plugin = MarkerFilePlugin.new :marker_file => '/tmp/my_marker', :critical => 120
	plugin.exec
	puts plugin.single_line_output
	exit plugin.status.to_i   
    

Notice that `plugin` must always return a `Result`. You can define `plugin` in any way you choose, accepting whatever arguments are necessary. Let's make the above example a little more flexible and robust:

    require 'naplug'

	class MarkerFilePlugin < Nagios::Plugin

  	  plugin do |args|
        result = Result.new
        begin
          delta = Time.now - File.mtime(args[:marker_file])
          result.output = 'marker file is %d seconds out of date' % [delta]
          case
            when delta < args[:w_seconds]
              result.status = :ok
              result.output = 'marker file %s is up to date' % [args[:marker_file]]
            when (args[:w_seconds]..args[:c_seconds]).include?(delta)
              result.status = :warning
            when delta >= args[:c_seconds]
              result.status = :critical
          end
        rescue Errno::ENOENT => e
          result.status = :unknown
          result.output = 'marker file %s does not exist' % [args[:marker_file]]
          result.payload = e
        end
        result
      end
    end

    plugin = MarkerFilePlugin.new :marker_file => '/tmp/my_marker', :c_seconds => 120, :w_seconds => 60
    plugin.exec!

Some interesting observations about the above code:

* The case where the marker file is missing is handled, resulting in an `unknown` status
* The exception is saved as the `result.payload`, in case this is useful to the caller
* The `exec!` call is used, which instructs the plugin to execute, output and exit in a single call

### Helpers

Plugins sometimes need helpers, and this can be accomplished by defining `private` methods in the class, which can then be used in the plugin. `Nagios::Plugin` does not enforce the privacy of the said helpers, but it's good form to make them so.
   
    class HelpedPlugin < Nagios::Plugin
    
      plugin do |args|
        size, mtime = file_mtime_and_size(args[:market_file]
        ... 
      end
      
      private
      
      def file_mtime_and_size(file)
        fs = File.stat(file)
        return fs.size,fs.mtime
      end
      
    end
     
### Sub-plugins
 
Plugins sometimes need to perform a number of tasks to reach a final, _aggregated_ status of the check. This could be done in a single `plugin` block, but it is far cleaner to define multiple `plugins` and let `Nagios::Plugin` do the dirty work.

When `plugin` is called as shown in the examples above, an implicit _tag_ `main` is created for the plugin. Said tags can, however, be explicitly defined, which is handy with sub-plugins:

    require 'naplug'
    
    class MultiPlugin < Nagios::Plugin
    
      plugin :subplug1 do |args|
        ...
      end
      
      plugin :subplug2 do |args|
        ...
      end
      
    end
    
Plugin tags are used internally to keep track of different bits of data relevant to each sub-plugin. On the outside, tags are how arguments are passed on to the appropriate sub-plugin:

	multiplugin = MultiPlugin.new(:subplug1 => { :critical => 120, :warning => 60 }, 
                                  :subplug2 => { :ok => 0, :warning => 5, :critical => 10 })

When the plugin is instantiated, an argument key that matches a sub`plugin` tag is assumed to contain arguments for said subplugin.

#### Shared Arguments

In some cases, it may be desirable to provide shared arguments. This is done by passing arguments keys that do not match any of the subplugin tags.

	multiplugin = MultiPlugin.new(:shared => '/tmp/file',
	                              :subplug1 => { :critical => 120, :warning => 60 }, 
                                  :subplug2 => { :ok => 0, :warning => 5, :critical => 10 })


Thus, when the actual calls are made, the argument hashes are merged. Thus, in the above example, the following calls will take place:

    plugin_subplug1 :shared => '/tmp/file', :critical => 120, :warning => 60

and

    plugin_subplug2 :shared => '/tmp/file', :ok => 0, :warning => 5, :critical => 10

Arguments can be overwritten:

    multiplugin = MultiPlugin.new(:shared => '/tmp/file', 
                                  :subplug1 => { :shared => '/var/tmp/file', :critical => 120 },
                                  :subplug2 => { :ok => 0, :warning => 5, :critical => 10 })

 
                                 

      
  