require 'csv'
require 'irb'

anime_list = CSV.read('dataset/anime_with_name.csv')
train_data = CSV.read('dataset/train.csv')
test_data = CSV.read('dataset/test.csv')
genre_list = []

anime_genres = Hash.new
anime_data = Hash.new { |h, k| h[k] = Hash.new }
anime_score_histgram = Hash.new { |h, k| h[k] = Array.new(11, 0) }
studio_list = []
producer_list = []

def aired2int(str)
  str.split.map(&:to_i).max
end

def rating2int(str)
  str.split.map(&:to_i).max
end

def clean_list(str)
  str.split(',').map(&:strip).map(&:downcase)
end

def duration2int(duration)
  if duration == 'Unknown'
    return nil
  else
    time = 0

    duration.split.each_cons(2) do |val, unit|
      if unit =~ /min/
        time += val.to_i
      elsif unit =~ /hr/
        time += 60 * val.to_i
      end
    end

    time
  end
end

def episodes2int(str)
  if str == 'Unknown'
    nil
  else
    str.to_i
  end
end

review_count = Hash.new(0)
total_score = Hash.new(0)

train_data[1..].each do |row|
  user_id, anime_id, score = row
  score = score.to_i

  review_count[anime_id] += 1
  total_score[anime_id] += score
  anime_score_histgram[anime_id][score] += 1
end

anime_list[1..].each do |row|
  anime_id = row[0]
  episodes = episodes2int(row[5])
  producers = row[7]
  studios = row[9]
  plan_to_watch = row[-1].to_i
  dropped = row[-2].to_i
  on_hold = row[-3].to_i
  completed = row[-4].to_i
  watching = row[-5].to_i
  members = row[-6].to_i
  genres = clean_list(row[1])

  studio_list << clean_list(studios)
  producer_list << clean_list(producers)

  anime_data[anime_id] = {
    episodes: episodes,
    aired: aired2int(row[6]),
    duration: duration2int(row[11]),
    plan_to_watch: plan_to_watch,
    dropped: dropped,
    on_hold: on_hold,
    completed: completed,
    watching: watching,
    watch_rate_by_members: watching / [1.0, members.to_f].max,
    watch_rate_by_completed: watching / [1.0, completed.to_f].max,
    watch_rate_by_on_hold: watching / [1.0, on_hold.to_f].max,
    watch_rate_by_dropped: watching / [1.0, dropped.to_f].max,
    watch_rate_by_plan_to_watch: watching / [1.0, plan_to_watch.to_f].max,
    comp_rate_by_members: completed / [1.0, members.to_f].max,
    comp_rate_by_watching: completed / [1.0, watching.to_f].max,
    comp_rate_by_on_hold: completed / [1.0, on_hold.to_f].max,
    comp_rate_by_dropped: completed / [1.0, dropped.to_f].max,
    comp_rate_by_plan_to_watch: completed / [1.0, plan_to_watch.to_f].max,
    drop_rate_by_members: dropped / [1.0, members.to_f].max,
    drop_rate_by_watching: dropped / [1.0, watching.to_f].max,
    drop_rate_by_on_hold: dropped / [1.0, on_hold.to_f].max,
    drop_rate_by_completed: dropped / [1.0, completed.to_f].max,
    drop_rate_by_plan_to_watch: dropped / [1.0, plan_to_watch.to_f].max,
    hold_rate_by_members: on_hold / [1.0, members.to_f].max,
    hold_rate_by_watching: on_hold / [1.0, watching.to_f].max,
    hold_rate_by_dropped: on_hold / [1.0, dropped.to_f].max,
    hold_rate_by_completed: on_hold / [1.0, completed.to_f].max,
    hold_rate_by_plan_to_watch: on_hold / [1.0, plan_to_watch.to_f].max,
    review_score: review_count[anime_id] < 10 ? nil : total_score[anime_id] / review_count[anime_id].to_f,
    review_count: review_count[anime_id],
  }
  anime_genres[anime_id] = genres
  genre_list |= genres
end

studio_list = studio_list.flatten.uniq.sort
studio_ids = Hash.new
studio_list.each.with_index(1) do |name, id|
  studio_ids[name] = id
end

producer_list = producer_list.flatten.uniq.sort
producer_ids = Hash.new
producer_list.each.with_index(1) do |name, id|
  producer_ids[name] = id
end

genre_list = genre_list.map(&:downcase)
genre_list.sort!
genre_idx = Hash.new
genre_list.each_with_index do |name, id|
  genre_idx[name] = id
end

labels = [
  anime_list[0],
  'main_producer',
  'main_studio',
  'watch_rate_by_members',
  'watch_rate_by_completed',
  'watch_rate_by_on_hold',
  'watch_rate_by_dropped',
  'watch_rate_by_plan_to_watch',
  'comp_rate_by_members',
  'comp_rate_by_watching',
  'comp_rate_by_on_hold',
  'comp_rate_by_dropped',
  'comp_rate_by_plan_to_watch',
  'drop_rate_by_members',
  'drop_rate_by_watching',
  'drop_rate_by_on_hold',
  'drop_rate_by_completed',
  'drop_rate_by_plan_to_watch',
  'hold_rate_by_members',
  'hold_rate_by_watching',
  'hold_rate_by_dropped',
  'hold_rate_by_completed',
  'hold_rate_by_plan_to_watch',
  'review_score',
  'review_count',
  (1..10).map { |x| "anime_#{x}_review_count" },
  (1..10).map { |x| "anime_#{x}_review_rate" },
  genre_list,
].flatten

File.open('dataset/anime_rebuild.csv', 'w') do |file|
  file.puts(labels.join(','))

  anime_list[1..].each do |row|
    anime_id = row[0]
    genres = clean_list(row[1])
    producers = clean_list(row[7])
    studios = clean_list(row[9])
    check_list = genre_list.map { |genre| genres.include?(genre) ? 1 : 0 }
    review_count = anime_data[anime_id][:review_count]
    row[5] = anime_data[anime_id][:episodes]
    row[6] = anime_data[anime_id][:aired]
    row[11] = anime_data[anime_id][:duration]

    row << producer_ids[producers.flatten.first]
    row << studio_ids[studios.flatten.first]
    row << anime_data[anime_id][:watch_rate_by_members]
    row << anime_data[anime_id][:watch_rate_by_completed]
    row << anime_data[anime_id][:watch_rate_by_on_hold]
    row << anime_data[anime_id][:watch_rate_by_dropped]
    row << anime_data[anime_id][:watch_rate_by_plan_to_watch]
    row << anime_data[anime_id][:comp_rate_by_members]
    row << anime_data[anime_id][:comp_rate_by_watching]
    row << anime_data[anime_id][:comp_rate_by_on_hold]
    row << anime_data[anime_id][:comp_rate_by_dropped]
    row << anime_data[anime_id][:comp_rate_by_plan_to_watch]
    row << anime_data[anime_id][:drop_rate_by_members]
    row << anime_data[anime_id][:drop_rate_by_watching]
    row << anime_data[anime_id][:drop_rate_by_on_hold]
    row << anime_data[anime_id][:drop_rate_by_completed]
    row << anime_data[anime_id][:drop_rate_by_plan_to_watch]
    row << anime_data[anime_id][:hold_rate_by_members]
    row << anime_data[anime_id][:hold_rate_by_watching]
    row << anime_data[anime_id][:hold_rate_by_dropped]
    row << anime_data[anime_id][:hold_rate_by_completed]
    row << anime_data[anime_id][:hold_rate_by_plan_to_watch]
    row << anime_data[anime_id][:review_score]
    row << review_count
    row.concat((1..10).map { |x| anime_score_histgram[anime_id][x] })
    row.concat((1..10).map { |x| review_count == 0 ? nil : anime_score_histgram[anime_id][x] / review_count.to_f })
    row.concat(check_list)

    if labels.size != row.size
      raise
    end

    file.puts(row.to_csv)
  end
end
