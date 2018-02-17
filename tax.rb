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
      "送金" => :out, # TODO fee
      "銀行振込で出金" => :out, # TODO fee
    }
    OUT_FEE_TABLE = {
      "ZEC" => 0.001,
      "REP" => 0.01,
      "XRP" => 0.15,
      "BTC" => 0.0005, # TODO 0.0002 (-2016/11?)
      "ETH" => 0.01,
      "ETC" => 0.01,
      "DAO" => 1.0,
      "JPY" => 500.0, # TODO
    }
    TYPE_TABLE_ORDERS = {
      "sell" => :sell,
      "buy" => :buy,
    }
    TYPE_TABLE_BUYS = {
      "completed" => :completed,
      "pending" => :pending,
    }
  end
  include Constants
end

class Zaif
  module Constants
    TYPE_TABLE = {
      "bid" => :buy,
      "ask" => :sell,
    }
  end
  include Constants
end

class BitBank
  module Constants
    TYPE_TABLE = {
      "buy" => :buy,
      "sell" => :sell,
    }
  end
  include Constants
end

timetable = {}

#files = Dir.glob(['zaif/*.csv', 'coincheck/*.csv', 'bitbank/*.csv'])
#files = Dir.glob(['coincheck/*.csv'])
files = Dir.glob(['zaif/*.csv'])
#files = Dir.glob(['bitbank/*.csv'])

files.each do |fn|
  body = File.open(fn, 'r') do |fd|
    fd.read()
  end
  mode = nil
  case fn

  when /^coincheck\/[0-9]+_/
    mode = :coincheck
    ym = fn.split(/[_.]/)[1,1].first
    year = ym[0,4].to_i
    month = ym[4,6].to_i
  when /^coincheck\/my-complete-orders-/
    mode = :coincheck_orders
  when /^coincheck\/buys-/
    mode = :coincheck_buys
  when /^coincheck\/sells-/
    mode = :coincheck_sells
  when /^coincheck\/withdraws-/
    mode = :coincheck_withdraws
  when /^coincheck\/deposits-/
    mode = :coincheck_deposits
  when /^coincheck\/send-/
    mode = :coincheck_send

  when /^zaif\/[0-9]+_/
    mode = :zaif
  when /^zaif\/.*_deposit.csv/
    mode = :zaif_deposit
  when /^zaif\/.*_withdraw.csv/
    mode = :zaif_withdraw
  # TODO zaif/obtain_bonus.csv
  # TODO zaif/tip_receive.csv

  when /^bitbank\/trade_history/
    mode = :bitbank
  # TODO bitbank/order_history.csv
  # TODO bitbank/trade_history.csv
  # TODO bitbank/bitbank_deposit
  # TODO bitbank/bitbank_withdraw

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
        if type == :etc
          timetable[date] ||= []
          timetable[date] << {
            :type => type, :amount => amount, :coinid => coinid
          }
        end
      end
    when :coincheck_orders
      if i == 0
      else
        datestr = csv[0]
        date = DateTime.parse(datestr)
        typestr = csv[1]
        type = CoinCheck::TYPE_TABLE_ORDERS[typestr]
        rate = csv[3].to_f
        amount = csv[4].to_f
        jpy = csv[5].to_f
        jpyfee = csv[6].to_f
        timetable[date] ||= []
        timetable[date] << {
          :type => type, :amount => amount, :coinid => 'BTC'
        }
        timetable[date] << {
          :type => type, :amount => jpy, :coinid => 'JPY'
        }
      end
    when :coincheck_buys
      if i == 0
      else
        datestr = csv[6]
        date = DateTime.parse(datestr)
        typestr = csv[5]
        type = CoinCheck::TYPE_TABLE_BUYS[typestr]
        amount1 = csv[1].to_f
        coinid1 = csv[3]
        price = csv[2].to_f
        coinid2 = csv[4]
        timetable[date] ||= []
        timetable[date] << {
          :type => type, :amount => amount1, :coinid => coinid1
        }
        timetable[date] << {
          :type => type, :amount => -price, :coinid => coinid2
        }
      end
    when :coincheck_sells
      if i == 0
      else
        datestr = csv[6]
        date = DateTime.parse(datestr)
        typestr = csv[5]
        type = CoinCheck::TYPE_TABLE_BUYS[typestr]
        amount1 = csv[1].to_f
        coinid1 = csv[3]
        price = csv[2].to_f
        coinid2 = csv[4]
        timetable[date] ||= []
        timetable[date] << {
          :type => type, :amount => -amount1, :coinid => coinid1
        }
        timetable[date] << {
          :type => type, :amount => price, :coinid => coinid2
        }
      end
    when :coincheck_deposits
      if i == 0
      else
        datestr = csv[1]
        date = DateTime.parse(datestr)
        amount = csv[2].to_f
        coinid = csv[3]
        timetable[date] ||= []
        timetable[date] << {
          :type => :out, :amount => amount, :coinid => coinid
        }
      end

    when :coincheck_withdraws
      if i == 0
      else
        datestr = csv[1]
        date = DateTime.parse(datestr)
        amount = -csv[2].to_f
        fee = -csv[3].to_f
        timetable[date] ||= []
        timetable[date] << {
          :type => :out, :amount => amount + fee, :coinid => 'JPY'
        }
      end

    when :coincheck_send
      if i == 0
      else
        datestr = csv[1]
        date = DateTime.parse(datestr)
        coinid = csv[2]
        amount = -csv[3].to_f
        fee = -csv[5].to_f
        timetable[date] ||= []
        timetable[date] << {
          :type => :out, :amount => amount + fee, :coinid => coinid
        }
      end

    when :zaif
      if i == 0
      else
        coinpair = csv[0][1..-2].upcase
        coinid1, coinid2 = coinpair.split('_')
        typestr = csv[1][1..-2]
        type = Zaif::TYPE_TABLE[typestr]
        pricestr = csv[2][1..-2]
        price = pricestr.to_f
        amountstr = csv[3][1..-2]
        amount = amountstr.to_f
        feestr = csv[4][1..-2]
        fee = feestr.to_f
        bonusstr = csv[5][1..-2]
        bonus = bonusstr.to_f
        datestr = csv[6][1..-2].split('.').first
        date = DateTime.parse(datestr)
        amount = -amount if type == :sell
        timetable[date] ||= []
        timetable[date] << {
          :type => type, :amount => amount, :coinid => coinid1
        }
        timetable[date] << {
          :type => type, :amount => -amount * price, :coinid => coinid2
        }
      end
    when :zaif_deposit
      if i == 0
      else
        datestr = csv[0].split('.').first
        date = DateTime.parse(datestr)
        case fn
        when /token_deposit.csv$/
          coinid = csv[1]
          amountstr = csv[2]
          amount = amountstr.to_f
          timetable[date] ||= []
          timetable[date] << {
            :type => type, :amount => amount, :coinid => coinid
          }
        else
          amountstr = csv[1]
          amount = amountstr.to_f
          coinid = fn.split(/[\/_]/)[1].upcase
          timetable[date] ||= []
          timetable[date] << {
            :type => type, :amount => amount, :coinid => coinid
          }
        end
      end
    when :zaif_withdraw
      if i == 0
      else
        case fn
        when /token_withdraw.csv$/
        else
          datestr = csv[0].split('.').first
          date = DateTime.parse(datestr)
          amountstr = csv[1]
          amount = amountstr.to_f
          fee = csv[2].to_f
          coinid = fn.split(/[\/_]/)[1].upcase
          timetable[date] ||= []
          timetable[date] << {
            :type => type, :amount => -(amount + fee), :coinid => coinid
          }
        end
      end
    when :bitbank
      if i == 0
      else
        coinpair = csv[2].upcase
        coinid1, coinid2 = coinpair.split('_')
        typestr = csv[3]
        type = BitBank::TYPE_TABLE[typestr]
        amount = csv[4].to_f
        price = csv[5].to_f
        fee = csv[6].to_f
        datestr = csv[8]
        date = DateTime.parse(datestr)
        timetable[date] ||= []
        timetable[date] << {
          :type => type, :amount => amount, :coinid => coinid1
        }
        timetable[date] << {
          :type => type, :amount => -amount * price, :coinid => coinid2
        }
      end
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
      puts [datestr, current_stat.select{|k,v0|v0[:amount] != 0.0}.map{|v| '%s:%.3f' % [v[0][0,3], v[1][:amount]]}.join(' ')].join(' ')
      pcoins = ['JPY','BTC','MONA']
      #puts [datestr, current_stat.select{|k,v0|pcoins.include?(k)}.map{|v| '%s:%f' % [v[0], v[1][:amount]]}.join(' ')].join(' ')
    end
  end
end
