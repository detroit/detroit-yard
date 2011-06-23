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
    DEFAULT_OUTPUT_MATCH = "{site/,website/,doc/,}{yard,doc}"

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

    public

    # If set to true, use `.yardopts` file and ignore other settings.
    attr_accessor :yardopts

    # Title of documents. Defaults to general metadata title field.
    attr_accessor :title

    # Where to save yard files (doc/yard).
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

    # Which project top-files to document.
    attr_reader :topfiles

    # Alias for +files+.
    alias_accessor :include, :files

    # Set topfiles list.
    def topfiles=(list)
      @resolved_topfiles = nil
      @topfiles = list.to_list
    end

    # Paths to specifically exclude.
    attr_accessor :exclude

    # Additional options passed to the yardoc command.
    attr_accessor :extra


    # Are YARD docs current and not in need of updating?
    # If yes, returns string message, otherwise `false`.
    def current?
      if outofdate?(output, *(resolved_files + resolved_topfiles))
        false
      else
        "YARD docs are current (#{output})."
      end
    end

    # Generate Rdoc documentation. Settings are the
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
        status "Generating #{output}"

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

        #insert_ads(output, adfile)

        touch(output)
      end
    end

    # Mark the output directory as out of date.
    def reset
      if directory?(output)
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

    # Attach document method to assembly.
    def assembly_document
      document
    end

    # Attach reset method to assembly.
    def assembly_reset
      reset
    end

    # Attach clean method to assembly.
    def assembly_clean
      clean
    end

    # Attach purge method to assembly.
    def assembly_purge
      purge
    end

    private

    #
    def resolved_files
      @resolved_files ||= (
        list = self.files
        list = list.map{ |g| Dir.glob(g) }.flatten
        list = list.map{ |f| File.directory?(f) ? File.join(f,'**','*') : f }
        list = list.map{ |g| Dir.glob(g) }.flatten  # need this to remove unwanted toplevel files
        list = list.reject{ |f| File.directory?(f) }

        # TODO: Does YARD command have an exclude option, use it instead if so?
        exclude = self.exclude.to_list
        exclude = exclude.collect{ |g| Dir.glob(File.join(g, '**/*')) }.flatten

        #mfile = project.manifest.file
        #mfile = project.manifest.file.basename if mfile
        #exclude = (exclude + [mfile].compact).uniq
        #files = files - [mfile].compact

        list = list - exclude

        list.uniq
      )
    end

    #
    def resolved_topfiles
      @resolved_topfiles ||= (
        list = self.topfiles
        list = list.map{ |g| Dir.glob(g) }.flatten
        list = list.map{ |f| File.directory?(f) ? File.join(f,'**','*') : f }
        list = list.map{ |g| Dir.glob(g) }.flatten  # need this to remove unwanted toplevel files
        list = list.reject{ |f| File.directory?(f) }
        list = list - Dir.glob('rakefile{,.rb}', File::FNM_CASEFOLD)
        list
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

      status cmd

      if trial?
      else
        YARD::CLI::Yardoc.run(*argv)
      end
    end

    # Require yard library.
    def initialize_requires
      require 'yard'
    end

  end

end
