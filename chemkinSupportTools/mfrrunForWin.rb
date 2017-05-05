#This file is support tool of computational code of MFR.
#(c) Tomohiro Tanaka <tanakat@edyn.ifs.tohoku.ac.jp>

require "fileutils"
require "win32ole"

#-------------------------------------------------------------------------------
####Pressuremode class----------------------------------------------------------
class Pressuremode
  attr_accessor :xrange, :range, :step, :datafile, :restartfile, :runfile, :inputfile, :outfile, :resultfile, :parameter, :current_folder, :current_mixture, :current_mech, :current_condition, :current_value

  def initialize(xrange = "10.0000", range = 0, step = 1, datafile = "XMLdata.zip", restartfile = "XMLrestart.zip", runfile = "run.bat", inputfile = "premix.inp", outfile = "premix.out", resultfile = "result.txt")
    @xrange = xrange
    @range = range
    @step = step
    @datafile = datafile
    @restartfile = restartfile
    @runfile = runfile
    @inputfile = inputfile
    @outfile = outfile
    @resultfile = resultfile

    @parameter = nil

    @current_folder = nil
    @current_mixture = nil
    @current_mech = nil
    @current_condition = nil
    @current_value = nil
  end

  def run #File check & run.bat
    wsh = WIN32OLE.new('WScript.Shell')
    #File check
    if File.exist?(@restartfile) && File.exist?(@datafile) #XMLdata&XMLrestart remain
      File.delete @restartfile
      File.rename(@datafile,@restartfile)
    elsif File.exist?(@datafile) #XMLdata onle remain
      File.rename(@datafile,@restartfile)
    end #if File.exist?(restartfile) && File.exist?(datafile) end

    #run.bat
    runcomputation = system(@runfile)
    if runcomputation
      puts "Success"
    else
      wsh.Popup("FAILURE!!DO NOT MIND!!")
      exit
    end #if rumcomputation end
  end #def run end
  
  def xmlmanipulation(modenum)
    temporary_parameter = 0
    datafile_arr = [@datafile, @resultfile,@outfile]
    File.open(@inputfile, "r+") do |inp_l|
      inputfile_lines = inp_l.readlines
      inputfile_lines.length.to_i.times do |parm_l|
        if /^#{@parameter}/ =~ inputfile_lines[parm_l]
          temporary_parameter = inputfile_lines[parm_l].split.slice!(1)
          break
        end #if /^#{@parameter}/ =~ inputfile_lines[parm_l]
      end #inputfile_lines.length.to_i.times do |parm_l|
    end #File.open(@inputfile, "r+") do |f| end

    case modenum
    when 1 #GRAD&CURV mode
      xmldata_newname = "XMLdata_GRADCURV#{temporary_parameter}.zip"
      result_newname = "result_GRADCURV#{temporary_parameter}.txt"
      premixout_newname = "premix_GRADCURV#{temporary_parameter}.out"

      datafile_arr.each do |datafile_element|
        if File.exist?(datafile_element)
          if datafile_element == @datafile #XMLdata.zip
              FileUtils.cp_r(@datafile, xmldata_newname)
          elsif datafile_element == @resultfile #result.txt
            FileUtils.cp_r(@resultfile, result_newname)
          elsif datafile_element == @outfile #premix.ou
            FileUtils.cp_r(@outfile, premixout_newname)
          else
            puts "No file exist"
          end #if datafile_element == @datafile
          #copy & rename file
        end #if File.exist?(datafile_element)
      end #datafile_arr.each do |datafile_element|
    when 2 #pressure mode
      puts "under constructing"
    end #case modenum
  end


  def dataplot #Read premix.out -> Extract results only -> Plot data to csv file
    chemicalspecieslist = Array.new(["H2","CO", "H", "OH","O", "HO2", "H2O2"]) #Plotするchemical speciesを増やす場合はここに加える
    open(@outfile,"r+") do |out_l| #outputfileの中身を逆にする
      outputfile_lines = out_l.readlines
      out_l.rewind
      out_l.truncate(0)
      out_l.write outputfile_lines.reverse.join()
    end #open(outputfile,"r+") do |l| end

    extractfile = File.read(@outfile) #中身が逆になったoutputfileを上から必要な結果部分まで抽出してresultfileへ出力
    File.open(@resultfile, "w") do |res_l|
      in_header = true
      extractfile.each_line do |ext_l|
        if in_header && / TWOPNT:  SUCCESS.  PROBLEM SOLVED./ !~ ext_l
          next
        else
          in_header = false
        end #if in_header && / TWOPNT:  SUCCESS.  PROBLEM SOLVED./ !~line end
        break if / TWOPNT:  FINAL SOLUTION:/ =~ ext_l
        res_l.write ext_l
      end #extractfile.each_line do |ext_l| end
    end #File.open(resultfile, "w") do |result| end

    open(@outfile,"r+") do |out_l| #中身が逆になったoutputfileを元の表示に戻す
      outputfile_lines = out_l.readlines
      out_l.rewind
      out_l.truncate(0)
      out_l.write outputfile_lines.reverse.join()
    end #open(outputfile,"r+") do |f| end

    open(@resultfile,"r+") do |res_l| #中身が逆に記述されているresultfileを元の表示に戻す
      resultfile_lines = res_l.readlines
      res_l.rewind
      res_l.truncate(0)
      res_l.write resultfile_lines.reverse.join()
    end #open(resultfile,"r+") do |res_l| end

    #------hrrdata.csv書き出し
    endpoint = 0 #end point of x
    chemicalspecies_line = Array.new
    chemicalspecies_column = Array.new
    #Serach number of end point of x
    File.open(@resultfile, "r+") do |chem_l| #Serach number of end point of x
      col_arr = chem_l.readlines
      col_arr.length.to_i.times do |col_l|
        if /#{@xrange}/ =~ col_arr[col_l]
          endpoint = col_l
          break
        end #if /10.0000/ =~ col_arr[col_l] end
      end #col_arr.length.to_i.times do |col_l| end

      #molefraction
      for chem in 0..chemicalspecieslist.count-1 do #molefraction plot
        sp = Regexp.quote("#{chemicalspecieslist[chem]}")
        col_arr.length.to_i.times do |col_l|
          if /^#{sp}/ || / #{sp} / =~ col_arr[col_l] #plotとしたいmole speciesが何行目にあるか探す
            chemicalspecies_line[chem] = col_l
            break
          end #if /#{chemicalspecieslist[chem]}        / =~ col_arr[col_l] end
        end #col_arr.length.to_i.times do |col_l| end
        col_arr[chemicalspecies_line[chem]].split.count.times do |molefraction|
          if /^#{sp}+$/ =~ col_arr[chemicalspecies_line[chem]].split.slice!(molefraction) #plotするmolefractionが何列目にあるか
            chemicalspecies_column[chem] = molefraction
          end #if /^#{chemicalspecieslist[chem]}+$/ =~ col_arr[chemicalspecies_line[chem]].split.slice!(molefraction) end
        end #col_arr[chemicalspecies_line[chem]].split.count.times do |molefraction| end
      end #for t in 0..chemicalspecieslist.count-1 do end

      #data output
      File.open("plot_#{@current_mixture}_#{@current_mech}_#{@current_condition}=#{@current_value}.csv", "w") do |prof_l|
        #l1 output
        prof_l.write "#{col_arr[1].split.slice!(0)},Tw[K],HRR[J/cm3sec]," #l1 output
        for speciestitle in 0..chemicalspecieslist.count-1 do #l1 output of chemical speacies
          if speciestitle == chemicalspecieslist.count-1
            prof_l.write "#{chemicalspecieslist[speciestitle]}\n"
          else
            prof_l.write "#{chemicalspecieslist[speciestitle]},"
          end #if speciestitle == chemicalspecieslist.count-1 end
        end #for speciestitle in 0..chemicalspecieslist.count-1 do end

        #from l2 output
        for eachline in 2..endpoint do
          x = col_arr[eachline].split.slice!(1).to_f #location
          hrr = 4.1868.col_arr[eachline].split.slice!(6).to_f #heat release rate
          if x <= 2.5 #If necessary, change the paramter of temperature profile
            prof_l.write "#{x},300,#{hrr},"
          elsif x >= 2.5 && x < 4.5
            prof_l.write "#{x},#{125*x*x-625*x+1081.25},#{hrr},"
          elsif x >= 4.5 && x < 6.5
            prof_l.write "#{x},#{-125*x*x+1625*x-3981.25},#{hrr},"
          else
            prof_l.write "#{x},1300,#{hrr},"
          end #if col_arr[eachline].split.slice!(1).to_f <= 2.5 end
          for species_col in 0..chemicalspecieslist.count-1 do
            if species_col == chemicalspecieslist.count-1
              prof_l.write "#{col_arr[eachline+chemicalspecies_line[species_col]-1].split.slice!(chemicalspecies_column[species_col]+2)}\n"
            else
              prof_l.write "#{col_arr[eachline+chemicalspecies_line[species_col]-1].split.slice!(chemicalspecies_column[species_col]+2)},"
            end #if species_col == chemicalspecieslist.count-1 end
          end #for x in 0..chemicalspecieslist.count-1 do end
        end #for eachline in 2..endpoint do end
      end #File.open("plotresults_#{@current_condition}=#{@current_value}.csv", "w") do |prof_l| end
    end #File.open(@resultfile, "r+") do |chem_l| end
    #-----------------------
  end #def dataplot end

  def changeparameter #Change the parameter
    changeparameter_line = 0
    File.open(@inputfile, "r+") do |inp_l|
      inputfile_lines = inp_l.readlines
      inputfile_lines.length.to_i.times do |parm_l|
        if /^#{@parameter}/ =~ inputfile_lines[parm_l]
          changeparameter_line = parm_l
          break
        end #if /^#{@parameter}/ =~ inputfile_lines[parm_l]
      end #inputfile_lines.length.to_i.times do |parm_l|
      inputfile_lines[changeparameter_line] = "#{@parameter}     #{@current_value}\n"

      File.open(@inputfile, "w") do |inp2_l|
        inputfile_lines.each do |write_l|
          inp2_l.write write_l
        end #inputfile_lines.each do |write_l|
      end #File.open(@inputfile, "r+") do |inp_l|
    end #File.open(@inputfile, "r+") do |f| end
  end #def changeparameter end

  def checkdirectory # check the current directory
    @current_folder = File.basename(Dir.pwd) #現在のdirectoryの最後の/部分を返す
    @current_folder.scan(/^([^\_]+)_([^\_]+)_(.*)$/) do |current_factor|
      @current_mixture = current_factor[0]
      @current_mech = current_factor[1]

      $3.scan(/^([^\=]+)=(.*)$/) do |current_parameter|
        @current_condition = current_parameter[0]
        @current_value = current_parameter[1].to_f
      end #$3.scan(/^([^\=]+)=(.*)$/) do |current_pressure| end
    end #currentfolder.scan(/^([^\_]+)_([^\_]+)_(.*)$/) do |re| end
  end #checkdirectory end

  def changedirectory #Change the directory
    current_directory = "#{@current_mixture}_#{@current_mech}_#{@current_condition}=#{@current_value}"
    next_directory =  "#{@current_mixture}_#{@current_mech}_#{@current_condition}=#{@current_value + @step}"
    Dir.chdir("..") #directoryを変更する
    if  @current_value == @range
      puts "Finish"
      exit
    end #if  @current_value == @range end

    if File.exist?(next_directory)
    else
      FileUtils.cp_r(current_directory, next_directory)
    end #if File.exist?(nextdir) end

    Dir.chdir(next_directory)
  end #def changedirectory end
end #class Pressuremode end

####Gradcurvmode class----------------------------------------------------------
class Gradcurvmode < Pressuremode
  def checkpremixinp_commentout(timenumber)
    nocommentout_line = 0
    commentout_line = 0

    File.open(@inputfile, "r+") do |inp_l|
      inputfile_lines = inp_l.readlines
      inputfile_lines.length.to_i.times do |parm_l|
        if /^#{@parameter}/ =~ inputfile_lines[parm_l] #no / case
          nocommentout_line = parm_l
          break
        elsif /^(\/#{@parameter})/ =~ inputfile_lines[parm_l] #/ case
          commentout_line = parm_l
          break
        else

        end #if @parameter.match(/^(#{@parameter})/) end
      end #if /^#{@parameter}/ =~ inputfile_lines[parm_l] end

      case timenumber
      when 0 #1回目の処理の場合@parameterの有無入力
        #Ask to continue computation or add(or Remove) /
        if nocommentout_line.to_i != 0 #no / case
          puts "\nThere are #{@parameter}\nContinue computation(Type 1) or Add / (Type 2)?"

          loop do
            commentout_choice = 0
            commentout_choice = gets.chomp.to_i
            if commentout_choice == 1 #Continue computation case
              break
            elsif commentout_choice == 2 #Add /
              inputfile_lines[nocommentout_line] = "/#{@parameter}\n"
              File.open(@inputfile, "w") do |inp2_l|
                inputfile_lines.each do |write_l|
                  inp2_l.write write_l
                end #inputfile_lines.each do |write_l|
              end #File.open(@inputfile, "r+") do |inp_l|
              break
            else
              puts "Please type 1 or 2"
            end #if commentout_choice == 1 end
          end #loop do end

        elsif commentout_line.to_i != 0 #/case
          puts "\nThere are /#{@parameter}\nContinue computation(Type 1) or Remove / (Type 2)?"
          
          loop do
            commentout_choice = 0
            commentout_choice = gets.chomp.to_i
            if commentout_choice == 1 #Continue computation case
              break
            elsif commentout_choice == 2 #Remove /
              inputfile_lines[commentout_line] = "#{@parameter}\n"
              File.open(@inputfile, "w") do |inp2_l|
                inputfile_lines.each do |write_l|
                  inp2_l.write write_l
                end #inputfile_lines.each do |write_l|
              end #File.open(@inputfile, "r+") do |inp2_l|
              break
            else
              puts "Please type 1 or 2"
            end #if commentout_choice == 1 end
          end #loop do end

        else #Other case
          puts "Please add #{@parameter} or /#{@parameter} to #{@inputfile}"
          exit
        end #if nocommentout_line.to_i != 0 end

      else #2回目以降
        if commentout_line.to_i != 0
          inputfile_lines[commentout_line] = "#{@parameter}\n"
          File.open(@inputfile, "w") do |inp2_l|
            inputfile_lines.each do |write_l|
              inp2_l.write write_l
            end #inputfile_lines.each do |write_l|
          end #File.open(@inputfile, "r+") do |inp2_l|
        end #if commentout_line.to_i != 0 end
      end #case timenumber end
    end #File.open(@inputfile, "r+") do |inp_l| end

  end #def checkpremixparameter(timenumber) end

  def changeparameter_gradcurv(gradcurv_value) #Change parameters of GRAD & CURV
    changeparameter_line = 0
    File.open(@inputfile, "r+") do |inp_l|
      inputfile_lines = inp_l.readlines
      inputfile_lines.length.to_i.times do |parm_l|
        if /^#{@parameter}/ =~ inputfile_lines[parm_l]
          changeparameter_line = parm_l
          break
        end #if /^#{@parameter}/ =~ inputfile_lines[parm_l]
      end #inputfile_lines.length.to_i.times do |parm_l|
      inputfile_lines[changeparameter_line] = "#{@parameter}     #{gradcurv_value}\n"

      File.open(@inputfile, "w") do |inp2_l|
        inputfile_lines.each do |write_l|
          inp2_l.write write_l
        end #inputfile_lines.each do |write_l|
      end #File.open(@inputfile, "r+") do |inp_l|
    end #File.open(@inputfile, "r+") do |f| end
  end #def changeparameter end
end #class Gradcurvmode < Pressuremode end

####Inletvelocitymode class-----------------------------------------------------
=begin
class Inletvelocitymode < Pressuremode
end #Inletvelocitymode < Pressuremode end
=end
#-------------------------------------------------------------------------------

####Plotdatamode class-----------------------------------------------------
class Plottingdatamode < Pressuremode
  def checkplottingfilename
    if File.exist?("plot_#{@current_mixture}_#{@current_mech}_#{@current_condition}=#{@current_value}.csv")
      return "plot_#{@current_mixture}_#{@current_mech}_#{@current_condition}=#{@current_value}.csv"
    else
      puts "No file exist"
      exit
    end #if File.exist?("plot_#{@current_mixture}_#{@current_mech}_#{@current_condition}=#{@current_value}.csv")
  end #def checkplottingfilename
end #Plodatamode < Pressuremode end
#-------------------------------------------------------------------------------
  
#以下に処理記述------------------------------------------------------------------
#Mode select
loop do
  puts "GRAD&CURV mode->Type 1\nPressure mode->Type 2\nPlotting data mode->Type 3"
  $modenum = gets.chomp.to_i

  if $modenum == 1
    puts "GRAD&CURV mode was selected"
    break
  elsif $modenum == 2
    puts "Pressure mode was selected"
    break
  elsif $modenum == 3
    puts "Plotting data mode was selected"
    break
  end #if modenum == 1 end
end #loop end

#Mode run
case $modenum
when 1 #GRAD&CURV mode
  gradcurv_arr = Array.new
  puts "\nType GRAD & CURV which is calculated\n*Type q when you stop typing"
  loop do #input GRAD&CURV
    gradcurv_input = gets.chomp #計算したいGRAD&CURVを入力
    if /(^\d).(\d+)$|^\d$/ =~ gradcurv_input && gradcurv_input.to_f <= 1
      gradcurv_arr.push(gradcurv_input) #入力したGRAD&CURVを格納
    elsif gradcurv_input == "q"
      break
    else
      puts "Please type number or under 1.0"
    end #if /(^\d).(\d+)$|^\d$/ =~ gradcurv_input && gradcurv_input.to_f <= 1 end
  end #loop do end

  chemkinpro_grad = Gradcurvmode.new
  chemkinpro_curv = Gradcurvmode.new
  chemkinpro_rstr = Gradcurvmode.new
  chemkinpro_usev = Gradcurvmode.new

  chemkinpro_grad.parameter = "GRAD"
  chemkinpro_curv.parameter = "CURV"
  chemkinpro_rstr.parameter = "RSTR"
  chemkinpro_usev.parameter = "USEV"

  chemkinpro_grad.checkdirectory
  
  chemkinpro_grad.xmlmanipulation($modenum)

  gradcurv_arr.count.to_i.times do |gc_element|
    chemkinpro_rstr.checkpremixinp_commentout(gc_element)
    chemkinpro_usev.checkpremixinp_commentout(gc_element)

    chemkinpro_grad.changeparameter_gradcurv(gradcurv_arr[gc_element])
    chemkinpro_curv.changeparameter_gradcurv(gradcurv_arr[gc_element])

    chemkinpro_grad.run
    chemkinpro_grad.dataplot
    chemkinpro_grad.xmlmanipulation($modenum)
  end

when 2 ##Pressure mode
  p_range_input = true
  p_step_input = true

  puts "Target pressure [atm]?"
  loop do #input target pressure
    p_range_input = gets.chomp
    if /(^\d+).(\d+)$|^\d+$/ =~ p_range_input
      break
    else
      puts "Please type number"
    end #if /(^\d).(\d+)$|^\d$/ =~ pressure_range end
  end #loop do end

  puts "Pressure step? (e.g.)0.5 => 1.0 to 1.5"
  loop do #input pressure step
    p_step_input = gets.chomp
    if /(^\d+).(\d+)$|^\d+$/ =~ p_step_input
      break
    else
      puts "Please type number"
    end #if /(^\d).(\d+)$|^\d$/ =~ pressure_step end
  end #loop do end

  chemkinpro_pressure = Pressuremode.new
  chemkinpro_pressure.range = p_range_input.to_f
  chemkinpro_pressure.step = p_step_input.to_f
  chemkinpro_pressure.parameter = "PRES"

  chemkinpro_pressure.checkdirectory

  ((chemkinpro_pressure.range-chemkinpro_pressure.current_value)/chemkinpro_pressure.step + 1).to_i.times do
    chemkinpro_pressure.checkdirectory
    chemkinpro_pressure.changeparameter
    chemkinpro_pressure.run
    chemkinpro_pressure.dataplot
    chemkinpro_pressure.changedirectory
  end #times end
  
when 3 ##Plotting data mode
  chemkinpro_plottingdata = Plottingdatamode.new
  modenum_plottingdata = TRUE
  loop do
    puts "Plotting data in current directory->Type 1, Choosing the directory->Type 2"
    modenum_plottingdata = gets.chomp.to_i

    if modenum_plottingdata == 1
      break
    elsif modenum_plottingdata == 2
      break
    else
      puts "Please type 1 or 2"
    end #if modenum_plottingdata == 1 end
  end #loop do end

  case modenum_plottingdata
  when 1 #current directory
    chemkinpro_plottingdata.checkdirectory
    chemkinpro_plottingdata.dataplot
    puts "Check the result!!"
  when 2 #choosing directory
    directory_input = TRUE
    directory_arr = Array.new
    puts "Type your choosing directory.\n*Type q when you stop typing"
    loop do #プロットしたいpremix.outのあるdirectoryを入力する
      directory_input =  gets.chomp
      if Dir.exist?(directory_input)
        directory_arr.push(directory_input) #入力したDirectoryを格納
      elsif directory_input == "q"
        break
      else
        puts "Type existed directory!!"
      end #if Dir.exist?(directory_input)
    end #loop do end

    resultdirectory_input = TRUE #Making direcotry to put on results
    puts "Type the directory in which you put on results."
    resultdirectory_input = gets.chomp
    Dir.mkdir("#{resultdirectory_input}/Plottingdata")

    directory_arr.count.to_i.times do |directory_input_element| #plotting data and collect chosen file
      Dir.chdir(directory_arr[directory_input_element])
      chemkinpro_plottingdata.checkdirectory
      chemkinpro_plottingdata.dataplot
      FileUtils.cp(chemkinpro_plottingdata.checkplottingfilename, "#{resultdirectory_input}/Plottingdata")
    end #directory_arr.count.to_i.times do |directory_input_element| end

    wsh = WIN32OLE.new('WScript.Shell')
    wsh.Popup("Complete plotting data")
  end #case modenum_plottingdata
end #case $modenum end
