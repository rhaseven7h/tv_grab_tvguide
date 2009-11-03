#!/usr/bin/env ruby

require 'rubygems'
require 'open-uri'
require 'pp'
require 'hpricot'

class XMLTVUtilisima
  def initialize()
    @url_base = "http://www.utilisima.com/programacion/%04i%02i%02i"
  end

  def fetch
    time_fr = Time.parse(Time.now.strftime('%Y-%m-%d'))
    time_to = time_fr + (7 * 24 * 60 * 60)
    data = get_data
    (0..(data.size-1)).each do |i|
      if i == data.size - 1
        data[i][:stop] = Time.parse(data[i][:start].strftime('%Y-%m-%d'))+(7 * 60 * 60)
      else
        data[i][:stop] = data[i+1][:start]
      end
    end
    data = data.map do |i|
      i[:number] = '67'
      i[:xmltv_id] = '67.UTIL.cmj'
      if i[:start] < time_fr and i[:stop] <= time_fr
        out = nil
      elsif i[:start] >= time_to and i[:stop] > time_to
        nil
      elsif i[:start] < time_fr
        i[:start] = time_fr
        i
      elsif i[:stop] > time_to
        i[:stop] = time_to
        i
      else
        i
      end
      i[:title] = "<![CDATA[#{i[:title]}]]>"
      i[:length] = ((i[:stop] - i[:start]) / 60.0).to_i.to_s
      i[:start] = i[:start].strftime('%Y%m%d%H%M')+' -0600'
      i[:stop] = i[:stop].strftime('%Y%m%d%H%M')+' -0600'
      i[:category] = 'tvshow'
      i[:programme_id] = ''
      i[:callsign] = 'UTIL'
      i[:offset] = '-0600'
      i
    end
    data.compact
  end

  private

  def get_data
    return (0..8).to_a.
      map{|num| Time.parse((Time.now-(24 * 60 * 60)).strftime('%Y-%m-%d')) + (num * 24 * 60 * 60) }.
      map{|day| get_programmes(day) }.
      flatten.
      sort{|i,j| i[:start] <=> j[:start] }
  end

  def get_programmes(this_day)
    next_day = this_day + (24 * 60 * 60)
    url = sprintf(@url_base, this_day.year, this_day.month, this_day.day)
    src = ''
    open(url) do |fh|
      # Nasty structure error in Utilisima HTML source
      src = fh.read.gsub('div id="show""', 'div id="show"')
      # Now take into account the silly CSS class used for the currently running show and the annoying AHORA!!! label.
      src = src.gsub('div id="show_onNow"','div id="show"').gsub(' - AHORA !!!','')
    end
    doc = Hpricot(src)
    data = [] 
    (doc/"div#programacion/div#show/a.thickbox").each do |a|
      str_text = ''
      if a.at('span')
        str_text = a.at('span').inner_text.gsub(/\r\n/,' ').strip
      else
        str_text = a.inner_text.gsub(/\r\n/,' ').strip
      end
      int_secs = (str_text[0..1].to_i * 60 * 60)+(str_text[3..4].to_i * 60)
      str_desc = str_text[8..-1]

      prog_time = this_day
      if int_secs >= (7 * 60 * 60)
        prog_time = this_day + int_secs
      else
        prog_time = next_day + int_secs
      end
      prog_time -= 60 * 60
      eh = {}
      eh[:start] = prog_time
      eh[:title] = str_desc
      data << eh
    end
    data
  end
  
end


