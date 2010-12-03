module Spider; module Components
    
    class MonthCalendar < Spider::Widget
        tag 'month_calendar'
        
        i_attr_accessor :start_month, :type => Fixnum
        i_attr_accessor :start_year, :type => Fixnum
        is_attr_accessor :busy
        
        def prepare
            super
            today = Date.today
            @start_month ||= today.month
            @start_year ||= today.year
            if params['d'] && params['d'] =~ /(\d{4})\/(\d{1,2})/
                @month = $2.to_i
                @year = $1.to_i
            else
                @month = @start_month
                @year = @start_year
            end
            @busy ||= {}
        end
        
        def run
            month = @month; year = @year
            @scene.month = month
            @scene.year = year
            @scene.first_week_day = Spider.i18n.week_start
            @scene.weekend_start = Spider.i18n.weekend_start
            @scene.weekend_end = Spider.i18n.weekend_end
            @scene.days_short_names = Spider.i18n.day_names(:narrow)
            @scene.week_days = (0..6).map{ |i| (@scene.first_week_day + i) % 7 }
            @scene.current_month_name = Spider.i18n.month_names[month]
            @scene.first_day = Date.civil(year, month, 1)
            @scene.first_day_wday = @scene.first_day.wday
            @scene.last_day = Date.civil(year, month, -1)
            @scene.days_in_month = @scene.last_day.day
            @scene.last_day_wday = @scene.last_day.wday
            @scene.prev_month = (@scene.first_day - 1)
            @scene.prev_month_last_day = @scene.prev_month.day
            @scene.next_month = (@scene.first_day + 31)
            @scene.prev_link = "#{@scene.prev_month.year}/#{@scene.prev_month.month}"
            @scene.next_link = "#{@scene.next_month.year}/#{@scene.next_month.month}"
            @scene.rows = [[]]
            row = 0
            col = ((@scene.first_day_wday - @scene.first_week_day) % 7) - 1
            0.upto(col){ |i| @scene.rows[0][i] = {:day => @scene.prev_month_last_day - col + i, :classes => ['prev-month'] } }
            1.upto(@scene.days_in_month) do |i|
                col += 1
                if (col == 7)
                    col = 0
                    row += 1
                    @scene.rows[row] = []
                end
                classes = []
                is_busy = @busy[year] && @busy[year][month] && @busy[year][month][i]
                classes << 'busy' if is_busy
                @scene.rows[row][col] = {:day => i, :classes => classes, :busy => is_busy, :current_month => true}
            end
            (col+1).upto(6){ |i| @scene.rows[row][i] = {:day => i - col, :classes => ['next-month'] } }
        end
        
        def set_busy_date(d)
            @busy ||= {}
            @busy[d.year] ||= {}
            @busy[d.year][d.month] ||= {}
            @busy[d.year][d.month][d.day] = true
        end
        
        
    end
    
end; end