require 'rainbow'

module Reek
  module Cli
    module ReportFormatter
      def self.format_list(warnings, formatter = SimpleWarningFormatter)
        warnings.map do |warning|
          "  #{formatter.format warning}"
        end.join("\n")
      end

      def self.header(examiner)
        count = examiner.smells_count
        result = Rainbow("#{examiner.description} -- ").cyan + Rainbow("#{count} warning").yellow
        result += Rainbow('s').yellow unless count == 1
        result
      end
    end

    module SimpleWarningFormatter
      def self.format(warning)
        "#{warning.context} #{warning.message} (#{warning.subclass})"
      end
    end

    module WarningFormatterWithLineNumbers
      def self.format(warning)
        "#{warning.lines.inspect}:#{SimpleWarningFormatter.format(warning)}"
      end
    end

    module SingleLineWarningFormatter
      def self.format(warning)
        "#{warning.source}:#{warning.lines.first}: #{SimpleWarningFormatter.format(warning)}"
      end
    end

    module ReportStrategy
      #
      # Base class for report startegies.
      # Each gathers results according to strategy chosen
      #
      class Base
        attr_reader :report_formatter, :warning_formatter, :examiners

        def initialize(report_formatter, warning_formatter, examiners)
          @report_formatter = report_formatter
          @warning_formatter = warning_formatter
          @examiners = examiners
        end

        def summarize_single_examiner(examiner)
          result = report_formatter.header examiner
          if examiner.smelly?
            formatted_list = report_formatter.format_list examiner.smells, warning_formatter
            result += ":\n#{formatted_list}"
          end
          result
        end
      end

      #
      # Lists out each examiner, even if it has no smell
      #
      class Verbose < Base
        def gather_results
          examiners.each_with_object([]) do |examiner, result|
            result << summarize_single_examiner(examiner)
          end
        end
      end

      #
      # Lists only smelly examiners
      #
      class Quiet < Base
        def gather_results
          examiners.each_with_object([]) do |examiner, result|
            if examiner.smelly?
              result << summarize_single_examiner(examiner)
            end
          end
        end
      end

      #
      # Lists smells without summarization
      # Used for yaml and html reports
      #
      class Normal < Base
        def gather_results
          examiners.each_with_object([]) { |examiner, smells| smells << examiner.smells }
                           .flatten
        end
      end
    end

    #
    # A report that contains the smells and smell counts following source code analysis.
    #
    class Report
      DefaultFormat = :text
      NoWarningsColor = :green
      WarningsColor = :red

      def initialize(options = {})
        @warning_formatter   = options.fetch :warning_formatter, SimpleWarningFormatter
        @report_formatter    = options.fetch :report_formatter, ReportFormatter
        @examiners           = []
        @total_smell_count   = 0
        @sort_by_issue_count = options.fetch :sort_by_issue_count, false
        @strategy = options.fetch(:strategy, ReportStrategy::Quiet)
      end

      def add_examiner(examiner)
        @total_smell_count += examiner.smells_count
        @examiners << examiner
        self
      end

      def has_smells?
        @total_smell_count > 0
      end

      def smells
        @strategy.new(@report_formatter, @warning_formatter, @examiners).gather_results
      end
    end

    #
    # Generates a sorted, text summary of smells in examiners
    #
    class TextReport < Report
      def show
        if has_smells?
          sort_examiners
        end
        display_summary
        display_total_smell_count
      end

      private

      def display_summary
        print smells.reject(&:empty?).join("\n")
      end

      def display_total_smell_count
        if @examiners.size > 1
          print "\n"
          print total_smell_count_message
        end
      end

      def sort_examiners
        @examiners.sort! {|first, second| second.smells_count <=> first.smells_count } if @sort_by_issue_count
      end

      def total_smell_count_message
        colour = has_smells? ? WarningsColor : NoWarningsColor
        Rainbow("#{@total_smell_count} total warning#{'s' unless @total_smell_count == 1 }\n").color(colour)
      end
    end

    #
    # Displays a list of smells in YAML format
    # YAML with empty array for 0 smells
    class YamlReport < Report
      def initialize(options ={})
        super options.merge!(strategy: ReportStrategy::Normal)
      end

      def show
        print(smells.to_yaml)
      end
    end

    #
    # Saves the report as a HTML file
    #
    class HtmlReport < Report
      def initialize(options ={})
        super options.merge!(strategy: ReportStrategy::Normal)
      end

      require 'erb'

      TEMPLATE = File.read(File.expand_path('../../../../assets/html_output.html.erb', __FILE__))

      def show
        File.open('reek.html', 'w+') do |file|
          file.puts ERB.new(TEMPLATE).result(binding)
        end
        print("Html file saved\n")
      end
    end
  end
end
