#!/usr/bin/ruby
require 'json'
require 'time'

json = File.open('setting.json', 'r') do |fd|
  fd.read()
end
setting = JSON.parse(json)

dust_table = {
  'JPY' => 0.1,
  'BTC' => 0.0000001,
  'LTC' => 0.00001,
  'MONA' => 0.0001,
  'MIZUKI' => 0.1,
  'SHIRAHOSHI' => 0.1,
  'ICHARLOTTE' => 0.1,
  'MAMICHANNEL' => 0.1,
  'HINANOMAI' => 0.1,
  'RURU' => 0.1,
}

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

ex_table = {}

files = Dir.glob(['zaif/*.csv', 'coincheck/*.csv', 'bitbank/*.csv'])

files.each do |fn|
  body = File.open(fn, 'r') do |fd|
    fd.read()
  end
  mode = nil
  exchange_id = nil
  case fn

  when /^coincheck\/[0-9]+_/
    exchange_id = :coincheck
    mode = :coincheck
    ym = fn.split(/[_.]/)[1,1].first
    year = ym[0,4].to_i
    month = ym[4,6].to_i
  when /^coincheck\/my-complete-orders-/
    exchange_id = :coincheck
    mode = :coincheck_orders
  when /^coincheck\/buys-/
    exchange_id = :coincheck
    mode = :coincheck_buys
  when /^coincheck\/sells-/
    exchange_id = :coincheck
    mode = :coincheck_sells
  when /^coincheck\/withdraws-/
    exchange_id = :coincheck
    mode = :coincheck_withdraws
  when /^coincheck\/deposits-/
    exchange_id = :coincheck
    mode = :coincheck_deposits
  when /^coincheck\/send-/
    exchange_id = :coincheck
    mode = :coincheck_send

  when /^zaif\/[0-9]+_/
    exchange_id = :zaif
    mode = :zaif
  when /^zaif\/.*_deposit.csv/
    exchange_id = :zaif
    mode = :zaif_deposit
  when /^zaif\/.*_withdraw.csv/
    exchange_id = :zaif
    mode = :zaif_withdraw
  when /^zaif\/obtain_bonus.csv/
    exchange_id = :zaif
    mode = :zaif_obtain_bonus

  when /^bitbank\/trade_history/
    exchange_id = :bitbank
    mode = :bitbank
  when /^bitbank\/withdraws-/
    exchange_id = :bitbank
    mode = :bitbank_withdraws
  when /^bitbank\/deposits-/
    exchange_id = :bitbank
    mode = :bitbank_deposits
  # TODO bitbank/order_history.csv
  # TODO bitbank/asset_records.csv

  else
    puts 'skip: ' + fn
    next
  end

  exchange = ex_table[exchange_id] ||= {}
  timetable = exchange[:timetable] ||= {}
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
        if type == :etc # use affiliate only
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
    when :zaif_obtain_bonus
      if i == 0
      else
        datestr = csv[0].split('.').first
        date = DateTime.parse(datestr)
        amount = csv[2].to_f
        coinid = csv[3].upcase
        timetable[date] ||= []
        timetable[date] << {
          :type => :in, :amount => amount, :coinid => coinid
        }
      end

    when :bitbank
      if i == 0
      else
        coinpair = csv[2].upcase
        coinid1, coinid2 = coinpair.split('_')
        coinid1 = 'BCH' if coinid1 == 'BCC'
        coinid2 = 'BCH' if coinid2 == 'BCC'
        typestr = csv[3]
        type = BitBank::TYPE_TABLE[typestr]
        amount = csv[4].to_f
        price = csv[5].to_f
        fee = csv[6].to_f
        datestr = csv[8]
        date = DateTime.parse(datestr)
        timetable[date] ||= []
        case type
        when :buy
          timetable[date] << {
            :type => type, :amount => amount, :coinid => coinid1
          }
          timetable[date] << {
            :type => type, :amount => -amount * price - fee,
            :coinid => coinid2
          }
        when :sell
          timetable[date] << {
            :type => type, :amount => -amount, :coinid => coinid1
          }
          timetable[date] << {
            :type => type, :amount => amount * price + fee,
            :coinid => coinid2
          }
        end
      end
    when :bitbank_deposits
      if i == 0
      else
        datestr = csv[1]
        date = DateTime.parse(datestr)
        amount = csv[2].to_f
        coinid = csv[3]
        coinid = 'BCH' if coinid == 'BCC'
        timetable[date] ||= []
        timetable[date] << {
          :type => :in, :amount => amount, :coinid => coinid
        }
      end
    when :bitbank_withdraws
      if i == 0
      else
        datestr = csv[1]
        date = DateTime.parse(datestr)
        amount = -csv[2].to_f
        fee = -csv[3].to_f
        coinid = csv[4]
        coinid = 'BCH' if coinid == 'BCC'
        timetable[date] ||= []
        timetable[date] << {
          :type => :out, :amount => amount + fee, :coinid => coinid
        }
      end
    end
    i += 1
  end
end

ex_table.each do |exid, exchange|

  timetable = exchange[:timetable]
  current_stat = {}

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
        puts ['internal error', v]
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
    end
  end
  exchange[:current] = current_stat
end

ex_table.each do |exid, exchange|
  current_stat = exchange[:current]
  not_dust = current_stat.select do |k,v0|
    dust = dust_table[k] || 0.000001
    v0[:amount].abs > dust
  end
  puts exid.to_s + ': ' + not_dust.map{|v| '%s:%.3f' % [v[0][0,3], v[1][:amount]]}.join(' ')
end
