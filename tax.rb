#!/usr/bin/ruby
files = Dir.glob('*.csv')

coincheckid = '99999' # TODO
zaifid = '999' # TODO

files.each do |fn|
  body = File.open(fn, 'r') do |fd|
    fd.read()
  end
  mode = nil
  case fn
  when /^#{coincheckid}_/
    mode = :coincheck
    ym = fn.split(/[_.]/)[1,1].first
    year = ym[0,4].to_i
    month = ym[4,6].to_i
  when /^#{zaifid}_/
    mode = :zaif
  when /^trade_history/
    mode = :bitbank
  end

  i = 0
  body.each_line do |line|
    csv = line.chomp.split(',')
    case mode
    when :coincheck
      if i == 0
      elsif i == 1
        coins = csv[5,10] # JPY, BTC, ...
      elsif csv[0] == ''
        p [year, month, csv]
      else
        #p csv
      end
    when :zaif
    when :bitbank
    end
    i += 1
  end
end
