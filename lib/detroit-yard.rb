require 'detroit/tool'

module Detroit

  # Yard tool.
  def Yard(options={})
    Yard.new(options)
  end

  # Yard documentation tool generates YARD documentation for a project.
  #
  # By default it places the documentaiton file in the standard `doc`
  # directory unless a `site/yard` or `yard` directory exists, in which
  # case the documentation will be stored there.
  #
  #--
  # TODO: Should this autodetect .yardopts and use them unless told
  # to do otherwise?
  #
  # TODO: Not sure the #current? code is exactly correct, might get
  # false negatives.
  #++
  class Yard < Tool

    # Default location to store yard documentation files.
    DEFAULT_OUTPUT = "doc"

    # Locations to check for existance in deciding where to store
    # yard documentation.
    DEFAULT_OUTPUT_MATCH = "{site/,website/,doc/}yard"

    # Default main file.
    DEFAULT_README = "README"

    # Default template to use.
    DEFAULT_TEMPLATE = "default"

    # Deafult extra options to add to yardoc call.
    DEFAULT_EXTRA = ''

    #
    #DEFAULT_FILES = 'lib/**/*;bin/*'

    #
    #DEFAULT_TOPFILES = '[A-Z]*'


    #  A T T R I B U T E S

    # If set to true, use `.yardopts` file and ignore other settings.
    attr_accessor :yardopts

    # Title of documents. Defaults to general metadata title field.
    attr_accessor :title

    # Directory in which to save yard files.
    attr_accessor :output

    # Template to use (defaults to ENV['YARD_TEMPLATE'] or 'default')
    attr_accessor :template

    # Main file.  This can be file pattern. (README{,.txt})
    attr_accessor :readme

    # Which library files to document.
    attr_reader :files

    #
    def files=(list)
      @resolved_files = nil
      @files = list.to_list
    end

    # More generic alternative to +files+.
    alias_accessor :include, :files

    # Which project top-files to document.
    attr_reader :topfiles

    # Set topfiles list.
    def topfiles=(list)
      @resolved_topfiles = nil
      @topfiles = list.to_list
    end

    # Alias for +topfiles+.
    alias_accessor :docs, :topfiles

    # Paths to specifically exclude.
    attr_accessor :exclude

    # File patterns to ignore.
    attr_accessor :ignore

    # Additional options passed to the yardoc command.
    attr_accessor :extra


    #  A S S E M B L Y  M E T H O D S

    #
    def assemble?(station, options={})
      case station
      when :document then true
      when :reset    then true
      when :clean    then true
      when :purge    then true
      end
    end

    #
    def assemble(station)
      case station
      when :document then document
      when :reset    then reset
      when :clean    then clean
      when :purge    then purge
      end
    end


    #  M E T H O D S

    # Are YARD docs current and not in need of updating?
    # If yes, returns string message, otherwise `false`.
    def current?
      if outofdate?(output, *(resolved_files + resolved_topfiles))
        false
      else
        "YARD docs are current (#{output})."
      end
    end

    # Generate documentation. Settings are the
    # same as the yardoc command's option, with two
    # exceptions: +inline+ for +inline-source+ and
    # +output+ for +op+.
    def document
      title    = self.title
      output   = self.output
      readme   = self.readme
      template = self.template
      #exclude  = self.exclude
      extra    = self.extra

      # TODO: add to resolved_topfiles ?
      readme = Dir.glob(readme, File::FNM_CASEFOLD).first

      if (msg = current?) && ! force?
        report msg
      else
        if !yardopts
          status "Generating YARD documentation in #{output}."
        end

        #target_main = Dir.glob(target['main'].to_s, File::FNM_CASEFOLD).first
        #target_main   = File.expand_path(target_main) if target_main
        #target_output = File.expand_path(File.join(output, subdir))
        #target_output = File.join(output, subdir)

        if yardopts
          argv = []
        else
          argv = []
          argv.concat(String === extra ? extra.split(/\s+/) : extra)
          argv.concat ['--output-dir', output] if output
          argv.concat ['--readme', readme] if readme
          argv.concat ['--template', template] if template
          argv.concat ['--title', title] if title
          #argv.concat ['--exclude', exclude]
          argv.concat resolved_files
          argv.concat ['-', *resolved_topfiles]
        end

        yard_target(output, argv)

        touch(output) if File.directory?(output) unless yardopts
      end
    end

    # Mark the output directory as out of date.
    def reset
      if directory?(output) && !yardopts
        utime(0, 0, output)
        report "Reset #{output}" #unless trial?
      end
    end

    # TODO: remove .yardoc ?
    def clean
    end

    # Remove yardoc output directory.
    def purge
      if directory?(output)
        rm_r(output)
        status "Removed #{output}" unless trial?
      end
    end

  private

    #
    def initialize_defaults
      @title    = metadata.title
      @files    = metadata.loadpath + ['bin'] # DEFAULT_FILES
      @topfiles = ['[A-Z]*']

      @output   = Dir[DEFAULT_OUTPUT_MATCH].first || DEFAULT_OUTPUT
      @readme   = DEFAULT_README
      @extra    = DEFAULT_EXTRA
      @template = ENV['YARD_TEMPLATE'] || DEFAULT_TEMPLATE
    end

    #
    LOCAL_SETTINGS = %w{files includes topfiles docs readme output template exclude ignore extra}

    # If there are no options set than default to using the .yardopts file (if it exists).
    def initialize_options(options)
      if !options.keys.any?{ |k| LOCAL_SETTINGS.include?(k) }
        @yardopts = true if (project.root + '.yardopts').exist?
      end
      super(options)
    end

    #
    def resolved_files
      @resolved_files ||= (
        amass(files, exclude || [], ignore || []).uniq
      )
    end

    #
    def resolved_topfiles
      @resolved_topfiles ||= (
        amass(topfiles, exclude || [], ignore || [])
      )
    end

    # Generate yardocs for input targets.
    def yard_target(output, argv=[])
      # remove old yardocs
      #rm_r(output) if exist?(output) and safe?(output)
      #options['output-dir'] = output
      #args = "#{extra} " + [input, options].to_console
      #argv = args.split(/\s+/)

      args = argv.join(' ')
      cmd  = "yardoc " + args

      trace(cmd)

      if trial?
      else
        YARD::CLI::Yardoc.run(*argv)
      end
    end

    # Require yard library.
    def initialize_requires
      require 'yard'
    end

  public

    def self.man_page
      File.dirname(__FILE__)+'/../man/detroit-yard.5'
    end

  end

end
