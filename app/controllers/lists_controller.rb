class ListsController < ApplicationController

  helper_method :desc_stat

  CARD_NAME_RGX = /\A\s*(.*?>)?\s?(.*?)\s?(\([\d\-\^\.\/]+\))?\s*(\[[\d\/\-\.\^]+\])?\s*\z/
  TIME_SLICE = 31

  THEMES = {
    account:    'Аккаунт-менеджер',
    analyze:    'Анализ',
    anketa:     'Анкета',
    api:        'API',
    appcraft:   'AppCraft',
    auth:       'Авторизация',
    core:       'CoreCRM',
    doc:        'Документация',
    export:     'Экспорт/подача заявки',
    feed:       'Лента проекта',
    improve:    'Улучшения',
    hosting:    'Хостинг',
    layout:     'Верстка',
    meeting:    'Консультации',
    partner:    'Кабинет партнера',
    recommend:  'Рекомендации',
    small:      'Мелкие улучшения',
    stats:      'Статистика',
    tracking:   'Трекинг проектов',
    trellostat: 'Треллостат',
    triggers:   'Триггерная рассылка',
    users:      'Пользователи',
    video:      'Видео'
  }

  FACTORS = {
    '@arseniykanev' => 0.5,
    '@ksilenium' => 0.75
  }

  def show
    session[:selected] = []
    single_list
    get_data
  end

  def selected
    multiple_lists
    get_data
    rows_sorted_by_list = @rows.group_by { |row| row[:list_pos] }
    rows_sorted_by_list = rows_sorted_by_list.sort.to_h
    rows_sorted_by_list.each do |k, v|
      rows_sorted_by_list[k] = v.sort_by { |row| row[:pos] }
    end
    t_rows = []
    rows_sorted_by_list.each do |k, v|
      v.each do |row|
        t_rows << row
      end
    end
    @rows = t_rows
  end

  def report
    if session[:selected].size > 0
      multiple_lists
    else
      single_list
    end
    get_data
    @rows.sort_by! { |row| row[:theme] }
  end

  def stats
    if session[:selected].size > 0
      multiple_lists
    else
      single_list
    end
    get_data
    @data = Hash.new
    @rows.each do |row|
      begin
        card_stat = desc_stat(row[:desc])
        card_stat.each do |user, user_stat|
          user_stat.each do |date, date_stat|
            @data[user] ||= {}
            @data[user][date] ||= [0, 0, 0, 0]
            @data[user][date][0] += date_stat[:spent] + date_stat[:bugfix] + date_stat[:offhour]
            @data[user][date][1] += date_stat[:spent]
            @data[user][date][2] += date_stat[:offhour]
            @data[user][date][3] += date_stat[:bugfix]
          end
        end
      rescue
        next
      end
    end
    @data = @data.sort
  end

  def update_card
    card = trello_client.find(:card, params[:card_id])
    @board = trello_client.find(:board, card.board_id)
    @members = @board.members.map { |member| '@' + member.username }
    @list = trello_client.find(:list, card.list_id)
    name, desc, checklists, factor_time = card.name, card.desc, card.checklists, nil
    if checklists.size > 0 && check_for_hours(checklists)
      card_stat = checklists_stat_by_date(checklists)
      desc = build_desc(card_stat, desc)
      card.desc = desc
    else
      card_stat = desc_stat_by_date(desc)
    end
    factor_time = factor_time(desc)
    if factor_time
      factor_time_spent = factor_time[:spent]
      factor_time_bugfix = factor_time[:bugfix]
      factor_time_offhour = factor_time[:offhour]
      total_work = params[:total_work].to_f - params[:spent].to_f - params[:offhour].to_f + factor_time_spent + factor_time_offhour
      total_bugfix = params[:total_bugfix].to_f - params[:bugfix].to_f + factor_time_bugfix
    else
      total_work = params[:total_work].to_f - params[:spent].to_f - params[:offhour].to_f + parsed_name[:spent] + parsed_name[:offhour]
      total_bugfix = params[:total_bugfix].to_f - params[:bugfix].to_f + parsed_name[:bugfix]
    end
    estimated = parse_card_name(name)[:estimated]
    card_estimated_stat = checklists_estimated_stat(checklists)
    if card_estimated_stat < estimated
      card_estimated_stat = estimated
    end
    name = build_name(card_stat, name, card_estimated_stat)
    parsed_name = parse_card_name(name)
    data = {
      estimated: parsed_name[:estimated],
      spent: parsed_name[:spent],
      bugfix: parsed_name[:bugfix],
      offhour: parsed_name[:offhour]
    }
    card.name = name
    card.save
    cards = @list.cards
    threads = []
    total_estimated = 0
    cards.each do |card|
      threads << Thread.new do
        parsed_name = parse_card_name(card.name)
        total_estimated += parsed_name[:estimated]
      end
    end
    threads.each { |t| t.join }
    data['total_estimated'] = total_estimated
    data['total_work'] = total_work
    data['total_bugfix'] = total_bugfix
    data['factor_time_spent'] = factor_time_spent
    data['factor_time_bugfix'] = factor_time_bugfix
    data['factor_time_offhour'] = factor_time_offhour
    render json: data
  end

  def refresh_card
    card = trello_client.find(:card, params[:card_id])
    p params[:spent]
    @board = trello_client.find(:board, card.board_id)
    @members = @board.members.map { |member| '@' + member.username }
    @list = trello_client.find(:list, card.list_id)
    name, desc, checklists = card.name, card.desc, card.checklists
    parsed_name = parse_card_name(name)

    equality, updatable, factor_time = nil, nil, nil
    valid = check_validity(checklists, desc)
    if valid[0]
      equality = check_hours_equality(parsed_name, desc, checklists)
      if equality
        card_estimated_stat = checklists_estimated_stat(checklists)
        updatable = check_updatable(parsed_name, desc, checklists, card_estimated_stat) || check_estimated_updatable(parsed_name, card_estimated_stat)
        if !updatable
          factor_time = factor_time(desc)
        end
      end
    end
    data = {
      estimated: parsed_name[:estimated],
      spent: parsed_name[:spent],
      bugfix: parsed_name[:bugfix],
      offhour: parsed_name[:offhour]
    }
    card.name = name
    card.save
    if factor_time
      factor_time_spent = factor_time[:spent]
      factor_time_bugfix = factor_time[:bugfix]
      factor_time_offhour = factor_time[:offhour]
      total_work = params[:total_work].to_f - params[:spent].to_f - params[:offhour].to_f + factor_time_spent + factor_time_offhour
      total_bugfix = params[:total_bugfix].to_f - params[:bugfix].to_f + factor_time_bugfix
    else
      total_work = params[:total_work].to_f - params[:spent].to_f - params[:offhour].to_f + parsed_name[:spent] + parsed_name[:offhour]
      total_bugfix = params[:total_bugfix].to_f - params[:bugfix].to_f + parsed_name[:bugfix]
    end
    cards = @list.cards
    threads = []
    total_estimated = 0
    cards.each do |card|
      threads << Thread.new do
        parsed_name = parse_card_name(card.name)
        total_estimated += parsed_name[:estimated]
      end
    end
    threads.each { |t| t.join }
    data['total_estimated'] = total_estimated
    data['total_work'] = total_work
    data['total_bugfix'] = total_bugfix
    data['valid'] = valid
    data['equality'] = equality
    data['updatable'] = updatable
    data['factor_time_spent'] = factor_time_spent
    data['factor_time_bugfix'] = factor_time_bugfix
    data['factor_time_offhour'] = factor_time_offhour
    render json: data
  end

  private

  def factor_time(desc)
    out = {}
    desc_stat = desc_stat(desc)
    desc_stat.each do |user, user_stat|
      if FACTORS.include?(user)
        factor = FACTORS[user]
      else
        factor = 1
      end
      out[:spent] ||= 0
      out[:bugfix] ||= 0
      out[:offhour] ||= 0
      user_stat.each do |date, date_stat|
        out[:spent] += date_stat[:spent] * factor
        out[:bugfix] += date_stat[:bugfix] * factor
        out[:offhour] += date_stat[:offhour] * factor
      end
    end
    out
  end

  def single_list
    @lists = [trello_client.find(:list, params[:id])]
    @board = trello_client.find(:board, @lists[0].board_id)
    @members = @board.members.map { |member| '@' + member.username }
  end

  def multiple_lists
    @lists = session[:selected].map { |list_id| trello_client.find(:list, list_id) }
    @board = trello_client.find(:board, @lists[0].board_id)
    @members = @board.members.map { |member| '@' + member.username }
  end

  def get_data
    Object.const_set("CHECKLIST_ITEM_NAME_RGX", /\A((?!(\d+\.\d+\s+\[\S+\]\s*)).)*((#{@members.join('|')})\s+(\d+\.\d+\s+\[\S+\]\s*)+)+\z/)
    Object.const_set("DESC_RGX", /(^(\d+\.\d+\s*((#{@members.join('|')})\s*\[\S*\]\s*)+)+)$/)
    @rows = []
    threads = []
    total_estimated = 0
    total_work = 0
    total_bugfix = 0
    @lists.each do |list|
      list.cards.each do |card|
        threads << Thread.new do
          parsed_name = parse_card_name(card.name)
          total_estimated += parsed_name[:estimated]
          checklists = card.checklists
          desc = card.desc
          valid = check_validity(checklists, desc)
          card_estimated_stat = checklists_estimated_stat(checklists)
          factor_time = nil
          if valid[0]
            equality = check_hours_equality(parsed_name, desc, checklists)
            if equality
              updatable = check_updatable(parsed_name, desc, checklists, card_estimated_stat) || check_estimated_updatable(parsed_name, card_estimated_stat)
              if !updatable
                factor_time = factor_time(desc)
              end
            end
          end
          if factor_time
            factor_time_spent = factor_time[:spent]
            factor_time_bugfix = factor_time[:bugfix]
            factor_time_offhour = factor_time[:offhour]
            total_work += factor_time_spent + factor_time_offhour
            total_bugfix += factor_time_bugfix
          else
            total_work += parsed_name[:spent] + parsed_name[:offhour]
            total_bugfix += parsed_name[:bugfix]
          end
          @rows << {
            id: card.id,
            theme: parsed_name[:theme],
            name: parsed_name[:name],
            estimated: parsed_name[:estimated],
            spent: parsed_name[:spent],
            bugfix: parsed_name[:bugfix],
            offhour: parsed_name[:offhour],
            valid: valid,
            equality: equality,
            updatable: updatable,
            pos: card.pos,
            desc: desc,
            list_name: list.name,
            url: card.short_url,
            pos: card.pos,
            list_pos: list.pos,
            factor_time_spent: factor_time_spent,
            factor_time_bugfix: factor_time_bugfix,
            factor_time_offhour: factor_time_offhour,
          }
        end
      end
    end
    threads.each { |t| t.join }
    @sum = {
      total_estimated: total_estimated,
      total_work: total_work,
      total_bugfix: total_bugfix
    }
    @rows.sort_by! { |row| row[:pos] }
  end

  def parse_card_name(name)
    theme, name, estimated, hours = name.match(CARD_NAME_RGX).captures
    if theme
      theme = THEMES[theme[0...-1].to_sym] || 'UNKNOWN'
    else
      theme = "\u2014"
    end
    if estimated && estimated[1...-1].match(/\A\/?\d*\.?\d*\^?\z/)
      estimated = estimated[1...-1].match(/\A\/?(\d*\.?\d*)\^?\z/)[1].to_f
    else
      estimated = 0
    end
    if hours
      hours = hours[1...-1]
      spent = parse_hours(hours)[0]
      bugfix = parse_hours(hours)[1]
      offhour = parse_hours(hours).last
    else
      hours = 0
      spent = 0
      bugfix = 0
      offhour = 0
    end
    {
      theme: theme,
      name: name,
      estimated: estimated,
      hours: hours,
      spent: spent,
      bugfix: bugfix,
      offhour: offhour
    }
  end

  def parse_hours(hours)
    hours = hours.split('/')
    case hours.size
    when 1
      if hours[0].include?('^')
        [0, 0, hours[0][0...-1].to_f]
      else
        [hours[0].to_f, 0, 0]
      end
    when 2
      if hours[1].include?('^')
        [hours[0].to_f, 0, hours[1][0...-1].to_f]
      else
        [hours[0].to_f, hours[1].to_f, 0]
      end
    when 3
      [hours[0].to_f, hours[1].to_f, hours[2][0...-1].to_f]
    end
  end

  def build_desc(card_stat, desc)
    out = ""
    card_stat.each do |date, date_stat|
      out += date.strftime("%d.%m")
      date_stat.each do |member, hours|
        out += ' ' + member + ' ' + '['
        hours.each do |type, hour|
          if hour != 0
            case type
            when :spent
              out += "%g" % ("%.2f" % hour)
            when :bugfix
              out += '/' + "%g" % ("%.2f" % hour)
            when :offhour
              if out[-1] == '['
                out += "%g" % ("%.2f" % hour) + '^'
              else
                out += '/' + "%g" % ("%.2f" % hour) + '^'
              end
            end
          end
        end
        out += ']'
      end
      out += "\n"
    end
    out = out[0..-2]
    if desc.include?("~~~")
      desc = desc[0..desc.index("~~~") + 2] + "\n" + out
    else
      desc += "\n" + "~~~" + "\n" + out
    end
  end

  def build_name(card_stat, name, card_checklists_estimated)
    estimated = /(\(\d*\.?\d*\))\s*\z/
    estimated_and_hours = /(\(\d*\.?\d*\))\s*\[[\/\d\.\-\^]*\]/
    hours = /\[[\/\d\.\-\^]*\]/
    total = total_card_stat(card_stat)
    if card_checklists_estimated > 0
      if name.match(estimated_and_hours)
        name = name.gsub(name.match(estimated_and_hours).captures[0], "(" + "%g" % ("%.2f" % card_checklists_estimated) + ")")
      elsif name.match(hours)
        hours_index = name.index(name.match(hours)[0])
        name = name[0...hours_index] + "(" + "%g" % ("%.2f" % card_checklists_estimated) + ")"
      elsif name.match(estimated)
        name = name.gsub(name.match(estimated).captures[0], "(" + "%g" % ("%.2f" % card_checklists_estimated) + ")")
      else
        name += " (" + "%g" % ("%.2f" % card_checklists_estimated) + ")"
      end
    end
    if name.match(hours)
      name = name[0...name.index(name.match(hours)[0]) - 1]
    end
    name += " ["
    if total[:spent] != 0
      name += "%g" % ("%.2f" % total[:spent])
    end
    if total[:bugfix] != 0
      name += "/"+ "%g" % ("%.2f" % total[:bugfix])
    end
    if total[:offhour] != 0
      if name[-1] == '['
        name += "%g" % ("%.2f" % total[:offhour]) + "^"
      else
        name += "/" + "%g" % ("%.2f" % total[:offhour]) + "^"
      end
    end
    name += "]"
  end

  def check_for_hours(checklists)
    flag = false
    hours = /\[[\/\d\.\-\^]*\]/
    checklists.each do |checklist|
      checklist.items.each do |item|
        if item.name.match(hours)
          flag = true
        end
      end
    end
    flag
  end

  def check_hours_equality(parsed_name, desc, checklists)
    begin
      checklists_stat = checklists_stat(checklists)
    rescue
    end
    begin
      desc_stat = desc_stat(desc)
    rescue
    end

    if checklists_stat.present? && desc_stat.present?
      desc_stat.each do |member, member_stat|
        if checklists_stat.include?(member)
          member_stat.each do |date, date_stat|
            if checklists_stat[member].include?(date)
              if date_stat[:spent] > checklists_stat[member][date][:spent] ||\
                 date_stat[:bugfix] > checklists_stat[member][date][:bugfix] ||\
                 date_stat[:offhour] > checklists_stat[member][date][:offhour]
                  return false
              end
            else
              return false
            end
          end
        else
          return false
        end
      end
      return total_card_stat(checklists_stat)[:spent] >= parsed_name[:spent] &&\
             total_card_stat(checklists_stat)[:bugfix] >= parsed_name[:bugfix] &&\
             total_card_stat(checklists_stat)[:offhour] >= parsed_name[:offhour]
    elsif checklists_stat.present?
      return total_card_stat(checklists_stat)[:spent] >= parsed_name[:spent] &&\
             total_card_stat(checklists_stat)[:bugfix] >= parsed_name[:bugfix] &&\
             total_card_stat(checklists_stat)[:offhour] >= parsed_name[:offhour]
    elsif desc_stat.present?
      return total_card_stat(desc_stat)[:spent] >= parsed_name[:spent] &&\
             total_card_stat(desc_stat)[:bugfix] >= parsed_name[:bugfix] &&\
             total_card_stat(desc_stat)[:offhour] >= parsed_name[:offhour]
    end
  end

  def check_updatable(parsed_name, desc, checklists, card_estimated_stat)
    begin
      checklists_stat = checklists_stat(checklists)
    rescue
    end
    begin
      desc_stat = desc_stat(desc)
    rescue
    end

    if checklists_stat.present? && desc_stat.present?
      checklists_stat.each do |member, member_stat|
        if desc_stat.include?(member)
          member_stat.each do |date, date_stat|
            if desc_stat[member].include?(date)
              if date_stat[:spent] > desc_stat[member][date][:spent] ||\
                 date_stat[:bugfix] > desc_stat[member][date][:bugfix] ||\
                 date_stat[:offhour] > desc_stat[member][date][:offhour]
                  return true
              end
            else
              return true
            end
          end
        end
      end
      return total_card_stat(checklists_stat)[:spent] > parsed_name[:spent] ||\
             total_card_stat(checklists_stat)[:bugfix] > parsed_name[:bugfix] ||\
             total_card_stat(checklists_stat)[:offhour] > parsed_name[:offhour]
    elsif checklists_stat.present? && !desc_stat.present?
      return true
    elsif checklists_stat.present?
      return total_card_stat(checklists_stat)[:spent] > parsed_name[:spent] ||\
             total_card_stat(checklists_stat)[:bugfix] > parsed_name[:bugfix] ||\
             total_card_stat(checklists_stat)[:offhour] > parsed_name[:offhour]
    elsif desc_stat.present?
      return total_card_stat(desc_stat)[:spent] > parsed_name[:spent] ||\
             total_card_stat(desc_stat)[:bugfix] > parsed_name[:bugfix] ||\
             total_card_stat(desc_stat)[:offhour] > parsed_name[:offhour]
    end

  end

  def check_estimated_updatable(parsed_name, card_estimated_stat)
    estimated = parsed_name[:estimated]
    checklists_estimated = card_estimated_stat
    return false if checklists_estimated == 0
    return estimated < checklists_estimated
  end

  def total_card_stat(card_stat)
    spent = 0
    bugfix = 0
    offhour = 0
    card_stat.each do |member, member_stat|
      member_stat.each do |date, date_stat|
        spent += date_stat[:spent]
        bugfix += date_stat[:bugfix]
        offhour += date_stat[:offhour]
      end
    end
    { spent: spent, bugfix: bugfix, offhour: offhour }
  end

  def checklists_estimated_stat(checklists)
    total_estimated = 0
    estimated_user = /\((\d*\.?\d*)\)\s*(#{@members.join('|')})/
    estimated_no_data = /\A.*\((\d*\.?\d*)\)\z/
    checklists.each do |checklist|
      checklist.items.each do |item|
        if item.name.match(estimated_user)
          total_estimated += item.name.match(estimated_user).captures[0].to_f
        elsif item.name.match(estimated_no_data)
          total_estimated += item.name.match(estimated_no_data).captures[0].to_f
        end
      end
    end
    total_estimated
  end

  def checklists_stat(checklists)
    card_stat = {}
    checklists.each do |checklist|
      checklist.items.each do |item|
        member_stat = item.name.scan(/(#{@members.join('|')})\s*([^@]+)/).to_h
        member_stat.each do |member, date_hours|
          card_stat[member] ||= {}
          date_hours.split.each_slice(2) do |day_hours|
            date = nearest_date(day_hours[0])
            card_stat[member][date] ||= {}
            card_stat[member][date][:spent] ||= 0
            card_stat[member][date][:bugfix] ||= 0
            card_stat[member][date][:offhour] ||= 0
            card_stat[member][date][:spent] += parse_hours(day_hours[1][1...-1])[0]
            card_stat[member][date][:bugfix] += parse_hours(day_hours[1][1...-1])[1]
            card_stat[member][date][:offhour] += parse_hours(day_hours[1][1...-1]).last
          end
        end
      end
    end
    card_stat
  end

  def desc_stat(desc)
    card_stat = {}
    desc = DESC_RGX.match(desc)[0].split("\n")
    desc.each do |line|
      date = nearest_date(line.split[0])
      members_stat = line.scan(/(#{@members.join('|')})\s*([^@]+)/)
      members_stat.each do |member_hours|
        member_hours[1].strip!
        card_stat[member_hours[0]] ||= {}
        card_stat[member_hours[0]][date] ||= {}
        card_stat[member_hours[0]][date][:spent] ||= 0
        card_stat[member_hours[0]][date][:bugfix] ||= 0
        card_stat[member_hours[0]][date][:offhour] ||= 0
        card_stat[member_hours[0]][date][:spent] += parse_hours(member_hours[1][1...-1])[0]
        card_stat[member_hours[0]][date][:bugfix] += parse_hours(member_hours[1][1...-1])[1]
        card_stat[member_hours[0]][date][:offhour] += parse_hours(member_hours[1][1...-1]).last
      end
    end
    card_stat
  end

  def checklists_stat_by_date(checklists)
    card_stat = {}
    checklists.each do |checklist|
      checklist.items.each do |item|
        member_stat = item.name.scan(/(#{@members.join('|')})\s*([^@]+)/).to_h
        member_stat.each do |member, date_hours|
          date_hours.split.each_slice(2) do |day_hours|
            date = nearest_date(day_hours[0])
            card_stat[date] ||= {}
            card_stat[date][member] ||= {}
            card_stat[date][member][:spent] ||= 0
            card_stat[date][member][:bugfix] ||= 0
            card_stat[date][member][:offhour] ||= 0
            card_stat[date][member][:spent] += parse_hours(day_hours[1][1...-1])[0]
            card_stat[date][member][:bugfix] += parse_hours(day_hours[1][1...-1])[1]
            card_stat[date][member][:offhour] += parse_hours(day_hours[1][1...-1]).last
          end
        end
      end
    end
    card_stat = card_stat.sort
    card_stat
  end

  def desc_stat_by_date(desc)
    card_stat = {}
    desc = DESC_RGX.match(desc)[0].split("\n")
    desc.each do |line|
      date = nearest_date(line.split[0])
      members_stat = line.scan(/(#{@members.join('|')})\s*([^@]+)/)
      members_stat.each do |member_hours|
        member_hours[1].strip!
        card_stat[date] ||= {}
        card_stat[date][member_hours[0]] ||= {}
        card_stat[date][member_hours[0]][:spent] ||= 0
        card_stat[date][member_hours[0]][:bugfix] ||= 0
        card_stat[date][member_hours[0]][:offhour] ||= 0
        card_stat[date][member_hours[0]][:spent] += parse_hours(member_hours[1][1...-1])[0]
        card_stat[date][member_hours[0]][:bugfix] += parse_hours(member_hours[1][1...-1])[1]
        card_stat[date][member_hours[0]][:offhour] += parse_hours(member_hours[1][1...-1]).last
      end
    end
    card_stat
  end

  def check_validity(checklists, desc)
    hours = /\[[\/\d\.\-\^]*\]/
    estimated_user = /\(\S+\)\s*(#{@members.join('|')})/
    estimated = /\(\d*\.?\d*\)/
    checklists.each do |checklist|
      checklist.items.each do |item|
        if item.name.match(hours)
          if !item.name.match(CHECKLIST_ITEM_NAME_RGX)
            return [false, "Ошибка в чеклисте: #{item.name}"]
          end
        end
      end
    end
    check_desc(desc)
  end

  def check_desc(desc)
    flag = false
    desc = desc.split("\n")
    flag = true if desc.size >= 0
    hours = /(#{@members.join('|')})\s*\[[\/\d\.\-\^]*\]/
    members = /\@(\w+)\s+\[[\/\d\.\-\^]*\]/
    desc.each do |line|
      if line.match(hours)
        flag = true
        if !line.match(DESC_RGX)
          return [false, "Ошибка в описании"]
        end
      end
    end
    if flag
      return [flag]
    else
      return [flag, "Ошибка в описании"]
    end
  end

  def nearest_date(str)
    require 'date'
    today = Date.today
    date = Date.strptime(str, "%d.%m")
    if today - date < 0
      if date - today < TIME_SLICE
        date = Date.strptime(str + ".#{date.year}", "%d.%m.%Y")
      else
        date = Date.strptime(str + ".#{date.year - 1}", "%d.%m.%Y")
      end
    end
    date
  end

end
