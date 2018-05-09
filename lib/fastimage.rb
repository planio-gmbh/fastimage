# frozen_string_literal: true
# coding: ASCII-8BIT

# FastImage finds the size or type of an image given its path. FastImage knows
# about GIF, JPEG, BMP, TIFF, ICO, CUR, PNG, PSD, SVG and WEBP files.
#
# No external libraries such as ImageMagick are used here, this is a very
# lightweight solution to finding image information.
#
# FastImage reads the file in chunks of 256 bytes until it has enough. This is
# possibly a useful bandwidth-saving feature if the file is on a network
# attached disk rather than truly local.
#
# FastImage will automatically read from any object that responds to :read - for
# instance an IO object if that is passed instead of a path.
#
# FastImage can give you information about the parsed display orientation of an image with Exif
# data (jpeg or tiff).
#
# === Examples
#   require 'fastimage'
#
#   FastImage.size("image.gif")
#   => [266, 56]
#   FastImage.type("/some/local/file.png")
#   => :png
#   File.open("/some/local/file.gif", "r") {|io| FastImage.type(io)}
#   => :gif
#   FastImage.new("ExifOrientation3.jpg").orientation
#   => 3
#
# === References
# * http://www.anttikupila.com/flash/getting-jpg-dimensions-with-as3-without-loading-the-entire-file/
# * http://pennysmalls.wordpress.com/2008/08/19/find-jpeg-dimensions-fast-in-pure-ruby-no-ima/
# * https://rubygems.org/gems/imagesize
# * https://github.com/remvee/exifr
#

require 'delegate'
require 'pathname'
require 'stringio'

class FastImage
  attr_reader :size, :type, :orientation, :source, :path

  attr_reader :bytes_read

  class FastImageException < StandardError # :nodoc:
  end
  class UnknownImageType < FastImageException # :nodoc:
  end
  class ImageFetchFailure < FastImageException # :nodoc:
  end
  class SizeNotFound < FastImageException # :nodoc:
  end
  class CannotParseImage < FastImageException # :nodoc:
  end

  LocalFileChunkSize = 256 unless const_defined?(:LocalFileChunkSize)

  # Returns an array containing the width and height of the image.  It will
  # return nil if the image could not be fetched, or if the image type was not
  # recognised.
  #
  # If you wish FastImage to raise if it cannot size the image for any reason,
  # then pass :raise_on_failure => true in the options.
  #
  # FastImage knows about GIF, JPEG, BMP, TIFF, ICO, CUR, PNG, PSD, SVG and WEBP
  # files.
  #
  # === Example
  #
  #   require 'fastimage'
  #
  #   FastImage.size("example.gif")
  #   => [266, 56]
  #   FastImage.size("does_not_exist")
  #   => nil
  #   FastImage.size("does_not_exist", :raise_on_failure => true)
  #   => raises FastImage::ImageFetchFailure
  #   FastImage.size("example.png", :raise_on_failure => true)
  #   => [16, 16]
  #   FastImage.size("app.icns", :raise_on_failure=>true)
  #   => raises FastImage::UnknownImageType
  #   FastImage.size("faulty.jpg", :raise_on_failure=>true)
  #   => raises FastImage::SizeNotFound
  #
  # === Supported options
  # [:raise_on_failure]
  #   If set to true causes an exception to be raised if the image size cannot be found for any reason.
  #
  def self.size(source, options={})
    new(source, options).size
  end

  # Returns an symbol indicating the image type located at source.  It will
  # return nil if the image could not be fetched, or if the image type was not
  # recognised.
  #
  # If you wish FastImage to raise if it cannot find the type of the image for
  # any reason, then pass :raise_on_failure => true in the options.
  #
  # === Example
  #
  #   require 'fastimage'
  #
  #   FastImage.type("example.gif")
  #   => :gif
  #   FastImage.type("image.png")
  #   => :png
  #   FastImage.type("photo.jpg")
  #   => :jpeg
  #   FastImage.type("lena512.bmp")
  #   => :bmp
  #   FastImage.type("does_not_exist")
  #   => nil
  #   File.open("file.gif", "r") {|io| FastImage.type(io)}
  #   => :gif
  #   FastImage.type("test/fixtures/test.tiff")
  #   => :tiff
  #   FastImage.type("test/fixtures/test.psd")
  #   => :psd
  #
  # === Supported options
  # [:raise_on_failure]
  #   If set to true causes an exception to be raised if the image type cannot be found for any reason.
  #
  def self.type(source, options={})
    new(source, options.merge(:type_only=>true)).type
  end

  def initialize(source, options={})
    @source = source
    @options = {
      :type_only        => false,
      :raise_on_failure => false,
      :proxy            => nil,
      :http_header      => {}
    }.merge(options)

    @property = @options[:type_only] ? :type : :size

    @type, @state = nil

    if @source.respond_to?(:read)
      @path = @source.path if @source.respond_to? :path
      fetch_using_read
    else
      @path = @source
      fetch_using_file_open
    end

    raise SizeNotFound if @options[:raise_on_failure] && @property == :size && !@size

  rescue ImageFetchFailure, EOFError, Errno::ENOENT, Errno::EISDIR
    raise ImageFetchFailure if @options[:raise_on_failure]
  rescue UnknownImageType
    raise UnknownImageType if @options[:raise_on_failure]
  rescue CannotParseImage
    if @options[:raise_on_failure]
      if @property == :size
        raise SizeNotFound
      else
        raise ImageFetchFailure
      end
    end

  ensure
    source.rewind if source.respond_to?(:rewind)
  end

  private

  def fetch_using_read(readable = @source)
    # Pathnames respond to read, but always return the first
    # chunk of the file unlike an IO (even though the
    # docuementation for it refers to IO). Need to supply
    # an offset in this case.
    if readable.is_a?(Pathname)
      read_fiber = Fiber.new do
        offset = 0
        while str = readable.read(LocalFileChunkSize, offset)
          Fiber.yield str
          offset += LocalFileChunkSize
        end
      end
    else
      read_fiber = Fiber.new do
        while str = readable.read(LocalFileChunkSize)
          Fiber.yield str
        end
      end
    end

    parse_packets FiberStream.new(read_fiber)
  end

  def fetch_using_file_open
    File.open(@source) do |file|
      fetch_using_read(file)
    end
  end

  def parse_packets(stream)
    @stream = stream

    begin
      result = send("parse_#{@property}")
      if result
        # extract exif orientation if it was found
        if @property == :size && result.size == 3
          @orientation = result.pop
        else
          @orientation = 1
        end

        instance_variable_set("@#{@property}", result)
      else
        raise CannotParseImage
      end
    rescue FiberError
      raise CannotParseImage
    end
  end

  def parse_size
    @type = parse_type unless @type
    send("parse_size_for_#{@type}")
  end

  module StreamUtil # :nodoc:
    def read_byte
      read(1)[0].ord
    end

    def read_int
      read(2).unpack('n')[0]
    end

    def read_string_int
      value = []
      while read(1) =~ /(\d)/
        value << $1
      end
      value.join.to_i
    end
  end

  class FiberStream # :nodoc:
    include StreamUtil
    attr_reader :pos

    def initialize(read_fiber)
      @read_fiber = read_fiber
      @pos = 0
      @strpos = 0
      @str = ''
    end

    # Peeking beyond the end of the input will raise
    def peek(n)
      while @strpos + n - 1 >= @str.size
        unused_str = @str[@strpos..-1]
        new_string = @read_fiber.resume
        raise CannotParseImage if !new_string

        # we are dealing with bytes here, so force the encoding
        new_string.force_encoding("ASCII-8BIT") if String.method_defined? :force_encoding

        @str = unused_str + new_string
        @strpos = 0
      end

      @str[@strpos..(@strpos + n - 1)]
    end

    def read(n)
      result = peek(n)
      @strpos += n
      @pos += n
      result
    end

    def skip(n)
      discarded = 0
      fetched = @str[@strpos..-1].size
      while n > fetched
        discarded += @str[@strpos..-1].size
        new_string = @read_fiber.resume
        raise CannotParseImage if !new_string

        new_string.force_encoding("ASCII-8BIT") if String.method_defined? :force_encoding

        fetched += new_string.size
        @str = new_string
        @strpos = 0
      end
      @strpos = @strpos + n - discarded
      @pos += n
    end
  end

  class IOStream < SimpleDelegator # :nodoc:
    include StreamUtil
  end

  def parse_type
    parsed_type = case @stream.peek(2)
    when "BM"
      :bmp
    when "GI"
      :gif
    when 0xff.chr + 0xd8.chr
      :jpeg
    when 0x89.chr + "P"
      :png
    when "II", "MM"
      :tiff
    when '8B'
      :psd
    when "\0\0"
      # ico has either a 1 (for ico format) or 2 (for cursor) at offset 3
      case @stream.peek(3).bytes.to_a.last
      when 1 then :ico
      when 2 then :cur
      end
    when "RI"
      :webp if @stream.peek(12)[8..11] == "WEBP"
    when '<s', /<[?!]/
      # Peek 10 more chars each time, and if end of file is reached just raise
      # unknown. We assume the <svg tag cannot be within 10 chars of the end of
      # the file, and is within the first 250 chars.
      begin
        :svg if (1..25).detect {|n| @stream.peek(10 * n).include?("<svg")}
      rescue FiberError, CannotParseImage
        nil
      end
    end

    parsed_type or raise UnknownImageType
  end

  def parse_size_for_ico
    icons = @stream.read(6)[4..5].unpack('v').first
    sizes = icons.times.map { @stream.read(16).unpack('C2').map { |x| x == 0 ? 256 : x } }.sort_by { |w,h| w * h }
    sizes.last
  end
  alias_method :parse_size_for_cur, :parse_size_for_ico

  def parse_size_for_gif
    @stream.read(11)[6..10].unpack('SS')
  end

  def parse_size_for_png
    @stream.read(25)[16..24].unpack('NN')
  end

  def parse_size_for_jpeg
    exif = nil
    loop do
      @state = case @state
      when nil
        @stream.skip(2)
        :started
      when :started
        @stream.read_byte == 0xFF ? :sof : :started
      when :sof
        case @stream.read_byte
        when 0xe1 # APP1
          skip_chars = @stream.read_int - 2
          data = @stream.read(skip_chars)
          io = StringIO.new(data)
          if io.read(4) == "Exif"
            io.read(2)
            new_exif = Exif.new(IOStream.new(io)) rescue nil
            exif ||= new_exif # only use the first APP1 segment
          end
          :started
        when 0xe0..0xef
          :skipframe
        when 0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF
          :readsize
        when 0xFF
          :sof
        else
          :skipframe
        end
      when :skipframe
        skip_chars = @stream.read_int - 2
        @stream.skip(skip_chars)
        :started
      when :readsize
        @stream.skip(3)
        height = @stream.read_int
        width = @stream.read_int
        width, height = height, width if exif && exif.rotated?
        return [width, height, exif ? exif.orientation : 1]
      end
    end
  end

  def parse_size_for_bmp
    d = @stream.read(32)[14..28]
    header = d.unpack("C")[0]

    result = if header == 40
               d[4..-1].unpack('l<l<')
             else
               d[4..8].unpack('SS')
             end

    # ImageHeight is expressed in pixels. The absolute value is necessary because ImageHeight can be negative
    [result.first, result.last.abs]
  end

  def parse_size_for_webp
    vp8 = @stream.read(16)[12..15]
    @stream.read(4).unpack("V") # len
    case vp8
    when "VP8 "
      parse_size_vp8
    when "VP8L"
      parse_size_vp8l
    when "VP8X"
      parse_size_vp8x
    else
      nil
    end
  end

  def parse_size_vp8
    w, h = @stream.read(10).unpack("@6vv")
    [w & 0x3fff, h & 0x3fff]
  end

  def parse_size_vp8l
    @stream.skip(1) # 0x2f
    b1, b2, b3, b4 = @stream.read(4).bytes.to_a
    [1 + (((b2 & 0x3f) << 8) | b1), 1 + (((b4 & 0xF) << 10) | (b3 << 2) | ((b2 & 0xC0) >> 6))]
  end

  def parse_size_vp8x
    flags = @stream.read(4).unpack("C")[0]
    b1, b2, b3, b4, b5, b6 = @stream.read(6).unpack("CCCCCC")
    width, height = 1 + b1 + (b2 << 8) + (b3 << 16), 1 + b4 + (b5 << 8) + (b6 << 16)

    if flags & 8 > 0 # exif
      # parse exif for orientation
      # TODO: find or create test images for this
    end

    return [width, height]
  end

  class Exif # :nodoc:
    attr_reader :width, :height, :orientation

    def initialize(stream)
      @stream = stream
      @width, @height, @orientation = nil
      parse_exif
    end

    def rotated?
      @orientation >= 5
    end

    private

    def get_exif_byte_order
      byte_order = @stream.read(2)
      case byte_order
      when 'II'
        @short, @long = 'v', 'V'
      when 'MM'
        @short, @long = 'n', 'N'
      else
        raise CannotParseImage
      end
    end

    def parse_exif_ifd
      tag_count = @stream.read(2).unpack(@short)[0]
      tag_count.downto(1) do
        type = @stream.read(2).unpack(@short)[0]
        @stream.read(6)
        data = @stream.read(2).unpack(@short)[0]
        case type
        when 0x0100 # image width
          @width = data
        when 0x0101 # image height
          @height = data
        when 0x0112 # orientation
          @orientation = data
        end
        if @width && @height && @orientation
          return # no need to parse more
        end
        @stream.read(2)
      end
    end

    def parse_exif
      @start_byte = @stream.pos

      get_exif_byte_order

      @stream.read(2) # 42

      offset = @stream.read(4).unpack(@long)[0]
      if @stream.respond_to?(:skip)
        @stream.skip(offset - 8)
      else
        @stream.read(offset - 8)
      end

      parse_exif_ifd

      @orientation ||= 1
    end

  end

  def parse_size_for_tiff
    exif = Exif.new(@stream)
    if exif.rotated?
      [exif.height, exif.width, exif.orientation]
    else
      [exif.width, exif.height, exif.orientation]
    end
  end

  def parse_size_for_psd
    @stream.read(26).unpack("x14NN").reverse
  end

  class Svg # :nodoc:
    def initialize(stream)
      @stream = stream
      @width, @height, @ratio, @viewbox_width, @viewbox_height = nil
      parse_svg
    end

    def width_and_height
      if @width && @height
        [@width, @height]
      elsif @width && @ratio
        [@width, @width / @ratio]
      elsif @height && @ratio
        [@height * @ratio, @height]
      elsif @viewbox_width && @viewbox_height
        [@viewbox_width, @viewbox_height]
      else
        nil
      end
    end

    private

    def parse_svg
      attr_name = []
      state = nil

      while (char = @stream.read(1)) && state != :stop do
        case char
        when "="
          if attr_name.join =~ /width/i
            @stream.read(1)
            @width = @stream.read_string_int
            return if @height
          elsif attr_name.join =~ /height/i
            @stream.read(1)
            @height = @stream.read_string_int
            return if @width
          elsif attr_name.join =~ /viewbox/i
            values = attr_value.split(/\s/)
            if values[2].to_f > 0 && values[3].to_f > 0
              @ratio = values[2].to_f / values[3].to_f
              @viewbox_width = values[2].to_i
              @viewbox_height = values[3].to_i
            end
          end
        when /\w/
          attr_name << char
        when "<"
          attr_name = [char]
        when ">"
          state = :stop if state == :started
        else
          state = :started if attr_name.join == "<svg"
          attr_name.clear
        end
      end
    end

    def attr_value
      @stream.read(1)

      value = []
      while @stream.read(1) =~ /([^"])/
        value << $1
      end
      value.join
    end
  end

  def parse_size_for_svg
    svg = Svg.new(@stream)
    svg.width_and_height
  end
end
