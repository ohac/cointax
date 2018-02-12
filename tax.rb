#!/usr/bin/ruby
require 'json'
require 'time'

json = File.open('setting.json', 'r') do |fd|
  fd.read()
end
setting = JSON.parse(json)
coincheckid = setting['coincheckid']
zaifid = setting['zaifid']


class CoinCheck
  module Constants
    TYPE_TABLE = {
      "入金" => :in,
      "取引が成約" => :exec,
      "アフィリエイト報酬" => :etc,
      "指値注文" => :order,
      "指値注文をキャンセル" => :cancel,
      "振替" => nil,
      "購入" => :buy,
      "送金" => :out,
      "銀行振込で出金" => :out,
    }
  end
  include Constants
end

timetable = {}

files = Dir.glob('*.csv')

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
  coins = nil
  body.each_line do |line|
    csv = line.chomp.split(',')
    case mode
    when :coincheck
      if i == 0
      elsif i == 1
        coins = csv[5..-1] # JPY, BTC, ...
      elsif csv[0] == ''
        month += 1
        if month == 13
          year += 1
          month = 1
        end
        datestr = '%04d-%02d-01 00:00:00 JST' % [year, month]
        date = DateTime.parse(datestr)
        j = 5
        coins.each do |coinid|
          amount = csv[j].to_f
          timetable[date] ||= []
          timetable[date] << {
            :type => :checkpoint, :amount => amount, :coinid => coinid
          }
          j += 1
        end
      else
        datestr = csv[1]
        date = DateTime.parse(datestr)
        typestr = csv[2]
        type = CoinCheck::TYPE_TABLE[typestr]
        amount = csv[3].to_f
        coinid = csv[4]
        timetable[date] ||= []
        timetable[date] << {
          :type => type, :amount => amount, :coinid => coinid
        }
      end
    when :zaif
    when :bitbank
    end
    i += 1
  end
end

current_stat = {
}

cc_order_sell_jpy = nil
cc_order_sell_btc = nil
sorted = timetable.sort_by{|k, v| k}
sorted.each do |v|
  date = v[0]
  datestr = date.strftime("%Y/%m/%d %H:%M:%S")
  v[1].each do |stat|
    coinid = stat[:coinid]
    type = stat[:type]
    amount = stat[:amount]
    current_stat[coinid] ||= {
      :amount => 0.0
    }
    case type
    when :checkpoint
      if current_stat[coinid][:amount] < amount - 0.0001
        p [coinid, current_stat[coinid][:amount], amount]
        current_stat[coinid][:amount] = amount
      end
    when :order
      case coinid
      when 'BTC'
        cc_order_sell_btc = amount
      when 'JPY'
        cc_order_sell_jpy = amount
      else
        puts ['internal error', v]
      end
    when :exec
      case coinid
      when 'BTC'
        rate = -cc_order_sell_jpy / amount
        current_stat['BTC'][:amount] += amount
        current_stat['JPY'][:amount] += cc_order_sell_jpy
        cc_order_sell_jpy = nil
      when 'JPY'
        rate = amount / -cc_order_sell_btc
        current_stat['BTC'][:amount] += cc_order_sell_btc
        current_stat['JPY'][:amount] += amount
        cc_order_sell_btc = nil
      else
        puts ['internal error', v]
      end
    when :cancel
      case coinid
      when 'BTC'
        if cc_order_sell_btc.nil?
          p :warn
        end
        cc_order_sell_jpy = nil
      when 'JPY'
        if cc_order_sell_jpy.nil?
          p :warn
          current_stat['JPY'][:amount] += amount
        end
        cc_order_sell_btc = nil
      else
        puts ['internal error', v]
      end
    else
      current_stat[coinid][:amount] += amount
    end
    if amount != 0.0
      p [datestr, stat, current_stat.select{|k,v0|v0[:amount] != 0.0}.map{|v| '%s:%f' % [v[0], v[1][:amount]]}]
    end
  end
end
