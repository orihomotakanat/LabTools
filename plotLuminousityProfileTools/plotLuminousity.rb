require 'RMagick'
require "fileutils"
include Magick

inputpressure = [1.0, 2.0, 3.0, 4.0, 5.0]

#dir change
def dirchange(nextdir)
  Dir.chdir(nextdir)
end

#減算処理メソッド
def diffrenceimage(pressure)
  #differenceimages dirが存在するか調べる
  unless File.exist?("differenceimages")
    Dir.mkdir("differenceimages")
  end

  for i in 0..pressure.count-1 do
    weakflameimage = Magick::Image.read("#{pressure[i]}atm.JPG").first
    bgimage = Magick::Image.read("BG.JPG").first

    modefiedimage = weakflameimage.composite(bgimage, Magick::NorthWestGravity, Magick::DifferenceCompositeOp)
    modefiedimage.write("mod_#{pressure[i]}atm.JPG")

    FileUtils.mv("mod_#{pressure[i]}atm.JPG", "differenceimages")
  end
end

#pixel cut
def cutimage(pressure)
  #Typing pixel of image
  puts "Type pixel from upper image to lower figure in image"
  uppertolowerfig = gets.chomp.to_f
  puts "Type pixel from upper image to upper figure in image"
  uppertoupperfig = gets.chomp.to_f

  unless File.exist?("cutimages")
    Dir.mkdir("cutimages")
  end

  for i in 0..pressure.count-1 do
    originalimage = Magick::Image.read("mod_#{pressure[i]}atm.JPG").first

    firstcropimage = originalimage.crop(Magick::NorthWestGravity, 0, uppertolowerfig)
    completecropimage = firstcropimage.crop(Magick::SouthWestGravity, 0, uppertolowerfig - uppertoupperfig)

    completecropimage.write("crop_#{pressure[i]}atm.JPG")

    FileUtils.mv("crop_#{pressure[i]}atm.JPG", "cutimages")
  end
end

#グレースケールに変換
def grayimage(pressure)
  unless File.exist?("grayimages")
    Dir.mkdir("grayimages")
  end

  for i in 0..pressure.count-1 do
    inputimage = Magick::Image.read("crop_#{pressure[i]}atm.JPG").first
    colorimage = inputimage.quantize(256, Magick::RGBColorspace)

    emptygrayimage = Magick::Image.new(colorimage.columns,colorimage.rows)
    grayimage = emptygrayimage.quantize(256, Magick::RGBColorspace)

    colorimage.columns.times do |c|
      colorimage.rows.times do |r|
        px = colorimage.export_pixels(c,r,1,1)
        outputpx = ( px[0]*0.30 + px[1]*0.59 + px[2]*0.11 )
        grayimage.pixel_color(c,r,Magick::Pixel.new(outputpx,outputpx,outputpx))

      end
    end
    grayimage.write("gray_#{pressure[i]}atm.JPG")
    FileUtils.mv("gray_#{pressure[i]}atm.JPG", "grayimages")
  end
end

#輝度値 to CSV file
def brightnessprofileplot(pressure)
  for t in 0.. pressure.count-1 do
    allbrightness = 0
    avebrightness = Array.new
    avebrightnessmin = Array.new
    brightnessprofile = Array.new
    brightnessprofilemax = Array.new
    normbrightnessprofile = Array.new
    pix = Array.new
    #input image
    inputgrayimage = Magick::Image.read("gray_#{pressure[t]}atm.JPG").first

    #各pixelにおける輝度値
    inputgrayimage.columns.times do |c|
      inputgrayimage.rows.times do |r|
        element = inputgrayimage.export_pixels(c,r,1,1)
        normelement = ( element[0]*0.30 + element[1]*0.59 + element[2]*0.11 )
        allbrightness = allbrightness + normelement
      end
      avebrightness.push(allbrightness / inputgrayimage.rows)
      pix.push(c)
      allbrightness = 0
    end

    #profileの最小値
    for i in 0..inputgrayimage.columns-1 do
      avebrightnessmin.push(avebrightness.min)
    end

    #baselineを0にしたbrightness profile
    for i in 0..avebrightness.count-1 do
      brightnessprofile.push(avebrightness[i] - avebrightnessmin[i])
    end

    #brightness profileの最大値
    for i in 0..brightnessprofile.count-1 do
      brightnessprofilemax.push(brightnessprofile.max)
    end

    #brightness profileの最大値
    for i in 0..brightnessprofilemax.count-1 do
      normbrightnessprofile.push(brightnessprofile[i]/brightnessprofilemax[i])
    end

    #output to CSV
    File.open("normbrightnessprofile_#{pressure[t]}atm.csv", "w") do |bright|
      for i in 0..inputgrayimage.columns do
        bright.write "#{pix[i]}, #{normbrightnessprofile[i]}\n"
      end
    end
  end
end

#処理記述-----------------------------------------------------------------------#

diffrenceimage(inputpressure) #減算処理
dirchange("differenceimages")
cutimage(inputpressure) #pixelでカット
dirchange("cutimages")
grayimage(inputpressure) #画像をグレースケールに
dirchange("grayimages")
brightnessprofileplot(inputpressure) #輝度値をCSVで出力
