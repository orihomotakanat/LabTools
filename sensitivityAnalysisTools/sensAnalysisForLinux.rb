#This file is support tool of computational code of MFR.
#(c) Tomohiro Tanaka <tanakat@edyn.ifs.tohoku.ac.jp>

require "fileutils"
require "parallel"
require 'sqlite3'

#Number of computational processor----------------------------------------------
#-------------------------------------------------------------------------------
computational_processor_count = 6 #Parallel.processor_count
####Sensitivityinput class------------------------------------------------------

####Sensitivityinput class------------------------------------------------------
class Sensitivityinput
  attr_accessor :inputfile, :outfile, :resultfile, :runfile, :reaction_number, :rateconstant_condition, :tw_hrr, :tw_coo, :hrr_column, :coo_column, :main_directory, :reaction_directory, :temporary_file, :plot_file, :idfile, :locationrange, :dbname, :sensitivity_dbname, :sensitivity_csvname, :failure_file, :jump_makedb_signal, :make_reactionfile_signal, :failurelog

  def initialize(inputfile = "chem.inp", outfile = "premix.out", resultfile = "result.txt", runfile = "./run.sh", rateconstant_condition = 0, reaction_number = 0, main_directory = "Syngas5050_Li_P=1.0", temporary_file = "temp.csv", locationrange = "10.0000", jump_makedb_signal = 1, make_reactionfile_signal = 1, failurelog = "failurelog.txt")
    @inputfile = inputfile
    @outfile = outfile
    @resultfile = resultfile
    @runfile = runfile
    @reaction_number = reaction_number
    @rateconstant_condition = rateconstant_condition
    @tw_hrr = nil
    @tw_coo = nil
    @locationrange = locationrange

    @hrr_column = nil
    @coo_column = nil

    @main_directory = main_directory
    @reaction_directory = nil
    @idfile = nil
    @temporary_file = temporary_file
    @plot_file = nil
    @dbname = nil
    @sensitivity_dbname = nil
    @sensitivity_csvname = nil

    @failure_file = nil
    @jump_makedb_signal = jump_makedb_signal #jump_makedb_signal = 1 -> chem.inp mode / jump_makedb_signal = 2 -> making db/ signal = 3 -> exit with def finisher
    @make_reactionfile_signal = make_reactionfile_signal #make_reactionfile_signal
    @failurelog = failurelog
  end #def initialize end

  def reaction_number_getter
    File.open(@inputfile,"r+") do |cheminp_l|
      element_line = cheminp_l.readlines
      element_line.count.times do |cheminp_reaction_l|
        if /^(.*)=(.*)$/ =~ element_line[cheminp_reaction_l]
          @reaction_number = @reaction_number + 1
        end #if /^(.*)=(.*)$/ =~ element_line[cheminp_reaction_l] end
      end #element_line.count.times do |cheminp_reaction_l| end
    end #File.open(@inputfile,"r+") do |cheminp_l| end
    return @reaction_number
  end #def reaction_number_getter end

  def change_cheminp
    #making chem.inp for sensitivity analysis
    File.open(@inputfile, "r+") do |cheminp_l|
      eachline = cheminp_l.readlines
      agreement_line_arr = Array.new
      eachline.count.times do |line_num|
        if /^(.*)=(.*)$/ =~ eachline[line_num]
          agreement_line_arr.push(line_num)
        end
      end #eachline.count.times do |line_num|

      eachline.count.times do |line_num|
        if agreement_line_arr[@reaction_number-1] == line_num
          rateconstant = @rateconstant_condition*eachline[line_num].split.slice!(1).to_f
          eachline[line_num] = "#{eachline[line_num].split.slice!(0)}                     #{rateconstant}   #{eachline[line_num].split.slice!(2)}    #{eachline[line_num].split.slice!(3)}\n"

          File.open(@idfile, "w") do |new_chem_line|
            eachline.each do |write_l|
              new_chem_line.write write_l
            end #eachline.each do |write_l| end
          end #File.open(output, "w") do |new_chem_line| end
        end #if reaction_l == line_num
      end #eachline.count.times do |line_num|
    end #File.open(input, "r+") do |cheminp_l|
  end #def change_cheminp

  def mv_cheminp
    #Making directory
    if File.exist?(@main_directory) && File.exist?(@reaction_directory)
    elsif File.exist?(@main_directory)
      FileUtils.cp_r(@main_directory, @reaction_directory)
    else
      puts "Main directory was not found"
      exit
    end #if File.exist?(@main_directory) end

    #Move file to directory
    FileUtils.mv(@idfile, @reaction_directory)
  end #def mv_cheminp end

  def run_sensitivity
    run = system(@runfile)
    if run
      puts "#{@idfile} is succeeded."
    else
      FileUtils.cp(@outfile, @failure_file)
      puts "!!!!!!!!!!!!!!!ATTENTION!!!!!!!!!!!!!!!\nFailure. Please check #{@failure_file}\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    end
  end #def run_sensitivity end

  def output_result
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
  end #def output_result end

  def changedirectory_sensitivity
    current_directory = File.basename(Dir.pwd)
    if /^reaction_/ =~ current_directory || current_directory == @main_directory
      Dir.chdir("..")
    elsif File.exist?(@main_directory)
      Dir.chdir(@reaction_directory)
    else
      puts "Directory ERROR"
    end
  end #def changedirectory_sensitivity end

  def rescue_failure
    current_directory = File.basename(Dir.pwd)
    if /^reaction_/ =~ current_directory
      if File.exist?(@failure_file)
        Dir.chdir("..")
        #making failurelog------------------------------------------------------
        if File.exist?(@failurelog)
          File.open(@failurelog, "a+") do |log_l|
            log_l.write "#{@failure_file}\n"
          end #File.open(@failurelog, "a+") do |log_l|
        else
          File.open(@failurelog, "w") do |log_l|
            log_l.write "Please check reaction number of failed computation below\n#{@failure_file}\n"
          end #File.open(@failurelog, "r+") do |log_l|
        end #if File.exist?(@failure_file) end
        #-----------------------------------------------------------------------
        Dir.chdir(current_directory)
        @jump_makedb_signal = 2 #do not go to making db & exit with def finisher
      end #if File.exist?(@failure_file)
    else
      if File.exist?(@reaction_directory)
        @make_reactionfile_signal = 2
      end #if File.exist?(@failurelog)
    end #if /^reaction_/ =~ current_directory
  end #def rescue_failure end

  def finisher
    if @jump_makedb_signal == 2
      puts "Please check failurelog.txt, or if you have all succeded computational results, please delete failure.out files!! "
      exit
    end
  end

end #class Sensitivityinput end
################################################################################
####Sensitivityoutput class-----------------------------------------------------
class Sensitivityoutput < Sensitivityinput
  def dataplot_sensitivity
    chemicalspecieslist = Array.new(["CO", "O"])
    chemicalspecies_line = Array.new
    chemicalspecies_column = Array.new
    endpoint = 0 #end point of location

    File.open(@idfile, "r+") do |chem_l|
      #search number of end point of location-----------------------------------
      col_arr = chem_l.readlines
      col_arr.length.to_i.times do |col_l|
        if /#{@locationrange}/ =~ col_arr[col_l]
          endpoint = col_l
          break
        end #if /10.0000/ =~ col_arr[col_l] end
      end #col_arr.length.to_i.times do |col_l| end

      #molefraction-------------------------------------------------------------
      for chem in 0..chemicalspecieslist.count-1 do #molefraction plot
        col_arr.length.to_i.times do |col_l|
          if /^#{chemicalspecieslist[chem]}/ || / #{chemicalspecieslist[chem]} / =~ col_arr[col_l] #plotとしたいmole speciesが何行目にあるか探す
            chemicalspecies_line[chem] = col_l
            break
          end #if /#{chemicalspecieslist[chem]}        / =~ col_arr[col_l] end
        end #col_arr.length.to_i.times do |col_l| end
        col_arr[chemicalspecies_line[chem]].split.count.times do |molefraction|
          if /^#{chemicalspecieslist[chem]}+$/ =~ col_arr[chemicalspecies_line[chem]].split.slice!(molefraction) #plotするmolefractionが何列目にあるか
            chemicalspecies_column[chem] = molefraction
          end #if /^#{chemicalspecieslist[chem]}+$/ =~ col_arr[chemicalspecies_line[chem]].split.slice!(molefraction) end
        end #col_arr[chemicalspecies_line[chem]].split.count.times do |molefraction| end
      end #for t in 0..chemicalspecieslist.count-1 do end

      #output data--------------------------------------------------------------
      File.open(@plot_file, "w") do |prof_l|
        #l1 output
        prof_l.write "#{col_arr[1].split.slice!(0)},Tw[K],HRR[J/cm3sec],COO\n" #l1 output

        #from l2 output
        for eachline in 2..endpoint do
          if col_arr[eachline].split.slice!(1).to_f <= 2.5
            prof_l.write "#{col_arr[eachline].split.slice!(1)},300,#{4.1868*col_arr[eachline].split.slice!(6).to_f},"
          elsif col_arr[eachline].split.slice!(1).to_f >= 2.5 && col_arr[eachline].split.slice!(1).to_f < 4.5
            prof_l.write "#{col_arr[eachline].split.slice!(1)},#{125*col_arr[eachline].split.slice!(1).to_f*col_arr[eachline].split.slice!(1).to_f-625*col_arr[eachline].split.slice!(1).to_f+1081.25},#{4.1868*col_arr[eachline].split.slice!(6).to_f},"
          elsif col_arr[eachline].split.slice!(1).to_f >= 4.5 && col_arr[eachline].split.slice!(1).to_f < 6.5
            prof_l.write "#{col_arr[eachline].split.slice!(1)},#{-125*col_arr[eachline].split.slice!(1).to_f*col_arr[eachline].split.slice!(1).to_f+1625*col_arr[eachline].split.slice!(1).to_f-3981.25},#{4.1868*col_arr[eachline].split.slice!(6).to_f},"
          else
            prof_l.write "#{col_arr[eachline].split.slice!(1)},1300,#{4.1868*col_arr[eachline].split.slice!(6).to_f},"
          end #if col_arr[eachline].split.slice!(1).to_f <= 2.5 end
          prof_l.write "#{col_arr[eachline+chemicalspecies_line[0]-1].split.slice!(chemicalspecies_column[0]+2).to_f*col_arr[eachline+chemicalspecies_line[1]-1].split.slice!(chemicalspecies_column[1]+2).to_f}\n"
        end #for eachline in 2..endpoint do end
      end #File.open("plotresults_#{@current_condition}=#{@current_value}.csv", "w") do |prof_l| end

    end #File.open(@idfile, "r+") do |chem_l| end
  end #def dataplot_sensitivity end

  def output_db
    if File.exist?(@temporary_file)
      FileUtils.rm(@temporary_file)
    end
    FileUtils.install(@plot_file, @temporary_file)

    #l1 delete
    File.open(@temporary_file, "r+") do |prof|
      new_l = prof.readlines
      File.open(@temporary_file, "w") do |temp_l|
        new_l.count.times do |write_l|
          if write_l == 0
          else
            temp_l.write new_l[write_l]
          end #if write_l == 0 end
        end #new_l.count.times do |write_l| end
      end #File.open(@temporary_file, "w") do |temp_l| end
    end #File.open(@temporary_file, "r+") do |prof| end

    #make database of output
    if File.exist?(@dbname)
      FileUtils.rm(@dbname) #****for debug code
    end
    ##column name for dbname
    x_col = 0
    tw_col = 1
    hrr_col = 2
    coo_col = 3
    ##----------------------

    SQLite3::Database.open(@dbname) do |db|
      db.execute <<-SQL
      CREATE TABLE profile
      (
        location real,
        tw real,
        hrr real,
        coo real
      )
      SQL

      File.open(@temporary_file, "r+") do |prof|
        db.execute "BEGIN TRANSACTION"
        prof.each_line do |prof_l|
          prof_col = prof_l.split(/,/)
          location = prof_col[x_col]
          tw = prof_col[tw_col]
          hrr = prof_col[hrr_col]
          coo = prof_col[coo_col]
          #output to db
          db.execute "INSERT INTO profile VALUES(?,?,?,?)", [location, tw, hrr, coo]
        end #prof.each_line do |prof_l|
        db.execute "COMMIT TRANSACTION"
      end #File.open(importfile, "r+") do |prof_l|
    end #SQLite3::Database.open(outdb) do |db| end
    if File.exist?(@temporary_file)
      FileUtils.rm(@temporary_file)
    end
  end #def output_db end

end #class Sensitivityoutput < Sensitivityinput end
################################################################################
####Sensitivityoutput class-----------------------------------------------------
class Makingsensitivitydatabase < Sensitivityinput
  def create_db
    if File.exist?(@sensitivity_dbname)
      FileUtils.rm(@sensitivity_dbname)
    end
    SQLite3::Database.open(@sensitivity_dbname) do |db|
      db.execute <<-SQL
      CREATE TABLE sensitivity
      (
        Reaction_number integer,
        Reaction text,
        Tw_HRR_High real,
        Tw_HRR_Low real,
        Tw_HRR real,
        Tw_COO_High real,
        Tw_COO_Low real,
        Tw_COO real
      )
      SQL

      #db用各カラム名------------------------------------------------------------
      reaction_number = 1
      reac_col = 0
      #-------------------------------------------------------------------------
      File.open(@inputfile, "r+") do |file_l|
        db.execute "BEGIN TRANSACTION"
        file_l.each_line do |reaction_l|
          if /^(.*)=(.*)$/ =~ reaction_l
            prof_line = reaction_l.split
            reaction = prof_line[reac_col]

            db.execute "INSERT INTO sensitivity(Reaction_number, Reaction) VALUES(?,?)", [reaction_number,reaction]
            reaction_number = reaction_number + 1
          end #if /^(.*)=(.*)$/ =~ reaction_l end
        end #file_l.each_line do |reaction_l| end
        #db.execute "SELECT * FROM sensitivity" do |result| #for debug
          #puts "#{result[0]} | #{result[1]} | #{result[7]}"
        #end
        db.execute "COMMIT TRANSACTION"
      end #File.open(@inputfile, "r+") do |file_l| end
    end #SQLite3::Database.open(outdb) do |db|
  end #def make_db end

  def peak_getter
    SQLite3::Database.open(@dbname) do |db|
      db.execute "SELECT AVG(tw) FROM profile WHERE hrr=(SELECT max(hrr) FROM profile)" do |hrr|
        @tw_hrr = hrr[0]
      end #db.execute "SELECT AVG(tw) FROM result WHERE hrr=(SELECT max(hrr) FROM result)" do |hrr| end

      db.execute "SELECT AVG(tw) FROM profile WHERE coo=(SELECT max(coo) FROM profile)" do |coo|
        @tw_coo = coo[0]
      end #db.execute "SELECT AVG(tw) FROM result WHERE coo=(SELECT max(coo) FROM result)" do |coo| end
    end #SQLite3::Database.open(@dbname) do |db| end
  end #def peak_getter end

  def migrate_db
    SQLite3::Database.open(@sensitivity_dbname) do |db|
      ##column name for dbname
      reaction_number_col = 0
      ##----------------------
      tw_hrr = @tw_hrr
      tw_coo = @tw_coo
      ##----------------------
      db.execute "BEGIN TRANSACTION"
      db.execute "SELECT Reaction_number FROM sensitivity" do |reac|
        if reac[reaction_number_col] == @reaction_number
          db.execute "UPDATE sensitivity SET #{@hrr_column} = '#{tw_hrr}' WHERE Reaction_number = '#{@reaction_number}'"
          db.execute "UPDATE sensitivity SET #{@coo_column} = '#{tw_coo}' WHERE Reaction_number = '#{@reaction_number}'"
        end
      end #db.execute "SELECT Reaction_number FROM sensitivity" do |reac| end
      db.execute "COMMIT TRANSACTION"
    end #SQLite3::Database.open(@sensitivity_dbname) do |db|
  end #def migrate_main_db end

  def database_to_csv
    File.open(@sensitivity_csvname, "w+") do |csv_l|
      csv_l.write "Reaction_number,Reaction,Tw_HRR_High,Tw_HRR_Low,Tw_HRR,Tw_COO_High,Tw_COO_Low,Tw_COO\n"
    end #File.open(@sensitivity_csvname, "w+") do |csv_l|
    File.open(@sensitivity_csvname, "a+") do |csv_l|
      SQLite3::Database.open(@sensitivity_dbname) do |db|
        db.execute "BEGIN TRANSACTION"
        db.execute "SELECT * FROM sensitivity" do |reac|
          csv_l.write "#{reac[0]},#{reac[1]},#{reac[2]},#{reac[3]},#{reac[4]},#{reac[5]},#{reac[6]},#{reac[7]}\n"
        end #db.execute "SELECT * FROM sensitivity" do |reac|
        db.execute "COMMIT TRANSACTION"
      end #File.open(@sensitivity_csvname, "a+") do |csv_l|
    end #File.open("sensitivity_analysis_database.csv", "w") do |csv_l| end
  end

  def debug
    SQLite3::Database.open(@sensitivity_dbname) do |db|
      #debug
      db.execute "BEGIN TRANSACTION"
      db.execute "SELECT * FROM sensitivity" do |reac_2|
        puts "#{reac_2[7]}" #{reac_2[0]}" #{reac_2[7]}"
      end
      db.execute "COMMIT TRANSACTION"
      #
    end
  end
end #class Makingsensitivitydatabase < Sensitivityinput end
################################################################################
#以下に処理記述------------------------------------------------------------------

sensitivity_input = Sensitivityinput.new
sensitivity_input_high = Sensitivityinput.new
sensitivity_input_low = Sensitivityinput.new

reaction_count = sensitivity_input.reaction_number_getter
sensitivity_input_high.rateconstant_condition = 2.0
sensitivity_input_low.rateconstant_condition = 0.5
sensitivity_input.reaction_directory = "reaction_1"
sensitivity_input.rescue_failure

#File checker###################################################################
sensitivity_condition = Array.new([sensitivity_input_high.rateconstant_condition, sensitivity_input_low.rateconstant_condition])
if sensitivity_input.make_reactionfile_signal == 2
  for reaction in 1..reaction_count
    sensitivity_input.reaction_directory = "reaction_#{reaction}"
    sensitivity_condition.each do |element|
      sensitivity_input.failure_file = "failure_#{reaction}_#{element}.out" #failure case file
      sensitivity_input.changedirectory_sensitivity
      sensitivity_input.rescue_failure
      sensitivity_input.changedirectory_sensitivity
    end #sensitivity_condition.each do |element|
  end #for reaction in 1..reaction_count
end #if sensitivity_input.make_reactionfile_signal == 2
################################################################################

sensitivity_input.finisher

if sensitivity_input.jump_makedb_signal == 1 && sensitivity_input.make_reactionfile_signal == 2
else #run lower code
#Making chem.inp for sensitivity analysis#######################################
##Setting rate constant condition
  processor_count = 6#Parallel.processor_count
  Parallel.map(1..reaction_count, in_processes: processor_count) do |reaction|
    sensitivity_input_high.reaction_number = reaction
    sensitivity_input_low.reaction_number = reaction

    sensitivity_input_high.idfile = "chem_#{reaction}_#{sensitivity_input_high.rateconstant_condition}.inp"
    sensitivity_input_low.idfile = "chem_#{reaction}_#{sensitivity_input_low.rateconstant_condition}.inp"
    sensitivity_input_high.reaction_directory = "reaction_#{reaction}"
    sensitivity_input_low.reaction_directory = "reaction_#{reaction}"

    sensitivity_input_high.change_cheminp
    sensitivity_input_high.mv_cheminp
    sensitivity_input_low.change_cheminp
    sensitivity_input_low.mv_cheminp
  end #Parallel.map(1..reaction_count, in_processes: processor_count) do |reaction| end
################################################################################

#Computation####################################################################
  sensitivity_cheminp = Sensitivityinput.new
  sensitivity_premixout = Sensitivityinput.new
  sensitivity_resulttxt = Sensitivityinput.new

  Parallel.map(1..reaction_count, in_processes: computational_processor_count) do |reaction|
  #set the parameter condition--------------------------------------------------
    sensitivity_condition = Array.new([sensitivity_input_high.rateconstant_condition, sensitivity_input_low.rateconstant_condition])
    sensitivity_input.reaction_directory = "reaction_#{reaction}"
  #-----------------------------------------------------------------------------
    sensitivity_input.changedirectory_sensitivity #home directory -> reaction dir

    sensitivity_condition.each do |element|
    #set the parameter condition------------------------------------------------
      sensitivity_input.idfile = "Reaction number: #{reaction} & Times: #{element}" #for output result
      sensitivity_cheminp.idfile = "chem_#{reaction}_#{element}.inp" #modefying chem.inp
      sensitivity_premixout.idfile = "premix_#{reaction}_#{element}.out" #modefying premix.out
      #sensitivity_resulttxt.idfile = "result_#{reaction}_#{element}.txt" #modefying result.txt
      sensitivity_input.failure_file = "failure_#{reaction}_#{element}.out" #failure case file
    #---------------------------------------------------------------------------
      File.rename(sensitivity_cheminp.idfile, sensitivity_input.inputfile)
      sensitivity_input.run_sensitivity #run
      #sensitivity_input.output_result #output results

      File.rename(sensitivity_input.outfile, sensitivity_premixout.idfile)
      #File.rename(sensitivity_input.resultfile, sensitivity_resulttxt.idfile)
      File.rename(sensitivity_input.inputfile, sensitivity_cheminp.idfile)
    end #sensitivity_condition.each do |element| end
    sensitivity_input.changedirectory_sensitivity #reaction directory -> home dir
  end #Parallel.map(1..reaction_count, in_processes: processor_count) do |reaction| end
################################################################################
end #case sensitivity_input.jump_makedb_signal end


#File checker###################################################################
sensitivity_condition = Array.new([sensitivity_input_high.rateconstant_condition, sensitivity_input_low.rateconstant_condition])
  for reaction in 1..reaction_count
    sensitivity_input.reaction_directory = "reaction_#{reaction}"
    sensitivity_condition.each do |element|
      sensitivity_input.failure_file = "failure_#{reaction}_#{element}.out" #failure case file
      sensitivity_input.changedirectory_sensitivity
      sensitivity_input.rescue_failure
      sensitivity_input.changedirectory_sensitivity
    end #sensitivity_condition.each do |element|
  end #for reaction in 1..reaction_count
################################################################################
sensitivity_input.finisher #reaction fileがあるorfailureファイルがある場合->exit



#Making each database###########################################################
sensitivity_plot = Sensitivityoutput.new
#processor_count = Parallel.processor_count
Parallel.map(1..reaction_count, in_processes: processor_count) do |reaction|
  #set the parameter condition--------------------------------------------------
  sensitivity_condition = Array.new([sensitivity_input_high.rateconstant_condition, sensitivity_input_low.rateconstant_condition])
  sensitivity_input.reaction_directory = "reaction_#{reaction}"
  #-----------------------------------------------------------------------------
  sensitivity_input.changedirectory_sensitivity #home directory -> reaction dir
  sensitivity_condition.each do |element|
    #set the parameter condition------------------------------------------------
    sensitivity_plot.outfile = "premix_#{reaction}_#{element}.out"
    sensitivity_plot.resultfile = "result_#{reaction}_#{element}.txt" #modefying result.txt
    sensitivity_plot.idfile = sensitivity_plot.resultfile
    sensitivity_plot.plot_file = "plot_#{reaction}_#{element}.csv" #plot csvfile
    sensitivity_plot.dbname = "plotdb_#{reaction}_#{element}.db"
    #---------------------------------------------------------------------------
    sensitivity_plot.output_result
    sensitivity_plot.dataplot_sensitivity
    sensitivity_plot.output_db
  end #sensitivity_condition.each do |element| end
  sensitivity_input.changedirectory_sensitivity #reaction dir -> home dir
end #Parallel.map(1..reaction_count, in_processes: processor_count) do |reaction| end
################################################################################
#Making main database###########################################################
sensitivity_main = Sensitivityoutput.new
#Parmater set-------------------------------------------------------------------
sensitivity_main.reaction_directory = sensitivity_main.main_directory
sensitivity_main.idfile = sensitivity_main.resultfile
sensitivity_main.plot_file = "plot_main.csv"
sensitivity_main.dbname = "plotdb_main.db"
#-------------------------------------------------------------------------------
sensitivity_main.changedirectory_sensitivity
sensitivity_main.output_result
sensitivity_main.dataplot_sensitivity
sensitivity_main.output_db
sensitivity_main.changedirectory_sensitivity
################################################################################

#Making sensitivity database of main directory##################################
sensitivity_maindir = Makingsensitivitydatabase.new #上にもある
sensitivity_maindir.dbname = "plotdb_main.db" #上にもある
sensitivity_maindir.sensitivity_dbname = "sensitivity_analysis_database.db"
sensitivity_maindir.sensitivity_csvname = "sensitivity_analysis_database.csv"
sensitivity_maindir.hrr_column = "Tw_HRR"
sensitivity_maindir.coo_column = "Tw_COO"
sensitivity_maindir.create_db

sensitivity_maindir.reaction_directory = sensitivity_maindir.main_directory #上にもある

for reac_n in 1..reaction_count
  sensitivity_maindir.reaction_number = reac_n
  sensitivity_maindir.changedirectory_sensitivity
  sensitivity_maindir.peak_getter #tw_hrr & tw_cooに数値格納
  sensitivity_maindir.changedirectory_sensitivity
  sensitivity_maindir.migrate_db
end
#sensitivity_maindir.debug
################################################################################
#Making sensitivity database of reaction directory##############################
sensitivity_highdir = Makingsensitivitydatabase.new
sensitivity_lowdir = Makingsensitivitydatabase.new
sensitivity_highdir.hrr_column = "Tw_HRR_High"
sensitivity_lowdir.hrr_column = "Tw_HRR_Low"
sensitivity_highdir.coo_column = "Tw_COO_High"
sensitivity_lowdir.coo_column = "Tw_COO_Low"
sensitivity_highdir.sensitivity_dbname = sensitivity_maindir.sensitivity_dbname
sensitivity_lowdir.sensitivity_dbname = sensitivity_maindir.sensitivity_dbname

for reac_n in 1..reaction_count
  sensitivity_highdir.reaction_directory = "reaction_#{reac_n}"
  sensitivity_highdir.dbname = "plotdb_#{reac_n}_#{sensitivity_input_high.rateconstant_condition}.db"
  sensitivity_lowdir.dbname = "plotdb_#{reac_n}_#{sensitivity_input_low.rateconstant_condition}.db"
  sensitivity_highdir.reaction_number = reac_n
  sensitivity_lowdir.reaction_number = reac_n
  sensitivity_highdir.changedirectory_sensitivity
  sensitivity_highdir.peak_getter
  sensitivity_lowdir.peak_getter
  sensitivity_highdir.changedirectory_sensitivity
  sensitivity_highdir.migrate_db
  sensitivity_lowdir.migrate_db
end
################################################################################
sensitivity_maindir.database_to_csv
