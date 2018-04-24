require 'test_helper'

class FastImageTest < Minitest::Test
  FixturePath = File.join(File.dirname(__FILE__), "fixtures")

  GoodFixtures = {
    "test.bmp"=>[:bmp, [40, 27]],
    "test2.bmp"=>[:bmp, [1920, 1080]],
    "test.gif"=>[:gif, [17, 32]],
    "test.jpg"=>[:jpeg, [882, 470]],
    "test.png"=>[:png, [30, 20]],
    "test2.jpg"=>[:jpeg, [250, 188]],
    "test3.jpg"=>[:jpeg, [630, 367]],
    "test4.jpg"=>[:jpeg, [1485, 1299]],
    "test.tiff"=>[:tiff, [85, 67]],
    "test2.tiff"=>[:tiff, [333, 225]],
    "test.psd"=>[:psd, [17, 32]],
    "exif_orientation.jpg"=>[:jpeg, [600, 450]],
    "infinite.jpg"=>[:jpeg, [160,240]],
    "orient_2.jpg"=>[:jpeg, [230,408]],
    "favicon.ico" => [:ico, [16, 16]],
    "favicon2.ico" => [:ico, [32, 32]],
    "man.ico" => [:ico, [256, 256]],
    "test.cur" => [:cur, [32, 32]],
    "webp_vp8x.webp" => [:webp, [386, 395]],
    "webp_vp8l.webp" => [:webp, [386, 395]],
    "webp_vp8.webp" => [:webp, [550, 368]],
    "test.svg" => [:svg, [200, 300]],
    "test_partial_viewport.svg" => [:svg, [860, 400]],
    "test2.svg" => [:svg, [366, 271]],
    "test3.svg" => [:svg, [255, 48]]
  }

  BadFixtures = [
    "faulty.jpg",
    "test_rgb.ct",
    "test.xml"
  ]
  # man.ico courtesy of http://www.iconseeker.com/search-icon/artists-valley-sample/business-man-blue.html
  # test_rgb.ct courtesy of http://fileformats.archiveteam.org/wiki/Scitex_CT
  # test.cur courtesy of http://mimidestino.deviantart.com/art/Clash-Of-Clans-Dragon-Cursor-s-Punteros-489070897

  ExifDirectories = ["jpg", "tiff-ccitt-rle", "tiff-ccitt4", "tiff-jpeg6",
                     "tiff-jpeg7", "tiff-lzw-bw", "tiff-lzw-color",
                     "tiff-packbits-color"]


  def test_should_report_type_correctly
    GoodFixtures.each do |fn, info|
      assert_equal info[0], FastImage.type(FixturePath + "/" + fn)
      assert_equal info[0], FastImage.type(FixturePath + "/" + fn, :raise_on_failure=>true)
    end
  end

  def test_should_report_size_correctly
    GoodFixtures.each do |fn, info|
      assert_equal info[1], FastImage.size(FixturePath + "/" + fn)
      assert_equal info[1], FastImage.size(FixturePath + "/" + fn, :raise_on_failure=>true)
    end
  end

  def test_should_return_nil_on_fetch_failure
    assert_nil FastImage.size(FixturePath + "/" + "does_not_exist")
  end

  def test_should_return_nil_for_faulty_jpeg_where_size_cannot_be_found
    assert_nil FastImage.size(FixturePath + "/" + "faulty.jpg")
  end

  def test_should_return_nil_when_image_type_not_known
    assert_nil FastImage.size(FixturePath + "/" + "test_rgb.ct")
  end

  def test_should_return_nil_if_timeout_occurs
    assert_nil FastImage.size("http://example.com/does_not_exist", :timeout=>0.001)
  end

  def test_should_raise_when_asked_to_when_size_cannot_be_found
    assert_raises(FastImage::SizeNotFound) do
      FastImage.size(FixturePath + "/" + "faulty.jpg", :raise_on_failure=>true)
    end
  end

  def test_should_raise_when_asked_to_when_timeout_occurs
    assert_raises(FastImage::ImageFetchFailure) do
      FastImage.size("http://example.com/does_not_exist", :timeout=>0.001, :raise_on_failure=>true)
    end
  end

  def test_should_raise_when_asked_to_when_file_does_not_exist
    assert_raises(FastImage::ImageFetchFailure) do
      FastImage.size("http://www.google.com/does_not_exist_at_all", :raise_on_failure=>true)
    end
  end

  def test_should_raise_when_asked_when_image_type_not_known
    assert_raises(FastImage::UnknownImageType) do
      FastImage.size(FixturePath + "/" + "test_rgb.ct", :raise_on_failure=>true)
    end
  end

  def test_should_raise_unknown_image_typ_when_file_is_smil_xml
    assert_raises(FastImage::UnknownImageType) do
      FastImage.size(FixturePath + "/test.smil", :raise_on_failure => true)
    end
  end

  def test_should_raise_unknown_image_typ_when_file_is_non_svg_xml
    assert_raises(FastImage::UnknownImageType) do
      FastImage.size(FixturePath + "/test.xml", :raise_on_failure => true)
    end
  end

  def test_should_report_type_correctly_for_local_files
    GoodFixtures.each do |fn, info|
      assert_equal info[0], FastImage.type(File.join(FixturePath, fn))
    end
  end

  def test_should_report_size_correctly_for_local_files
    GoodFixtures.each do |fn, info|
      assert_equal info[1], FastImage.size(File.join(FixturePath, fn))
    end
  end

  def test_should_report_type_correctly_for_ios
    GoodFixtures.each do |fn, info|
      File.open(File.join(FixturePath, fn), "r") do |io|
        assert_equal info[0], FastImage.type(io)
      end
    end
  end

  def test_should_report_size_correctly_for_ios
    GoodFixtures.each do |fn, info|
      File.open(File.join(FixturePath, fn), "r") do |io|
        assert_equal info[1], FastImage.size(io)
      end
    end
  end

  def test_should_report_size_correctly_on_io_object_twice
    GoodFixtures.each do |fn, info|
      File.open(File.join(FixturePath, fn), "r") do |io|
        assert_equal info[1], FastImage.size(io)
        assert_equal info[1], FastImage.size(io)
      end
    end
  end

  def test_should_report_size_correctly_for_local_files_with_path_that_has_spaces
    assert_equal GoodFixtures["test.bmp"][1], FastImage.size(File.join(FixturePath, "folder with spaces", "test.bmp"))
  end

  def test_should_return_nil_on_fetch_failure_for_local_path
    assert_nil FastImage.size("does_not_exist")
  end

  def test_should_return_nil_for_faulty_jpeg_where_size_cannot_be_found_for_local_file
    assert_nil FastImage.size(File.join(FixturePath, "faulty.jpg"))
  end

  def test_should_return_nil_when_image_type_not_known_for_local_file
    assert_nil FastImage.size(File.join(FixturePath, "test_rgb.ct"))
  end

  def test_should_raise_when_asked_to_when_size_cannot_be_found_for_local_file
    assert_raises(FastImage::SizeNotFound) do
      FastImage.size(File.join(FixturePath, "faulty.jpg"), :raise_on_failure=>true)
    end
  end

  require 'pathname'
  def test_should_handle_pathname
    # bad.jpg does not have the size info in the first 256 bytes
    # so this tests if we are able to read past that using a
    # Pathname (which has a different API from an IO).
    path = Pathname.new(File.join(FixturePath, "bad.jpg"))
    assert_equal([500,500], FastImage.size(path))
  end

  def test_should_report_type_and_size_correctly_for_stringios
    GoodFixtures.each do |fn, info|
      string = File.read(File.join(FixturePath, fn))
      stringio = StringIO.new(string)
      assert_equal info[0], FastImage.type(stringio)
      assert_equal info[1], FastImage.size(stringio)
    end
  end

  def test_should_rewind_ios
    string = File.read(File.join(FixturePath, "test.bmp"))
    stringio = StringIO.new(string)
    FastImage.type(stringio)
    assert_equal 0, stringio.pos

    string = File.read(File.join(FixturePath, "test.xml"))
    stringio = StringIO.new(string)
    FastImage.type(stringio)
    assert_equal 0, stringio.pos
  end

  def test_cant_access_shell
    url = "|echo>shell_test"
    %x{rm -f shell_test}
    FastImage.size(url)
    assert_raises(Errno::ENOENT) do
      File.open("shell_test")
    end
  ensure
    %x{rm -f shell_test}
  end

  def test_should_return_correct_exif_orientation
    ExifDirectories.each do |d|
      1.upto(8) do |n|
        fn = "#{FixturePath}/exif-orientation-testimages/#{d}/ExifOrientation#{n}.#{d == "jpg" ? "jpg" : "tif"}"
        fi = FastImage.new(fn)
        assert_equal [1240, 1754], fi.size
        assert_equal n, fi.orientation
      end
    end
  end

  def test_should_return_orientation_1_when_exif_not_present
    url = "#{FixturePath}/test.gif"
    assert_equal 1, FastImage.new(url).orientation
  end

  def test_should_raise_when_handling_files_looking_like_icons
    stringio = StringIO.new("\x00\x00003")
    assert_raises(FastImage::UnknownImageType) do
      FastImage.type(stringio, :raise_on_failure => true)
    end
  end

  def test_should_raise_when_handling_invalid_ico_files
    stringio = StringIO.new("\x00\x00003")
    assert_raises(FastImage::UnknownImageType) do
      FastImage.type(stringio, :raise_on_failure => true)
    end
  end
end
