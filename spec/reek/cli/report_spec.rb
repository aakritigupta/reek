require 'spec_helper'
require 'reek/examiner'
require 'reek/cli/report'
require 'rainbow'
require 'stringio'

include Reek
include Reek::Cli

describe QuietReport, " when empty" do
  context 'empty source' do
    let(:examiner) { Examiner.new('') }

    def report(obj)
      obj.add_examiner examiner
    end

    it 'has an empty quiet_report' do
      qr = QuietReport.new
      qr.add_examiner(examiner)
      expect(qr.gather_results).to eq([])
    end

    context 'when output format is html' do
      it 'has the text 0 total warnings' do
        html_report = report(HtmlReport.new(SimpleWarningFormatter, ReportFormatter, :html))
        html_report.show

        file = File.expand_path('../../../../reek.html', __FILE__)
        text = File.read(file)
        File.delete(file)

        expect(text).to include("0 total warnings")
      end
    end

    context 'when output format is yaml' do
      it 'prints empty yaml' do
        yaml_report = report(QuietReport.new(SimpleWarningFormatter, ReportFormatter, :yaml))

        stdout = StringIO.new
        $stdout = stdout
        yaml_report.show
        $stdout = STDOUT
        output = stdout.string

        # Regexp should match expected output for ruby versions 1.9.2 through latest
        # In ruby 1.9.2 yaml will be: --- []\n
        # So additionally, checking for length to ensure that the yaml has the least length for a valid yaml
        output.match(/^--- \[\].*$/) && (output.length <= "--- []\n".length)
      end
    end

    context 'when output format is text' do
      it 'prints nothing' do
        text_report = report(QuietReport.new)
        text_report.gather_results
        expect{text_report.show}.to_not output.to_stdout
      end
    end
  end

  context 'with a couple of smells' do
    before :each do
      @examiner = Examiner.new('def simple(a) a[3] end')
      @rpt = QuietReport.new(SimpleWarningFormatter, ReportFormatter, :text)
    end

    context 'with colors disabled' do
      before :each do
        Rainbow.enabled = false
        @result = @rpt.add_examiner(@examiner).gather_results.first
      end

      it 'has a header' do
        expect(@result).to match('string -- 2 warnings')
      end

      it 'should mention every smell name' do
        expect(@result).to include('UncommunicativeParameterName')
        expect(@result).to include('FeatureEnvy')
      end
    end

    context 'with colors enabled' do
      before :each do
        Rainbow.enabled = true
      end

      context 'with non smelly files' do
        before :each do
          Rainbow.enabled = true
          @rpt.add_examiner(Examiner.new('def simple() puts "a" end'))
          @rpt.add_examiner(Examiner.new('def simple() puts "a" end'))
          @result = @rpt.gather_results
        end

        it 'has a footer in color' do
          stdout = StringIO.new
          $stdout = stdout
          @rpt.show
          $stdout = STDOUT

          expect(stdout.string).to end_with "\e[32m0 total warnings\n\e[0m"
        end
      end

      context 'with smelly files' do
        before :each do
          Rainbow.enabled = true
          @rpt.add_examiner(Examiner.new('def simple(a) a[3] end'))
          @rpt.add_examiner(Examiner.new('def simple(a) a[3] end'))
          @result = @rpt.gather_results
        end

        it 'has a header in color' do
          expect(@result.first).to start_with "\e[36mstring -- \e[0m\e[33m2 warning\e[0m\e[33ms\e[0m"
        end

        it 'has a footer in color' do
          stdout = StringIO.new
          $stdout = stdout
          @rpt.show
          $stdout = STDOUT

          expect(stdout.string).to end_with "\e[31m4 total warnings\n\e[0m"
        end
      end
    end
  end

  context 'when report format is not supported' do
    it 'raises exception' do
      report = QuietReport.new(SimpleWarningFormatter, ReportFormatter, :pdf)
      expect{ report.show }.to raise_error Reek::Cli::UnsupportedReportFormatError
    end
  end
end
