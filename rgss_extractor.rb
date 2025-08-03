# frozen_string_literal: true

require 'fileutils'
require 'optparse'
require_relative 'src/serialize'
require_relative 'src/RGSS'

# RxdataExtractor

# This is a tool designed to extract data from
# RPG Maker's .rxdata files and convert it into
# a more readable YAML format.
class RxdataExtractor
  include RGSS
  # Using class << self block to define all class methods
  # to avoid duplicated `self`.
  class << self
    def convert(src_file, dest_file, version = :xp)
      validate_source_file(src_file)

      ensure_destination_directory(dest_file)

      final_dest_path = create_destination_path(dest_file)
      io_processors = get_io_processors(src_file, dest_file)
      options = build_conversion_options(version)

      process_conversion(src_file, final_dest_path, io_processors[:loader], io_processors[:dumper], options)
    end

    def convert_list(src_file_list, dest_file_list, version = :xp)
      raise 'Source file number not match destination file number' if src_file_list.size != dest_file_list.size

      ensure_destination_directory(dest_file_list[0])
      options = build_conversion_options(version)
      (0..src_file_list.size - 1).each do |i|
        src_file = src_file_list[i]
        dest_file = dest_file_list[i]
        validate_source_file(src_file)
        final_dest_path = create_destination_path(dest_file)
        io_processors = get_io_processors(src_file, dest_file)
        process_conversion(src_file, final_dest_path, io_processors[:loader], io_processors[:dumper], options)
      end
    end

    def convert_dir(src_dir, dest_dir, target_ext, version = :xp)
      ext_in_src_dir = get_most_ext_name_in_dir(src_dir)
      files = RGSS.files_with_extension(src_dir, ext_in_src_dir)

      scripts = RGSS::SCRIPTS_BASE + RGSS::XP_DATA_EXT
      doodads = RGSS::DOODADS_POSTFIX + RGSS::XP_DATA_EXT
      exclude_pats = [scripts, doodads]
      exclude_pats.each do |pattern|
        files.reject! { |file| file.match(pattern) }
      end
      options = build_conversion_options(version)

      files.each do |file|
        src_file = File.join(src_dir, file)
        dest_file = File.join(dest_dir, RGSS.change_extension(file, target_ext))

        io_processors = get_io_processors(src_file, dest_file)
        loader = io_processors[:loader]
        dumper = io_processors[:dumper]
        RGSS.process_file(file, src_file, dest_file, target_ext, loader, dumper, options)
      end
    end

    private

    def get_most_ext_name_in_dir(dir)
      file_list_in_dir = Dir.entries(dir).reject { |entry| File.extname(entry) == '' }
      ext_name_map = {}

      file_list_in_dir.each do |file|
        ext_name_map[File.extname(file)] = (ext_name_map[File.extname(file)] || 0) + 1
      end

      max_ext_key = ''
      max_ext_num = 0
      ext_name_map.each_key do |k|
        if ext_name_map[k] > max_ext_num
          max_ext_key = k
          max_ext_num = ext_name_map[k]
        end
      end

      max_ext_num.positive? && max_ext_key != 0 ? max_ext_key : (raise 'No file with valid ext name')
    end

    def validate_source_file(src_file)
      raise "Source file not found: #{src_file}" unless File.exist?(src_file)
    end

    def build_conversion_options(version)
      options = { force: true, line_width: -1, table_width: -1, round_trip: false }
      RGSS.setup_classes(version, options)

      options[:sort] = true if %i[vx xp].include?(version)
      options[:flow_classes] = RGSS::FLOW_CLASSES
      options[:line_width] ||= 130
      RGSS.reset_const(Table, :MAX_ROW_LENGTH, options[:table_width] || 20)

      options
    end

    def ensure_destination_directory(dest_file)
      dest_dir = File.dirname(dest_file)
      FileUtils.mkdir_p(dest_dir) unless File.exist?(dest_dir)
    end

    def create_destination_path(dest_file)
      dest_dir = File.dirname(dest_file)
      File.join(dest_dir, File.basename(dest_file, '.*') + File.extname(dest_file))
    end

    def get_io_processors(src_file, dest_file)
      exts = { from: File.extname(src_file), to: File.extname(dest_file) }

      case exts
      when { from: RGSS::XP_DATA_EXT, to: RGSS::YAML_EXT }
        { loader: :load_data_file, dumper: :dump_yaml_file }
      when { from: RGSS::YAML_EXT, to: RGSS::XP_DATA_EXT }
        { loader: :load_yaml_file, dumper: :dump_data_file }
      when { from: RGSS::XP_DATA_EXT, to: '' }
        { loader: :load_data_file, dumper: :dump_yaml_file }
      when { from: '', to: RGSS::XP_DATA_EXT }
        { loader: :load_yaml_file, dumper: :dump_data_file }
      else
        raise "Unsupported loader and dumper type for { from: #{exts[:from]}, to: #{exts[:to]} }."
      end
    end

    def get_convert_direction(from, to)
      case [from, to]
      when [RGSS::XP_DATA_EXT, RGSS::YAML_EXT]
        :data_bin_to_text
      when [RGSS::YAML_EXT, RGSS::XP_DATA_EXT]
        :data_text_to_bin
      else
        raise "Unsupported direction for [ #{from}, #{to} ]."
      end
    end

    def process_conversion(src_file, final_dest_path, loader, dumper, options)
      dest_ext = File.extname(final_dest_path)

      RGSS.process_file(File.basename(src_file), File.realpath(src_file), final_dest_path, dest_ext, loader, dumper,
                        options)
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: ruby opt_example.rb [opt] [arg]'

  opts.on('-v', '--verbose', 'Enable verbose log mode') do
    options[:verbose] = true
  end

  opts.on('-i', '--input-file FILE', String, 'Input file, use with `-o`') do |input_file|
    options[:input_file] = input_file
  end

  opts.on('-o', '--output-file FILE', String, 'Output file, use with `-i`') do |output_file|
    options[:output_file] = output_file
  end

  opts.on('-I', '--input-file-list FILE_LIST', String,
          'Input file list, comma separated, use with `-O`') do |input_file_list|
    options[:input_file_list] = input_file_list.split(',')
  end

  opts.on('-O', '--output-file-list FILE_LIST', String,
          'Output file list, comma separated, use with `-I`') do |output_file_list|
    options[:output_file_list] = output_file_list.split(',')
  end

  opts.on('-S', '--source-dir DIR', String, 'Source data directory, use with `-D`') do |src_dir|
    options[:src_dir] = src_dir
  end

  opts.on('-D', '--dest-dir DIR', String, 'Destination data directory, use with `-S`') do |dest_dir|
    options[:dest_dir] = dest_dir
  end

  opts.on('-T', '--target-ext EXT', String, 'Target ext name, for example: `.yaml`') do |target_ext|
    options[:target_ext] = target_ext
  end

  opts.on('-h', '--help', 'Show this menu') do
    puts opts
    exit
  end
end.parse!

begin
  verbose = options[:verbose]

  input_file = options[:input_file]
  output_file = options[:output_file]

  input_file_list = options[:input_file_list]
  output_file_list = options[:output_file_list]

  src_dir = options[:src_dir]
  dest_dir = options[:dest_dir]
  target_ext = options[:target_ext]

  if input_file && output_file
    puts "#{input_file} #{output_file}" if verbose
    RxdataExtractor.convert(input_file, output_file)
  end
  if input_file_list && output_file_list
    puts "#{input_file_list} #{output_file_list}" if verbose
    RxdataExtractor.convert_list(input_file_list, output_file_list)
  end
  if src_dir && dest_dir && target_ext
    puts "#{src_dir} #{dest_dir} #{target_ext}" if verbose
    RxdataExtractor.convert_dir(src_dir, dest_dir, target_ext)
  end
rescue StandardError => e
  puts e.message
  puts e.backtrace_locations
  exit(1)
end
