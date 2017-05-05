# Support tools for Lab computation and experiment

Contains "chemkinSupportTools", "plotLuminousityProfileTools" and "sensitivityAnalysisTools"

## chemkinSupportTools
###Introduction
Codes to support using chemkin-PRO

###Needed gems
* fileutils
\*For Win
* win32ole


###How to use
1. mfrrun.rb
  1. Create directory which you calculate and directory name must be "{mixture name}_{mechanism name}_P={Pressure}".
  2. Put this code on dirctory which you calculate.
  3. Run this code
  4. Choosing GRAD&CURV mode, Pressure mode and Plotting data mode
  GRAD&CURV mode: You can choose GRAD&CURV condition. And then, under the condition, it is calculated.
    ex: You typed 1, 0.1 and 0.01 -> Under GRAD&CURV is 1, 0.1 and 0.01, you get 0.01 results
  Pressure mode: You have to type target pressure and pressure step.
    ex: Your current directory is "/CH4_GRI3.0_P=1.0". You typed target pressure; 5.0 and pressure step; 0.5 -> You get P=1.0, 1.5, 2.0,...,4.5, 5.0 results.
  Plotting data mode: You can choose (1)directly plot results from "premix.out" or (2)plot results and collect the results to a directory.


## plotLuminousityProfileTools
This code is enable you to create graph of pixel vs. luminousity of flame.
Output file: ".csv"

## sensitivityAnalysisTools
This code helps you brute-force type sensitivity analysis

### How to use sensitivityanalysis.rb & sensitivityanalysis_linux.rb
1. When you use this code, the following files are needed
 - Based computational results which have "restart.zip"
 -"chem.inp" which is same as it in"Based computational results" directory THIS CODE

2. Before you run,
 - Change the "main_directory" in this code to your "Based computational results".
 - (sensitivityanalysis_linux.rb case only) You can change "processor_count" written in l:439 but less than liscence numbers.

3. If "Please check failurelog.txt, or if you have all succeded computational results, please delete failure.out files!!"is showed
  - Check "failurelog.txt"
  - Seek the solution which is failed to caluculate
  - If you have all succeded computational results, delete "failure.out" files and then run this code again.
4. After you run,
  Please check "sensitivity_analysis_database.csv"

### *Attention!!*
This code is not perfect!!
The following contents is wished to be added
* Getting 2nd & 3rd HRR peak getter
* If encoding error is occured, you have to modefy "chem.inp"
